local _, rematch = ...

-- Rematch Battle Breed Tooltip
-- Adds a compact breed-information tooltip while hovering any pet in a pet battle.
--
-- Shows:
--   Current Breed
--   Owned Breeds
--   every possible breed's level-25 Rare HP/Power/Speed
--
-- It intentionally does NOT print a "Possible Breeds: ..." name-only line.

local module = {}
rematch.battleBreedTooltip = module

local tooltip
local hooked = false
local eventFrame = CreateFrame("Frame")

local ALLY = Enum.BattlePetOwner.Ally
local ENEMY = Enum.BattlePetOwner.Enemy

local GOLD = "|cFFD4A017"
local BLUE = "|cFF0070DD"
local WHITE = "|cFFFFFFFF"
local RESET = "|r"

local function EnsureArrays()
    if BPBID_Arrays and not BPBID_Arrays.BasePetStats and BPBID_Arrays.InitializeArrays then
        BPBID_Arrays.InitializeArrays()
    end
end

local function GetBreedName(breedID)
    if type(breedID) ~= "number" then
        return "???"
    end

    if rematch.breedInfo and rematch.breedInfo.GetBreedNameByID then
        local name = rematch.breedInfo:GetBreedNameByID(breedID)
        if name then
            return name
        end
    end

    if BPBID_Internal and BPBID_Internal.RetrieveBreedName then
        local ok, name = pcall(BPBID_Internal.RetrieveBreedName, breedID)
        if ok and name then
            return name
        end
    end

    return tostring(breedID)
end

local function GetRare25Stats(speciesID, breedID)
    EnsureArrays()

    if not BPBID_Arrays
        or not BPBID_Arrays.BasePetStats
        or not BPBID_Arrays.BreedStats
        or not BPBID_Arrays.RealRarityValues then
        return
    end

    local base = BPBID_Arrays.BasePetStats[speciesID]
    local breed = BPBID_Arrays.BreedStats[breedID]
    local rarityValue = BPBID_Arrays.RealRarityValues[4] -- Rare

    if not base or not breed or not rarityValue then
        return
    end

    local qualityFactor = ((rarityValue - 0.5) * 2 + 1)

    local health = math.ceil(
        (base[1] + breed[1]) * 25 * qualityFactor * 5 + 100 - 0.5
    )
    local power = math.ceil(
        (base[2] + breed[2]) * 25 * qualityFactor - 0.5
    )
    local speed = math.ceil(
        (base[3] + breed[3]) * 25 * qualityFactor - 0.5
    )

    return health, power, speed
end

local function CalculateOwnedBreed(petID, speciesID)
    if not petID or not speciesID or not BPBID_Internal or not BPBID_Internal.CalculateBreedID then
        return
    end

    local _, _, _, _, level = C_PetJournal.GetPetInfoByPetID(petID)
    local health, maxHealth, power, speed, rarity = C_PetJournal.GetPetStats(petID)

    if not level or not rarity or not maxHealth or not power or not speed then
        return
    end

    local ok, breedID = pcall(
        BPBID_Internal.CalculateBreedID,
        speciesID,
        rarity,
        level,
        maxHealth,
        power,
        speed,
        false,
        false
    )

    if ok and type(breedID) == "number" then
        return breedID
    end
end

local function GetOwnedBreedNames(speciesID)
    local result = {}
    if not speciesID then
        return result
    end

    -- Native Rematch breed engine returns one breed ID per owned pet copy.
    -- Deliberately preserve duplicates so 3 identical copies display as:
    -- P/P, P/P, P/P
    if rematch.nativeBreed and rematch.nativeBreed.GetOwnedBreeds then
        local breedIDs = rematch.nativeBreed:GetOwnedBreeds(speciesID)
        for _,breedID in ipairs(breedIDs) do
            result[#result+1] = GetBreedName(breedID)
        end
        return result
    end

    -- Fallback for the pre-native setup. Also preserve every copy.
    local oldSearch = C_PetJournal.GetSearchFilter and C_PetJournal.GetSearchFilter() or ""
    local restoreSearch = oldSearch and oldSearch ~= ""

    if restoreSearch and C_PetJournal.ClearSearchFilter then
        C_PetJournal.ClearSearchFilter()
    end

    local numPets = C_PetJournal.GetNumPets and C_PetJournal.GetNumPets() or 0

    for i = 1, numPets do
        local petID, speciesID2 = C_PetJournal.GetPetInfoByIndex(i)

        if petID and speciesID2 == speciesID then
            local breedID = CalculateOwnedBreed(petID, speciesID)
            if breedID then
                result[#result + 1] = GetBreedName(breedID)
            end
        end
    end

    if restoreSearch and C_PetJournal.SetSearchFilter then
        C_PetJournal.SetSearchFilter(oldSearch)
    end

    return result
end

local function GetBattleInfo(owner, index)
    if not owner or not index then
        return
    end

    local speciesID = C_PetBattles.GetPetSpeciesID(owner, index)
    if not speciesID or speciesID == 0 then
        return
    end

    local petID
    if rematch.battle and rematch.battle.GetUnitPetID then
        petID = rematch.battle:GetUnitPetID(owner, index)
    else
        petID = ("battle:%d:%d"):format(owner, index)
    end

    local petInfo = rematch.petInfo:Fetch(petID)
    local currentBreedID = petInfo.breedID
    local currentBreedName = petInfo.breedName

    -- If Rematch hasn't populated breed info yet, use BPBID's battle cache.
    if (not currentBreedID or currentBreedID == 0) and BPBID_Internal and BPBID_Internal.breedCache then
        local cacheIndex = index + (owner == ENEMY and 3 or 0)
        local cached = BPBID_Internal.breedCache[cacheIndex]
        if type(cached) == "number" then
            currentBreedID = cached
            currentBreedName = GetBreedName(cached)
        end
    end

    local possibleIDs = petInfo.possibleBreedIDs
    if (not possibleIDs or #possibleIDs == 0)
        and BPBID_Arrays
        and BPBID_Arrays.BreedsPerSpecies then
        possibleIDs = BPBID_Arrays.BreedsPerSpecies[speciesID]
    end

    return speciesID, currentBreedID, currentBreedName, possibleIDs
end

local function EnsureTooltip()
    if tooltip then
        return
    end

    tooltip = CreateFrame(
        "GameTooltip",
        "RematchBattleBreedTooltip",
        UIParent,
        "GameTooltipTemplate"
    )
    tooltip:SetFrameStrata("TOOLTIP")
end

local function AnchorTooltip(unitFrame)
    tooltip:ClearAllPoints()

    -- If Rematch is replacing Blizzard's unit tooltip with the Pet Card,
    -- attach our breed block beneath that card. Otherwise attach it beneath
    -- Blizzard's normal battle-pet tooltip.
    if rematch.settings.PetCardInBattle
        and rematch.petCard
        and rematch.petCard:IsShown() then
        tooltip:SetPoint("TOPLEFT", rematch.petCard, "BOTTOMLEFT", 0, -2)
        tooltip:SetPoint("TOPRIGHT", rematch.petCard, "BOTTOMRIGHT", 0, -2)
    elseif PetBattlePrimaryUnitTooltip and PetBattlePrimaryUnitTooltip:IsShown() then
        tooltip:SetPoint("TOPLEFT", PetBattlePrimaryUnitTooltip, "BOTTOMLEFT", 0, -2)
        tooltip:SetPoint("TOPRIGHT", PetBattlePrimaryUnitTooltip, "BOTTOMRIGHT", 0, -2)
    else
        tooltip:SetOwner(unitFrame, "ANCHOR_NONE")
        tooltip:SetPoint("TOPLEFT", unitFrame, "BOTTOMLEFT", 0, -6)
    end
end

function module:Show(unitFrame)
    if not unitFrame or not C_PetBattles.IsInBattle() then
        return
    end

    local owner = unitFrame.petOwner
    local index = unitFrame.petIndex
    local speciesID, currentBreedID, currentBreedName, possibleIDs = GetBattleInfo(owner, index)

    if not speciesID then
        self:Hide()
        return
    end

    EnsureTooltip()
    tooltip:SetOwner(unitFrame, "ANCHOR_NONE")
    tooltip:ClearLines()
    AnchorTooltip(unitFrame)

    currentBreedName = currentBreedName
        or (currentBreedID and GetBreedName(currentBreedID))
        or "???"

    tooltip:AddLine(
        GOLD .. "Current Breed:" .. RESET .. " " .. WHITE .. currentBreedName .. RESET,
        1, 1, 1, true
    )

    local ownedBreeds = GetOwnedBreedNames(speciesID)
    local ownedText = #ownedBreeds > 0 and table.concat(ownedBreeds, ", ") or "None"

    tooltip:AddLine(
        GOLD .. "Owned Breeds:" .. RESET .. " " .. WHITE .. ownedText .. RESET,
        1, 1, 1, true
    )

    EnsureArrays()

    if possibleIDs and #possibleIDs > 0 then
        for _, breedID in ipairs(possibleIDs) do
            local health, power, speed = GetRare25Stats(speciesID, breedID)
            local breedName = GetBreedName(breedID)

            if health and power and speed then
                tooltip:AddLine(
                    BLUE .. breedName .. " at 25:" .. RESET .. " "
                        .. WHITE .. health .. "/" .. power .. "/" .. speed .. RESET,
                    1, 1, 1, false
                )
            end
        end
    else
        tooltip:AddLine(GOLD .. "Breed stats:" .. RESET .. " Unknown", 1, 1, 1, true)
    end

    tooltip:Show()
end

function module:Hide()
    if tooltip then
        tooltip:Hide()
    end
end

local function HookUnitFrame(frame)
    if not frame or frame.RematchBattleBreedTooltipHooked then
        return
    end

    frame.RematchBattleBreedTooltipHooked = true

    frame:HookScript("OnEnter", function(self)
        -- Defer one frame so Blizzard/Rematch finishes placing its own tooltip/card.
        C_Timer.After(0, function()
            if self:IsMouseMotionFocus() and C_PetBattles.IsInBattle() then
                module:Show(self)
            end
        end)
    end)

    frame:HookScript("OnLeave", function()
        module:Hide()
    end)
end

function module:Setup()
    if hooked or not PetBattleFrame then
        return
    end

    hooked = true

    for _, key in ipairs({
        "ActiveAlly", "ActiveEnemy",
        "Ally2", "Ally3",
        "Enemy2", "Enemy3"
    }) do
        HookUnitFrame(PetBattleFrame[key])
    end
end

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PET_BATTLE_CLOSE")

eventFrame:SetScript("OnEvent", function(_, event, addonName)
    if event == "PLAYER_LOGIN" then
        if C_AddOns.IsAddOnLoaded("Blizzard_PetBattleUI") then
            module:Setup()
        end
    elseif event == "ADDON_LOADED" and addonName == "Blizzard_PetBattleUI" then
        module:Setup()
    elseif event == "PET_BATTLE_CLOSE" then
        module:Hide()
    end
end)

C_Timer.After(0, function()
    if PetBattleFrame then
        module:Setup()
    end
end)
