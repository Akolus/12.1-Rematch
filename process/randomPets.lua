local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.randomPets = {}

-- picks a random high level petID by weight. info is a table of options to influence random pet:
-- info = {
--  petType = preferred pet type can be nil/0 or 1-10
--  rules = one of C.RANDOM_RULES_STRONG/NORMAL/LENIENT
--  excludePetIDs = {} -- lookup table of PetIDs to not pick (eg loaded in other slots)
--  strongVs = pet type the random pet prefers to be strong against
--  toughVs = pet type the random pet prefers to be tough against
--  levelable = true if pet should can level be max level (but still meet loaded preferences)
-- }
local randomPetIDs = {} -- list of random petIDs of the highest weight
function rematch.randomPets:PickRandomPetID(info)
    -- if info is a "random:x" petID, then build info options for that type
    if type(info)=="string" and info:match("^random:") then
        local petType = tonumber(info:match("^random:(%d+)"))
        if type(petType)=="number" and petType>=1 and petType<=10 then
            info = {petType=petType}
        end
    end
    -- if info is still not a table (maybe random:0 for any pet type, or no info given), make it one
    if type(info)~="table" then
        info = {} -- empty table for totally random pet no restrictions
    end
    local bestWeight = 0 -- becomes heighest weight
    wipe(randomPetIDs)
    -- if no rules defined, then use saved setting
    if not info.rules then
        info.rules = settings.RandomPetRules
    end
    for petID in rematch.roster:AllOwnedPets() do
        if not info.excludePetIDs or not info.excludePetIDs[petID] then
            local weight = rematch.randomPets:GetPetIDWeight(petID,info)
            if weight and weight > bestWeight then
                wipe(randomPetIDs)
                tinsert(randomPetIDs,petID)
                bestWeight = weight
            elseif weight==bestWeight then
                tinsert(randomPetIDs,petID)
            end
        end
    end
    if #randomPetIDs > 0 then
        return randomPetIDs[random(#randomPetIDs)],bestWeight
    end
end

-- returns the weight of the petID against the options in info
-- petType      0-1   (1 digit)  10000000  0=don't care about type/doesn't match, 1=pet type matches
-- level        01-25 (2 digits)  1100000  01-25 level value
-- rarity       1-4   (1 digit)     10000  1-4 rarity value
-- in team      0-1   (1 digit)      1000  0=in team, 1=not in team
-- strongVs     0-6   (1 digit)       100  0=no strong vs, 1-6=count of strong vs abilities
-- toughVs      0-1   (1 digit)        10  0=not tough vs, 1=tough vs type
-- health       0-2   (1 digit)         1  0=dead, 1=injured, 2=full health
function rematch.randomPets:GetPetIDWeight(petID,info)
    if not info then
        info = {}
    end
    local petInfo = rematch.altInfo:Fetch(petID)
    -- excluding excluded pets, pets that can't battle, dead pets, elekk plushie, unsummonable pets
    if petInfo.canBattle and not petInfo.isDead and petInfo.speciesID~=1426 and petInfo.isSummonable then

        if info.rules==C.RANDOM_RULES_STRICT and (petInfo.inTeams or petInfo.isInjured) then
            return nil -- for strict rules, always exclude pets that are in teams or injured
        end

        -- total up weight of this pet, starting with health as lowest weight
        local weight = petInfo.health==petInfo.maxHealth and 2 or petInfo.health>0 and 1 or 0
        -- if a toughVs type used, add that type as next highest weight (0=no match, 1=match)
        if info.toughVs then
            weight = weight + 10*(petInfo.toughVs==info.toughVs and 1 or 0)
        end
        -- if a strongVs type used and pet not vulnerable to toughVs type, add the number of abilities that are strong vs
        if info.strongVs and petInfo.vulnerableVs~=info.toughVs then
            local strongCount = 0
            for k,v in pairs(petInfo.strongVs) do
                if v==info.strongVs then
                    -- if Pick Aggressive Counters chosen, then it will prefer pets with more strong abilities
                    if settings.PickAggressiveCounters then
                        strongCount = strongCount + 1
                    else
                        strongCount = 1
                    end
                end
            end
            weight = weight + 100*ceil(strongCount/2) -- halving strongCount to prevent pures from dominating
        end
        --if pet not in any teams (or under lenient rules and we don't care), add next highest
        if info.rules==C.RANDOM_RULES_LENIENT or not petInfo.inTeams then
            weight = weight + 1000
        end
        -- next highest is rarity
        if petInfo.rarity then
            weight = weight + 10000*petInfo.rarity
        end
        -- next highest is level
        if petInfo.level then
            local levelWeight = petInfo.level
            -- for picking a random pet that can level
            if info.levelable and settings.QueueRandomWhenEmpty and not settings.QueueRandomMaxLevel then
                -- if pet can be slotted(summoned) and it can level, weight is 25 for preferred, 1 for non-preferred
                if petInfo.isSummonable and rematch.queue:PetIDCanLevel(petID) then
                    levelWeight = rematch.preferences:IsPetPreferred(petID) and 25 or 1
                else -- 0 weight if it can't be slotted or level
                    levelWeight = 0
                end
            end
            weight = weight + 100000*levelWeight
        end
        -- highest is preferred pet type, if given (and a valid pet type)
        if info.petType and tonumber(info.petType) and info.petType>=1 and info.petType<=10 then
            weight = weight + 10000000*(petInfo.petType==info.petType and 1 or 0)
        end
        return weight -- return weight of this pet
    else
        return nil -- pets that don't qualify don't even get a weight
    end
end

-- given the speciesID, pick a random petID and tag (abilities) that counters the speciesID
local toughCounts = {} -- indexed by ability type, the count of that ability type known by the pet
local counterAbilities = {} -- indexed by ability slot (1-3), the abilityID to use in the counter pet
function rematch.randomPets:PickCounter(speciesID,info)
    local petInfo = rematch.petInfo:Fetch(speciesID)
    if not petInfo.speciesID then -- if not a valid speciesID, then pick a totally random one
        local petID = rematch.randomPets:PickRandomPetID(info)
        return petID, rematch.petTags:Create(petID)
    end
    local strongVs = petInfo.petType
    -- count up the ability types used by opponent pet
    wipe(toughCounts)
    for _,abilityID in ipairs(petInfo.abilityList) do
        local _,_,_,_,_,_,abilityType,noHints = C_PetBattles.GetAbilityInfoByID(abilityID)
        if not noHints and abilityType then -- skipping self heals and such that don't attack
            toughCounts[abilityType] = (toughCounts[abilityType] or 0)+1
        end
    end
    -- pick the ability type used most for toughVs
    local toughMax, toughVs = 0
    for abilityType,count in pairs(toughCounts) do
        if count > toughMax then
            toughVs = abilityType
            toughMax = count
        elseif count==toughMax and random(100)>50 then -- for a bit of randomness, allow switching to different types
            toughVs = abilityType -- (so if opponent has 3 different attach types, it won't always choose tough vs first)
        end
    end
    -- add strongVs and toughVs to info for random pet
    if not info then
        info = {}
    end
    info.strongVs = strongVs
    info.toughVs = toughVs
    info.rules = C.RANDOM_RULES_LENIENT -- always use lenient rules when picking counters
    -- pick a random pet
    local petID = self:PickRandomPetID(info)
    local petInfo = rematch.petInfo:Fetch(petID)
    -- now pick abilities that are strongVs
    wipe(counterAbilities)
    for i,abilityID in ipairs(petInfo.abilityList) do
        if petInfo.strongVs[abilityID]==strongVs then
            if i>3 then
                if not counterAbilities[i-3] or random(100)>40 then -- 60% change to load higher level ability
                    counterAbilities[i-3] = abilityID
                end
            else
                counterAbilities[i] = abilityID
            end
        end
    end
    -- return petID and tag made from petID and abilities
    return petID, rematch.petTags:Create(petID,counterAbilities[1] or 0,counterAbilities[2] or 0,counterAbilities[3] or 0)
end

-- this builds a random team (metateam "counter") to counter the npcID. if no notable pets, it builds from
-- random pets
local opponents = {} -- indexed 1-3, the "target" pet to counter for each slot
local chosenPets = {} -- lookup table of pets already chosen to exclude for random pets
function rematch.randomPets:BuildCounterTeam(npcID)
    if not npcID then -- if no npcID given, use recent target
        npcID = rematch.targetInfo.recentTarget
    end
    rematch.savedTeams:Reset("counter")
    wipe(chosenPets)
    local team = rematch.savedTeams.counter
    team.name = C.COUNTER_TEAM_NAME
    if npcID then
        team.targets = {npcID} -- save target to the team
    end
    local numPets = rematch.targetInfo:GetNumPets(npcID)
    local opponents = rematch.targetInfo:GetNpcPets(npcID)
    for slot=1,3 do
        local counterPetID
        if numPets==3 then
            counterPetID = opponents[slot]
        elseif numPets==2 then
            counterPetID = slot==3 and opponents[2] or opponents[1]
        elseif numPets==1 then
            counterPetID = opponents[1]
        end
        local speciesID = counterPetID and rematch.petInfo:Fetch(counterPetID).speciesID
        local petID,petTag = rematch.randomPets:PickCounter(speciesID,{excludePetIDs=chosenPets})
        team.pets[slot] = petID
        team.tags[slot] = petTag
        if petID then
            chosenPets[petID] = true
        end
    end
end
