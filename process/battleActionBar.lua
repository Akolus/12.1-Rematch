local _, rematch = ...

-- A compact replacement for Blizzard's wooden pet-battle bottom bar. The
-- original action buttons keep their scripts and state; only their parent,
-- layout and artwork are changed.

rematch.battleActionBar = rematch.battleActionBar or {}
local module = rematch.battleActionBar

local ICON_SIZE = 54
local ICON_SPACING = 9
local BAR_PADDING = 10
local BAR_HEIGHT = ICON_SIZE + BAR_PADDING * 2
local MASK_TEXTURE = "Interface\\AddOns\\Rematch\\textures\\enemyAbilityMask"

local bar
local actionButtons = {}
local layingOut = false
local layoutScheduled = false
local actionLayoutHooked = false
local layoutActionBar
local scheduleLayout

local colors = {
    background = {0.02, 0.03, 0.045, 0.94},
    border = {0.22, 0.28, 0.33, 1},
    accent = {0.95, 0.58, 0.08, 1},
    hover = {1, 1, 1, 0.14},
}

local function setColor(texture, color)
    texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
end

local function hideTexture(texture)
    if texture and texture.SetAlpha then
        texture:SetAlpha(0)
    end
end

local function hideFrameTextures(frame)
    if not frame or not frame.GetRegions then
        return
    end

    local regions = {frame:GetRegions()}
    for _, region in ipairs(regions) do
        if region.GetObjectType and region:GetObjectType() == "Texture" then
            region:SetAlpha(0)
        end
    end
end

local function hideOldBottomBar(bottomFrame)
    if bottomFrame.__rematchModernBottomHidden then
        return
    end
    bottomFrame.__rematchModernBottomHidden = true

    hideFrameTextures(bottomFrame)
    hideFrameTextures(bottomFrame.FlowFrame)
    hideFrameTextures(bottomFrame.ArtFrame)

    if bottomFrame.Delimiter then
        bottomFrame.Delimiter:Hide()
    end

    local microMenu = bottomFrame.MicroButtonFrame
    if microMenu then
        microMenu:SetAlpha(0)
        microMenu:EnableMouse(false)
        microMenu:Hide()
        if not microMenu.__rematchHideHooked then
            microMenu.__rematchHideHooked = true
            microMenu:HookScript("OnShow", function(self)
                self:Hide()
            end)
        end
    end
end

local function createBarBorder(frame, point1, relativePoint1, x1, y1, point2, relativePoint2, x2, y2)
    local texture = frame:CreateTexture(nil, "BORDER")
    texture:SetPoint(point1, frame, relativePoint1, x1, y1)
    texture:SetPoint(point2, frame, relativePoint2, x2, y2)
    setColor(texture, colors.border)
end

local function ensureBar(bottomFrame)
    if bar then
        return bar
    end

    bar = CreateFrame("Frame", "RematchPetBattleActionBar", _G.PetBattleFrame or UIParent)
    bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 14)
    bar:SetSize(BAR_PADDING * 2, BAR_HEIGHT)
    bar:SetFrameStrata("HIGH")
    bar:SetFrameLevel((bottomFrame.GetFrameLevel and bottomFrame:GetFrameLevel() or 1) + 10)

    local shadow = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
    shadow:SetPoint("TOPLEFT", bar, "TOPLEFT", -4, 4)
    shadow:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 4, -4)
    shadow:SetColorTexture(0, 0, 0, 0.45)

    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    setColor(background, colors.background)

    createBarBorder(bar, "TOPLEFT", "TOPLEFT", 0, 0, "TOPRIGHT", "TOPRIGHT", 0, -1)
    createBarBorder(bar, "BOTTOMLEFT", "BOTTOMLEFT", 0, 1, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0)
    createBarBorder(bar, "TOPLEFT", "TOPLEFT", 0, -1, "BOTTOMLEFT", "BOTTOMLEFT", 1, 1)
    createBarBorder(bar, "TOPRIGHT", "TOPRIGHT", -1, -1, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 1)

    local accent = bar:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 1, 1)
    accent:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -1, 1)
    accent:SetHeight(2)
    setColor(accent, colors.accent)

    return bar
end


local function getButtonIcon(button)
    return button and (button.Icon or button.icon)
end

local function hideButtonChrome(button)
    if button.GetNormalTexture then
        hideTexture(button:GetNormalTexture())
    end
    if button.GetPushedTexture then
        hideTexture(button:GetPushedTexture())
    end
    if button.GetDisabledTexture then
        hideTexture(button:GetDisabledTexture())
    end
    if button.GetHighlightTexture then
        hideTexture(button:GetHighlightTexture())
    end
    if button.GetCheckedTexture then
        hideTexture(button:GetCheckedTexture())
    end

    hideTexture(button.Border)
    hideTexture(button.Framing)
    hideTexture(button.SelectedHighlight)
    hideTexture(button.pushed)
    hideTexture(button.hover)
end

local function styleActionButton(button)
    if not button then
        return
    end

    button:SetSize(ICON_SIZE, ICON_SIZE)
    hideButtonChrome(button)

    if button.__rematchModernActionButton then
        return
    end
    button.__rematchModernActionButton = true

    local icon = getButtonIcon(button)
    if icon then
        icon:ClearAllPoints()
        icon:SetAllPoints(button)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        local mask = button:CreateMaskTexture()
        mask:SetAllPoints(icon)
        mask:SetTexture(MASK_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        icon:AddMaskTexture(mask)
        button.__rematchActionMask = mask

        local hover = button:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints(icon)
        setColor(hover, colors.hover)
        hover:AddMaskTexture(mask)
        button.__rematchActionHover = hover
    end

    local hotKey = button.HotKey
    if hotKey then
        hotKey:ClearAllPoints()
        hotKey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -3, -3)
        hotKey:SetFontObject(_G.NumberFontNormalSmallGray or _G.GameFontNormalSmall)
        hotKey:SetTextColor(0.9, 0.93, 0.96, 1)
        hotKey:SetShadowColor(0, 0, 0, 1)
        hotKey:SetShadowOffset(1, -1)
    end

    button:HookScript("OnShow", function()
        scheduleLayout()
    end)
    button:HookScript("OnHide", function()
        scheduleLayout()
    end)

    if not button.__rematchActionPointHooked and hooksecurefunc then
        button.__rematchActionPointHooked = true
        hooksecurefunc(button, "SetPoint", function()
            if button.__rematchActionManaged and not layingOut then
                scheduleLayout()
            end
        end)
    end
end

local function collectActionButtons(bottomFrame)
    local buttons = {}

    for index = 1, 3 do
        local button = bottomFrame.abilityButtons and bottomFrame.abilityButtons[index]
        if button then
            buttons[#buttons + 1] = button
        end
    end

    for _, key in ipairs({"SwitchPetButton", "CatchButton", "ForfeitButton"}) do
        if bottomFrame[key] then
            buttons[#buttons + 1] = bottomFrame[key]
        end
    end

    return buttons
end


layoutActionBar = function()
    if not bar then
        return
    end

    layoutScheduled = false
    layingOut = true

    local visibleButtons = {}
    for _, button in ipairs(actionButtons) do
        styleActionButton(button)
        button.__rematchActionManaged = true
        button:SetParent(bar)
        button:SetScale(1)
        button:SetFrameLevel(bar:GetFrameLevel() + 1)
        button:ClearAllPoints()
        if button:IsShown() then
            visibleButtons[#visibleButtons + 1] = button
        end
    end

    local count = #visibleButtons
    if count == 0 then
        bar:Hide()
        layingOut = false
        return
    end

    local width = BAR_PADDING * 2 + count * ICON_SIZE + (count - 1) * ICON_SPACING
    bar:SetSize(width, BAR_HEIGHT)

    for index, button in ipairs(visibleButtons) do
        local x = BAR_PADDING + (index - 1) * (ICON_SIZE + ICON_SPACING)
        button:SetPoint("LEFT", bar, "LEFT", x, 0)
    end

    bar:Show()
    layingOut = false
end

scheduleLayout = function()
    if layoutScheduled then
        return
    end
    layoutScheduled = true

    if C_Timer and C_Timer.After then
        C_Timer.After(0, layoutActionBar)
    else
        layoutActionBar()
    end
end

function module:Refresh()
    local bottomFrame = _G.PetBattleFrame and PetBattleFrame.BottomFrame
    if not bottomFrame then
        return
    end

    hideOldBottomBar(bottomFrame)
    ensureBar(bottomFrame)
    actionButtons = collectActionButtons(bottomFrame)

    for _, button in ipairs(actionButtons) do
        styleActionButton(button)
    end

    if not actionLayoutHooked and type(_G.PetBattleFrame_UpdateActionBarLayout) == "function" and hooksecurefunc then
        actionLayoutHooked = true
        hooksecurefunc("PetBattleFrame_UpdateActionBarLayout", scheduleLayout)
    end

    scheduleLayout()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PET_BATTLE_OPENING_START")
eventFrame:RegisterEvent("PET_BATTLE_PET_CHANGED")
eventFrame:RegisterEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE")
eventFrame:SetScript("OnEvent", function()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            module:Refresh()
        end)
    else
        module:Refresh()
    end
end)

module:Refresh()
