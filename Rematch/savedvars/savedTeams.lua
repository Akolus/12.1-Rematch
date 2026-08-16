local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.savedTeams = {}

--[[
    A team has this definition:

        rematch.savedTeams[teamID] = {
            teamID = "team:0", -- unique identifier of the team (required and persistent)
            name = "", -- unique name of the team (required, case insensitive)
            pets = {petID,petID,petID}, -- list of petIDs (or speciesIDs/"leveling"/"random:0"/"ignored") (required)
            tags = {petTag,petTag,petTag}, -- list of petTags of petIDs (required)
            [favorite = true,] -- whether team is favorited
            [groupID = "group:0",] -- group for team (defaults to group:none)
            [homeID = "group:0",] -- groupID the team belongs to when it's not favorited (or potential future group)
            [notes = "",] -- notes for team
            [targets = {targetID,targetID,targetID,...},] -- ordered list of targets
            [preferences = {minHP=0,maxHP=0,minXP=0,maxXP=0,allowMM=true,expectedDD=0},]
            [winrecord = {wins=0,losses=0,draws=0,battles=0},]
        }

    teamID is generated for each new team and always increments. Deleted teamIDs may be reused.

]]

Rematch5SavedTeams = {} -- actual savedvar for the teams (don't reference this directly)

-- some teams are not a savedvar but can be used/referenced like one and serve a special role
local metaTeams = {
    empty = {teamID="empty",name="",pets={},tags={}}, -- a team with empty values (for resetting sideline or temporary)
    sideline = {teamID="sideline",name="",pets={},tags={}}, -- teams being created/manipulated without affecting a live team
    loadonly = {teamID="loadonly",name=BATTLE_PET_SLOTS,pets={},tags={}}, -- teams loaded without being saved
    temporary = {teamID="temporary",name="",pets={},tags={}}, -- temporary holding place for teams
    original = {teamID="original",name="",pets={},tags={}}, -- for save dialog to compare original team against modifications
    counter = {teamID="counter",name=C.COUNTER_TEAM_NAME,pets={},tags={}}, -- for random counter teams from target panel
}

-- indexed by petID, the count of teams that contain the petID (updated in updatePets())
local numPetsByTeamID = {}
-- indexed by team name, the teamID that has the name
local teamIDsByName = {}
-- number of teams (updated during afterTeamsChange)
local numTeams = 0

-- ordered list of team events and the args to pass when they fire at the end of afterTeamsChanged
dispatch = {}

--[[ local functions ]]

-- returns true if the given team is structured properly
local function validateTeamStructure(team)
    if not team or type(team)~="table" then -- this isn't even an attempt at a team
        return false
    elseif not team.teamID then -- all teams must have a teamID
        return false
    elseif not team.name then -- all teams must have a name
        return false
    elseif type(team.pets)~="table" then -- all teams must have a list of petIDs (even if empty)
        return false
    elseif type(team.tags)~="table" then -- all teams must have a list of petTags (even if empty)
        return false
    end
    return true -- gauntlet passed, this team is valid
end

-- copies a team from the source to the destination; all except teamID
local function copyTeam(source,dest)
    assert(type(dest)=="table" and dest.teamID,"Attempt to copy to a malformed team: "..(source.teamID or "nil").." to "..(type(dest)=="table" and "nil" or "non-tabnle"))
    assert(validateTeamStructure(source),"Attempt to copy from a malformed team: "..(source.teamID or "nil").." to "..(dest.teamID or "nil"))
    source.name = source.name:trim()
    -- first wipe the destination of all but teamID
    for k,v in pairs(dest) do
        if k=="teamID" then
            -- do nothing
        elseif k=="pets" or k=="tags" then
            wipe(v) -- pets and tags tables are mandatory
        else
            dest[k] = nil -- but all other tables (and non-tables beside teamID) are optional
        end
    end
    -- now copy contents of source to dest
    for k,v in pairs(source) do
        if k=="teamID" then
            -- never replace teamID
        elseif type(v)=="table" then --k=="pets" or k=="tags" or k=="targets" or k=="preferences" then
            dest[k] = CopyTable(v)
        else
            dest[k] = v
        end
    end
    -- if non-meta team doesn't have a group after copy, put it in group:none
    if not dest.groupID and not metaTeams[dest.teamID] then
        dest.groupID = "group:none"
    end
end

-- returns an unused team:<number> for use as a unique teamID
local function getNewUniqueTeamID()
    local teamID = 1
    while Rematch5SavedTeams["team:"..teamID] do
        teamID = teamID + 1
    end
    return "team:"..teamID
end

-- rematch.savedTeams[key] will get the savedvar unless it's a meta teamID
local function getter(self,key)
    if metaTeams[key] then
        return metaTeams[key]
    else -- every other teamID should be a number
        return Rematch5SavedTeams[key] -- otherwise returns the savedvar team of the given temID
    end
end

-- rematch.savedTeams[key] = {team} will "copy" the contents of {team} to rematch.savedTeams[key]
-- if {team} is nil, it will empty metateams or nil savedvar teams
local function setter(self,key,value)
    if key=="empty" then
        return -- empty team should never be modified
    elseif value==nil then -- if nil'ing a team
        if metaTeams[key] then -- if nil'ing a metateam, empty it but don't nil it
            copyTeam(metaTeams.empty,metaTeams[key])
        else -- otherwise nil the saved team
            Rematch5SavedTeams[key] = nil
            tinsert(dispatch,{"REMATCH_TEAM_DELETED",key})
            rematch.savedTeams:TeamsChanged()
        end
    elseif validateTeamStructure(value) then -- if assigning another team to this team
        value.name = value.name:trim()
        if metaTeams[key] then -- if setting a metaTeam value, then copy the team
            copyTeam(value,metaTeams[key])
        elseif Rematch5SavedTeams[key] then -- team already exists, replace contents
            copyTeam(value,Rematch5SavedTeams[key])
            tinsert(dispatch,{"REMATCH_TEAM_UPDATED",key})
            rematch.savedTeams:TeamsChanged()
        end
    end
end

-- updates numPetsByTeamID with all petIDs in a team and how many teams they belong to
-- while here looping through teams, update numTeams to the number of teams
local function updatePets()
    local pets = numPetsByTeamID
    wipe(pets)
    numTeams = 0
    for teamID,team in rematch.savedTeams:AllTeams() do
        numTeams = numTeams + 1
        for i=1,3 do
            local petID = team.pets[i]
            if petID then
                if type(petID)=="number" and ((i==2 and petID==team.pets[1]) or (i==3 and (petID==team.pets[1] or petID==team.pets[2]))) then
                    -- for speciesIDs, we only want to count it once per team; so do nothing if we already added this speciesID
                elseif not pets[petID] then
                    pets[petID] = 1 -- first time encountering petID, start count at 1
                else
                    pets[petID] = pets[petID] + 1 -- already-encountede petID, increment count
                end
            end
        end
    end
end

-- updates teamIDsByName with all team names and the teamID the name is used by
local function updateNames()
    wipe(teamIDsByName)
    for teamID,team in rematch.savedTeams:AllTeams() do
        teamIDsByName[team.name:lower()] = teamID
    end
end

-- runs 0 frames after rematch.savedTeams:TeamsChanged() to do housekeeping and fires REMATCH_TEAMS_CHANGED event
local function afterTeamsChanged()
    rematch.savedTargets:Update() -- update targets based on teams
    rematch.savedGroups:Update() -- update groups based on teams
    updatePets()
    updateNames()
    -- if any REMATCH_TEAM_CREATED, REMATCH_TEAM_DELETED, REMATCH_TEAM_UPDATED events are waiting to fire them, fire them here
    if #dispatch>0 then
        for _,info in ipairs(dispatch) do
            rematch.events:Fire(info[1],info[2],info[3],info[4])
        end
        wipe(dispatch)
    end
    -- and then fire a generic REMATCH_TEAMS_CHANGED
    rematch.events:Fire("REMATCH_TEAMS_CHANGED")
    if rematch.frame:IsVisible() then
        rematch.frame:Update()
    end
end

--[[ public functions ]]

-- iterator for all teams (a normal loop over rematch.savedTeams is a loop over a near-empty table with just a couple functions)
function rematch.savedTeams:AllTeams()
    return next, Rematch5SavedTeams, nil
end

-- empties a metateam ("sideline" or "temporary")
-- to reset a regular team, reset a sideline and assign it to the team
function rematch.savedTeams:Reset(teamID)
    assert(metaTeams[teamID],"Reset must be a named metaTeam such as \"sideline\" or \"temporary\"")
    -- to reset a regular team, reset a sideline and assign it to the team
    copyTeam(metaTeams.empty,metaTeams[teamID])
end

-- constructor for a new team; creates a new teamID in Rematch5SavedTeams from the sideline team
function rematch.savedTeams:Create()
    local sideline = metaTeams.sideline
    assert(sideline,"Sideline team is malformed. Can't create a new team.")
    --assert(sideline.name:len()>0,"Sideline team has no name. Can't create a new team.")
    if not sideline.name or sideline.name:len()==0 then
        sideline.name = L["New Team"]
    end
    -- create a new table from a copy of the sideline
    local team = CopyTable(sideline)
    -- if name is already taken, make a unique name by appending (2) after it (or 3, 4, etc.)
    team.name = rematch.savedTeams:GetUniqueName(team.name:trim())
    -- assign a unique teamID
    team.teamID = getNewUniqueTeamID()
    -- and a groupID if none was in sideline
    if not team.groupID then
        team.groupID = "group:none"
    end
    -- and save
    Rematch5SavedTeams[team.teamID] = team
    tinsert(dispatch,{"REMATCH_TEAM_CREATED",team.teamID})
    rematch.savedTeams:TeamsChanged()
    return team
end

-- deletes a non-meta team
function rematch.savedTeams:DeleteTeam(teamID)
    if teamID and rematch.savedTeams[teamID] then
        rematch.savedTeams[teamID] = nil
        rematch.savedTeams:TeamsChanged()
    end
end

-- moves teamID to groupID and returns true if teamID's groupID was successfully changed
function rematch.savedTeams:MoveTeam(teamID,groupID)
    local moved = false
    if rematch.savedTeams:IsUserTeam(teamID) and groupID and rematch.savedGroups[groupID] then
        local team = rematch.savedTeams[teamID]
        if groupID=="group:favorites" and groupID~=team.groupID then -- moving to favorites, set homeID
            team.homeID = team.groupID
            team.favorite = true
            team.groupID = groupID
            moved = true
        elseif team.groupID=="group:favorites" and groupID~=team.groupID then -- moving out of favorites, clear homeID
            team.homeID = nil
            team.favorite = nil
            team.groupID = groupID
            moved = true
        end
    end
    if moved then -- calling procedure may call this too which is fine; this is critical to run so group.teams can be rebuilt
        rematch.savedTeams:TeamsChanged()
    end
    return moved
end

-- returns a unique team name, either based off the given name or "New Team", appending a (2) (or (3), (4), etc.)
-- if the name is already taken
function rematch.savedTeams:GetUniqueName(name)
    updateNames()
    name = (name or L["New Team"]):trim()
    if not teamIDsByName[tostring(name):lower()] then
        return name -- name given (or "New Team") is not taken yet, return it
    end
    name = name:trim():gsub(" %(%d+%)$","") -- take off any trailing (2)s
    local num = 1 -- this will be incremented to 2
    local newName
    repeat
        num = num + 1
        newName = format("%s (%d)",name,num)
    until newName and not teamIDsByName[newName:lower()]
    return newName
end

-- returns the number of teams with the given petID (can be a speciesID for uncollected pets)
function rematch.savedTeams:GetNumTeamsWithPet(petID)
    return petID and numPetsByTeamID[petID] or 0
end

-- returns the teamID of the team with the given name
function rematch.savedTeams:GetTeamIDByName(name)
    return name and teamIDsByName[name:lower()]
end

-- returns true if the teamID is not a "meta" team like "counter" or "sideline"
function rematch.savedTeams:IsUserTeam(teamID)
    return (teamID and not metaTeams[teamID] and rematch.savedTeams[teamID]) and true or false
end

-- returns the number of teams saved (excludes meta teams)
function rematch.savedTeams:GetNumTeams()
    return numTeams
end

-- deletes all teams
function rematch.savedTeams:Wipe()
    Rematch5SavedTeams = {}
    tinsert(dispatch,{"REMATCH_TEAMS_WIPED"})
    rematch.savedTeams:TeamsChanged()
end

-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
-- !!                                                       !!
-- !!  CALL THIS WHEN TARGETS/PETS/NAMES ON A TEAM CHANGES  !!
-- !!                                                       !!
-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
-- this does a 0-frame timer before running housekeeping from changing teams; the validation is relatively
-- expensive, so a 0-frame timer is used out of an abundance of caution that it doesn't happen multiple times in a row
function rematch.savedTeams:TeamsChanged(now)
    if now then
        afterTeamsChanged() -- if now is true, do an immediate update (only do this when necessary; eg dragging teams)
    else
        rematch.timer:Start(0,afterTeamsChanged)
    end
end

-- add getter and setter metamethods that get/set to savedvar instead of rematch.savedTeams
setmetatable(rematch.savedTeams,{__index=getter,__newindex=setter})

-- after pets are loaded (this fires from roster), do housekeeping (roster will already call ValidateAllTeams)
rematch.events:Register(rematch.savedTeams,"REMATCH_PETS_LOADED",function()
    tinsert(dispatch,{"REMATCH_TEAMS_READY"})
    rematch.savedTeams:TeamsChanged()
end)
