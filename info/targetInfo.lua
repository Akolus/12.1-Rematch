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
local sortedTargetNames = {}

local targetHistory = {}
local targetHistoryLookup = {} -- reusable table for target history cleanup
local wildPets = {} -- lookup by npcID, whether this is a wild pet

-- Secret values must be rejected before they are compared, indexed or passed
-- to string functions. In particular, keep this check first in every guard:
-- Lua evaluates boolean expressions from left to right.
local function isSecretValue(value)
    return issecretvalue and issecretvalue(value)
end

local function isPublicString(value)
    if isSecretValue(value) then
        return false
    end
    return type(value) == "string" and value ~= ""
end

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
                local lower = strlower(targetName)
                if not targetNameLookup[lower] then
                    targetNameLookup[lower] = info[2]
                elseif targetNameLookup[lower] ~= info[2] then
                    targetNameLookup[lower] = false
                end
            end
        end

        -- WoW 12.1 compatibility:
        -- In restricted instances UnitGUID/unit names may be secret, but battle-pet
        -- species IDs can remain readable before combat. Map every enemy pet on the
        -- notable team (not only the first): Plagued Critters is a swarm, and the
        -- targeted rat/roach is often pet 2 or 3. If a species maps to more than
        -- one target, mark it ambiguous and never guess.
        for slot = 6, #info do
            local pet = info[slot]
            local speciesID
            if type(pet)=="string" then
                speciesID = tonumber(pet:match("^battlepet:(%d+):"))
            elseif type(pet)=="number" then
                speciesID = pet
            end
            if speciesID then
                if speciesTargetLookup[speciesID] and speciesTargetLookup[speciesID]~=info[2] then
                    speciesTargetLookup[speciesID] = false
                elseif speciesTargetLookup[speciesID]~=false then
                    speciesTargetLookup[speciesID] = info[2]
                end
            end
        end
    end

    if rematch.targetData.nameAliases then
        for aliasName, aliasNpcID in pairs(rematch.targetData.nameAliases) do
            if targetNameLookup[aliasName] and targetNameLookup[aliasName]~=aliasNpcID then
                targetNameLookup[aliasName] = false
            elseif targetNameLookup[aliasName]~=false then
                targetNameLookup[aliasName] = aliasNpcID
                local lower = strlower(aliasName)
                if not targetNameLookup[lower] then
                    targetNameLookup[lower] = aliasNpcID
                elseif targetNameLookup[lower] ~= aliasNpcID then
                    targetNameLookup[lower] = false
                end
            end
        end
    end

    wipe(sortedTargetNames)
    for name, npcID in pairs(targetNameLookup) do
        if type(name) == "string" and type(npcID) == "number" and #name >= 10 then
            sortedTargetNames[#sortedTargetNames + 1] = name
        end
    end
    table.sort(sortedTargetNames, function(a, b) return #a > #b end)

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
    local npcID
    if UnitExists("target") then
        npcID = rematch.targetInfo:GetUnitNpcID("target")
    end
    if not npcID then
        npcID = rematch.targetInfo:GetUnitNpcID("npc")
            or rematch.targetInfo:GetNpcIDFromPublicName("target")
    end
    if npcID then
        self.recentTarget = npcID
        rematch.loadedTargetPanel.teamMode = C.ENEMY_TEAM
        tinsert(targetHistory,npcID)
        rematch.timer:Start(30,cleanupTargetHistory)
        if not wildPets[npcID] and UnitExists("target") then
            local isWildPet = UnitIsWildBattlePet("target")
            if not isSecretValue(isWildPet) and isWildPet then
                local speciesID = UnitBattlePetSpeciesID("target")
                if not isSecretValue(speciesID) and type(speciesID) == "number" then
                    wildPets[npcID] = speciesID
                end
            end
        end
        self.currentTarget = npcID
    elseif not UnitExists("target") then
        self.currentTarget = nil
    end
    rematch.events:Fire("REMATCH_TARGET_CHANGED")
end

-- rematch.targetInfo.recentTarget should be registered first (before PLAYER_LOGIN) so it can define recentTarget
-- before anything else hears the target has changed
rematch.events:Register(rematch.targetInfo,"PLAYER_TARGET_CHANGED",rematch.targetInfo.PLAYER_TARGET_CHANGED)

-- Gossip-enabled dungeon opponents can finish exposing their unit information
-- after PLAYER_TARGET_CHANGED. Re-evaluate once the gossip frame is available.
function rematch.targetInfo:ApplyIdentifiedNpc(npcID)
    if not npcID then
        return
    end
    if npcID == self.currentTarget then
        rematch.events:Fire("REMATCH_TARGET_CHANGED")
        return
    end
    self.recentTarget = npcID
    self.currentTarget = npcID
    rematch.loadedTargetPanel.teamMode = C.ENEMY_TEAM
    tinsert(targetHistory, npcID)
    rematch.events:Fire("REMATCH_TARGET_CHANGED")
end

function rematch.targetInfo:GOSSIP_SHOW()
    local npcID = rematch.targetInfo:GetUnitNpcID("npc")
        or rematch.targetInfo:GetUnitNpcID("target")
        or rematch.targetInfo:GetUnitNpcID("softinteract")
        or rematch.targetInfo:GetNpcIDFromPublicName("npc")
    self:ApplyIdentifiedNpc(npcID)
    if not npcID and C_Timer and C_Timer.After then
        C_Timer.After(0.15, function()
            local retry = rematch.targetInfo:GetUnitNpcID("npc")
                or rematch.targetInfo:GetNpcIDFromPublicName("npc")
            rematch.targetInfo:ApplyIdentifiedNpc(retry)
        end)
    end
end
rematch.events:Register(rematch.targetInfo,"GOSSIP_SHOW",rematch.targetInfo.GOSSIP_SHOW)

function rematch.targetInfo:NAME_PLATE_UNIT_ADDED(unit)
    if not unit then
        return
    end
    local function isSameUnit(other)
        if not UnitIsUnit then
            return
        end
        local ok, result = pcall(UnitIsUnit, unit, other)
        return ok and not isSecretValue(result) and result and true or false
    end
    if isSameUnit("target") or isSameUnit("npc") then
        local npcID = rematch.targetInfo:GetUnitNpcID(unit) or rematch.targetInfo:GetNpcIDFromPublicName(unit)
        self:ApplyIdentifiedNpc(npcID)
    end
end
rematch.events:Register(rematch.targetInfo,"NAME_PLATE_UNIT_ADDED",rematch.targetInfo.NAME_PLATE_UNIT_ADDED)

function rematch.targetInfo:SCENARIO_UPDATE()
    local npcID = rematch.targetInfo:GetNpcIDFromPublicName("target")
    self:ApplyIdentifiedNpc(npcID)
end
rematch.events:Register(rematch.targetInfo,"SCENARIO_UPDATE",rematch.targetInfo.SCENARIO_UPDATE)
rematch.events:Register(rematch.targetInfo,"SCENARIO_CRITERIA_UPDATE",rematch.targetInfo.SCENARIO_UPDATE)


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

local function lookupNpcByName(name)
    if not isPublicString(name) then
        return
    end
    name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%.+$", ""):gsub("%s+$", "")
    local npcID = targetNameLookup[name]
    if type(npcID) ~= "number" then
        npcID = targetNameLookup[strlower(name)]
    end
    if type(npcID) == "number" then
        return rematch.targetData.redirects[npcID] or npcID
    end
    -- Truncated unit-frame names such as "Plagued Critt..."
    if #name >= 8 then
        local hits, only, count = {}, nil, 0
        local prefix = strlower(name)
        for known, id in pairs(targetNameLookup) do
            if type(known) == "string" and type(id) == "number" and #known >= #name and strlower(known):sub(1, #prefix) == prefix then
                if not hits[id] then
                    hits[id] = true
                    count = count + 1
                    only = id
                end
            end
        end
        if count == 1 then
            return rematch.targetData.redirects[only] or only
        end
    end
end

local function matchPublicBlob(text)
    if not isPublicString(text) then
        return
    end
    local lower = strlower(text)
    local hints = rematch.targetData.publicTextHints
    if hints then
        for hint, npcID in pairs(hints) do
            if lower:find(hint, 1, true) then
                return rematch.targetData.redirects[npcID] or npcID
            end
        end
    end
    for i = 1, #sortedTargetNames do
        local known = sortedTargetNames[i]
        if lower:find(strlower(known), 1, true) then
            return lookupNpcByName(known)
        end
    end
end

local function considerName(name, into)
    local npcID = lookupNpcByName(name)
    if npcID then
        into[#into + 1] = npcID
    end
end

local function scanFrameForKnownNames(frame, into, depth)
    if not frame or (depth or 0) > 6 then
        return
    end
    if frame.GetObjectType and frame:GetObjectType() == "FontString" then
        considerName(frame.GetText and frame:GetText(), into)
        return
    end
    if frame.GetRegions then
        local regions = {frame:GetRegions()}
        for i = 1, #regions do
            local region = regions[i]
            if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                considerName(region.GetText and region:GetText(), into)
            end
        end
    end
    if frame.GetChildren then
        local children = {frame:GetChildren()}
        for i = 1, #children do
            scanFrameForKnownNames(children[i], into, (depth or 0) + 1)
        end
    end
end

-- Identify a notable npcID from any public name still readable in a secret dungeon:
-- unit names, gossip titles, and on-screen gossip FontStrings.
function rematch.targetInfo:GetNpcIDFromPublicName(unit)
    local found = {}

    if unit then
        considerName(UnitName(unit), found)
        if GetUnitName then
            considerName(GetUnitName(unit, false), found)
        end
    end

    considerName(UnitName("npc"), found)
    considerName(UnitName("target"), found)
    considerName(UnitName("softinteract"), found)
    considerName(UnitName("mouseover"), found)

    if C_GossipInfo then
        if C_GossipInfo.GetCustomGossipTitleName then
            considerName(C_GossipInfo.GetCustomGossipTitleName(), found)
        end
        if C_GossipInfo.GetText then
            local npcID = matchPublicBlob(C_GossipInfo.GetText())
            if npcID then
                found[#found + 1] = npcID
            end
        end
        if C_GossipInfo.GetOptions then
            local options = C_GossipInfo.GetOptions()
            if type(options) == "table" then
                for i = 1, #options do
                    local option = options[i]
                    local optionName = type(option) == "table" and (option.name or option.text or option[2]) or option
                    local npcID = lookupNpcByName(optionName) or matchPublicBlob(optionName)
                    if npcID then
                        found[#found + 1] = npcID
                    end
                end
            end
        end
    end

    if GossipFrame then
        if GossipFrame.TitleContainer and GossipFrame.TitleContainer.TitleText then
            considerName(GossipFrame.TitleContainer.TitleText:GetText(), found)
        end
        if GossipFrameNpcNameText then
            considerName(GossipFrameNpcNameText:GetText(), found)
        end
        pcall(scanFrameForKnownNames, GossipFrame, found, 0)
        local npcID = matchPublicBlob(GossipFrameGreetingText and GossipFrameGreetingText:GetText())
        if npcID then
            found[#found + 1] = npcID
        end
    end

    if TargetFrame then
        if TargetFrame.name then
            considerName(TargetFrame.name.GetText and TargetFrame.name:GetText(), found)
        end
        if TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentMain then
            local main = TargetFrame.TargetFrameContent.TargetFrameContentMain
            if main.Name and main.Name.GetText then
                considerName(main.Name:GetText(), found)
            end
        end
    end

    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        for _, token in ipairs({unit or "target", "target", "npc", "softinteract", "mouseover"}) do
            local plate = C_NamePlate.GetNamePlateForUnit(token)
            if plate then
                pcall(scanFrameForKnownNames, plate, found, 0)
                if plate.UnitFrame then
                    if plate.UnitFrame.name then
                        considerName(plate.UnitFrame.name.GetText and plate.UnitFrame.name:GetText(), found)
                    end
                    if plate.UnitFrame.Name then
                        considerName(plate.UnitFrame.Name.GetText and plate.UnitFrame.Name:GetText(), found)
                    end
                end
            end
        end
    end

    if C_Scenario then
        local ok, scenarioName, currentStage = pcall(C_Scenario.GetInfo)
        if ok then
            local npcID = matchPublicBlob(scenarioName)
            if npcID then
                found[#found + 1] = npcID
            end
        end
        if C_Scenario.GetStepInfo then
            local okStep, stepName, stageDescription = pcall(C_Scenario.GetStepInfo)
            if okStep then
                local npcID = matchPublicBlob(stepName) or matchPublicBlob(stageDescription)
                if npcID then
                    found[#found + 1] = npcID
                end
            end
        end
    end

    if ScenarioObjectiveTracker then
        pcall(scanFrameForKnownNames, ScenarioObjectiveTracker, found, 0)
    end

    if C_TooltipInfo and C_TooltipInfo.GetUnit then
        for _, tooltipUnit in ipairs({unit or "npc", "npc", "target"}) do
            local ok, info = pcall(C_TooltipInfo.GetUnit, tooltipUnit)
            if ok and info and info.lines then
                for i = 1, #info.lines do
                    local line = info.lines[i]
                    if line then
                        considerName(line.leftText, found)
                    end
                end
            end
        end
    end

    return found[1]
end

-- returns the npcID of the given unit ("target"/"mouseover"), or nil if unit doesn't exist/is a player
function rematch.targetInfo:GetUnitNpcID(unit)
    if not UnitExists(unit) then
        return
    end

    -- Normal path: use the unit GUID when Blizzard allows addon code to read it.
    local guid = UnitGUID(unit)
    if not isSecretValue(guid) and type(guid) == "string" then
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
    if not isSecretValue(speciesID) and type(speciesID) == "number" then
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
    if not isSecretValue(isPlayer) and isPlayer then
        return
    end
    local unitName = UnitName(unit)
    if isPublicString(unitName) then
        local npcID = lookupNpcByName(unitName)
        if npcID then
            return npcID
        end
    end

    return rematch.targetInfo:GetNpcIDFromPublicName(unit)
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
            if isPublicString(name) then
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
