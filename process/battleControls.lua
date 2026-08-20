local _, rematch = ...

-- Gives the pet-battle utility buttons a compact, consistent appearance.
-- The Autobattle button and its HotKey region are owned by Pet Battle Scripts;
-- all interaction remains with the addon that created each button.

rematch.battleControls = rematch.battleControls or {}
local module = rematch.battleControls

local BUTTON_HEIGHT = 30
local BUTTON_GAP = 6
local BUTTON_WIDTHS = {
    battleData = 104,
    pass = 112,
    auto = 164,
}
local BUTTON_X = {
    battleData = 0,
    pass = BUTTON_WIDTHS.battleData + BUTTON_GAP,
    auto = BUTTON_WIDTHS.battleData + BUTTON_GAP + BUTTON_WIDTHS.pass + BUTTON_GAP,
}
local TOTAL_WIDTH = BUTTON_WIDTHS.battleData + BUTTON_WIDTHS.pass + BUTTON_WIDTHS.auto + BUTTON_GAP * 2
local MIN_SCALE_PERCENT = 50
local MAX_SCALE_PERCENT = 200
local controlFrame

local function setTextureColor(texture, color)
    texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
end

local colors = {
    background = {0.035, 0.05, 0.065, 0.96},
    backgroundHover = {0.075, 0.105, 0.135, 0.98},
    backgroundPressed = {0.02, 0.03, 0.045, 1},
    backgroundDisabled = {0.025, 0.03, 0.04, 0.9},
    border = {0.25, 0.31, 0.36, 1},
    borderHover = {0.95, 0.67, 0.16, 1},
    borderDisabled = {0.13, 0.15, 0.17, 1},
    accent = {0.95, 0.58, 0.08, 1},
    text = {0.92, 0.94, 0.96, 1},
    textDisabled = {0.43, 0.46, 0.49, 1},
    keyBackground = {0.015, 0.025, 0.035, 0.9},
    keyText = {0.67, 0.78, 0.88, 1},
}

local function getScalePercent()
    local percent = math.floor((tonumber(rematch.settings.BattleControlsScale) or 100) + 0.5)
    return math.max(MIN_SCALE_PERCENT, math.min(MAX_SCALE_PERCENT, percent))
end

local function getControlScale()
    return getScalePercent() / 100
end

local function getCenterOffset(frame)
    local frameX, frameY = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if not frameX or not frameY or not parentX or not parentY then
        return
    end

    local frameScale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    return (frameX * frameScale - parentX * parentScale) / parentScale,
        (frameY * frameScale - parentY * parentScale) / parentScale
end

local function saveControlPosition()
    if not controlFrame then
        return
    end

    local x, y = getCenterOffset(controlFrame)
    if not x or not y then
        return
    end

    x = math.floor(x + 0.5)
    y = math.floor(y + 0.5)
    rematch.settings.BattleControlsX = x
    rematch.settings.BattleControlsY = y
    controlFrame.__rematchCenterX = x
    controlFrame.__rematchCenterY = y

    controlFrame:ClearAllPoints()
    controlFrame:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

local function changeControlScale(delta)
    if delta == 0 then
        return
    end

    local percent = getScalePercent()
    percent = math.max(MIN_SCALE_PERCENT, math.min(MAX_SCALE_PERCENT, percent + (delta > 0 and 1 or -1)))
    rematch.settings.BattleControlsScale = percent

    if module.Refresh then
        module:Refresh()
    end
end

local function setBorderColor(button, color)
    for _, texture in ipairs(button.__rematchModernBorders) do
        setTextureColor(texture, color)
    end
end

local function updateButtonState(button)
    if not button.__rematchModernBackground then
        return
    end

    local enabled = not button.IsEnabled or button:IsEnabled()
    local background = colors.background
    local border = colors.border
    local text = colors.text

    if not enabled then
        background = colors.backgroundDisabled
        border = colors.borderDisabled
        text = colors.textDisabled
    elseif button.__rematchModernPressed then
        background = colors.backgroundPressed
        border = colors.borderHover
    elseif button.__rematchModernHover then
        background = colors.backgroundHover
        border = colors.borderHover
    end

    setTextureColor(button.__rematchModernBackground, background)
    setBorderColor(button, border)

    local fontString = button:GetFontString()
    if fontString then
        fontString:SetTextColor(text[1], text[2], text[3], text[4])
    end
end

local function createBorder(button, point1, relativePoint1, x1, y1, point2, relativePoint2, x2, y2)
    local texture = button:CreateTexture(nil, "BORDER")
    texture.__rematchModernTexture = true
    texture:SetPoint(point1, button, relativePoint1, x1, y1)
    texture:SetPoint(point2, button, relativePoint2, x2, y2)
    setTextureColor(texture, colors.border)
    button.__rematchModernBorders[#button.__rematchModernBorders + 1] = texture
end

local function hideLegacyTextures(button)
    if not button.GetRegions then
        return
    end

    local regions = {button:GetRegions()}
    for _, region in ipairs(regions) do
        if region.GetObjectType and region:GetObjectType() == "Texture" and not region.__rematchModernTexture then
            region:SetAlpha(0)
        end
    end
end

local function styleButton(button)
    if not button then
        return
    end

    if button.__rematchModernBackground then
        local fontString = button:GetFontString()
        if fontString and button.__rematchBaseFont then
            fontString:SetFont(
                button.__rematchBaseFont[1],
                button.__rematchBaseFont[2] * getControlScale(),
                button.__rematchBaseFont[3]
            )
        end
        button.__rematchModernAccent:SetHeight(2 * getControlScale())
        updateButtonState(button)
        return
    end

    hideLegacyTextures(button)

    button.__rematchModernBorders = {}

    local background = button:CreateTexture(nil, "BACKGROUND")
    background.__rematchModernTexture = true
    background:SetAllPoints()
    setTextureColor(background, colors.background)
    button.__rematchModernBackground = background

    createBorder(button, "TOPLEFT", "TOPLEFT", 0, 0, "TOPRIGHT", "TOPRIGHT", 0, -1)
    createBorder(button, "BOTTOMLEFT", "BOTTOMLEFT", 0, 1, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0)
    createBorder(button, "TOPLEFT", "TOPLEFT", 0, -1, "BOTTOMLEFT", "BOTTOMLEFT", 1, 1)
    createBorder(button, "TOPRIGHT", "TOPRIGHT", -1, -1, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 1)

    local accent = button:CreateTexture(nil, "ARTWORK")
    accent.__rematchModernTexture = true
    accent:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
    accent:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    accent:SetHeight(2)
    setTextureColor(accent, colors.accent)
    button.__rematchModernAccent = accent

    local fontString = button:GetFontString()
    if fontString then
        fontString:SetFontObject(_G.GameFontNormalSmall or _G.GameFontNormal)
        fontString:SetShadowColor(0, 0, 0, 1)
        fontString:SetShadowOffset(0, -1)
        local font, size, flags = fontString:GetFont()
        if font and size then
            button.__rematchBaseFont = {font, size, flags}
            fontString:SetFont(font, size * getControlScale(), flags)
        end
    end

    button:HookScript("OnEnter", function(self)
        self.__rematchModernHover = true
        updateButtonState(self)
    end)
    button:HookScript("OnLeave", function(self)
        self.__rematchModernHover = false
        self.__rematchModernPressed = false
        updateButtonState(self)
    end)
    button:HookScript("OnMouseDown", function(self)
        self.__rematchModernPressed = true
        updateButtonState(self)
    end)
    button:HookScript("OnMouseUp", function(self)
        self.__rematchModernPressed = false
        updateButtonState(self)
    end)
    button:HookScript("OnEnable", updateButtonState)
    button:HookScript("OnDisable", updateButtonState)

    updateButtonState(button)
end

local function fitHotKey(autoButton)
    local hotKey = autoButton and autoButton.HotKey
    if not hotKey then
        return
    end

    local fontObject = _G.NumberFontNormalSmallGray or _G.GameFontHighlightSmall or _G.GameFontNormalSmall
    if fontObject then
        hotKey:SetFontObject(fontObject)
    end

    local font = hotKey:GetFont()
    if font then
        local scale = getControlScale()
        local fontSize = 11 * scale
        local minimumSize = 8 * scale
        hotKey:SetFont(font, fontSize, "OUTLINE")
        while hotKey:GetStringWidth() > 48 * scale and fontSize > minimumSize do
            fontSize = fontSize - scale
            hotKey:SetFont(font, fontSize, "OUTLINE")
        end
    end
end

local function reserveHotKey(autoButton)
    local hotKey = autoButton and autoButton.HotKey
    if not hotKey then
        return
    end

    local scale = getControlScale()

    if not autoButton.__rematchKeyBackground then
        local keyBackground = autoButton:CreateTexture(nil, "BORDER", nil, 1)
        keyBackground.__rematchModernTexture = true
        setTextureColor(keyBackground, colors.keyBackground)
        autoButton.__rematchKeyBackground = keyBackground

        local divider = autoButton:CreateTexture(nil, "ARTWORK")
        divider.__rematchModernTexture = true
        setTextureColor(divider, colors.border)
        autoButton.__rematchKeyDivider = divider
    end


    autoButton.__rematchKeyBackground:ClearAllPoints()
    autoButton.__rematchKeyBackground:SetPoint("TOPRIGHT", autoButton, "TOPRIGHT", -scale, -scale)
    autoButton.__rematchKeyBackground:SetPoint("BOTTOMLEFT", autoButton, "BOTTOMRIGHT", -58 * scale, 3 * scale)

    autoButton.__rematchKeyDivider:ClearAllPoints()
    autoButton.__rematchKeyDivider:SetPoint("TOP", autoButton, "TOPRIGHT", -58 * scale, -4 * scale)
    autoButton.__rematchKeyDivider:SetPoint("BOTTOM", autoButton, "BOTTOMRIGHT", -58 * scale, 4 * scale)
    autoButton.__rematchKeyDivider:SetWidth(math.max(1, scale))

    local label = autoButton:GetFontString()
    if label then
        label:ClearAllPoints()
        label:SetPoint("LEFT", autoButton, "LEFT", 10 * scale, 0)
        label:SetPoint("RIGHT", autoButton, "RIGHT", -66 * scale, 0)
        label:SetJustifyH("CENTER")
    end

    hotKey:ClearAllPoints()
    hotKey:SetPoint("LEFT", autoButton, "RIGHT", -55 * scale, 0)
    hotKey:SetPoint("RIGHT", autoButton, "RIGHT", -5 * scale, 0)
    hotKey:SetJustifyH("CENTER")
    hotKey:SetJustifyV("MIDDLE")
    hotKey:SetWordWrap(false)
    hotKey:SetTextColor(colors.keyText[1], colors.keyText[2], colors.keyText[3], colors.keyText[4])

    fitHotKey(autoButton)

    if not autoButton.__rematchHotKeyHooked and hooksecurefunc then
        autoButton.__rematchHotKeyHooked = true
        hooksecurefunc(hotKey, "SetText", function()
            fitHotKey(autoButton)
        end)
    end
end

local function centerLabel(button)
    local label = button and button:GetFontString()
    if label then
        label:ClearAllPoints()
        label:SetPoint("CENTER", button, "CENTER", 0, 0)
        label:SetJustifyH("CENTER")
    end
end

local function hidePetBattleScriptsArt()
    local addon = _G.PetBattleScripts
    if not addon or type(addon.GetModule) ~= "function" then
        return
    end

    local ok, petBattleModule = pcall(addon.GetModule, addon, "UI.PetBattle", true)
    if ok and petBattleModule and petBattleModule.ArtFrame2 then
        petBattleModule.ArtFrame2:SetAlpha(0)
    end
end

local function anchorControlButton(button)
    if not button or not button.__rematchControlRole or not controlFrame then
        return
    end

    local role = button.__rematchControlRole
    local scale = getControlScale()
    button.__rematchControlAnchoring = true
    button:ClearAllPoints()
    button:SetPoint("LEFT", controlFrame, "LEFT", BUTTON_X[role] * scale, 0)
    button.__rematchControlAnchoring = false
end

local function installControlInteraction(button)
    if button.__rematchControlInteraction then
        return
    end
    button.__rematchControlInteraction = true

    button:RegisterForDrag("LeftButton")
    button:EnableMouseWheel(true)

    button:HookScript("OnDragStart", function()
        if not IsShiftKeyDown() or not controlFrame then
            return
        end

        GameTooltip:Hide()
        controlFrame.__rematchMoving = true
        controlFrame:StartMoving()
    end)

    button:HookScript("OnDragStop", function()
        if not controlFrame or not controlFrame.__rematchMoving then
            return
        end

        controlFrame:StopMovingOrSizing()
        controlFrame.__rematchMoving = false
        saveControlPosition()
    end)

    button:HookScript("OnMouseWheel", function(_, delta)
        if IsControlKeyDown() then
            changeControlScale(delta)
        end
    end)
end

local function attachControlButton(button, role)
    if not button or not controlFrame then
        return
    end

    button.__rematchControlRole = role
    local scale = getControlScale()
    button:SetParent(controlFrame)
    button:SetScale(1)
    button:SetSize(BUTTON_WIDTHS[role] * scale, BUTTON_HEIGHT * scale)
    button:SetFrameLevel(controlFrame:GetFrameLevel() + 1)
    anchorControlButton(button)
    styleButton(button)
    installControlInteraction(button)

    if role == "auto" then
        reserveHotKey(button)
    else
        centerLabel(button)
    end

    if not button.__rematchControlPointHooked and hooksecurefunc then
        button.__rematchControlPointHooked = true
        hooksecurefunc(button, "SetPoint", function(self)
            if self.__rematchControlRole and not self.__rematchControlAnchoring then
                anchorControlButton(self)
            end
        end)
    end
end

local function ensureControlFrame(passButton, turnTimer)
    if not controlFrame then
        controlFrame = CreateFrame("Frame", "RematchBattleControls", _G.PetBattleFrame or UIParent)
        controlFrame:SetFrameStrata("HIGH")
        controlFrame:SetFrameLevel(passButton:GetFrameLevel())
        controlFrame:SetClampedToScreen(true)
        controlFrame:SetMovable(true)
    end

    local scale = getControlScale()
    controlFrame:SetScale(1)
    controlFrame:SetSize(TOTAL_WIDTH * scale, BUTTON_HEIGHT * scale)

    if not controlFrame.__rematchPositionInitialized then
        local savedX = rematch.settings.BattleControlsX
        local savedY = rematch.settings.BattleControlsY

        controlFrame:ClearAllPoints()
        if type(savedX) == "number" and type(savedY) == "number" then
            controlFrame.__rematchCenterX = savedX
            controlFrame.__rematchCenterY = savedY
            controlFrame:SetPoint("CENTER", UIParent, "CENTER", savedX, savedY)
        else
            local passX, passY = getCenterOffset(passButton)
            if passX and passY then
                local passLocalX = BUTTON_X.pass + BUTTON_WIDTHS.pass / 2 - TOTAL_WIDTH / 2
                controlFrame.__rematchCenterX = passX - passLocalX * scale
                controlFrame.__rematchCenterY = passY
                controlFrame:SetPoint(
                    "CENTER",
                    UIParent,
                    "CENTER",
                    controlFrame.__rematchCenterX,
                    controlFrame.__rematchCenterY
                )
            else
                controlFrame:SetPoint("CENTER", turnTimer, "CENTER", 0, 0)
                controlFrame.__rematchCenterX, controlFrame.__rematchCenterY = getCenterOffset(controlFrame)
            end
        end
        controlFrame.__rematchPositionInitialized = true
    end

    return controlFrame
end

function module:Refresh()
    local turnTimer = _G.PetBattleFrame and PetBattleFrame.BottomFrame and PetBattleFrame.BottomFrame.TurnTimer
    local passButton = turnTimer and turnTimer.SkipButton
    local battleDataButton = _G.RematchBattleDataButton
    local autoButton = _G.tdBattlePetScriptAutoButton

    if not passButton then
        return
    end

    ensureControlFrame(passButton, turnTimer)
    attachControlButton(battleDataButton, "battleData")
    attachControlButton(passButton, "pass")
    attachControlButton(autoButton, "auto")

    if autoButton then
        if not autoButton.__rematchAutoShowHooked then
            autoButton.__rematchAutoShowHooked = true
            autoButton:HookScript("OnShow", function(self)
                reserveHotKey(self)
                updateButtonState(self)
            end)
        end
        hidePetBattleScriptsArt()
    end
end

local function scheduleRefresh()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            module:Refresh()
        end)
    else
        module:Refresh()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PET_BATTLE_OPENING_START")
eventFrame:SetScript("OnEvent", scheduleRefresh)

scheduleRefresh()
