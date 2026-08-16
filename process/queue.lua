local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.queue = {}

--[[

    The queue can process (update queue and change pets in leveling slots) in many scenarios:
        - changing queue sort
        - toggling preferences
        - changing preferences from CurrentPreferences dialog
        - saving a team with SavedTeam dialog
        - slotting a pet (could be leveling pet or moving leveling slot)
        - loading team
        - adding a pet to the queue
        - removing a pet from the queue
        - leaving pet battle
        - releasing a pet
        - caging a pet
        - logging in
        - using a rarity stone
        - using a leveling stone

    In any of these scenarios it should call:

        rematch.queue:Process()

    This will do a 0-frame wait (in case multiple of the above happen in the same frame) and then call
    startProcess() which will update the queue (apply preferences, kick out level 25 pets, sort if active
    sort enabled), and then call runProcess() to slot any pets in the queue into the respecting leveling
    slots if they're not already slotted. If a pet from the queue is slotted, it will call itself after
    a short (0.25 second) interval to confirm pets loaded, repeating until all expected pets are loaded.

]]

local queueLookup = {} -- indexed by petID, the index into settings.LevelingQueue for the petID
local timeout = 0 -- after C.QUEUE_PROCESS_TIMEOUT tries, queue gives up slotting leveling pets
local blingPetID -- at the end of a process, scroll to and bling the petID in the queue
local topPicks = {} -- top three pets in the queue to be chosen for a leveling slot

local excludePetIDs = {} -- in the event the queue needs rebuilt, petIDs already in the queue are added here

rematch.events:Register(rematch.queue,"PLAYER_LOGIN",function(self)
    -- if pets changed level or rarity then queue may be changing (can't limit to ActiveSort due to a pet reaching 25/out of preferences)
    rematch.events:Register(self,"REMATCH_PETS_CHANGED",self.Process)
    -- after pets loaded on login, remove any invalid pets (caged or released while addon disabled or potentially a petID reassignment)
    rematch.events:Register(self,"REMATCH_PETS_LOADED",self.REMATCH_PETS_LOADED)
    rematch.events:Register(self,"PET_JOURNAL_PET_DELETED",self.PET_JOURNAL_PET_DELETED)

    rematch.events:Register(self,"NEW_PET_ADDED",self.NEW_PET_ADDED)
end)

-- updates queue including lookup for indexes, removing pets that are 25/no longer exist, applying preferences and sorting if active sort enabled
function rematch.queue:Update(teamID)

    if not rematch.main:IsPlayerInWorld() then
        return -- player is in a loading screen, leave
    end

    local preferences = rematch.preferences:GetCurrentPreferences(teamID) -- if teamID not provided, it will get current teamID

    -- rebuild lookup indexes
    wipe(queueLookup)
    for index,info in ipairs(settings.LevelingQueue) do
        if not info.petID then
            info.petID = "delete" -- flag this for delete, petID doesn't exist
        elseif queueLookup[info.petID] then
            info.petID = "delete" -- flag this for delete, petID already encountered
        else
            queueLookup[info.petID] = index
        end
    end

    local invalidPetFound = false -- becomes true when an invalid pet is found (to initialize excludePetIDs)

    -- remove any flagged for deletion (or that have hit level 25) and set preferred flag while here
    for index=#settings.LevelingQueue,1,-1 do
        local info = settings.LevelingQueue[index]
        if info.petID=="delete" then
            tremove(settings.LevelingQueue,index) -- petID doesn't exist, remove from queue
        else
            local petInfo = rematch.petInfo:Fetch(info.petID)
            if petInfo.level==25 then
                tremove(settings.LevelingQueue,index) -- pet is level 25, remove from queue
            else
                if not petInfo.isValid then -- if pet is not valid, then look for a replacement
                    if not invalidPetFound then -- first finding an invalid pet, fill excludePetIDs from queue
                        invalidPetFound = true
                        wipe(excludePetIDs)
                        for _,queueInfo in ipairs(settings.LevelingQueue) do
                            excludePetIDs[queueInfo.petID] = true
                        end
                    end
                    local newPetID = rematch.petTags:FindPetID(info.petTag,excludePetIDs)
                    if newPetID then
                        info.petID = newPetID
                    else -- there was no replacement petID, should delete but letting it be a blank pet for now
                        --print(info.petID,petInfo.name,"is still not valid, tag:",info.petTag)
                    end
                end
                info.preferred = rematch.preferences:IsPetPreferred(info.petID,preferences)
            end
        end
    end

    -- after preferences updated, update top picks
    rematch.queue:UpdateTopPicks()

    if settings.QueueActiveSort then
        rematch.queue:SortQueue(C.QUEUE_SORT_ALL)
    end
end

-- after preferences updated, this picks the top 3 pets from the queue
function rematch.queue:UpdateTopPicks()
    wipe(topPicks)
    local pick = 1
    -- look for preferred pets first
    for _,info in ipairs(settings.LevelingQueue) do
        if info.preferred then
            topPicks[pick] = info.petID
            pick = pick + 1
            if pick > 3 then
                return -- no need to stick around after 3 pets picked
            end
        end
    end
    -- if still here, then not enough preferred pets to fill 3 top picks; try unpreferred
    for _,info in ipairs(settings.LevelingQueue) do
        if not info.preferred and rematch.petInfo:Fetch(info.petID).isSummonable then
            topPicks[pick] = info.petID
            pick = pick + 1
            if pick > 3 then
                return
            end
        end
    end
end

-- called immediately from startProcess and C.QUEUE_PROCESS_WAIT (0.25 seconds) after any leveling pets slotted to confirm they loaded
local function runProcess()
    local pickIndex = 1
    local petSlotted = false -- true if any pets are slotted
    local firstSlotted -- petID of first pet (pickIndex 1) slotted for toasting purposes
    for slot=1,3 do
        if rematch.loadouts:GetSpecialSlotType(slot)=="leveling" then
            local petID = rematch.queue:GetTopPick(pickIndex)
            local petInfo = rematch.petInfo:Fetch(petID)
            if petInfo.isOwned and petInfo.isSummonable then
                if rematch.loadouts:GetLoadoutInfo(slot)~=petID then
                    rematch.loadouts:SlotPet(slot,petID,0,true)
                    petSlotted = true
                    if pickIndex==1 then
                        firstSlotted = petID
                    end
                end
                pickIndex = pickIndex + 1
            end
        end
    end
    -- update UI if it's visible (to hide.show leveling badges everywhere)
    if rematch.frame:IsVisible() then
        rematch.frame:Update()
    end
    -- if a petID is waiting to be blinged
    if blingPetID then
        -- if queue panel is up, scroll to pet added to queue and bling it
        if rematch.queuePanel:IsVisible() and rematch.queue:IsPetLeveling(blingPetID) then
            rematch.queuePanel.List:BlingData(rematch.queue:GetPetIndex(blingPetID))
        end
        -- whether queue panel was up or not, clear petID so it's not blinged when going to queue panel later
        blingPetID = nil
    end
    -- if any pets were attempted to be slotted, come back in a bit to confirm they're all slotted
    if petSlotted and timeout>0 then
        timeout = timeout - 1
        rematch.timer:Start(C.QUEUE_PROCESS_WAIT,runProcess)
    end
    if firstSlotted and firstSlotted~=settings.LastToastedPetID then
        settings.LastToastedPetID = firstSlotted
        rematch.toast:ToastLevelingPet(firstSlotted)
    end
end

-- called from rematch.queue:Process() after a 0-frame update; updates the queue and kicks off runProcess
local function startProcess()
    rematch.queue:Update()
    timeout = C.QUEUE_PROCESS_TIMEOUT
    runProcess()
end

-- procedure to call when the queue may change or pet levels/rarity may change; can potentially slot leveling pets in their place
function rematch.queue:Process()
    if rematch.main:IsPlayerInWorld() then
        rematch.timer:Start(0,startProcess)
    else -- if in a loading screen, stop any pending queue process
        rematch.queue:CancelProcess()
    end
end

-- when queue should be updated/processed without a wait
function rematch.queue:ProcessNow()
    rematch.queue:CancelProcess()
    if rematch.main:IsPlayerInWorld() then
        startProcess()
    end
end

-- call this to cancel any pending swaps from a queue being processed (eg team loading)
function rematch.queue:CancelProcess()
    rematch.timer:Stop(startProcess)
    rematch.timer:Stop(runProcess)
end

-- bling the given petID at the end of the next process
function rematch.queue:BlingPetID(petID)
    blingPetID = petID
end

-- returns true if the petID is in the leveling queue; using lookup for performance
function rematch.queue:IsPetLeveling(petID)
    return (petID and queueLookup[petID]) and true or false
end

-- returns the numeric index of a petID in the queue from its petID
function rematch.queue:GetPetIndex(petID)
    return petID and queueLookup[petID]
end

-- return the topmost preferred petID from the queue, by the given index. (so index 3 will get the 3rd topmost pet from the queue)
function rematch.queue:GetTopPick(index)
    return topPicks[index] -- if there's a pet in the queue available, return it
end

-- returns true if the petID can level (is owned, can battle, has a level and is under 25)
function rematch.queue:PetIDCanLevel(petID)
    local petInfo = rematch.altInfo:Fetch(petID)
    return petInfo.isOwned and petInfo.canBattle and petInfo.level and petInfo.level<25
end

-- adds a petID to the end of the queue
function rematch.queue:AddPetID(petID)
    rematch.queue:InsertPetID(petID,#settings.LevelingQueue+1) -- adding to end of queue
end

-- inserts a petID into the queue at the given index
function rematch.queue:InsertPetID(petID,index)
    assert(type(index)=="number" and index>=1 and index<=(#settings.LevelingQueue+1),"Invalid index ("..(index or "nil")..") in queue:InsertPetID(index)")
    if rematch.queue:PetIDCanLevel(petID) then
        if rematch.queue:IsPetLeveling(petID) then
            rematch.queue:MoveIndex(rematch.queue:GetPetIndex(petID),index) -- pet was already in queue, move to this new position
        else
            tinsert(settings.LevelingQueue,index,{petID=petID,petTag=rematch.petTags:Create(petID,"Q"),added=rematch.utils:GetDateTime()})
        end
        rematch.queue:Process()
    end
end

-- removes a petID from the queue
function rematch.queue:RemovePetID(petID)
    local index = rematch.queue:GetPetIndex(petID)
    if index then
        tremove(settings.LevelingQueue,index)
    end
    rematch.queue:Process()
end

-- moves a pet in the queue from oldIndex to newIndex (newIndex can be #queue+1 to add to end of queue)
function rematch.queue:MoveIndex(oldIndex,newIndex)
    local queueSize = #settings.LevelingQueue
    assert(type(oldIndex)=="number" and oldIndex>=1 and oldIndex<=queueSize,"Invalid oldIndex ("..(oldIndex or "nil")..") in queue:MoveIndex(oldIndex,newIndex)")
    assert(type(newIndex)=="number" and newIndex>=1 and newIndex<=(queueSize+1),"Invalid newIndex ("..(newIndex or "nil")..") in queue:MoveIndex(oldIndex,newIndex)")
    local deleteIndex = newIndex<oldIndex and oldIndex+1 or oldIndex -- after copying queue entry, this index will be deleted
    tinsert(settings.LevelingQueue,newIndex,CopyTable(settings.LevelingQueue[oldIndex]))
    tremove(settings.LevelingQueue,deleteIndex)
    rematch.queue:Process()
end


--[[ queue sorting

    0 0 0 0 0000        Weight of a pet is an 8-digit number built from given sort and settings. Heaviest pets always list first.
    | | | | |           (This weight doesn't take names into account. A separate petNames is used for the secondary sort.)
    | | | | +-level
    | | | +---rarity
    | | +-----favorite
    | +-------inTeams
    +---------owned
]]

local petWeights = {}
local petNames = {}

-- calculates a weight for each petID in the queue
local function fillSortWeights(sort)
    wipe(petWeights)
    wipe(petNames)

    for _,info in ipairs(settings.LevelingQueue) do
        local petID = info.petID
        local petInfo = rematch.petInfo:Fetch(petID)

        -- weight is a value of the petID where the higher weight is listed first
        local weight = (petInfo.isOwned and 1 or 0) * 10000000 -- isOwned criteria is always used
        if sort==C.QUEUE_SORT_TEAMS or (sort==C.QUEUE_SORT_ALL and settings.QueueSortInTeamsFirst) then
            weight = weight + (petInfo.inTeams and 1 or 0) * 1000000
        end
        if sort==C.QUEUE_SORT_FAVORITES or (sort==C.QUEUE_SORT_ALL and settings.QueueSortFavoritesFirst) then
            weight = weight + (petInfo.isFavorite and 1 or 0) * 100000
        end
        if sort==C.QUEUE_SORT_RARITY or (sort==C.QUEUE_SORT_ALL and settings.QueueSortRaresFirst) then
            weight = weight + (petInfo.rarity or 0) * 10000
        end
        if sort==C.QUEUE_SORT_ASC or (sort==C.QUEUE_SORT_ALL and settings.QueueSortOrder==C.QUEUE_SORT_ASC) then
            weight = weight + (9999-floor((petInfo.fullLevel or 0)*100))
        end
        if sort==C.QUEUE_SORT_MID or (sort==C.QUEUE_SORT_ALL and settings.QueueSortOrder==C.QUEUE_SORT_MID) then
            weight = weight + (9999-floor((abs(10.5-petInfo.fullLevel)*100)))
        end
        if sort==C.QUEUE_SORT_DESC or (sort==C.QUEUE_SORT_ALL and settings.QueueSortOrder==C.QUEUE_SORT_DESC) then
            weight = weight + floor((petInfo.fullLevel or 0)*100)
        end

        petWeights[petID] = weight
        petNames[petID] = petInfo.name
    end
end

-- returns true if petIDs e1 and e2 should swap
local function shouldSwap(e1,e2)
    if petWeights[e1]~=petWeights[e2] then -- primary sort by weight
        return petWeights[e1] < petWeights[e2]
    elseif settings.QueueSortByNameToo then -- if Sort Queue By Pet Name Too enabled, name secondary sort
        return petNames[e1] > petNames[e2]
    else -- if reached here, no need to swap anything
        return false
    end
end

-- does a stable sort (insertion sort) of the queue for the given sort (C.QUEUE_SORT_ASC, C.QUEUE_SORT_MID, etc.; C.QUEUE_SORT_ALL for active sort)
function rematch.queue:SortQueue(sort)
    -- update weights before going into sort
    fillSortWeights(sort)
    -- perform insertion sort on the given sort (can't use table.sort since it's unstable)
    -- most of the time the queue should be mostly sorted so this shouldn't be too much work
    local queue = settings.LevelingQueue
    for i=2,#queue do
        local petID = queue[i].petID
        local petTag = queue[i].petTag
        local preferred = queue[i].preferred
        local added = queue[i].added
        local j = i-1
        while j>0 and shouldSwap(queue[j].petID,petID) do
            queue[j+1].petID = queue[j].petID
            queue[j+1].petTag = queue[j].petTag
            queue[j+1].preferred = queue[j].preferred
            queue[j+1].added = queue[j].added
            j = j-1
        end
        queue[j+1].petID = petID
        queue[j+1].petTag = petTag
        queue[j+1].preferred = preferred
        queue[j+1].added = added
    end
end

--[[ events ]]

-- this runs once after login when pets are loaded, to remove any pets that no longer exist, possibly from pets released/caged
-- while addon disabled or server-side petID reassignment. if all pets are invalid a petID reassignment happened, rebuild the queue
function rematch.queue:REMATCH_PETS_LOADED()
    local queue = settings.LevelingQueue
    local excludePetIDs = {} -- lookup table of petIDs added to queue (so they don't get added for repeats)
    -- first see if ALL pets are invalid; if so then likely a server-side petID reassignment happened
    local validFound = false
    local invalidFound = false
    for index,info in ipairs(queue) do
        local petInfo = rematch.petInfo:Fetch(queue[index].petID)
        if petInfo.idType=="species" then -- if a species, look for a pet to take its place; possibly remainingg a species
            local petID = rematch.petTags:FindPetID(info.petTag,excludePetIDs)
            if petID then
                excludePetIDs[petID] = true
                info.petID = petID
            end
        elseif petInfo.isValid then
            validFound = true
        else
            info.invalid = true -- flag pet for removal
            invalidFound = true
        end
    end
    if validFound and invalidFound then -- if only some pets are invalid, then remove them from the queue
        for index=#queue,1,-1 do
            if queue[index].invalid then
                tremove(queue,index)
            end
        end
    elseif invalidFound then -- if ALL pets are invalid, rebuild entire queue from tags
        for index,info in ipairs(queue) do
            local speciesID = rematch.petTags:GetSpecies(info.petTag)
            if speciesID then
                local petID = rematch.petTags:FindPetID(info.petTag,excludePetIDs)
                if petID then
                    excludePetIDs[petID] = true
                    info.petID = petID
                end
            end
        end
    end
    -- clear isValid flag from all pets in the queue, whole queue is now validated
    for _,info in ipairs(settings.LevelingQueue) do
        info.isValid = nil
    end
    rematch.queue:Process()
    rematch.events:Register(rematch.queue,"PET_JOURNAL_LIST_UPDATE",rematch.queue.Process)
end

-- when a pet is caged or released, remove from queue directly (this event doesn't fire naturally on release; roster is firing it on a hook)
function rematch.queue:PET_JOURNAL_PET_DELETED(petID)
    for index=#settings.LevelingQueue,1,-1 do
        local info = settings.LevelingQueue[index]
        if info.petID==petID then
            tremove(settings.LevelingQueue,index)
        end
    end
end

-- fills the queue with pets from the petsPanel (filtered and in the current order in the petsPanel)
-- when fillMore is false, only levelable pets with a species not already in the queue and not already at 25 will be added
-- when fillMore is true, one levelable copy of each species will be added to the queue
-- when countOnly is true, the pets won't actually be added, just a count of what would be added is returned
local speciesInQueue = {}
function rematch.queue:FillQueue(fillMore,countOnly)
    local count = 0
    wipe(speciesInQueue)
    if not fillMore then
        for _,info in ipairs(settings.LevelingQueue) do
            local petID = info.petID
            local petInfo = rematch.petInfo:Fetch(petID)
            speciesInQueue[petInfo.speciesID] = true
        end
    end
    -- for each petID in the filtered list of pets
    for _,petID in ipairs(rematch.filters:RunFilters()) do
        local petInfo = rematch.petInfo:Fetch(petID)
        local speciesID = petInfo.speciesID
        -- if speciesID is not in the queue and there's no level 25 version of the pet
        if speciesID and not speciesInQueue[speciesID] and not rematch.queue:IsPetLeveling(petID) and rematch.queue:PetIDCanLevel(petID) and (fillMore or not rematch.collectionInfo:IsSpeciesAt25(speciesID)) then
            if not countOnly then
                rematch.queue:AddPetID(petID) -- add it (this triggers a 0-frame process queue)
            end
            speciesInQueue[speciesID] = true
            count = count + 1
        end
    end
    return count
end

-- returns all petTags in the queue in a comma-separated list
function rematch.queue:ExportQueue()
    local result = ""
    for index,info in ipairs(settings.LevelingQueue) do
        result = result..info.petTag..(index==#settings.LevelingQueue and "" or ",")
    end
    return result
end

-- takes an export/import string and returns: numNew,numOld,numCant,numBad
function rematch.queue:AnalyzeImport(import)
    local numNew = 0 -- the number of pets importing this would add to the queue (will be added)
    local numOld = 0 -- the number of pets already in the queue (won't be added)
    local numCant = 0 -- the number of pets can't add to queue due to level or missing (can't be added)
    local numBad = 0 -- the number of "pets" in the import that could not be interpreted
    local excludePetIDs = {} -- lookup table of petIDs added to queue (so they don't get added for repeats)

    -- if nothing to import, return nothing
    if type(import)~="string" or import:trim()=="" then
        return
    end

    for petTag in import:gmatch("[^,]+") do
        local speciesID = rematch.petTags:GetSpecies(petTag)
        if speciesID then
            local petID = rematch.petTags:FindPetID(petTag,excludePetIDs)
            local petInfo = rematch.petInfo:Fetch(petID)
            if not petInfo.isValid or not petInfo.level then -- this pet is bad
                numBad = numBad + 1
            else
                if petInfo.level==25 then -- this pet is level 25, can't add
                    numCant = numCant + 1
                elseif not petInfo.isOwned then -- this pet is not owned, can't add
                    numCant = numCant + 1
                elseif rematch.queue:IsPetLeveling(petID) then -- this pet is already leveling, won't add
                    numOld = numOld + 1
                else -- this pet is ok to add
                    numNew = numNew + 1
                    excludePetIDs[petID] = true
                end
            end
        else -- this whole species is bad
            numBad = numBad + 1
        end
    end

    return numNew,numOld,numCant,numBad
end

--  imports the pets in the given string into the queue where it can
function rematch.queue:ImportQueue(import)
    local excludePetIDs = {}
    if not import or import=="" then
        return
    end
    for petTag in import:gmatch("[^,]+") do
        local speciesID = rematch.petTags:GetSpecies(petTag)
        if speciesID then
            local petID = rematch.petTags:FindPetID(petTag,excludePetIDs)
            excludePetIDs[petID] = true
            local petInfo = rematch.petInfo:Fetch(petID)
            if petInfo.isValid and petInfo.level and petInfo.level<25 and petInfo.isOwned and not rematch.queue:IsPetLeveling(petID) then
                rematch.queue:AddPetID(petID)
            end
        end
    end
end

-- fires when a pet is captured in a pet battle, learned from a caged pet, and from an item that learns a pet
-- if settings enabled, add new pets to the queue
function rematch.queue:NEW_PET_ADDED(petID)
    if settings.QueueAutoLearn then
        local petInfo = rematch.petInfo:Fetch(petID)
        if petInfo.canBattle and petInfo.level and petInfo.level<25 then
            -- if QueueAutoLearnOnly, only add pets whose species does not have a verion at 25 or in queue
            -- if QueueAutoLearnRare, only add pets that are rare
            local newSpeciesID = petInfo.speciesID -- IsSpeciesAt25 may invalidate petInfo, hold speciesID/name here
            local newFormattedName = petInfo.formattedName
            local isRare = petInfo.rarity==4
            local isAnyAt25 = rematch.collectionInfo:IsSpeciesAt25(newSpeciesID)
            -- QueueAutoLearnOnly also checks if any same species in queue; only bother checking if a 25 not already found
            if not isAnyAt25 and settings.QueueAutoLearnOnly then
                for _,info in ipairs(settings.LevelingQueue) do
                    local speciesID = rematch.petTags:GetSpecies(info.petTag)
                    if speciesID==newSpeciesID then
                        isAnyAt25 = true -- found species in queue, flag it as if there's a 25
                    end
                end
            end
            if (not settings.QueueAutoLearnOnly or not isAnyAt25) and (not settings.QueueAutoLearnRare or isRare) then
                -- add pet to queue and print a "system" message to match the that the pet was just added to journal
                rematch.queue:AddPetID(petID)
                rematch.utils:WriteSystem(format(L["%s has also been added to your leveling queue!"],newFormattedName))
            end
        end
    end
end
