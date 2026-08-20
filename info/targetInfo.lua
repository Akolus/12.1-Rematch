local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
rematch.targetInfo = {}

--[[
    This gets information about npcIDs, mostly for notable targets, but some support for all npcIDs

    Only three functions work for all npcIDs:
        GetUnicNpcID(unit) -- returns a numeric npcID for the unit, either "target" or "mouseover" usually
        GetNpcName(npcID) -- returns the name of the npcID (see comment on function; it returns C.CACHE_RETRIEVING
                             if the name is not returned and the call needs to happen again!)
        GetTargetHistory() -- returns an ordered list of the last 3 npcIDs the player targeted

    The rest of the functions are built around the 325+ notable targets:
        AllTargets() -- iterator function to iterate over all npcIDs in the order they list
        IsNotable(npcID) -- returns true if the npcID (or its redirected target) is in targetData
        GetNpcInfo(npcID) -- returns the headerID,mapID,expansionID,questID for the given notable npcID
        GetNpcPets(npcID) -- returns an ordered table of petInfo-usable battlepet:etc strings for the notable npcID
        GetHeaderName(npcID) -- returns the name of the header (generally name of map used to group) for notable npcID
        GetExpansionName(npcID) -- returns the name of the expansion for the notable npcID
        GetQuestName(npcID) -- returns the name of the npcID's quest (nil if no quest or C.CACHE_RETRIEVING if not cached)
        GetLocations(npcID) -- returns a \n-delimited list of map names associated with the notable npcID
]]

local targetIndexes = {} -- indexed by npcID, the index into targetData for that npcID
local speciesTargetLookup = {} -- WoW 12.1 fallback: first enemy battle-pet speciesID -> unique notable npcID
local targetNameLookup = {} -- WoW 12.1 fallback: readable unit name -> unique notable npcID
local targetNameCache = {} -- indexed by npcID, the localized name of the npcID
local targetsToCache = {} -- indexed by npcID, the number of cache attempts for this npcID
local reusedPets = {} -- reused table of pets to reduce garbage creation

local targetHistory = {}
local targetHistoryLookup = {} -- reusable table for target history cleanup
local wildPets = {} -- lookup by npcID, whether this is a wild pet

local testModel = CreateFrame("PlayerModel") -- used to get displayIDs, a hidden model to SetCreature(npcID) and GetDisplayInfo()
testModel:Hide()

rematch.targetInfo.recentTarget = nil -- the last npcID targeted (can be nil but is generally not nil'ed by dropping target)
rematch.targetInfo.currentTarget = nil -- the current npcID targeted (or nil if a player or no current target)

-- on login, populate targetIndexes with indexes into notableTargets for each npcID
rematch.events:Register(rematch.targetInfo,"PLAYER_LOGIN",function(self)
    for index,info in ipairs(rematch.targetData.notableTargets) do
        targetIndexes[info[2]] = index

        -- Some dungeon opponents are gossip-enabled objects rather than battle-pet
        -- units, so UnitBattlePetSpeciesID() returns nil for them. Their unit name
        -- can still be readable even when their GUID is secret. Build a second
        -- lookup and reject duplicate names rather than risk loading a wrong team.
        local targetName = rematch.targetData.targetNames and rematch.targetData.targetNames[info[2]]
        if type(targetName)=="string" then
            if targetNameLookup[targetName] and targetNameLookup[targetName]~=info[2] then
                targetNameLookup[targetName] = false
            elseif targetNameLookup[targetName]~=false then
                targetNameLookup[targetName] = info[2]
            end
        end

        -- WoW 12.1 compatibility:
        -- In restricted instances UnitGUID/unit names may be secret, but battle-pet
        -- species IDs can remain readable before combat. Build a lookup from the
        -- first enemy pet species to its notable target. If a species maps to more
        -- than one target, mark it ambiguous and never guess.
        local firstPet = info[6]
        local speciesID
        if type(firstPet)=="string" then
            speciesID = tonumber(firstPet:match("^battlepet:(%d+):"))
        elseif type(firstPet)=="number" then
            speciesID = firstPet
        end
        if speciesID then
            if speciesTargetLookup[speciesID] and speciesTargetLookup[speciesID]~=info[2] then
                speciesTargetLookup[speciesID] = false
            elseif speciesTargetLookup[speciesID]~=false then
                speciesTargetLookup[speciesID] = info[2]
            end
        end
    end
    -- if sometehing targeted while logging in, capture target
    if UnitExists("target") then
        self:PLAYER_TARGET_CHANGED()
    end
end)

-- does maintenance on the targetHistory list of targeted npcIDs
local function cleanupTargetHistory()
    -- first remove any duplicates, keeping only the topmost (most recent) distinct copy
    wipe(targetHistoryLookup)
    for i=#targetHistory,1,-1 do
        local npcID = targetHistory[i]
        if targetHistoryLookup[npcID] then
            tremove(targetHistory,i)
        else
            targetHistoryLookup[npcID] = true
        end
    end
    -- then if there's more than 3 (C.TARGET_HISTORY_SIZE) remove earlier ones so at most 3 remain
    for i=1,(#targetHistory-C.TARGET_HISTORY_SIZE) do
        tremove(targetHistory,1)
    end
end

function rematch.targetInfo:PLAYER_TARGET_CHANGED()
    if UnitExists("target") then
        local npcID = rematch.targetInfo:GetUnitNpcID("target")
        if npcID then
            self.recentTarget = npcID
            rematch.loadedTargetPanel.teamMode = C.ENEMY_TEAM

            -- add npcID to history and come back in a while to do cleanup so list doesn't get huge
            -- and we don't waste time doing maintenance in a PLAYER_TARGET_CHANGED
            tinsert(targetHistory,npcID)
            rematch.timer:Start(30,cleanupTargetHistory)

            -- if the target is a wild pet that hasn't been saved to the wildPets lookup yet, add it
            if not wildPets[npcID] and UnitIsWildBattlePet("target") then
                wildPets[npcID] = UnitBattlePetSpeciesID("target")
            end

        end
        self.currentTarget = npcID
    else
        self.currentTarget = nil
    end
    rematch.events:Fire("REMATCH_TARGET_CHANGED")
end

-- rematch.targetInfo.recentTarget should be registered first (before PLAYER_LOGIN) so it can define recentTarget
-- before anything else hears the target has changed
rematch.events:Register(rematch.targetInfo,"PLAYER_TARGET_CHANGED",rematch.targetInfo.PLAYER_TARGET_CHANGED)

-- Gossip-enabled dungeon opponents can finish exposing their unit information
-- after PLAYER_TARGET_CHANGED. Re-evaluate once the gossip frame is available.
function rematch.targetInfo:GOSSIP_SHOW()
    local npcID = rematch.targetInfo:GetUnitNpcID("target")
    if npcID and npcID~=self.currentTarget then
        self:PLAYER_TARGET_CHANGED()
    end
end
rematch.events:Register(rematch.targetInfo,"GOSSIP_SHOW",rematch.targetInfo.GOSSIP_SHOW)


-- sometimes this addon "targets" something via loadedTargetPanel:SetTarget(npcID); these should show in history also
function rematch.targetInfo:SetRecentTarget(npcID)
    if not npcID then
        self.recentTarget = nil
    else
        if type(npcID)=="string" then
            npcID = rematch.targetInfo:GetNpcID(npcID)
        end
        if type(npcID)=="number" then
            self.recentTarget = npcID
            tinsert(targetHistory,npcID)
        end
    end
end

-- returns an ordered list of the 3 (C.TARGET_HISTORY_SIZE) most recent targets, with the most recent at the end of the list
function rematch.targetInfo:GetTargetHistory()
    cleanupTargetHistory()
    return targetHistory
end

-- returns the npcID of the given unit ("target"/"mouseover"), or nil if unit doesn't exist/is a player
function rematch.targetInfo:GetUnitNpcID(unit)
    if not UnitExists(unit) then
        return
    end

    -- Normal path: use the unit GUID when Blizzard allows addon code to read it.
    local guid = UnitGUID(unit)
    if guid and not issecretvalue(guid) then
        local npcID = tonumber(guid:match(".-%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
        if npcID and npcID~=0 then
            return rematch.targetData.redirects[npcID] or npcID
        end
    end

    -- WoW 12.1 restricted-instance fallback:
    -- pet-battle targets can expose a non-secret species ID even when their GUID
    -- and name are secret. Do NOT require UnitIsWildBattlePet() here: scripted
    -- dungeon opponents such as "Captain" Klutz are battle pets but may not be
    -- flagged as wild pets before combat.
    local speciesID = UnitBattlePetSpeciesID(unit)
    if speciesID and not issecretvalue(speciesID) then
        local npcID = speciesTargetLookup[speciesID]
        if type(npcID)=="number" then
            return rematch.targetData.redirects[npcID] or npcID
        end
    end

    -- Gossip-enabled targets such as Gnomeregan's Door Control Console are
    -- interaction objects, not battle-pet units, and therefore have no species
    -- ID. Fall back to a public unit name only when it maps to one unique notable
    -- target. Explicitly exclude players to avoid matching an NPC-like character
    -- name.
    local isPlayer = UnitIsPlayer(unit)
    if not issecretvalue(isPlayer) and isPlayer then
        return
    end
    local unitName = UnitName(unit)
    if not issecretvalue(unitName) and type(unitName)=="string" then
        local npcID = targetNameLookup[unitName]
        if type(npcID)=="number" then
            return rematch.targetData.redirects[npcID] or npcID
        end
    end
end

-- gets the localized name of an npcID from a tooltip scan. tooltip scans are computationally expensive so
-- it will cache the result and use that in future calls. if the npcID didn't get a name the npcID will be
-- added to targetsToCache and return "Retrieving name..." to display. in this case, the calling function
-- can wait a second and re-update to try for the name again. once the number of attempts are exceeded, it
-- will return "NPC <npcID>". (the goal here is to not cache all 300+ npcs on login. the calling function
-- should do a delayed update if the name returned is C.CACHE_RETRIEVING)
function rematch.targetInfo:GetNpcName(npcID,noDisplay)
    if type(npcID)=="string" then
        npcID = tonumber(npcID:match("target:(%d+)"))
    end
    -- if target has a subname like (Legendary) then it will be appended to name
    local subname = ""
    if rematch.targetData.subnames[npcID] then
        subname = format(" (%s)",rematch.targetData.subnames[npcID])
    end
    if type(npcID)~="number" then
        return L["No Target"]
    elseif rematch.targetData.targetNames and rematch.targetData.targetNames[npcID] then
        return rematch.targetData.targetNames[npcID]..subname
    elseif targetNameCache[npcID] then -- if name cached, return it
        return targetNameCache[npcID]..subname
    else
        local tooltip = RematchTooltipScan or CreateFrame("GameTooltip","RematchTooltipScan",nil,"GameTooltipTemplate")
        tooltip:SetOwner(UIParent,"ANCHOR_NONE")
        tooltip:SetHyperlink(format("unit:Creature-0-0-0-0-%d-0000000000",npcID))
        if tooltip:NumLines()>0 then
            local name = RematchTooltipScanTextLeft1:GetText()
            if name and not issecretvalue(name) and name:len()>0 then
                targetNameCache[npcID] = name
                targetsToCache[npcID] = nil
                return name..subname
            end
        end
        -- if we reached here, then this npcID is still not cached
        if not targetsToCache[npcID] then
            targetsToCache[npcID] = GetTime()
        end
        if GetTime()-targetsToCache[npcID] < C.CACHE_TIMEOUT then -- haven't exceeded timeout duration, return temp name
            if not noDisplay then -- if name wasn't cached and we're displaying it, come back in a bit and update UI (could be team or target list or elsewhere that needs update)
                rematch.timer:Start(C.CACHE_WAIT,rematch.frame.Update) 
            end
            return C.CACHE_RETRIEVING
        else -- exceeded retry attempts, cache it as NPC <npcID> and give up trying
            local name = format(L["%s (npc id %d)"],UNKNOWN,npcID)
            targetNameCache[npcID] = name
            targetsToCache[npcID] = nil
            return name..subname
        end
    end
end

-- gets the displayID for the given npcID, by setting a model to that npcID and then getting its displayID from that
function rematch.targetInfo:GetNpcDisplayID(npcID)
    if type(npcID)=="number" then
        testModel:SetCreature(npcID)
        return testModel:GetDisplayInfo()
    end
end

--[[ notable npcs: the following only apply to the 300+ npcs in targetData ]]

-- iterator function to iterate over all npcIDs in order in targetData
-- usage: for npcID in rematch.targetInfo:AllTargets() do print(npcID) end
function rematch.targetInfo:AllTargets()
    local i = 0
    return function()
        local targetData = rematch.targetData.notableTargets
        i = i + 1
        if i <= #targetData then
            return targetData[i][2]
        end
    end
end

-- returns true if the npcID is in the notableTargets table (with redirect too)
function rematch.targetInfo:IsNotable(npcID)
    return rematch.targetInfo:GetNpcInfo(npcID) and true
end

function rematch.targetInfo:IsWildPet(npcID)
    return wildPets[npcID] and true or false
end

-- returns the headerID,mapID,expansionID,questID for the given notable npcID
function rematch.targetInfo:GetNpcInfo(npcID)
    if type(npcID)=="string" then
        npcID = tonumber(npcID:match("target:(%d+)"))
    end
    if not npcID then
        return
    end
    if rematch.targetData.redirects[npcID] then
        npcID = rematch.targetData.redirects[npcID]
    end
    if targetIndexes[npcID] then
        local info = rematch.targetData.notableTargets[targetIndexes[npcID]]
        --info[1] = "header:"..info[1] -- make header into a headerID usable in lists
        return "header:"..info[1],info[3],info[4],info[5]
    end
end

-- converts target:12345 to numeric 12345
function rematch.targetInfo:GetNpcID(targetID)
    return type(targetID)=="string" and tonumber(targetID:match("target:(.+)")) or targetID
end

-- returns an ordered table of petInfo-usable battlepet:etc strings for the notable npc
-- if numSlots is defined, the table is padded with empty slots before the pet(s)
-- returns a single unnotable pet if the npc is not notable (use GetNumPets to get a real count)
function rematch.targetInfo:GetNpcPets(npcID,numSlots)
    if type(npcID)=="string" then
        npcID = tonumber(npcID:match("target:(%d+)"))
    end
    if not npcID then
        return
    end
    if rematch.targetData.redirects[npcID] then
        npcID = rematch.targetData.redirects[npcID]
    end
    wipe(reusedPets)
    if targetIndexes[npcID] then -- if this is a notable npc, pets are known
        local info = rematch.targetData.notableTargets[targetIndexes[npcID]]
        for i=6,8 do
            if info[i] then
                tinsert(reusedPets,info[i])
            end
        end
    elseif wildPets[npcID] then -- if not a notable npc but it is a seen wild pet, add a speciesID for the pet
        tinsert(reusedPets,wildPets[npcID])
    else -- otherwise add unobtainable:npcID petID
        tinsert(reusedPets,"unnotable:"..npcID)
    end
    if numSlots then
        for i=#reusedPets+1,(numSlots or 3) do
            tinsert(reusedPets,1,"empty")
        end
    end
    return reusedPets
end

-- returns the number of pets this npcID is known to have, 0 if not notable or no pets
function rematch.targetInfo:GetNumPets(npcID)
    if type(npcID)=="string" then
        npcID = tonumber(npcID:match("target:(%d+)"))
    end
    if not npcID then
        return 0
    end
    if rematch.targetData.redirects[npcID] then
        npcID = rematch.targetData.redirects[npcID]
    end
    if targetIndexes[npcID] then
        return #rematch.targetData.notableTargets[targetIndexes[npcID]]-5
    elseif wildPets[npcID] then
        return 1 -- wild pets have 1 pet, the speciesID
    else
        return 0
    end
end

-- gets the headerID of the given npcID
function rematch.targetInfo:GetHeaderID(npcID)
    return rematch.targetInfo:GetNpcInfo(npcID)
end

-- returns the name of the header from the headerID (first return of GetNpcInfo)
function rematch.targetInfo:GetHeaderName(headerID)
    local name = headerID:match("header:(.+)")
    local mapID = tonumber(name)
    if mapID then
        local mapInfo = C_Map.GetMapInfo(mapID)
        return mapInfo and mapInfo.name or UNKNOWN
    else
        return L[name]
    end
end

-- returns the expansionID of the header
function rematch.targetInfo:GetHeaderExpansionID(headerID)
    return headerID and rematch.targetData.headerExpansions[headerID]
end

-- returns the name of the expansion associated with the notable npcID
function rematch.targetInfo:GetExpansionName(npcID)
    local _,_,expansionID = rematch.targetInfo:GetNpcInfo(npcID)
    return _G["EXPANSION_NAME"..expansionID]
end

-- returns the name of the quest associated with the notable npcID, if any. (if a quest name hasn't been
-- cached yet, it will return nothing; todo: make it return CACHE_RETRIEVING with a timeout like name?)
function rematch.targetInfo:GetQuestName(npcID)
    local _,_,_,questID = rematch.targetInfo:GetNpcInfo(npcID)
    if questID then
        local name = C_TaskQuest.GetQuestInfoByQuestID(questID) or C_QuestLog.GetTitleForQuestID(questID)
        return name --or C.CACHE_RETRIEVING
    end
end

function rematch.targetInfo:GetExpansionID(npcID)
    local _,_,expansionID = rematch.targetInfo:GetNpcInfo(npcID)
    return expansionID
end

-- for GetLocations(), a small recursive function to get a list of map names where mapID is
local exploredIDs = {} -- reused ordered list of map names in the following
local function exploreMapID(mapID)
    local mapInfo = C_Map.GetMapInfo(mapID)
    if mapInfo and mapInfo.name and mapID~=946 and mapID~=947 then
        local prefix = #exploredIDs>0 and "\124cffa0a0a0" or ""
        tinsert(exploredIDs,prefix..mapInfo.name)
        exploreMapID(mapInfo.parentMapID)
    end
end

-- returns a string of the map a notable npcID belongs to and its parent maps, up to but not
-- including cosmic/azeroth
function rematch.targetInfo:GetLocations(npcID)
    local _,mapID = rematch.targetInfo:GetNpcInfo(npcID)
    wipe(exploredIDs)
    exploreMapID(mapID)
    if #exploredIDs>0 then
        return table.concat(exploredIDs,"\n")
    else
        return UNKNOWN
    end
end
