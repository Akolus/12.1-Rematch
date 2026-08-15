local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.savedTargets = {}

--[[
    Teams can contain a list of targets; but targets also need an ordered list of teams so teams can
    load in a preferred order. There also needs to be a lookup table indexed by targetID so the player
    changing targets will have an immediate answer to whether the target has a team.

    rematch.savedTargets[targetID] = {
        teamID1, -- ordered lists of teamIDs that use this target
        teamID2,
        teamID3,
    }

    targetID is "target:npcID"

    Note: It's possible for npcID to not be a notable target. A player can save a target for any npc.
    (Use rematch.targetInfo to get information about a targetID)
]]

Rematch5SavedTargets = {} -- savedvar indexed by targetID, an ordered list of teamIDs for this target

-- iterator for targets: for targetID,teams in rematch.savedTargets:AllTargets()
function rematch.savedTargets:AllTargets()
    return next, Rematch5SavedTargets, nil
end

-- fills all savedTargets with teamIDs picked up from savedTeams
local targetsInTeams = {}
function rematch.savedTargets:Update()

    -- wipe old lookup
    for targetID,teams in pairs(targetsInTeams) do
        wipe(targetsInTeams[targetID])
    end

    -- gather targetIDs in teams into lookup table
    for teamID,team in rematch.savedTeams:AllTeams() do
        if team.targets then
            for _,targetID in ipairs(team.targets) do
                if not targetsInTeams[targetID] then
                    targetsInTeams[targetID] = {}
                end
                targetsInTeams[targetID][teamID] = true
            end
        end
    end

    -- if an existing saved target has no teams assigned to it, remove the saved target
    for targetID in pairs(targetsInTeams) do
        if not next(targetsInTeams[targetID]) then
            targetsInTeams[targetID] = nil
            rematch.savedTargets[targetID] = nil
        end
    end

    -- remove teams not used in a target
    for targetID,teams in rematch.savedTargets:AllTargets() do
        for i=#teams,1,-1 do
            if not targetsInTeams[targetID] or not targetsInTeams[targetID][teams[i]] then
                tremove(teams,i)
            end
        end
        if #teams==0 then -- and remove target if all teams removed
            rematch.savedTargets[targetID] = nil
        end
    end

    -- if any teams are not in savedTargets for a target, add them
    for targetID in pairs(targetsInTeams) do
        if not rematch.savedTargets[targetID] then
            rematch.savedTargets[targetID] = {}
        end
        for teamID in pairs(targetsInTeams[targetID]) do
            rematch.utils:TableInsertDistinct(rematch.savedTargets[targetID],teamID)
        end
    end

end

-- saves an ordered list of teamIDs to the targetID; specifically, updates the targets in each of the affected
-- teams while preserving the order of teamIDs in targets and targetIDs in teams
function rematch.savedTargets:Set(targetID,newTeams)
    if type(targetID)=="string" then
        targetID = rematch.targetInfo:GetNpcID(targetID)
    end
    local oldTeams = rematch.savedTargets[targetID] or {}
    -- first remove the targetID from any teams that are in oldTeams but not in newTeams
    for _,teamID in ipairs(oldTeams) do
        if not tContains(newTeams,targetID) then
            local team = rematch.savedTeams[teamID]
            if team and team.targets then
                rematch.utils:TableRemoveByValue(team.targets,targetID)
            end
            -- if no more targets in this team, remove the targets table from the team
            if #team.targets==0 then
                team.targets = nil
            end
        end
    end
    -- next add targetID to any teams in newTeams that are not in oldTeams
    for _,teamID in ipairs(newTeams) do
        if not tContains(oldTeams,targetID) then
            local team = rematch.savedTeams[teamID]
            if team then
                if not team.targets then
                    team.targets = {}
                end
                tinsert(team.targets,targetID)
            end
        end
    end
    -- update savedvar, bypassing setter
    if #newTeams==0 then -- the new teams has no targets, removed savedTargets
        Rematch5SavedTargets[targetID] = nil
    else -- otherwise update savedTargets with new teams without using locked-down setter
        -- create a savedvar for target if one doesn't already exist
        if not Rematch5SavedTargets[targetID] then
            Rematch5SavedTargets[targetID] = {}
        end
        -- then copy newTeams to the savedvar (preserver order)
        wipe(Rematch5SavedTargets[targetID])
        for _,teamID in ipairs(newTeams) do
            tinsert(Rematch5SavedTargets[targetID],teamID)
        end
    end
    -- finally, do a TeamsChanged so everything is ensured to be in sync
    rematch.savedTeams:TeamsChanged()
end

-- returns the ordered list of teamIDs for a target and the index of the first team, which will usually
-- be 1 (topmost team is preferred teamID for the target), but it can change if Prefer Uninjured Teams
-- options is enabled. if there are no valid teams it returns nil. if all pets are injured it will return
-- first valid team's index
function rematch.savedTargets:GetTeams(targetID)
    if type(targetID)=="string" then
        targetID = rematch.targetInfo:GetNpcID(targetID)
    end
    local teams = targetID and Rematch5SavedTargets[targetID]
    if not teams then
        return nil -- this target has no teams, return nothing
    elseif (#teams==1 or not settings.InteractPreferUninjured) and teams[1] and rematch.savedTeams[teams[1]] then
        return teams,1 -- if only one team (or Prefer Uninjured Teams unchecked), just return the team
    else
        local validIndex -- becomes the index to the first valid team
        for i=1,#teams do
            local team = rematch.savedTeams[teams[i]]
            if team then
                local anyInjured = false
                for j=1,3 do
                    anyInjured = anyInjured or rematch.petInfo:Fetch(team.pets[j]).isInjured
                end
                if not validIndex then
                    validIndex = i -- only set on first valid team encountered
                end
                if not anyInjured then
                    return teams,i -- found an uninjured team, return it
                end
            end
        end
        -- if reached here and a valid team was found, all teams are injured, return topmost team
        if validIndex then
            return teams,validIndex
        else -- if no valid team found, return nil
            return nil
        end
    end
end

-- getting a rematch.savedTargets[npcID] will return the Rematch5SavedTargets for that npcID
local function getter(self,targetID)
    -- for quickly looking up whether a target has a saved tean it uses npcID, but lists use target:npcID; convert target:npcID to just the numeric npcID if so
    if type(targetID)=="string" then
        local npcID = tonumber(targetID:match("target:(.+)"))
        if npcID then
            targetID = npcID
        end
    end
    if Rematch5SavedTargets[targetID] then
        return Rematch5SavedTargets[targetID]
    else
        return rawget(self,targetID)
    end
end

-- rematch.savedTargets[x] should only ever assign an empty table or nil; all other changes to savedTargets should be through Update or Set
local function setter(self,targetID,value)
    if not value or (type(value)=="table" and not next(value)) then
        Rematch5SavedTargets[targetID] = value
    end
end

rematch.savedTargets = setmetatable(rematch.savedTargets,{__index = getter, __newindex = setter})
