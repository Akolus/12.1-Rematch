local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.sort = {}

--[[
    RunSort(list) takes a list of petIDs (which can include speciesIDs) and sorts them in the orders
    defined in settings.Filters.Sort.

    When settings.Filters.Sort is empty, then it will use all defaults sorts, which would be
    (if they had values):

    Three tiers of sort are:
        settings.Filters.Sort[1] = C.SORT_NAME
        settings.Filters.Sort[2] = C.SORT_LEVEL
        settings.Filters.Sort[3] = C.SORT_RARITY
    Each tier can be reversed by having a true value in its negative tier:
        settings.Filters.Sort[-1] = false (don't reverse name sort)
        settings.Filters.Sort[-2] = false (don't reverse level sort)
        settings.Filters.Sort[-3] = false (don't reverse rarity sort)
    And extra settings:
        settings.Filters.Sort.FavoritesNotFirst = false (list favorites first)

    When a sort is applied, the list is sorted in this order:
        1. Owned first (BattlePet-0-etc strings before speciesID numbers)
        2. Favorites first (if settings.FavoritesNotFirst is false)
        2. Relevance if search is used
        3. Primary Sort
        4. Secondary Sort
        5. Tertiary Sort
        6. Name sort (if C.SORT_NAME not in primary-tertiary sort)
        7. petID

    C.SORT_NAME and C.SORT_TYPE default to ascending sort values, and the rest default to sort by
    descending values. The table ascendingSorts (set up during PrepareSort()) will be true for ascending
    tiers, and false for descending; and will be the opposite value if a sort tier is reversed.

    For faster sorts, as each pet is evaluated, ones to list run AddSortStats(petID) and it will
    populate sortValues with the value for the three tiers (+name if unused in the three tiers).
    Each subtable of sortValues is a lookup table indexed by petID and the value of the stat for that tier.
]]

-- the current sort orders, taken from settings.Filters.Sort
local activeSorts = {C.SORT_NAME,C.SORT_LEVEL,C.SORT_RARITY}
-- whether the sorts are ascending (true) or descending (false)
local ascendingSorts = {true,true,true}
-- which stats to put in the sortValues subtables (named sort will be speciesName unless SortByNickname enabled, when it'd be name)
local petInfoSorts = {"speciesName","level","rarity"}

-- lookup table of petIDs that are favorited (if settings.FavoritesNotFirst is false), filled during AddSortValues()
local favorites = {}
local listFavoritesFirst = false -- defined in PrepareSort, true if settings.Filters.Sort.FavoritesNotFirst is false

-- lookup tables of pets and their relevance when a search is involved, filled during AddSortValues()
local searchRelevance -- this is created during filter evaluation and is a cache indexed by speciesID (except customName relevances index by petID)
local sortRelevance = {} -- this is filled during AddSortValues() and indexed by a petID/speciesID for all pets

-- lookup tables of sort values, with index 1-3 being the primary, secondary and teriary sort values
-- and index 4 for names if it's not used in the other
local sortValues = { {},{},{},{} }

-- each sort type directly relates to a petInfo value. (to add sorts in the future, they need to be a petInfo value)
local petInfoStats = {
    [C.SORT_NAME] = "speciesName",
    [C.SORT_LEVEL] = "level",
    [C.SORT_RARITY] = "rarity",
    [C.SORT_TYPE] = "petType",
    [C.SORT_HEALTH] = "maxHealth",
    [C.SORT_POWER] = "power",
    [C.SORT_SPEED] = "speed",
    [C.SORT_TEAMS] = "numTeams",
}


local stickiedPetIDs = {} -- indexed by petID, these pets should be moved to the top of the list until rematch is closed
local stickiedStaging = {} -- for a quick stable sort, used as a temp space for swapping

-- call this before starting a filter run. it does pre-sort maintenance, such as wiping tables and filling actualSorts,
-- ascendingSorts and petInfoSorts depending on current settings. It needs to be before a filter run so that
-- AddSortValues() knows which sort values (name, level, rarity, etc.) to keep as pets are evaluated.
function rematch.sort:PrepareSort()
    -- first clean up the lookup tables
    for _,v in ipairs(sortValues) do
        wipe(v)
    end
    wipe(favorites)
    wipe(sortRelevance)
    local nameSorted = false -- assume no sort by name is happening until observed otherwise
    -- go through each of the three sort levels to set up activeSorts and ascendingSorts
    for sortLevel=1,3 do
        local sort = rematch.filters:GetSort(sortLevel)
        activeSorts[sortLevel] = sort
        -- choose whether it's ascending or descending based on the type of sort and the reverse filter setting
        if sort==C.SORT_NAME then -- name sorts happen in ascending order by default
            nameSorted = true -- note that a sort by name is happening (so don't need a 4th sort)
            ascendingSorts[sortLevel] = not settings.Filters.Sort[-sortLevel]
        elseif sort==C.SORT_TYPE then
            ascendingSorts[sortLevel] = not settings.Filters.Sort[-sortLevel]
        else -- all other sorts default to descending, so reverse would be ascending
            ascendingSorts[sortLevel] = settings.Filters.Sort[-sortLevel] or false
        end
        -- fill petInfoSorts with the petInfo stat to use for the sort
        if sort==C.SORT_NAME and settings.SortByNickname then
            petInfoSorts[sortLevel] = "name"
        else
            petInfoSorts[sortLevel] = petInfoStats[sort]
        end
    end
    -- if name is not one of the 3 sorts, then add it as a 4th sort
    if not nameSorted then
        activeSorts[4] = C.SORT_NAME
        ascendingSorts[4] = true
        petInfoSorts[4] = settings.SortByNickname and "name" or "speciesName"
    else
        activeSorts[4] = nil
        ascendingSorts[4] = nil
        petInfoSorts[4] = nil
    end
    -- create local flag to avoid doing table indexing
    listFavoritesFirst = not settings.Filters.Sort.FavoritesNotFirst
    -- if search is happening, keep a local reference for quick lookup
    searchRelevance = not settings.DontSortByRelevance and rematch.filters:GetSearchRelevance()
end

-- called after a filter run, wipes the sort cache tables
function rematch.sort:Cleanup()
    for _,v in ipairs(sortValues) do
        wipe(v)
    end
end

-- fills sortValues with the 3 values (4 if name needed) of the given petID; called as pets are evaluated in rematch.filter:RunFilters()
function rematch.sort:AddSortValues(petID)
    local petInfo = rematch.petInfo:Fetch(petID)
    for sortLevel=1,#activeSorts do
        sortValues[sortLevel][petID] = petInfo[petInfoSorts[sortLevel]]
    end
    -- if favorites list first, note which are favorites
    if listFavoritesFirst and petInfo.isFavorite then
        favorites[petID] = true
    end
    -- this searchRelevance is largely indexed by speciesID and used as a cache during search filter (except renamed pets use customName and
    -- have a petID index). here each pet in the list is getting assigned a relevance, either from its petID or speciesID, for sortRelevance
    if searchRelevance then
        local relevance = searchRelevance[petID] or searchRelevance[petInfo.speciesID]
        if relevance then
            sortRelevance[petID] = relevance
        end
    end
end

-- sorts the given list according to the current sort settings and sort values accumulated during RunFilters()
function rematch.sort:RunSort(list)
    table.sort(list,rematch.sort.SortFunc)
    -- once an epoch, a wrapped pet should be moved to top temporarily (until rematch closes or filter reset all)
    if C_PetJournal.GetNumPetsNeedingFanfare()>0 then
        for _,petID in ipairs(list) do
            if rematch.petInfo:Fetch(petID).needsFanfare then
                rematch.sort:AddStickiedPetID(petID)
            end
        end
    end
    if stickiedPetIDs then
        rematch.sort:MoveStickiedPetsToTop(list)
    end
end

-- if any petIDs are stickied, moves them to top of list with a simple stable sort (assumption: list is already sorted)
function rematch.sort:MoveStickiedPetsToTop(list)
    if #list<=1 then
        return -- only have 0-1 result, don't bother to sort
    end
    wipe(stickiedStaging)
    -- add stickied pets to the staging list in the order they appear in regular list; and remove from regular list
    for i=#list,1,-1 do
        if stickiedPetIDs[list[i]] then
            tinsert(stickiedStaging,list[i])
            tremove(list,i)
        end
    end
    -- now insert stickied pets back to start of regular list
    for _,petID in ipairs(stickiedStaging) do
        tinsert(list,1,petID)
    end
end

-- call when stickied pets should be unstickied (rematch window closes or filter reset all); return true if something was stickied
function rematch.sort:ClearStickiedPetIDs()
    local wasStickied = type(stickiedPetIDs)=="table"
    stickiedPetIDs = nil
    return wasStickied
end

-- adds a petID to be stickied (called in roster too for new pets)
function rematch.sort:AddStickiedPetID(petID)
    if not stickiedPetIDs then
        stickiedPetIDs = {}
    end
    stickiedPetIDs[petID] = true
end

function rematch.sort:IsPetIDStickied(petID)
    return (stickiedPetIDs and petID and stickiedPetIDs[petID]) and true or false
end

-- When a sort is applied, the list is sorted in this order:
-- 1. Owned first (BattlePet-0-etc strings before speciesID numbers)
-- 2. Favorites first (if settings.Filters.Sort.FavoritesNotFirst is false)
-- 2. Relevance if search is used
-- 3. Primary Sort
-- 4. Secondary Sort
-- 5. Tertiary Sort
-- 6. Name sort (if C.SORT_NAME not in primary-tertiary sort)
-- 7. petID
function rematch.sort.SortFunc(pet1,pet2)

    -- always sort owned pets (strings) before uncollected (number) pets
    local o1,o2 = type(pet1)=="string", type(pet2)=="string"
    if o1 and not o2 then
        return true
    elseif o2 and not o1 then
        return false
    end

    -- if a search is happening sort by relevance first
    if searchRelevance then
        local r1,r2 = sortRelevance[pet1],sortRelevance[pet2]
        if r1 and not r2 then return true
        elseif r2 and not r1 then return false
        elseif r1~=r2 then
            return r1<r2
        end
    end

    -- if 'Favorites First' is checked then always list favorites first
    if listFavoritesFirst then
        local f1,f2 = favorites[pet1],favorites[pet2]
        if f1 and not f2 then return true
        elseif f2 and not f1 then return false
        end
    end

    -- next do the primary, secondary, tertiary (and if needed, name) sort
    for sortLevel=1,#activeSorts do
        local s1,s2 = sortValues[sortLevel][pet1],sortValues[sortLevel][pet2]
        if s1 and not s2 then return true
        elseif s2 and not s1 then return false
        elseif s1~=s2 then
            if ascendingSorts[sortLevel] then
                return s1<s2
            else
                return s1>s2
            end
        end
    end

    -- if we reached here, these two pets are identical, order them by petID so the order is stable
    return pet1<pet2
end

