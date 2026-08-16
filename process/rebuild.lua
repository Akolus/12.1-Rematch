local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.rebuild = {}

-- making a separate petInfo so it doesn't clobber any other processing in progress
rematch.rebuild.petInfo = rematch.petInfo:Create()

-- indexed by teamID ({["team:1"]=true}) when teams need rebuild they're added to this lookup table
local rebuildQueue = {}
-- for finding replacement pets, so we don't grab pets from other slots on the team
local excludePetIDs = {}

-- does the actual rebuild of a specific teamID
local function rebuildTeamID(teamID)
    local teamChanged = false -- becomes true if a team change happened
    local team = rematch.savedTeams[teamID]
    if not team then
        return -- should already be vetted, but just to be safe
    end
    -- first add all petIDs in the team to excludePetIDs (if invalid it needs replaced anyway)
    wipe(excludePetIDs)
    for i=1,3 do
        local petID = team.pets[i]
        if petID then
            excludePetIDs[petID] = true
        end
    end
    -- then for any speciesIDs that player has collected, or a collected pet that's invalid, find a replacement
    for i=1,3 do
        local petID = team.pets[i]
        local petInfo = rematch.rebuild.petInfo:Fetch(petID)
        if team.tags[i] and ((petInfo.idType=="species" and petInfo.count>0) or (petInfo.idType=="pet" and not petInfo.isValid)) then
            local newPetID = rematch.petTags:FindPetID(team.tags[i],excludePetIDs)
            if newPetID then -- found a pet, update team with this new pet
                team.pets[i] = newPetID
                excludePetIDs[newPetID] = true -- and don't pick this pet for future slots in this team
            else -- no pet found, put a speciesID in its place
                local speciesID = rematch.petTags:GetSpecies(team.tags[i])
                if speciesID then
                    team.tags[i] = speciesID
                else
                    team.pets[i] = nil -- this pet is completely unrecoverable; empty it so we don't waste time on it again
                end
            end
            teamChanged = true
        end
    end
    -- this will run a 0-frame wait to update teams and then UI if the team changed at all
    if teamChanged then
        rematch.savedTeams:TeamsChanged()
    end
end

-- called after a delay to rebuild all waiting teams
local function rebuildAllTeams()
    -- go through queue and rebuild each team now
    for teamID in pairs(rebuildQueue) do
        rebuildTeamID(teamID)
    end
    wipe(rebuildQueue)
end

-- adds a teamID to the queue to be rebuilt (or rebuilds immediately if now is true)
local function rebuildTeam(teamID,now)
    if now then
        rebuildTeamID(teamID)
    else
        rebuildQueue[teamID] = teamID
        rematch.timer:Start(0,rebuildAllTeams)
    end
end

-- confirms all petIDs are valid; if not then it will be queued to be rebuilt; if now is true,
-- it will rebuild immediately. returns true if team was valid with no changes needed
function rematch.rebuild:ValidateTeamID(teamID,now)
    local team = teamID and rematch.savedTeams[teamID]
    if not team then
        return false -- team doesn't even exist, not valid
    end
    for i=1,3 do
        local petID = team.pets[i]
        local petInfo = rematch.rebuild.petInfo:Fetch(petID)
        if petInfo.idType=="species" then
            if petInfo.count>0 then -- this speciesID is owned, rebuild
                rebuildTeam(teamID,now)
                return false
            end
        elseif petInfo.idType=="pet" and not petInfo.isValid then
            rebuildTeam(teamID,now)
            return false
        end
    end
    -- if made it here, all pets are good (or unfixable!)
    return true
end
