local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.filters = {}

--[[
    In past versions, roster+filters+petlist were combined into a huge intertwined mess. Going forward, just as roster is
    now a data source and that's it, filters now manages filters and that's it. All filters are set, reset and cleared
    via these functions:

        rematch.filters:Set(filterGroup,key,value)
        rematch.filters:Clear(filterGroup)

    With these supporting functions:

        rematch.filters:WhatsFiltered() -- returns a comma-delimited list of filters currently active
        rematch.fitlers:ShouldPetDisplay(petID) -- returns true if given petID/speciesID meets all active filters

    To add new filters:
    - Add an entry to filterGroups below. (All filters must be in that table and have a unique filterKey.)
    - Add a rematch.filters.funcs[filterGroup], where self is the petInfo of a pet to evaluate, that returns true if the pet should list and false otherwise
    - If a function needs to run before a filter run (to set up temp tables and such), create a rematch.filters.preFuncs[filterGroup]
]]

-- this is a list of tables where filter settings are saved in settings.Filters and the localized
-- name of the table (the latter for displaying a summary of what's being filtered)

-- all filters belong in a group, listed here in the order that the filter check should happen
local filterGroups = {
    -- {filterkey,localized_name},
    {"Search",SEARCH},
    {"Stats",L["Stats"]},
    {"Collected",COLLECTED},
    {"Favorite",L["Favorites"]},
    {"Types",L["Types"]},
    {"Strong",L["Strong Vs"]},
    {"Tough",L["Tough Vs"]},
    {"Sources",L["Sources"]},
    {"Rarity",RARITY},
    {"Breed",L["Breed"]},
    {"Level",LEVEL},
    {"Marker",L["Pet Marker"]},
    {"Other",OTHER},
    {"Similar",L["Similar"]},
    {"Script",L["Script"]},
    {"Moveset",L["Moveset"]}, -- this is a specific moveset (moveset level is under leve, and unique/shared is under other/moveset)
    {"Expansion",EXPANSION_FILTER_TEXT},
    {"Sort",L["Sort"]},
}

-- for use with GetFilterList, to give other sub-groups a name
local otherGroups = {
    {"Leveling",L["Leveling"]},
    {"Tradable",L["Tradable"]},
    {"Battle",L["Battle"]},
    {"Quantity",L["Quantity"]},
    {"Team",L["Team"]},
    {"Moveset",L["Moveset"]}, -- this is unique/shared moveset; specific moveset or moveset level are their own groups
    {"HasNotes",L["Notes"]},
    {"Hidden",L["Hidden"]},
    {"CurrentZone",L["Zone"]},
}

-- the filtered list of petIDs/speciesIDs when the current filters are applied
local filteredPetList = {}

-- populated by rematch.filters:UpdateFiltersUsed(), ordered list of the above filterGroups that are not empty
local filtersUsed = {}
_filtersUsed = filtersUsed

-- dirty flag becomes true when the filtered list should be rebuilt (any filters change); if false then no need to re-run a filter
local dirty = true

local strongVsCache = rematch.odTable:Create() -- on-demand table to cache strongvs results
local strongNeeded = {} -- reused table to track which strong vs have passed
local searchRelevance = {} -- cache for search results of petID/speciesIDs
local abilityRelevance = rematch.odTable:Create() -- cache for search results of abilities
local sortStats = {} -- as pets pass evaluation, save the chosen sort stat here
local favoritesCache = {} -- lookup table of petIDs that are favorited for sort purposes

-- for parsing searches, use localized terms (or non-localized h, p, s and l for shorter version)
local searchStats = {
    [PET_BATTLE_STAT_HEALTH:lower()]="Health", [PET_BATTLE_STAT_POWER:lower()]="Power",
	[PET_BATTLE_STAT_SPEED:lower()]="Speed", [LEVEL:lower()]="Level", ["health"]="Health", ["power"]="Power",
	["speed"]="Speed", ["level"]="Level", ["h"]="Health", ["p"]="Power", ["s"]="Speed", ["l"]="Level"
}

local currentZone -- while Other -> Current Zone is enabled, this will update to the current zone the player is in (nil if not watching)

-- indexed by filter name (filterGroup[index][1]), the functions to run for each filterGroup (rematch.filters.funcs.Search, rematch.filters.funcs.Stats, etc.)
rematch.filters.funcs = {}
-- for filters that need to do something before a filter pass, create a function here (rematch.filters.preFuncs.Moveset)
rematch.filters.preFuncs = {}
-- for filters that need to do something after a filter pass, create a function here (rematch.filters.postFuncs.Search)
rematch.filters.postFuncs = {}


-- on login, make sure settings.Filters savedvar is set up properly
rematch.events:Register(rematch.filters,"PLAYER_LOGIN",function(self)
    -- make sure the Filters table is a table
    if type(settings.Filters)~="table" then
        settings.Filters = {}
    end
    -- and that all filterGroups are present
    for _,info in pairs(filterGroups) do
        if not settings.Filters[info[1]] or type(settings.Filters[info[1]])~="table" then
            settings.Filters[info[1]] = {}
        end
    end
end)

--[[ filter manipulation ]]

-- sets a filterGroup key to the given value
function rematch.filters:Set(filterGroup,key,value)
    assert(filterGroup,"invalid filterGroup")
    if value==false then -- the emptiness of a filterGroup depends on no keys, so no false allowed
        value = nil
    end
    settings.Filters[filterGroup][key] = value
    dirty = true
end

-- returns the current value of the filterGroup key
function rematch.filters:Get(filterGroup,key)
    return settings.Filters[filterGroup][key]
end

-- returns true if the filterGroup has no keys turned on
function rematch.filters:IsClear(filterGroup)
    if filterGroup=="Sort" and not settings.ResetSortWithFilters then -- ignore Sort unless Reset Sort With Filters checked
        return true
    end
    return (not next(settings.Filters[filterGroup])) and true
end

-- returns true if the filterGroup only has the given key enabled and no others
function rematch.filters:HasJust(filterGroup,key)
    local found = false
    for k,v in pairs(settings.Filters[filterGroup]) do
        if k~=key then -- a key other than the one given is enabled, fails
            return false
        else -- key we're looking for is enabled, but not done looking until all enabled keys checked
            found = true
        end
    end
    return found
end

-- clears a specific filterGroup
function rematch.filters:Clear(filterGroup)
    if filterGroup and settings.Filters[filterGroup] then
        wipe(settings.Filters[filterGroup])
    end
    dirty = true
end

-- clears all filterGroups
function rematch.filters:ClearAll()
    for _,info in ipairs(filterGroups) do
        if info[1]=="Sort" and not settings.ResetSortWithFilters then
            -- do nothing if clearing Sort and Reset Sort With Filters is unchecked
        elseif info[1]=="Search" and settings.ResetExceptSearch then
            -- do nothing if clearing Search and Don't Reset Search With Filters is checked
        else
            rematch.filters:Clear(info[1])
        end
    end
    dirty = true
end

-- sets dirty flag to force a rebuild of the list
function rematch.filters:ForceUpdate()
    dirty = true
end

-- returns true if all filterGroups are clear
function rematch.filters:IsAllClear()
    for _,info in ipairs(filterGroups) do
        if not rematch.filters:IsClear(info[1]) then
            return false
        end
    end
    return true
end

-- returns the filters used in a comma-separated list, like "Search, Collected, Strong Vs"
-- also returns true/false if search is the only filter being used
function rematch.filters:GetFilterList(filters)
    local list = ""
    if not filters then -- if no filters table provided, then use current filters
        filters = settings.Filters
    end
    for _,info in ipairs(filterGroups) do
        local filterGroup,filterName = info[1],info[2]
        if filterName and filterGroup and filters[filterGroup] then
            if filterGroup=="Sort" and not settings.ResetSortWithFilters then
                -- while Sort always exists in filter, only need to list it when sort is reset with filters
            elseif next(filters[filterGroup]) then -- this filterGroup has something in it, it should be listed
                if filterGroup=="Other" then -- for "Other" filterGroup, list out individual subgroups
                    for _,other in ipairs(otherGroups) do
                        local otherGroup,otherName = other[1],other[2]
                        if filters.Other[otherGroup] then
                            list = list..otherName..", "
                        end
                    end
                else -- for all other groups, add the name of the filterGroup to the list
                    list = list..filterName..", "
                end
            end
        end
    end
    list = list:gsub(", $","")
    return list,list==SEARCH
end


--[[ Special Filters ]]

function rematch.filters:SetSimilarFilter(speciesID)
    rematch.filters:ClearAll()
    local abilityList = rematch.petInfo:Fetch(speciesID).abilityList
    if abilityList then
        for _,abilityID in pairs(abilityList) do
            rematch.filters:Set("Similar",abilityID,true)
        end
    end
end

function rematch.filters:SetMovesetFilter(speciesID)
    rematch.filters:ClearAll()
    local moveset = rematch.petInfo:Fetch(speciesID).moveset
    if moveset then
        rematch.filters:Set("Moveset",moveset,true)
    end
end


--[[ Search Filter Parsing ]]

function rematch.filters:SetSearch(text)
    -- wipe any existing search; this will set dirty flag too
    rematch.filters:Clear("Search")
    rematch.filters:Clear("Stats")
    if not text or text:len()==0 then -- no search text, leave
        return
    end
    settings.Filters.RawSearchText = text -- before any parsing/changes are done, keep the original text
    -- pull out any stat operations and put them into Stats filterGroup (in the gsub function)
    text = text:gsub("(%w+[<>=]%d+)",rematch.filters.ParseStatOperators)
    text = text:gsub("(%w+=%d+%-%d)",rematch.filters.ParseStatRange)
    text = text:gsub("([<>=]%d+)",rematch.filters.ParseLegacyLevelOperators)
    text = text:gsub("(%d+%-%d+)",rematch.filters.ParseLegacyLevelRange)
    text = text:trim()
    -- any remaining text is intended for a traditional search
    if text:len()>0 then
        local pattern = rematch.utils:DesensitizeText(text)
        if pattern:match("^\".-\"$") then -- if there are quotes around remaing search term, this is an ^exact search$
            pattern = "^"..pattern:gsub("^\"",""):gsub("\"$","").."$" -- strip out quotes and append ^ and $
        end
        rematch.filters:Set("Search","Pattern",pattern)
        rematch.filters:Set("Search","Length",text:len())
    end
end

-- =25 or >17 or <23 by themselves can be used in place of level=25, level>17, level<23
function rematch.filters.ParseLegacyLevelOperators(capture)
    local operator,value = capture:match("^([<>=])(%d+)$")
    value = tonumber(value)
    if operator and value then
        if operator=="=" then rematch.filters:Set("Stats","Level",{value,value}) return "" end
        if operator=="<" then rematch.filters:Set("Stats","Level",{1,value-1}) return "" end
        if operator==">" then rematch.filters:Set("Stats","Level",{value+1,25}) return "" end
    end
end

-- 8-15 by itself can be used in place of level=8-15
function rematch.filters.ParseLegacyLevelRange(capture)
    local low,high = capture:match("^(%d+)%-(%d+)$")
    low = tonumber(low)
    high = tonumber(high)
    if low and high then rematch.filters:Set("Stats","Level",{low,high}) return "" end
end

-- level=25 or power>230 or speed<230 or health>1000
function rematch.filters.ParseStatOperators(capture)
    local stat,operator,value = capture:match("^(%w+)([<>=])(%d+)$")
    value = tonumber(value)
    if stat and value then
        stat = searchStats[(stat or ""):lower()]
        if stat then
            if operator=="=" then rematch.filters:Set("Stats",stat,{value,value}) return "" end
            if operator=="<" then rematch.filters:Set("Stats",stat,{1,value-1}) return "" end
            if operator==">" then rematch.filters:Set("Stats",stat,{value+1,9999}) return "" end
        end
    end
end

-- level=13-14 or health=1500-2300 or speed=100-200 or power=137-874
function rematch.filters.ParseStatRange(capture)
    local stat,low,high = capture:match("^(%w+)=(%d+)%-(%d+)")
    low = tonumber(low)
    high = tonumber(high)
    if low and high then
        stat = searchStats[(stat or ""):lower()]
        if stat then rematch.filters:Set("Stats",stat,{low,high}) return "" end
    end
end


--[[ filter functions ]]

-- Collected/Not Collected is unique in that a filter value (Collected.Owned) means DO NOT list these pets (since default is to list all of them, they will remain checked in default state)
function rematch.filters.funcs:Collected(petInfo)
    local idType = petInfo.idType
    if self.Owned and idType=="pet" then -- if Collected is unchecked (this one is reverse) and this is a collected pet, don't list
        return false
    elseif self.Missing and idType=="species" then -- if Not Collected is unchecked (this is reverse too) and this is an uncollected speciesID, don't list
        return false
    end
    return true
end

-- Only Favorites will only list favorited pets
function rematch.filters.funcs:Favorite(petInfo)
    return petInfo.isFavorite
end

-- Pet Families/pet type is a list of 1-10 petTypes
function rematch.filters.funcs:Types(petInfo)
    return self[petInfo.petType]
end

-- Strong Vs will return true only if every chosen Strong Vs pet type is strong against the chosen types (can be more than one)
-- self (like all these other filters.funcs) is the filter's table, {[2]=true,[10]=true} is strong vs dragonkin and mechanical
function rematch.filters.funcs:Strong(petInfo)
    if not settings.StrongVsLevel then -- if Pet Filter Options: Use Level In Strong Vs Filter is unchecked, we can use a cache to speed this up
        local speciesID = petInfo.speciesID
        if not speciesID then
            return false
        elseif strongVsCache[speciesID]==nil then -- this speciesID has not been tested yet
            -- to make sure all strong vs are accounted for, copy the filter into this reused strongNeeded
            wipe(strongNeeded)
            for petType in pairs(self) do
                strongNeeded[petType] = true
            end
            -- next nil out the strongNeeded that have a strongVs
            for abilityID,strongVsType in pairs(petInfo.strongVs) do
                strongNeeded[strongVsType] = nil -- this will nil other strong types that are already nil that we don't care about
            end
            if next(strongNeeded) then -- something is left in the strongNeeded table, not all strong vs passed; fail pet
                strongVsCache[speciesID] = false
            else -- nothing remains in strongNeeded table, so this pet passes
                strongVsCache[speciesID] = true
            end
        end
        return strongVsCache[speciesID]
    else -- Pet Filter Options: Use Level In Strong Filter is checked; need to check every pet since they can be different levels
        if not petInfo.isOwned then
            return false -- unowned pets can't be high enough level, immediately leave
        end
        wipe(strongNeeded)
        for petType in pairs(self) do
            strongNeeded[petType] = true
        end
        for abilityID,strongVsType in pairs(petInfo.strongVs) do
            if petInfo.usableAbilities[abilityID] then
                strongNeeded[strongVsType] = nil
            end
        end
        return not next(strongNeeded) -- if nothing left in strongNeeded table, return true (list pet) otherwise false (don't list pet)
    end
end

-- Tough Vs submenu
function rematch.filters.funcs:Tough(petInfo)
    return self[petInfo.toughVs]
end

-- Rarity submenu
function rematch.filters.funcs:Rarity(petInfo)
    return self[petInfo.rarity]
end

function rematch.filters.funcs:Expansion(petInfo)
    return self[petInfo.expansionID]
end

-- Level submenu
function rematch.filters.funcs:Level(petInfo)
    if not petInfo.canBattle then
        return false -- pets that can't battle never show in level filters
    end
    if self.MovesetNot25 and petInfo.isMovesetAt25 then
        return false -- Moveset Not At 25 is checked and pet has a moveset at 25, fail
    end
    if self.Without25s and petInfo.isSpeciesAt25 then
        return false -- Without Any 25s is checked and pet has a version at 25, fail
    end
    if self[1] or self[2] or self[3] or self[4] then
        local level = petInfo.level or 0
        if self[1] and level>0 and level<8 then
            return true
        end
        if self[2] and level>7 and level<15 then
            return true
        end
        if self[3] and level>14 and level<25 then
            return true
        end
        if self[4] and level==25 then
            return true
        end
        -- one of the level ranges was checked but all ranges failed, fail
        return false
    end
    -- no level range was used and reached here, success
    return true
end

function rematch.filters.funcs:Sources(petInfo)
    return self[petInfo.sourceID]
end

function rematch.filters.funcs:Breed(petInfo)
    local breed = petInfo.breedID
    if breed==0 then
        breed = 13 -- for filters, 3-12 is the breeds and 13 is NEW
    end
    return self[breed]
end

-- Similar filter finds any pets that have at least 3 of the same abilities
function rematch.filters.funcs:Similar(petInfo)
    local abilityList = petInfo.abilityList
    local numMatches = 0
    if abilityList then
        for _,abilityID in pairs(abilityList) do
            if self[abilityID] then
                numMatches = numMatches + 1
                if numMatches==C.SIMILIAR_FILTER_THRESHHOLD then
                    return true
                end
            end
        end
    end
    return false
end

-- Moveset filter finds all pets that have the exact same moveset
function rematch.filters.funcs:Moveset(petInfo)
    return self[petInfo.moveset]
end

-- pre-func for Script filters sets up the script environment to run the Code
function rematch.filters.preFuncs:Script()
    rematch.scriptFilter:SetupEnvironment()
end

-- Script filter will evaluate the pet against the rematch.scriptFilter environment
function rematch.filters.funcs:Script(petInfo)
    return rematch.scriptFilter:Evaluate(petInfo)
end

-- Pet Marker is 1-8 for actual marks or 9 for 'None'; though speciesIDs without a mark have nil in settings.PetMarkers
function rematch.filters.funcs:Marker(petInfo)
    local marker = petInfo.marker or 9
    return self[marker]
end

-- "Other" filter group has many radio button options. rather than run a gauntlet over each, only enabled ones are checked
-- by looping over the enabled filters and running their separate functions
function rematch.filters.funcs:Other(petInfo)
    local otherFuncs = rematch.filters.otherFuncs
    for key,value in pairs(self) do
        if otherFuncs[key] and not otherFuncs[key](self,petInfo,value) then
            return false
        end
    end
    return true
end

--[[ Other filter funcs ]]

-- "Other" sub-functions, where name of function is the key in the "Other" filter group and value is the value of the key
rematch.filters.otherFuncs = {}

-- Other -> Leveling (Leveling, NotLeveling)
function rematch.filters.otherFuncs:Leveling(petInfo,value)
    if value=="Leveling" and not petInfo.isLeveling then
        return false
    elseif value=="NotLeveling" and petInfo.isLeveling then
        return false
    end
    return true
end

-- Other -> Tradable (Tradable, NotTradable)
function rematch.filters.otherFuncs:Tradable(petInfo,value)
    if value=="Tradable" and not petInfo.isTradable then
        return false
    elseif value=="NotTradable" and petInfo.isTradable then
        return false
    end
    return true
end

-- Other -> Battle (Battle, NotBattle)
function rematch.filters.otherFuncs:Battle(petInfo,value)
    if value=="Battle" and not petInfo.canBattle then
        return false
    elseif value=="NotBattle" and petInfo.canBattle then
        return false
    end
    return true
end

-- Other -> Quantity (Qty1, Qty2, Qty3)
function rematch.filters.otherFuncs:Quantity(petInfo,value)
    local count = petInfo.count or 0
    if value=="Qty3" and count<3 then
        return false
    elseif value=="Qty2" and count<2 then
        return false
    elseif value=="Qty1" and count~=1 then
        return false
    end
    return true
end

-- Other -> Team (InTeam, NotInTeam)
function rematch.filters.otherFuncs:Team(petInfo,value)
    if value=="InTeam" and not petInfo.inTeams then
        return false
    elseif value=="NotInTeam" and petInfo.inTeams then
        return false
    end
    return true
end

-- Other -> Moveset (UniqueMoveset, SharedMoveset)
function rematch.filters.otherFuncs:Moveset(petInfo,value)
    local moveset = petInfo.moveset
    if not petInfo.canBattle or not moveset then
        return false -- not going to count pets that can't battle
    end
    local isUnique = rematch.collectionInfo:IsMovesetUnique(moveset)
    if value=="UniqueMoveset" and not isUnique then
        return false
    elseif value=="SharedMoveset" and isUnique then
        return false
    end
    return true
end

-- Other -> Has Notes (value is implicitly true if this filter is enabled)
function rematch.filters.otherFuncs:HasNotes(petInfo)
    return petInfo.hasNotes
end

-- Other -> Hidden Pets (value is implicitly true if this filter is enabled)
function rematch.filters.otherFuncs:Hidden(petInfo)
    local speciesID = petInfo.speciesID
    return speciesID and settings.HiddenPets[speciesID] or false
end

-- Other -> Current Zone (value is implicitly true if this filter is enabled)
-- in addition, to track zone changes, use of this filter will start watching for ZONE_CHANGED_NEW_AREA if not already
function rematch.filters.otherFuncs:CurrentZone(petInfo)
    if not currentZone then -- if this is the first filter run where filter is enabled, turn on zone updates
        rematch.events:Register(rematch.filters,"ZONE_CHANGED_NEW_AREA",rematch.filters.ZONE_CHANGED_NEW_AREA)
        currentZone = GetRealZoneText() or ""
    end
    if currentZone~="" and petInfo.sourceText and petInfo.sourceText:match(GetRealZoneText()) then
        return true
    else
        return false
    end
end

-- new zone isn't immediately available on ZONE_CHANGED_NEW_AREA; on zone change wait a second before updating
function rematch.filters:ZONE_CHANGED_NEW_AREA()
    if rematch.filters:Get("Other","CurrentZone") then -- if Current Zone filter enabled
        rematch.timer:Start(1,rematch.filters.UpdateCurrentZone) -- wait a second and update currentZone
    else -- filter is no longer enabled, stop watching for zone updates
        rematch.events:Unregister(rematch.filters,"ZONE_CHANGED_NEW_AREA")
        currentZone = nil -- nil currentZone
    end
end

-- this runs 1.0 second after zoning into a new area while Other -> Current Zone is enabled
function rematch.filters:UpdateCurrentZone()
    currentZone = GetRealZoneText() or ""
    rematch.filters:ForceUpdate() -- set dirty flag so next filter will run
    if rematch.petsPanel:IsVisible() then -- and if pet list on screen then do a filter run now
        rematch.petsPanel:Update()
    end
end

--[[ Searchbox filters ]]

-- Stats is generated from the search filters (SetSearch and the Parse gsub functions) and confirms the defined
-- stats are within the defined ranges
function rematch.filters.funcs:Stats(petInfo)
    if not petInfo.isOwned or not petInfo.canBattle then
        return -- all pets with stat searches must be collected pets that can battle
    end
    if self.Level then
        local level,low,high = petInfo.level,self.Level[1],self.Level[2]
        if level<low or level>high then return false end
    end
    if self.Health then
        local health,low,high = petInfo.maxHealth,self.Health[1],self.Health[2]
        if health<low or health>high then return false end
    end
    if self.Power then
        local power,low,high = petInfo.power,self.Power[1],self.Power[2]
        if power<low or power>high then return false end
    end
    if self.Speed then
        local speed,low,high = petInfo.speed,self.Speed[1],self.Speed[2]
        if speed<low or speed>high then return false end
    end
    return true
end

-- after a filter pass, wipe the caches used
function rematch.filters.postFuncs:Search()
    wipe(searchRelevance)
    wipe(abilityRelevance)
end

-- for now doing a single term search
function rematch.filters.funcs:Search(petInfo)
    local pattern = self.Pattern
    local length = self.Length
    local match = rematch.utils.match
    local speciesID = petInfo.speciesID

    -- if petInfo is invalid (perhaps pet in roster just released)
    if not petInfo or not petInfo.name then
        return false
    end

    -- customName is the only searchable attribute that can differ within a species, and has highest relevance
    if match(self,pattern,petInfo.customName) then
        -- petID is unique so no need to check for already-cached version, but cache regardless for future sort
        searchRelevance[petInfo.petID] = petInfo.customName:len()==length and 1 or 2
        return true
    end

    -- the rest of the matches are specific to all versions of the speciesID

    -- check cached results to see if species was evaluated yet, return its results if so
    if searchRelevance[speciesID]~=nil then
        return searchRelevance[speciesID]
    end

    -- speciesID results have not been cached, run the gauntlet

    -- speciesName relevance 3 or 4
    if match(self,pattern,petInfo.speciesName) then
        searchRelevance[speciesID] = petInfo.speciesName:len()==length and 3 or 4
        return true
    end

    -- notes relevance 5 or 6
    if match(self,pattern,petInfo.notes) then
        searchRelevance[speciesID] = petInfo.notes:len()==length and 5 or 6
        return true
    end

    if petInfo.abilityList then
        -- ability name relevant 7-8, abilityDescription relevance 9-10
        for _,abilityID in ipairs(petInfo.abilityList) do
            local searchAbilityID = abilityRelevance[abilityID]
            if searchAbilityID then -- if already encountered this abilityID and it was a match no need to keep looking
                searchRelevance[speciesID] = searchAbilityID
                return true
            elseif searchAbilityID==nil then -- this ability's result hasn't been cached yet
                local _,name,_,_,description = C_PetBattles.GetAbilityInfoByID(abilityID)
                -- ability name match: relevance 7-8
                if match(self,pattern,name) then
                    local relevance = name:len()==length and 7 or 8
                    searchRelevance[speciesID] = relevance
                    abilityRelevance[abilityID] = relevance -- cache in both places, abilityID can be used by difference species
                    return true
                end
                --  ability description match: relevance 9-10
                if match(self,pattern,description) then
                    local relevance = name:len()==length and 9 or 10
                    searchRelevance[speciesID] = relevance
                    abilityRelevance[abilityID] = relevance
                    return true
                end
            end
            -- if we reached here, the abilityID wasn't a match, cache it as such
            abilityRelevance[abilityID] = false
        end
    end

    -- sourceText (lore) relevance 11 or 12
    if match(self,pattern,petInfo.sourceText) then
        searchRelevance[speciesID] = petInfo.sourceText:len()==length and 11 or 12
        return true
    end

    -- finished search gauntlet; this pet had no matches and should not list
    searchRelevance[speciesID] = false -- cache it as such
    return false
end

--[[ pre-filter run ]]

-- prior to filtering all pets, do some housekeeping, which includes running preFuncs if any are needed
function rematch.filters:PreRun()
    -- update filtersUsed so we don't waste time evaluating unused filters
    wipe(filtersUsed)
    for _,info in ipairs(filterGroups) do
        if not rematch.filters:IsClear(info[1]) then
            tinsert(filtersUsed,info[1])
        end
    end
    -- reset petInfo in case anything lingering from execution path we're on
    rematch.petInfo:Reset()
    -- run preFuncs for each active filterGroup, if it has one
    for _,filterGroup in ipairs(filtersUsed) do
        local func = rematch.filters.preFuncs[filterGroup]
        if func then
            func(settings.Filters[filterGroup])
        end
    end
    -- empty the current filteredPetList
    wipe(filteredPetList)
    -- set up sort for gathering cache info
    rematch.sort:PrepareSort()
end

-- after filtering all pets, do cleanup housekeeping, such as wiping cache tables
function rematch.filters:PostRun()
    -- run any postFuncs
    for _,filterGroup in ipairs(filtersUsed) do
        local func = rematch.filters.postFuncs[filterGroup]
        if func then
            func(settings.Filters[filterGroup])
        end
    end
    -- wipe sort caches
    rematch.sort:Cleanup()
    -- the filtered list doesn't need re-evaluated if this dirty flag doesn't change
    dirty = false
    -- all done!
end

--[[ evaluate ]]

-- returns true if the given petInfo should display in the pet list given the current filters; false otherwise
function rematch.filters:Evaluate(petInfo)

    -- this is an option and not a filter; Pet Filter Options: Hide Non-Battle Pets; to never list companion pets that can't battle
    if settings.HideNonBattlePets and not petInfo.canBattle then
        return false
    end

    -- if Allow Hidden Pets is enabled and this pet is hidden, don't list it
    if settings.AllowHiddenPets then
        local speciesID = petInfo.speciesID
        if speciesID and settings.HiddenPets[speciesID] and not rematch.filters:Get("Other","Hidden") then
            return false
        end
    end

    for _,filterGroup in ipairs(filtersUsed) do
        local func = rematch.filters.funcs[filterGroup]
        if func then
            if not func(settings.Filters[filterGroup],petInfo) then -- if filter function returns false, this pet should not list
                return false -- immediately return; no need to test other filters
            end
        end
    end
    -- if we made it through the gauntlet of active filters without a fail, this pet passes
    return true
end

-- runs all filters and returns an ordered list of petID/speciesIDs that meet all filters
-- force is true to ignore the dirty flag and do a filter run regarldess whether any data has changed
function rematch.filters:RunFilters(force)
    if not dirty and not force then -- if we already did this work and nothing has changed since, return the same filtered list
        return filteredPetList
    end
    -- do housekeeping before evaluating pets
    rematch.filters:PreRun()
    -- evaluate each pet in the roster to see if it should list
    for petID in rematch.roster:AllPets() do
        local petInfo = rematch.petInfo:Fetch(petID)
        if rematch.filters:Evaluate(petInfo) then
            tinsert(filteredPetList,petID)
            rematch.sort:AddSortValues(petID)
        end
    end
    -- filteredPetList is the filtered list of pets; now sort them
    rematch.sort:RunSort(filteredPetList)
    -- do cleanup after evaluating and sorting pets
    rematch.filters:PostRun()
    return filteredPetList
end

-- returns a reference to searchRelevance lookup table if a search is happening; nil otherwise
function rematch.filters:GetSearchRelevance()
    if not rematch.filters:IsClear("Search") then
        return searchRelevance
    end
end

--[[ Sort ]]

-- the default sorts are: C.SORT_NAME, then C.SORT_LEVEL, finally C.SORT_RARITY
-- a nil sortKey means to use the default sort for that level (the goal is to have an empty settings.Filters.Sort for all defaults)
-- setting a sort should also set the subsorts to their default value; except when that sort is already used by a higher sort
-- (in this case use the first numerical sortKey 1-8 that's not used)
function rematch.filters:SetSort(sortLevel,sortKey)
    if sortLevel==1 then
        if sortKey==C.SORT_DEFAULT_LEVEL_1 then -- default for level 1 sort is C.SORT_NAME
            settings.Filters.Sort[sortLevel] = nil
        else
            settings.Filters.Sort[sortLevel] = sortKey
        end
        -- when setting a sortLevel 1 sort, clear the subsorts so it will pick up defaults
        settings.Filters.Sort[2] = nil
        settings.Filters.Sort[3] = nil
        settings.Filters.Sort[-2] = nil -- clear the subsort's reverse sort setting too
        settings.Filters.Sort[-3] = nil
    end
    if sortLevel==2 then
        if sortKey==C.SORT_DEFAULT_LEVEL_2 then -- default for level 2 sort is C.SORT_LEVEL
            settings.Filters.Sort[sortLevel] = nil
        else
            settings.Filters.Sort[sortLevel] = sortKey
        end
        -- when setting a sortLevel 2 sort, clear the subsort so it will pick up default
        settings.Filters.Sort[3] = nil
        settings.Filters.Sort[-3] = nil
    end
    if sortLevel==3 then
        if sortKey==C.SORT_DEFAULT_LEVEL_3 then -- default for level 3 sort is C.SORT_RARITY
            settings.Filters.Sort[sortLevel] = nil
        else
            settings.Filters.Sort[sortLevel] = sortKey
        end
    end
    -- when a primary or secondary sort is chosen, make sure the subsorts are possible; and if not, switch them to the first available
    if not rematch.filters:IsSortKeyAvailable(2,rematch.filters:GetSort(2)) then
        rematch.filters:SetSort(2,rematch.filters:GetFirstAvailableSort())
    end
    if not rematch.filters:IsSortKeyAvailable(3,rematch.filters:GetSort(3)) then
        rematch.filters:SetSort(3,rematch.filters:GetFirstAvailableSort())
    end
    dirty = true
end

-- returns the sort order at the given sortLevel (special handling for nil since nil is a default sort order)
function rematch.filters:GetSort(sortLevel)
    local sortKey = settings.Filters.Sort[sortLevel]
    if sortLevel==1 and not sortKey then
        return C.SORT_DEFAULT_LEVEL_1 -- default is C.SORT_NAME
    elseif sortLevel==2 and not sortKey then
        return C.SORT_DEFAULT_LEVEL_2 -- default is C.SORT_LEVEL
    elseif sortLevel==3 and not sortKey then
        return C.SORT_DEFAULT_LEVEL_3 -- default is C.SORT_RARITY
    else -- sortKey should have a value at this point, return it
        return sortKey
    end
end

-- returns true if no parent sort uses the given sortKey
function rematch.filters:IsSortKeyAvailable(sortLevel,sortKey)
    if sortLevel==2 and sortKey==rematch.filters:GetSort(1) then
        return false
    elseif sortLevel==3 and (sortKey==rematch.filters:GetSort(1) or sortKey==rematch.filters:GetSort(2)) then
        return false
    else
        return true
    end
end

-- when two sortLevels want to do the same sort, this function will return the first sort not used in all 3 sortLevels
-- the sort chosen is the first available of the sortKeys in their numerical order, the first of: name, level, rarity
function rematch.filters:GetFirstAvailableSort()
    for sortKey=1,4 do -- only need to do 3 really since this is only used for two sortLevels, but doing an extra to be certain
        local found = false
        for sortLevel=1,3 do
            if rematch.filters:GetSort(sortLevel)==sortKey then
                found = true
            end
        end
        if not found then
            return sortKey
        end
    end
end

-- replaces the existing filters with a saved filter
function rematch.filters:LoadFavoriteFilter(filters)
    for _,filterInfo in pairs(filterGroups) do
        local filterGroup = filterInfo[1]
        rematch.filters:Clear(filterGroup) -- even rolling over sort and search (which may not reset on a ClearAll)
        local savedGroup = filters[filterGroup]
        if not savedGroup then
            filters[filterGroup] = {} -- for older saved filters, in case new ones are added
        elseif type(savedGroup)=="table" then
            settings.Filters[filterGroup] = CopyTable(savedGroup)
        else
            settings.Filters[filterGroup] = savedGroup
        end
    end
end
