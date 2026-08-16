local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.collectionInfo = {}

--[[
    Information about the collection, such as number of pets at 25 and such, is kept here.
]]

-- on-demand table for species at 25
local speciesAt25 = rematch.odTable:Create(function(self)
    for petID in rematch.roster:AllOwnedPets() do
        local petInfo = rematch.petInfo:Fetch(petID)
        if petInfo.level==25 then
            self[petInfo.speciesID] = true
        end
    end
end)

-- this is used for level filter "Moveset Not At 25" and is probably used even more rarely
local movesetsAt25 = rematch.odTable:Create(function(self)
    speciesAt25:Start()
    for speciesID in pairs(speciesAt25) do
        local moveset = rematch.speciesInfo:GetMoveset(speciesID)
        if moveset then
            self[moveset] = true
        end
    end
end)

-- this is used for other filter "Unique Moveset" to find all pets that have a unique moveset
local uniqueMovesets = rematch.odTable:Create(function(self)
    -- first gather a count of all movesets
    for speciesID in rematch.roster:AllSpecies() do
        local petInfo = rematch.petInfo:Fetch(speciesID)
        local moveset = petInfo.moveset
        if moveset and petInfo.canBattle then
            self[moveset] = (self[moveset] or 0) + 1
        end
    end
    -- now remove the movesets with more than 1
    for moveset,count in pairs(self) do
        if count>1 then
            self[moveset] = nil
        end
    end
end)

-- used by pet summary/statistics to break down pets
local speciesStats = rematch.odTable:Create(function(self)
    for petID in rematch.roster:AllPets() do
        local petInfo = rematch.petInfo:Fetch(petID)
        local speciesID = petInfo.speciesID
        if not self[speciesID] then
            self[speciesID] = {petInfo.petType,petInfo.sourceID,0,0,0,0,0,0,0,0,0}
        end
        if petInfo.isOwned then
            local info = self[speciesID]
            info[3] = info[3] + 1 -- numPets
            info[4] = info[4] + (petInfo.level==25 and 1 or 0) -- numAt25
            info[5] = info[5] + (petInfo.level or 0) -- totalLevels
            if type(petInfo.rarity)=="number" and petInfo.rarity>0 then
                info[6+petInfo.rarity] = info[5+petInfo.rarity]+1 -- rarity takes up 7th through 10th indexes
            end
            info[11] = petInfo.canBattle and 1 or 0
        end
        -- unowned pets can be saved in a team, add those separately
        if petInfo.inTeams then
            self[speciesID][6] = self[speciesID][6] + 1
        end
    end
end)

-- an unordered table of details about the collection
local collectionStats = rematch.odTable:Create(function(self)
    -- collection[speciesID] = {petType,source,numPets,numAt25,totalLevels,numPoor,numCommon,numUncommon,numRare}
    local stats = rematch.collectionInfo:GetSpeciesStats()

    self.numInJournal = 0
    self.numCollectedUnique = 0
    self.numCollectedTotal = 0
    self.numUncollected = 0
    self.numUniqueMax = 0 -- unique pets at max level
    self.numTotalMax = 0 -- total pets at max level
    self.totalLevels = 0 -- used in average level calculation
    self.numUniqueRare = 0
    self.numTotalRare = 0
    self.numUncommon = 0
    self.numCommon = 0
    self.numPoor = 0
    self.averageLevel = 0

    -- average level will exclude pets that can't battle
    local battleNumCollectedTotal = 0
    local battleTotalLevels = 0

    for _,info in pairs(stats) do
        self.numInJournal = self.numInJournal + 1
        if info[3]==0 then
            self.numUncollected = self.numUncollected + 1
        else
            self.numCollectedTotal = self.numCollectedTotal + info[3] -- total collected pets
            self.numCollectedUnique = self.numCollectedUnique + 1 -- unique collected pets
            self.numTotalMax = self.numTotalMax + info[4] -- total pets at max level
            self.numUniqueMax = self.numUniqueMax + min(info[4],1) -- unique pets at max level
            self.totalLevels = self.totalLevels + info[5]
            self.numPoor = self.numPoor + info[7] -- total poor
            self.numCommon = self.numCommon + info[8] -- total common
            self.numUncommon = self.numUncommon + info[9] -- total uncommon
            self.numTotalRare = self.numTotalRare + info[10] -- rare pets
            self.numUniqueRare = self.numUniqueRare + min(info[10],1) -- unique rare pets
            if info[11]>0 then -- if pet can battle
                battleNumCollectedTotal = battleNumCollectedTotal + info[3]
                battleTotalLevels = battleTotalLevels + info[5]
            end
        end
    end

    if battleTotalLevels > 0 and battleNumCollectedTotal > 0 then
        self.averageLevel = battleTotalLevels/battleNumCollectedTotal
    end

end)

-- returns whether the given speciesID has a version at 25
function rematch.collectionInfo:IsSpeciesAt25(speciesID)
    return speciesAt25[speciesID] or false
end

-- returns the whole lookup table of species at 25
function rematch.collectionInfo:GetAllSpeciesAt25()
    speciesAt25:Start()
    return speciesAt25
end

-- returns whether the given moveset has a pet at 25
function rematch.collectionInfo:IsMovesetAt25(moveset)
    return movesetsAt25[moveset] or false
end

-- returns whether the moveset is unique
function rematch.collectionInfo:IsMovesetUnique(moveset)
    return uniqueMovesets[moveset] and true
end

-- returns stats about all species in a lookup table by speciesID where each is an ordered list of stats:
-- [speciesID] = {petType,source,numPets,numAt25,totalLevels,numPoor,numCommon,numUncommon,numRare}
function rematch.collectionInfo:GetSpeciesStats()
    speciesStats:Start()
    return speciesStats
end

function rematch.collectionInfo:GetCollectionStats()
    collectionStats:Start()
    return collectionStats
end

-- returns a table of winrecord stats for all teams, including a table of the top ten teamIDs by wins/percent
-- limit, if given, will limit the topTeams to the first limit entries (3 or 10)
function rematch.collectionInfo:GetWinStats(limit)
    local winStats = {battles=0,teams=0,wins=0,losses=0,draws=0,topTeams={}}
    local teamStats = {} -- ordered table of wins, percent wins and teamID gathered while counting totals
    for teamID,team in rematch.savedTeams:AllTeams() do
        if team.winrecord then
            local recordWins = team.winrecord.wins or 0
            local recordLosses = team.winrecord.losses or 0
            local recordDraws = team.winrecord.draws or 0
            local recordBattles = team.winrecord.battles or recordWins+recordLosses+recordDraws
            winStats.teams = winStats.teams + 1
            winStats.battles = winStats.battles + recordBattles
            winStats.wins = winStats.wins + recordWins
            winStats.losses = winStats.losses + recordLosses
            winStats.draws = winStats.draws + recordDraws
            if settings.RankWinsByPercent then
                tinsert(teamStats,format("%.5f %06d %s",recordBattles>0 and recordWins/recordBattles or 0,recordWins,teamID))
            else
                tinsert(teamStats,format("%09d %.5f %s",recordWins,recordBattles>0 and recordWins/recordBattles or 0,teamID))
            end
        end
    end
    table.sort(teamStats,function(e1,e2) return e1>e2 end)
    -- from all teams in teamStats, fill ordered table with top limit(eg top 10) {teamID,totalWins,percentWins}
    for i=1,(limit or #teamStats) do
        if teamStats[i] then
            local value1,value2,teamID = teamStats[i]:match("([0-9.]+) ([0-9.]+) (.+)")
            value1 = tonumber(value1)
            value2 = tonumber(value2)
            if settings.RankWinsByPercent then
                tinsert(winStats.topTeams,{teamID,value2,value1})
            else
                tinsert(winStats.topTeams,{teamID,value1,value2})
            end
        end
    end
    return winStats
end

