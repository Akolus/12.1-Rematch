local _,rematch = ...

--[[
Rematch Native Breed Engine

Breed formulas/data are based on Battle Pet BreedID by Simca/MMOSimca.
The companion breedData.lua is a renamed copy of BattlePetBreedID/PetData.lua.
Battle Pet BreedID's PetData.lua explicitly permits reuse of the compiled data.

This module intentionally exposes BPBID_Internal as a compatibility layer so
existing Rematch petInfo code and our Pet Card/Battle tooltip modules do not
need to know whether the standalone BattlePetBreedID addon is installed.
]]

rematch.nativeBreed = rematch.nativeBreed or {}
local native = rematch.nativeBreed

_G.BPBID_Internal = _G.BPBID_Internal or {}
local compat = _G.BPBID_Internal
compat.breedCache = compat.breedCache or {}
compat.speciesCache = compat.speciesCache or {}
compat.resultsCache = compat.resultsCache or {}
compat.rarityCache = compat.rarityCache or {}
compat.MAX_BREEDS = 10

local breedNames = {nil,nil,"B/B","P/P","S/S","H/H","H/P","P/S","H/S","P/B","S/B","H/B"}
local eventFrame = CreateFrame("Frame")

local function round(value)
    return math.floor(value + 0.5)
end

local function ensureData()
    if not BPBID_Arrays then
        return false
    end
    if not BPBID_Arrays.BasePetStats and BPBID_Arrays.InitializeArrays then
        BPBID_Arrays.InitializeArrays()
    end
    return BPBID_Arrays.BasePetStats and BPBID_Arrays.BreedStats and BPBID_Arrays.RealRarityValues
end

function compat.RetrieveBreedName(breedID)
    return breedNames[tonumber(breedID)]
end

function native:GetBreedName(breedID)
    return compat.RetrieveBreedName(breedID)
end

function native:GetPossibleBreeds(speciesID)
    if not ensureData() then return nil end
    return BPBID_Arrays.BreedsPerSpecies and BPBID_Arrays.BreedsPerSpecies[speciesID]
end

function native:GetBreedStats(speciesID, breedID, level, quality)
    if not ensureData() then return nil end
    local base = BPBID_Arrays.BasePetStats[speciesID]
    local breed = BPBID_Arrays.BreedStats[breedID]
    local rarity = BPBID_Arrays.RealRarityValues[quality or 4]
    if not base or not breed or not rarity or not level then return nil end

    local ql = rarity * 2 * level
    local health = round((base[1] + breed[1]) * ql * 5 + 100)
    local power  = round((base[2] + breed[2]) * ql)
    local speed  = round((base[3] + breed[3]) * ql)
    return health, power, speed
end

function native:GetBreedStats25(speciesID, breedID)
    return self:GetBreedStats(speciesID, breedID, 25, 4)
end

-- Brute-force equivalent of BPBID's breed solver.  Instead of ten hard-coded
-- diff formulas, generate every legal breed's predicted stats and select the
-- closest match. This also keeps the implementation much easier to maintain.
function compat.CalculateBreedID(speciesID, quality, level, maxHealth, power, speed, wild, flying)
    if not speciesID or quality == nil or not level or not maxHealth or not power or not speed then
        return "ERR", quality, {"ERR"}
    end
    if not ensureData() then
        return "ERR-DATA", quality, {"ERR-DATA"}
    end

    local base = BPBID_Arrays.BasePetStats[speciesID]
    if not base then
        return "NEW", quality, {"NEW"}
    end

    level = tonumber(level)
    quality = tonumber(quality) or 0
    maxHealth = tonumber(maxHealth)
    power = tonumber(power)
    speed = tonumber(speed)

    -- Flying racial: while above 50% health the displayed battle speed is 150%.
    if flying then
        speed = speed / 1.5
    end

    local wildHPFactor, wildPowerFactor = 1, 1
    if wild then
        wildHPFactor = 1.2
        wildPowerFactor = level < 6 and 1.4 or 1.25
    end

    local minQuality, maxQuality
    if quality < 1 then
        minQuality, maxQuality = 1, 6
    else
        minQuality, maxQuality = quality, quality
    end

    local possible = BPBID_Arrays.BreedsPerSpecies and BPBID_Arrays.BreedsPerSpecies[speciesID]
    local candidates = possible and #possible > 0 and possible or {3,4,5,6,7,8,9,10,11,12}

    local bestDiff, bestQuality
    local best = {}

    for q=minQuality,maxQuality do
        local rarity = BPBID_Arrays.RealRarityValues[q]
        if rarity then
            local ql = rarity * 2 * level
            for _,breedID in ipairs(candidates) do
                local breed = BPBID_Arrays.BreedStats[breedID]
                if breed then
                    local predictedHP = round(((base[1] + breed[1]) * ql * 5 + 100) / wildHPFactor)
                    local predictedPower = round(((base[2] + breed[2]) * ql) / wildPowerFactor)
                    local predictedSpeed = round((base[3] + breed[3]) * ql)

                    -- HP is naturally ~5x larger than the other two stats.
                    local diff = math.abs(predictedHP - maxHealth) / 5
                               + math.abs(predictedPower - power)
                               + math.abs(predictedSpeed - speed)

                    if not bestDiff or diff < bestDiff - 0.0001 then
                        bestDiff = diff
                        bestQuality = q
                        wipe(best)
                        best[1] = breedID
                    elseif math.abs(diff - bestDiff) < 0.0001 then
                        best[#best+1] = breedID
                    end
                end
            end
        end
    end

    if #best == 0 then
        return "ERR-MIN", -1, {"ERR-MIN"}
    end

    -- Match the API shape BattlePetBreedID consumers expect: primary breed,
    -- inferred quality, and all equally-good candidates (useful for level 1/2).
    return best[1], bestQuality or quality, best
end

local function isFlyingSpecies(speciesID, owner, index)
    local petType
    if C_PetBattles.GetPetType then
        petType = C_PetBattles.GetPetType(owner,index)
    end
    if not petType and C_PetJournal.GetPetInfoBySpeciesID then
        local _,_,journalType = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
        petType = journalType
    end
    if petType ~= 3 then -- Battle pet type 3 = Flying
        return false
    end
    local health = C_PetBattles.GetHealth(owner,index)
    local maxHealth = C_PetBattles.GetMaxHealth(owner,index)
    return health and maxHealth and maxHealth > 0 and health/maxHealth > 0.5
end

function native:CacheBattleBreeds()
    if not C_PetBattles.IsInBattle() or not ensureData() then return end

    wipe(compat.breedCache)
    wipe(compat.speciesCache)
    wipe(compat.resultsCache)
    wipe(compat.rarityCache)

    local wildBattle = C_PetBattles.IsWildBattle and C_PetBattles.IsWildBattle()

    for owner=1,2 do
        local numPets = C_PetBattles.GetNumPets(owner) or 0
        for index=1,numPets do
            local speciesID = C_PetBattles.GetPetSpeciesID(owner,index)
            if speciesID then
                local level = C_PetBattles.GetLevel(owner,index)
                local quality = (C_PetBattles.GetBreedQuality(owner,index) or 0) + 1
                local maxHealth = C_PetBattles.GetMaxHealth(owner,index)
                local power = C_PetBattles.GetPower(owner,index)
                local speed = C_PetBattles.GetSpeed(owner,index)
                local flying = isFlyingSpecies(speciesID,owner,index)
                local wild = owner==2 and wildBattle or false

                local breedID, inferredQuality, results = compat.CalculateBreedID(
                    speciesID,quality,level,maxHealth,power,speed,wild,flying
                )

                local cacheIndex = index + (owner==2 and 3 or 0)
                compat.breedCache[cacheIndex] = breedID
                compat.speciesCache[cacheIndex] = speciesID
                compat.resultsCache[cacheIndex] = results
                compat.rarityCache[cacheIndex] = inferredQuality
            end
        end
    end
end

function native:GetOwnedBreeds(speciesID)
    -- Return ONE entry for EVERY owned copy. Do not deduplicate breeds:
    -- if the player owns three P/P copies, this intentionally returns
    -- {4, 4, 4} so the UI can display "P/P, P/P, P/P".
    local breeds = {}
    if not speciesID then return breeds end

    local petIDs

    -- Modern Retail: this is independent of Pet Journal search/source filters.
    if C_PetJournal.GetOwnedPetIDs then
        petIDs = C_PetJournal.GetOwnedPetIDs()
    end

    if type(petIDs) == "table" then
        for _,petID in ipairs(petIDs) do
            local petSpeciesID, _, petLevel = C_PetJournal.GetPetInfoByPetID(petID)
            if petSpeciesID == speciesID then
                local _,maxHealth,petPower,petSpeed,petQuality = C_PetJournal.GetPetStats(petID)
                local breedID = compat.CalculateBreedID(
                    speciesID,petQuality,petLevel,maxHealth,petPower,petSpeed,false,false
                )
                if type(breedID)=="number" then
                    breeds[#breeds+1] = breedID
                end
            end
        end
        return breeds
    end

    -- Compatibility fallback for clients without GetOwnedPetIDs().
    -- Preserve/restore the text search and, again, do NOT deduplicate.
    local oldSearch = C_PetJournal.GetSearchFilter and C_PetJournal.GetSearchFilter() or ""
    local restoreSearch = oldSearch ~= ""
    if restoreSearch and C_PetJournal.ClearSearchFilter then
        C_PetJournal.ClearSearchFilter()
    end

    local numPets = C_PetJournal.GetNumPets and C_PetJournal.GetNumPets() or 0
    for i=1,numPets do
        local petID, petSpeciesID = C_PetJournal.GetPetInfoByIndex(i)
        if petID and petSpeciesID == speciesID then
            local _,_,petLevel = C_PetJournal.GetPetInfoByPetID(petID)
            local _,maxHealth,petPower,petSpeed,petQuality = C_PetJournal.GetPetStats(petID)
            local breedID = compat.CalculateBreedID(
                speciesID,petQuality,petLevel,maxHealth,petPower,petSpeed,false,false
            )
            if type(breedID)=="number" then
                breeds[#breeds+1] = breedID
            end
        end
    end

    if restoreSearch and C_PetJournal.SetSearchFilter then
        C_PetJournal.SetSearchFilter(oldSearch)
    end

    return breeds
end

local function scheduleBattleCache()
    C_Timer.After(0, function() native:CacheBattleBreeds() end)
    C_Timer.After(0.15, function() native:CacheBattleBreeds() end)
end

eventFrame:RegisterEvent("PET_BATTLE_OPENING_START")
eventFrame:RegisterEvent("PET_BATTLE_OPENING_DONE")
eventFrame:RegisterEvent("PET_BATTLE_CLOSE")
eventFrame:SetScript("OnEvent",function(_,event)
    if event=="PET_BATTLE_CLOSE" then
        wipe(compat.breedCache)
        wipe(compat.speciesCache)
        wipe(compat.resultsCache)
        wipe(compat.rarityCache)
    else
        scheduleBattleCache()
    end
end)
