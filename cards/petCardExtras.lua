local _, rematch = ...

-- Rematch Pet Card Extras
-- Hold SHIFT while the Rematch Pet Card is visible to show possible breeds.
-- Hold CTRL while the Rematch Pet Card is visible to show a model-only card.
-- Both companion cards are exactly the same outer size as RematchPetCard: 258x358.

local module = {}
rematch.petCardExtras = module

local MODEL_CARD_WIDTH = 258
local MODEL_CARD_HEIGHT = 358
local MODEL_DEFAULT_ZOOM = 0.15
local MODEL_MIN_ZOOM = 0.05
local MODEL_MAX_ZOOM = 0.80
local MODEL_ZOOM_STEP = 0.05

-- Breed card is a little wider to give the current-breed star its own column.
-- Its height is recalculated from the number of possible breeds.
local BREED_CARD_WIDTH = 278
local BREED_HEADER_HEIGHT = 114
local BREED_ROW_HEIGHT = 23
local BREED_BOTTOM_PADDING = 18
local CARD_GAP = 6

local eventFrame = CreateFrame("Frame")
local breedFrame
local modelFrame
local modelWindowOpen = false
local petIconClickHooked = false

-- Forward declaration because the PetIcon click handler can call this before
-- the function body appears later in the file.
local UpdateModelFrame

local function IsPetCardUsable()
    return rematch.petCard
        and rematch.petCard:IsShown()
        and rematch.petCard.petID ~= nil
end

local function GetPetInfo()
    if not IsPetCardUsable() then
        return nil
    end
    return rematch.petInfo:Fetch(rematch.petCard.petID)
end

local function GetRareLevel25Stats(speciesID, breedID)
    if not BPBID_Arrays then
        return nil
    end

    if not BPBID_Arrays.BasePetStats and BPBID_Arrays.InitializeArrays then
        BPBID_Arrays.InitializeArrays()
    end

    if not BPBID_Arrays.BasePetStats
        or not BPBID_Arrays.BreedStats
        or not BPBID_Arrays.RealRarityValues then
        return nil
    end

    local base = BPBID_Arrays.BasePetStats[speciesID]
    local breed = BPBID_Arrays.BreedStats[breedID]
    local rarityValue = BPBID_Arrays.RealRarityValues[4] -- Rare

    if not base or not breed or not rarityValue then
        return nil
    end

    local qualityFactor = ((rarityValue - 0.5) * 2 + 1)

    local health = math.ceil((base[1] + breed[1]) * 25 * qualityFactor * 5 + 100 - 0.5)
    local power  = math.ceil((base[2] + breed[2]) * 25 * qualityFactor - 0.5)
    local speed  = math.ceil((base[3] + breed[3]) * 25 * qualityFactor - 0.5)

    return health, power, speed
end

local function CreatePanel(name, title, width, height)
    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetFrameStrata("FULLSCREEN")
    frame:SetClampedToScreen(true)
    frame:Hide()

    -- Deliberately no edgeFile: the companion cards should look clean and
    -- borderless while retaining a subtle dark panel background.
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        tile = true,
        tileSize = 32,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })

    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.Title:SetPoint("TOP", 0, -14)
    frame.Title:SetText(title or "")

    return frame
end

local function EnsureBreedFrame()
    if breedFrame then
        return
    end

    breedFrame = CreatePanel("RematchPossibleBreedsCard", "Possible Breeds", BREED_CARD_WIDTH, BREED_HEADER_HEIGHT + BREED_ROW_HEIGHT + BREED_BOTTOM_PADDING)
    breedFrame:SetPoint("TOPRIGHT", rematch.petCard, "TOPLEFT", -CARD_GAP, 0)

    breedFrame.PetName = breedFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    breedFrame.PetName:SetPoint("TOP", 0, -42)
    breedFrame.PetName:SetWidth(242)
    breedFrame.PetName:SetJustifyH("CENTER")

    breedFrame.Subtitle = breedFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    breedFrame.Subtitle:SetPoint("TOP", breedFrame.PetName, "BOTTOM", 0, -4)
    breedFrame.Subtitle:SetText("Level 25 Rare stats")

    local line = breedFrame:CreateTexture(nil, "ARTWORK")
    line:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
    line:SetTexCoord(0.8125, 0.9453125, 0.625, 0.9375)
    line:SetPoint("TOPLEFT", 14, -78)
    line:SetPoint("TOPRIGHT", -14, -78)
    line:SetHeight(5)

    local headers = {
        { "",       14, 24 },
        { "Breed",  38, 58 },
        { "Health", 100, 58 },
        { "Power",  160, 52 },
        { "Speed",  214, 52 },
    }

    for _, info in ipairs(headers) do
        local fs = breedFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", info[2], -90)
        fs:SetWidth(info[3])
        fs:SetJustifyH("CENTER")
        fs:SetText(info[1])
    end

    breedFrame.rows = {}

    for i = 1, 10 do
        local row = CreateFrame("Frame", nil, breedFrame)
        row:SetSize(244, 22)
        row:SetPoint("TOP", 0, -110 - ((i - 1) * BREED_ROW_HEIGHT))

        row.Highlight = row:CreateTexture(nil, "BACKGROUND")
        row.Highlight:SetAllPoints()
        row.Highlight:SetColorTexture(1, 0.82, 0, 0.08)
        row.Highlight:Hide()

        -- Separate star icon instead of prefixing the breed text.
        row.Star = row:CreateTexture(nil, "OVERLAY")
        row.Star:SetSize(18, 18)
        row.Star:SetPoint("LEFT", 3, 0)
        row.Star:SetTexture("Interface\\AddOns\\Rematch\\textures\\breedstar")
        row.Star:Hide()

        row.Breed = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.Breed:SetPoint("LEFT", 24, 0)
        row.Breed:SetWidth(58)
        row.Breed:SetJustifyH("CENTER")

        row.Health = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.Health:SetPoint("LEFT", 86, 0)
        row.Health:SetWidth(58)
        row.Health:SetJustifyH("CENTER")

        row.Power = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.Power:SetPoint("LEFT", 146, 0)
        row.Power:SetWidth(52)
        row.Power:SetJustifyH("CENTER")

        row.Speed = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.Speed:SetPoint("LEFT", 200, 0)
        row.Speed:SetWidth(44)
        row.Speed:SetJustifyH("CENTER")

        breedFrame.rows[i] = row
    end

end

local function ClearBreedRows()
    if not breedFrame then
        return
    end
    for _, row in ipairs(breedFrame.rows) do
        row:Hide()
        row.Highlight:Hide()
        row.Star:Hide()
    end
end

local function UpdateBreedFrame()
    EnsureBreedFrame()
    ClearBreedRows()

    local petInfo = GetPetInfo()
    if not petInfo then
        breedFrame:Hide()
        return
    end

    local speciesID = petInfo.speciesID
    local ids = petInfo.possibleBreedIDs
    local names = petInfo.possibleBreedNames
    local currentBreedID = petInfo.breedID

    breedFrame.PetName:SetText(petInfo.formattedName or petInfo.name or "Pet")

    if not ids or #ids == 0 then
        local row = breedFrame.rows[1]
        row.Breed:SetText("Unknown")
        row.Health:SetText("-")
        row.Power:SetText("-")
        row.Speed:SetText("-")
        row:Show()
        breedFrame:SetHeight(BREED_HEADER_HEIGHT + BREED_ROW_HEIGHT + BREED_BOTTOM_PADDING)
        return
    end

    for i, breedID in ipairs(ids) do
        local row = breedFrame.rows[i]
        if not row then
            break
        end

        local breedName = names and names[i]
        if not breedName and rematch.breedInfo then
            breedName = rematch.breedInfo:GetBreedNameByID(breedID)
        end

        local isCurrent = currentBreedID == breedID
        row.Breed:SetText(tostring(breedName or breedID))
        row.Star:SetShown(isCurrent)
        row.Highlight:SetShown(isCurrent)

        local health, power, speed = GetRareLevel25Stats(speciesID, breedID)
        row.Health:SetText(health or "-")
        row.Power:SetText(power or "-")
        row.Speed:SetText(speed or "-")
        row:Show()
    end

    local visibleRows = math.max(1, math.min(#ids, #breedFrame.rows))
    breedFrame:SetHeight(BREED_HEADER_HEIGHT + (visibleRows * BREED_ROW_HEIGHT) + BREED_BOTTOM_PADDING)
end

local function ApplyModelZoom()
    if not modelFrame or not modelFrame.Model then
        return
    end

    local zoom = modelFrame.zoom or MODEL_DEFAULT_ZOOM

    if modelFrame.Model.SetPortraitZoom then
        pcall(modelFrame.Model.SetPortraitZoom, modelFrame.Model, zoom)
    end
end

local function EnsureModelFrame()
    if modelFrame then
        return
    end

    modelFrame = CreatePanel("RematchPetModelCard", "", MODEL_CARD_WIDTH, MODEL_CARD_HEIGHT)
    modelFrame:SetPoint("TOPLEFT", rematch.petCard, "TOPRIGHT", CARD_GAP, 0)
    modelFrame.Title:Hide()

    modelFrame.zoom = MODEL_DEFAULT_ZOOM

    modelFrame.Model = CreateFrame("PlayerModel", nil, modelFrame)
    modelFrame.Model:SetPoint("TOPLEFT", 6, -6)
    modelFrame.Model:SetPoint("BOTTOMRIGHT", -6, 6)
    modelFrame.Model:SetCamera(0)
    modelFrame.Model:EnableMouse(true)
    modelFrame.Model:EnableMouseWheel(true)

    modelFrame.Model:SetScript("OnMouseWheel", function(_, delta)
        modelFrame.zoom = math.max(
            MODEL_MIN_ZOOM,
            math.min(MODEL_MAX_ZOOM, (modelFrame.zoom or MODEL_DEFAULT_ZOOM) + (delta * MODEL_ZOOM_STEP))
        )
        ApplyModelZoom()
    end)

    -- Crisp custom close button; no Blizzard sprite sheet involved.
    modelFrame.CloseButton = CreateFrame("Button", nil, modelFrame)
    modelFrame.CloseButton:SetSize(24, 24)
    modelFrame.CloseButton:SetPoint("TOPRIGHT", -4, -4)
    modelFrame.CloseButton:SetFrameLevel(modelFrame:GetFrameLevel() + 20)

    modelFrame.CloseButton.Icon = modelFrame.CloseButton:CreateTexture(nil, "OVERLAY")
    modelFrame.CloseButton.Icon:SetAllPoints()
    modelFrame.CloseButton.Icon:SetTexture("Interface\\AddOns\\Rematch\\textures\\modelclose")

    modelFrame.CloseButton:SetScript("OnEnter", function(self)
        self.Icon:SetVertexColor(1, 1, 1)
    end)
    modelFrame.CloseButton:SetScript("OnLeave", function(self)
        self.Icon:SetVertexColor(0.82, 0.82, 0.82)
    end)
    modelFrame.CloseButton:SetScript("OnClick", function()
        modelWindowOpen = false
        modelFrame:Hide()
    end)
    modelFrame.CloseButton.Icon:SetVertexColor(0.82, 0.82, 0.82)

    modelFrame:HookScript("OnShow", function()
        ApplyModelZoom()
    end)
end

local function SetPetModel(petInfo)
    EnsureModelFrame()

    local model = modelFrame.Model
    model:ClearModel()
    modelFrame.zoom = MODEL_DEFAULT_ZOOM

    if not petInfo or not petInfo.speciesID then
        return
    end

    local _, _, _, creatureID, _, _, _, _, _, _, _, displayID = C_PetJournal.GetPetInfoBySpeciesID(petInfo.speciesID)

    local shown = false

    if displayID and model.SetDisplayInfo then
        local ok = pcall(model.SetDisplayInfo, model, displayID)
        shown = ok
    end

    if not shown and creatureID and model.SetCreature then
        local ok = pcall(model.SetCreature, model, creatureID)
        shown = ok
    end

    if model.SetCamera then
        pcall(model.SetCamera, model, 0)
    end
end

UpdateModelFrame = function()
    local petInfo = GetPetInfo()
    if not petInfo then
        if modelFrame then
            modelFrame:Hide()
        end
        return
    end

    EnsureModelFrame()
    SetPetModel(petInfo)
end

local function RefreshModifierCards()
    local petCardVisible = IsPetCardUsable()

    if not petCardVisible then
        if breedFrame then breedFrame:Hide() end
        if modelFrame then modelFrame:Hide() end
        return
    end

    if IsShiftKeyDown() then
        UpdateBreedFrame()
        breedFrame:Show()
    elseif breedFrame then
        breedFrame:Hide()
    end

    -- Model visibility is persistent/toggled by the model button now.
    if modelWindowOpen then
        UpdateModelFrame()
        modelFrame:Show()
    elseif modelFrame then
        modelFrame:Hide()
    end
end


local function ToggleModelWindow()
    if not IsPetCardUsable() then
        return
    end

    modelWindowOpen = not modelWindowOpen

    if modelWindowOpen then
        UpdateModelFrame()
        if modelFrame then
            modelFrame:Show()
        end
    elseif modelFrame then
        modelFrame:Hide()
    end
end

local function InstallPetIconClickHook()
    if petIconClickHooked
        or not rematch.petCard
        or not rematch.petCard.Content
        or not rematch.petCard.Content.Top
        or not rematch.petCard.Content.Top.PetIcon then
        return
    end

    local petIcon = rematch.petCard.Content.Top.PetIcon
    local originalOnClick = petIcon:GetScript("OnClick")

    petIcon:SetScript("OnClick", function(self, button, ...)
        -- When enabled, clicking the EXISTING pet portrait opens the model
        -- instead of flipping the card. Mouseover flip behavior remains exactly
        -- as Rematch normally handles it.
        if rematch.settings.PetCardModelOnIconClick then
            ToggleModelWindow()
        elseif originalOnClick then
            originalOnClick(self, button, ...)
        end
    end)

    petIconClickHooked = true
end

local function AddPetCardModelOption()
    if not rematch.optionsList then
        return
    end

    -- Avoid duplicates if another compatibility module already inserted it.
    for _, option in ipairs(rematch.optionsList) do
        if option.var == "PetCardModelOnIconClick" then
            return
        end
    end

    local insertAt = #rematch.optionsList + 1

    -- Place it directly after "Don't Flip On Mouseover" in Pet Card Options.
    for i, option in ipairs(rematch.optionsList) do
        if option.var == "PetCardNoMouseoverFlip" then
            insertAt = i + 1
            break
        end
    end

    table.insert(rematch.optionsList, insertAt, {
        type = "check",
        group = 4,
        text = "Click Pet Icon To Show Model",
        var = "PetCardModelOnIconClick",
        tooltip = "When enabled, clicking the pet portrait at the top-left of a pet card opens the 3D pet model window instead of flipping the card. The type icon can still be clicked to flip the card, and mouseover flipping continues to follow the existing Pet Card options."
    })
end

local function HookPetCard()
    if module.hooked or not rematch.petCard then
        return
    end

    module.hooked = true
    InstallPetIconClickHook()

    rematch.petCard:HookScript("OnShow", function()
        C_Timer.After(0, RefreshModifierCards)
    end)

    rematch.petCard:HookScript("OnHide", function()
        if breedFrame then breedFrame:Hide() end
        if modelFrame then modelFrame:Hide() end
        modelWindowOpen = false
    end)

    if type(rematch.petCard.Update) == "function" then
        hooksecurefunc(rematch.petCard, "Update", function()
            if modelWindowOpen then
                C_Timer.After(0, function()
                    if modelWindowOpen and IsPetCardUsable() then
                        UpdateModelFrame()
                    end
                end)
            end
        end)
    end
end

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("MODIFIER_STATE_CHANGED")

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        -- New option defaults ON for this customized build, but once the user
        -- changes it we preserve that saved choice.
        if rematch.settings.PetCardModelOnIconClick == nil then
            rematch.settings.PetCardModelOnIconClick = true
        end

        AddPetCardModelOption()
        HookPetCard()
    elseif event == "MODIFIER_STATE_CHANGED" then
        RefreshModifierCards()
    end
end)

C_Timer.After(0, function()
    AddPetCardModelOption()
    HookPetCard()
    RefreshModifierCards()
end)
