local _,rematch = ...
local settings = rematch.settings
rematch.roster = {}

--[[
    In past versions, rematch.roster was a starting point for any type of changes to the pet list, from adding new pets
    to a pet changing rarity or gaining a level, to even the pet list changing filters.

    This new roster is treated as a data source only. It will watch for pets being added and removed and keep a list
    of all current pets and species, but that's it.

    The main list of pets is a list of either "BattlePet-0-etc" petID for owned pets, or a numeric speciesID for
    uncollected pets. Another list is of distinct speciesIDs. These lists should be treated as a data source and are
    not intended to be altered outside this module.

    The lists can be read by one of three iterator functions:
        for petID in rematch.roster:AllPets() do -- do something -- end -- loop over all petIDs (and unowned speciesIDs)
        for petID in rematch.roster:AllOwnedPets() do -- do something -- end -- loop over all owned petIDs
        for petID in rematch.roster:AllSpecies() do -- do something -- end -- loop over all distinct speciesIDs

    The number of pets can be read by one of the following:
        rematch.roster:GetNumPets() -- returns the total number of pets, both owned (including duplicates) and uncollected
        rematch.roster:GetNumSpecies() -- returns the number of distinct speciesIDs in the journal, owned or not
        rematch.roster:GetNumOwned() -- returns the number of pets owned by the player, including duplicates
        rematch.roster:GetNumUniqueOwned() -- returns the number of distinct pets owned by the player (ignoring duplicates)
]]

-- master list of pets, either a petID ("BattlePet-0-etc") for owned pets, or a speciesID (42) for uncollected pets
local allPets = {}
-- list of all speciesIDs in the journal
local allSpecies = {}
-- indexed by speciesID, an ordered list of owned petIDs for the speciesID
local speciesPetIDs = {}
-- place to backup journal settings when we update the roster
local journalBackup = { search="", collected=nil, notCollected=nil, types={}, sources={} }

local isUpdatingRoster -- true while roster is updating (while expanding/collapsing journal and clears a frame after)
local uniqueOwnedCount = 0 -- number of distinct pets owned by the player

local waitingForFirstUpdate = true -- becomes nil after first update, to fire REMATCH_PETS_LOADED

rematch.events:Register(rematch.roster,"PLAYER_LOGIN",function(self)
    rematch.events:Register(rematch.roster,"NEW_PET_ADDED",rematch.roster.NEW_PET_ADDED)
    rematch.events:Register(rematch.roster,"PET_JOURNAL_PET_DELETED",rematch.roster.PET_JOURNAL_PET_DELETED)
    rematch.events:Register(rematch.roster,"UPDATE_SUMMONPETS_ACTION",rematch.roster.UPDATE_SUMMONPETS_ACTION)
    -- releasing a pet doesn't trigger any event except a PET_JOURNAL_LIST_UPDATE, so firing a fake PET_JOURNAL_PET_DELETD when it happens
    hooksecurefunc(C_PetJournal,"ReleasePetByID",function(petID)
        rematch.events:Fire("PET_JOURNAL_PET_DELETED",petID)
    end)
end)

-- in 5.1.2 and earlier, the first time this event fires started a 0-frame wait for roster:Update() to set up inital pets.
-- however, it seems that if the default journal had anything searched before reload/login, then at this point in next
-- login, the search is still limiting pets (without any way to know if a search was used if no addons enabled)
-- in 5.1.3 this now does a ClearSearchFilter to clear the potential search and trigger a one-off PET_JOURNAL_LIST_UPDATE
-- to do the initial update. (in the default journal, searches don't carry across sessions so this is safe to clear but
-- imho these steps shouldn't be necessary)
function rematch.roster:UPDATE_SUMMONPETS_ACTION(...)
    rematch.events:Unregister(rematch.roster,"UPDATE_SUMMONPETS_ACTION") -- it served its purpose, now rely on add/delete
    rematch.events:Register(rematch.roster,"PET_JOURNAL_LIST_UPDATE",rematch.roster.PET_JOURNAL_LIST_UPDATE) -- ClearSearchFilter will trigger this event
    C_PetJournal.ClearSearchFilter() -- without this line, then a search-filtered default journal in prior session may remain filtered
end

-- fires when a new pet is added to the journal
function rematch.roster:NEW_PET_ADDED(...)
    if settings.StickyNewPets then
        rematch.sort:AddStickiedPetID(...)
    end
    rematch.timer:Start(0,rematch.roster.Update) -- update allPets and allSpecies
end

-- fires when a pet is removed from the journal
function rematch.roster:PET_JOURNAL_PET_DELETED(...)
    rematch.timer:Start(0,rematch.roster.Update) -- update allPets and allSpecies
end

-- this is only called in response to a UPDATE_SUMMONPETS_ACTION on login
function rematch.roster:PET_JOURNAL_LIST_UPDATE(...)
    rematch.events:Unregister(rematch.roster,"PET_JOURNAL_LIST_UPDATE") -- this should've been a one-off call for releasing a pet
    rematch.timer:Start(0,rematch.roster.Update) -- update allPets and allSpecies
end

-- called one frame after the number of owned pets changes; expands the journal (clears filters) if they're not already,
-- gathers into allPets/allSpecies, and then restores the journal filters to their previous state (if they changed)
function rematch.roster:Update()
    if isUpdatingRoster or not rematch.main:IsPlayerInWorld() then
        return -- already doing an Update or player is in a loading screen, leave
    end
    rematch.roster:StartUpdatingRoster()
    local isAnyFilterUsed = rematch.roster:IsAnyFilterUsed()

    if isAnyFilterUsed then -- before expanding filters, confirm any are being used first (can drop from 122ms to 2ms to skip this)
        rematch.roster:ExpandJournal()
    end
    uniqueOwnedCount = 0
    wipe(allPets)
    wipe(allSpecies)
    for speciesID,petIDs in pairs(speciesPetIDs) do
        wipe(petIDs)
    end

    local numPets = C_PetJournal.GetNumPets()

    for i=1,numPets do
        local petID,speciesID = C_PetJournal.GetPetInfoByIndex(i)
        tinsert(allPets,petID or speciesID)
        if not speciesPetIDs[speciesID] then
            speciesPetIDs[speciesID] = {}
        end
        if petID then
            if #speciesPetIDs[speciesID]==0 then
                uniqueOwnedCount = uniqueOwnedCount + 1
            end
            tinsert(speciesPetIDs[speciesID],petID)
        end
    end
    -- now rebuild allSpecies
    for speciesID in pairs(speciesPetIDs) do
        tinsert(allSpecies,speciesID)
    end
    if isAnyFilterUsed then
        rematch.roster:RestoreJournal()
    end

    rematch.filters:ForceUpdate() -- set dirty flag on filter so list updates
    rematch.timer:Start(0,rematch.roster.FinishUpdatingRoster)
end

-- external so speciesInfo can also use the Expand/RestoreJournal
function rematch.roster:StartUpdatingRoster()
    isUpdatingRoster = true
end

-- delayed a frame in case a NEW_PET_ADDED and UPDATE_SUMMONPETS_ACTION fires in pairs; clears flag that says we're updating
-- and if this is the first update, then fire off a REMATCH_PETS_LOADED for anything waiting for pets to load on login
function rematch.roster:FinishUpdatingRoster()
    isUpdatingRoster = nil
    --rematch.savedTeams:ValidateAllTeams() -- if pets leaving/adding, adjust teams that might be impacted
    if waitingForFirstUpdate then
        waitingForFirstUpdate = nil
        rematch.events:Fire("REMATCH_PETS_LOADED")
    end
    rematch.events:Fire("REMATCH_PETS_CHANGED")
end

--[[ counts ]]

-- returns the total number of pets, both owned (including duplicates) and uncollected
function rematch.roster:GetNumPets()
    return #allPets
end

-- returns the number of distinct speciesIDs in the journal, owned or not
function rematch.roster:GetNumSpecies()
    return #allSpecies
end

-- returns the number of pets owned by the player, including duplicates
function rematch.roster:GetNumOwned()
    return select(2,C_PetJournal.GetNumPets())
end

-- returns the number of unique pets owned by the player (specifically, the number of different speciesIDs the player owns)
function rematch.roster:GetNumUniqueOwned()
    return uniqueOwnedCount
end

-- returns a small ordered list of petIDs that are owned for the given speciesID (honor system here, nothing should update this return)
function rematch.roster:GetSpeciesPetIDs(speciesID)
    return speciesID and speciesPetIDs[speciesID]
end

--[[ journal filter shenanigans ]]

-- since there is no C_PetJournal.GetSearchFilter, we need to watch for it changing
hooksecurefunc(C_PetJournal,"SetSearchFilter",function(search)
	if not isUpdatingRoster then
		journalBackup.search = search or ""
	end
end)
hooksecurefunc(C_PetJournal,"ClearSearchFilter",function()
	if not isUpdatingRoster then
		journalBackup.search = ""
	end
end)

-- clears all filters in the pet journal so all pets can be captured in roster:Update()
function rematch.roster:ExpandJournal()
    journalBackup.collected = C_PetJournal.IsFilterChecked(LE_PET_JOURNAL_FILTER_COLLECTED)
    journalBackup.notCollected = C_PetJournal.IsFilterChecked(LE_PET_JOURNAL_FILTER_NOT_COLLECTED)
    for i=1,C_PetJournal.GetNumPetTypes() do
        journalBackup.types[i] = C_PetJournal.IsPetTypeChecked(i)
    end
    for i=1,C_PetJournal.GetNumPetSources() do
        journalBackup.sources[i] = C_PetJournal.IsPetSourceChecked(i)
    end
    C_PetJournal.ClearSearchFilter()
    C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_COLLECTED,true)
    C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_NOT_COLLECTED,true)
    C_PetJournal.SetAllPetSourcesChecked(true)
    C_PetJournal.SetAllPetTypesChecked(true)
end

-- restores all filters that were cleared in roster:ExpandJournal()
function rematch.roster:RestoreJournal()
    C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_COLLECTED,journalBackup.collected)
    C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_NOT_COLLECTED,journalBackup.notCollected)
    for i=1,C_PetJournal.GetNumPetSources() do
        C_PetJournal.SetPetSourceChecked(i,journalBackup.sources[i])
    end
    for i=1,C_PetJournal.GetNumPetTypes() do
        C_PetJournal.SetPetTypeFilter(i,journalBackup.types[i])
    end
    C_PetJournal.SetSearchFilter(journalBackup.search)
end

-- returns true if any journal filters are used, since there's no need to expand/restore if it's already expanded
-- using this to skip the expand/restore drops an expand/capture/restore from 122ms to 2ms (!!!)
function rematch.roster:IsAnyFilterUsed()
    if journalBackup.search~="" then
        return true -- search is used
    end
    if not C_PetJournal.IsFilterChecked(LE_PET_JOURNAL_FILTER_COLLECTED) then
        return true -- collected is unchecked
    end
    if not C_PetJournal.IsFilterChecked(LE_PET_JOURNAL_FILTER_NOT_COLLECTED) then
        return true -- not collected is unchecked
    end
    for i=1,C_PetJournal.GetNumPetTypes() do
        if not C_PetJournal.IsPetTypeChecked(i) then
            return true -- a pet type is unchecked
        end
    end
    for i=1,C_PetJournal.GetNumPetSources() do
        if not C_PetJournal.IsPetSourceChecked(i) then
            return true -- a pet source is unchecked
        end
    end
    return false
end

--[[ iterator functions ]]

-- loops over allPets, which is a list of owned petIDs ("BattlePet-0-etc") and unowned speciesIDs (42)
function rematch.roster:AllPets()
    local i = 0
    return function()
        i = i + 1
        if i <= #allPets then
            return allPets[i]
        end
    end
end

-- loops over all owned petIDs
function rematch.roster:AllOwnedPets()
    local i = 0
    return function()
        i = i + 1
        if i <= #allPets then
            if type(allPets[i])=="string" then
                return allPets[i]
            end
        end
    end
end

-- loops over allSpecies, or all distinct speciesIDs
function rematch.roster:AllSpecies()
    local i = 0
    return function()
        i = i + 1
        if i <= #allSpecies then
            return allSpecies[i]
        end
    end
end

-- loops over all petIDs owned for the given speciesID
function rematch.roster:AllSpeciesPetIDs(speciesID)
    local i = 0
    return function()
        i = i + 1
        if speciesPetIDs[speciesID] and i<=#speciesPetIDs[speciesID] then
            return speciesPetIDs[speciesID][i]
        end
    end
end
