local _, rematch = ...

-- Gives the pet-battle utility buttons a compact, consistent appearance.
-- The Autobattle button and its HotKey region are owned by Pet Battle Scripts;
-- all interaction remains with the addon that created each button.

rematch.battleControls = rematch.battleControls or {}
local module = rematch.battleControls

local BUTTON_HEIGHT = 30
local BUTTON_GAP = 1
local LABEL_FONT_SIZE = 13
local BUTTON_WIDTHS = {
    battleData = 104,
    pass = 112,
    auto = 104,
}
local BUTTON_X = {
    battleData = 0,
    pass = BUTTON_WIDTHS.battleData + BUTTON_GAP,
    auto = BUTTON_WIDTHS.battleData + BUTTON_GAP + BUTTON_WIDTHS.pass + BUTTON_GAP,
}
local KEY_CELL_WIDTH = 56
local PLUS_SIZE = 22
local TOTAL_WIDTH = BUTTON_WIDTHS.battleData + BUTTON_WIDTHS.pass + BUTTON_WIDTHS.auto
    + KEY_CELL_WIDTH + BUTTON_GAP * 3
local MIN_SCALE_PERCENT = 50
local MAX_SCALE_PERCENT = 200
local controlFrame
local keybindCaptureFrame
local keybindClickCatcher
local rematchOwnedAutoButton
local applyAutobattleBinding, saveAutobattleKey
local pendingAutobattleBinding
local pendingControlRefresh

local function setTextureColor(texture, color)
    texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
end

local function setOnePixelWidth(texture)
    -- PixelUtil accounts for the current UI/effective scale, preventing a
    -- one-unit divider from rasterizing across two physical screen pixels.
    if _G.PixelUtil and PixelUtil.SetWidth then
        -- A zero requested width with a one-pixel minimum resolves to exactly
        -- one physical pixel instead of the nearest width to one UI unit.
        PixelUtil.SetWidth(texture, 0, 1)
    else
        local effectiveScale = texture.GetEffectiveScale and texture:GetEffectiveScale() or 1
        local _, physicalHeight = GetPhysicalScreenSize and GetPhysicalScreenSize()
        local pixelToUI = physicalHeight and physicalHeight > 0 and 768 / physicalHeight or 1
        texture:SetWidth(pixelToUI / math.max(effectiveScale, 0.01))
    end

    if texture.SetSnapToPixelGrid then
        texture:SetSnapToPixelGrid(true)
    end
    if texture.SetTexelSnappingBias then
        texture:SetTexelSnappingBias(0)
    end
end

local colors = {
    background = {0, 0, 0, 0},
    backgroundPressed = {0.03, 0.045, 0.06, 1},
    backgroundDisabled = {0, 0, 0, 0},
    border = {0, 0, 0, 1},
    text = {0.92, 0.94, 0.96, 1},
    textHover = {1, 0.82, 0.18, 1},
    textDisabled = {0.43, 0.46, 0.49, 1},
    keyText = {0.67, 0.78, 0.88, 1},
    keyButtonText = {1, 0.69, 0.20, 1},
    keyButtonTextHover = {1, 0.9, 0.58, 1},
    captureBackground = {0.035, 0.05, 0.065, 0.98},
    separator = {0.25, 0.72, 1, 0.82},
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
    local frame = rematch.battleActionBar and rematch.battleActionBar.GetFrame
        and rematch.battleActionBar:GetFrame() or controlFrame
    if not frame then
        return
    end

    local x, y = getCenterOffset(frame)
    if not x or not y then
        return
    end

    x = math.floor(x + 0.5)
    y = math.floor(y + 0.5)
    rematch.settings.BattleControlsX = x
    rematch.settings.BattleControlsY = y
    frame.__rematchCenterX = x
    frame.__rematchCenterY = y

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

function module:ChangeScale(delta)
    if delta == 0 then
        return
    end

    local percent = getScalePercent()
    percent = math.max(MIN_SCALE_PERCENT, math.min(MAX_SCALE_PERCENT, percent + (delta > 0 and 1 or -1)))
    rematch.settings.BattleControlsScale = percent

    module:Refresh(true)
    if rematch.battleActionBar and rematch.battleActionBar.Refresh then
        rematch.battleActionBar:Refresh()
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
    local text = colors.text

    if not enabled then
        background = colors.backgroundDisabled
        text = colors.textDisabled
    elseif button.__rematchModernPressed then
        background = colors.backgroundPressed
    elseif button.__rematchModernHover then
        text = colors.textHover
    end

    setTextureColor(button.__rematchModernBackground, background)

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
                LABEL_FONT_SIZE * getControlScale(),
                button.__rematchBaseFont[3]
            )
        end
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

    local fontString = button:GetFontString()
    if fontString then
        fontString:SetFontObject(_G.GameFontNormalSmall or _G.GameFontNormal)
        fontString:SetShadowColor(0, 0, 0, 1)
        fontString:SetShadowOffset(0, -1)
        local font, size, flags = fontString:GetFont()
        if font and size then
            button.__rematchBaseFont = {font, LABEL_FONT_SIZE, flags}
            fontString:SetFont(font, LABEL_FONT_SIZE * getControlScale(), flags)
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

local function abbreviateBinding(binding)
    if not binding or binding == "" then
        return ""
    end

    local abbrevs = {
        MOUSEWHEELDOWN = "MWD",
        MOUSEWHEELUP = "MWU",
        BUTTON1 = "M1",
        BUTTON2 = "M2",
        BUTTON3 = "M3",
        BUTTON4 = "M4",
        BUTTON5 = "M5",
        SPACE = "Spc",
        ENTER = "Ent",
        BACKSPACE = "Bksp",
        ESCAPE = "Esc",
        TAB = "Tab",
        PRINTSCREEN = "Prt",
        PAGEUP = "PgUp",
        PAGEDOWN = "PgDn",
        INSERT = "Ins",
        DELETE = "Del",
        HOME = "Home",
        NUMPADPLUS = "NP+",
        NUMPADMINUS = "NP-",
        NUMPADMULTIPLY = "NP*",
        NUMPADDIVIDE = "NP/",
        NUMPADDECIMAL = "NP.",
        NUMPADENTER = "NPE",
    }
    local mods = {
        SHIFT = "S",
        CTRL = "C",
        ALT = "A",
        META = "M",
    }

    local parts = {}
    for part in string.gmatch(binding, "[^-]+") do
        local upper = string.upper(part)
        if mods[upper] then
            parts[#parts + 1] = mods[upper]
        elseif abbrevs[upper] then
            parts[#parts + 1] = abbrevs[upper]
        elseif upper:match("^NUMPAD%d$") then
            parts[#parts + 1] = "NP" .. upper:sub(7)
        else
            parts[#parts + 1] = part
        end
    end
    return table.concat(parts, "-")
end

local function currentAutobattleBinding(autoButton)
    local binding = rematch.settings.AutobattleHotKey
    if (not binding or binding == "") and autoButton and autoButton.HotKey and autoButton.HotKey.GetText then
        binding = autoButton.HotKey:GetText() or ""
        binding = binding:match("([^/]+)") or binding
    end
    return binding or ""
end

local function fitHotKey(autoButton)
    local display = autoButton and autoButton.__rematchHotKeyDisplay
    if not display or not display.Text then
        return
    end

    local binding = currentAutobattleBinding(autoButton)
    display.__rematchFullBinding = binding
    display.Text:SetText(abbreviateBinding(binding))
    display:SetShown(binding ~= "")
end

local function getAutoButton()
    return _G.tdBattlePetScriptAutoButton or rematchOwnedAutoButton
end

local function ensureOwnedAutoButton(passButton)
    if rematchOwnedAutoButton then
        return rematchOwnedAutoButton
    end
    if not passButton then
        return
    end

    local button = CreateFrame("Button", "RematchAutoBattleButton", passButton:GetParent(), "UIPanelButtonTemplate")
    button:SetText("Autobattle")
    button:SetSize(passButton:GetSize())
    button.__rematchOwnedAutoButton = true
    rematchOwnedAutoButton = button
    return button
end

local modifierKeys = {
    LSHIFT = true,
    RSHIFT = true,
    LCTRL = true,
    RCTRL = true,
    LALT = true,
    RALT = true,
    LMETA = true,
    RMETA = true,
}

local function closeKeybindCapture()
    if keybindClickCatcher then
        keybindClickCatcher:Hide()
    end
    if keybindCaptureFrame then
        keybindCaptureFrame:EnableKeyboard(false)
        keybindCaptureFrame:Hide()
    end
end

local function ensureKeybindClickCatcher()
    if keybindClickCatcher then
        return keybindClickCatcher
    end

    local catcher = CreateFrame("Button", "RematchAutobattleKeybindClickCatcher", UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("HIGH")
    catcher:EnableMouse(true)
    catcher:EnableMouseWheel(true)
    catcher:RegisterForClicks("AnyUp")
    catcher:SetScript("OnMouseWheel", function(_, delta)
        local autoButton = keybindCaptureFrame and keybindCaptureFrame.autoButton
        local binding = buildBindingKey(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
        if autoButton and binding then
            saveAutobattleKey(autoButton, binding)
        end
    end)
    catcher:SetScript("OnClick", function(_, button)
        local autoButton = keybindCaptureFrame and keybindCaptureFrame.autoButton
        local mouseMap = {
            MiddleButton = "BUTTON3",
            Button4 = "BUTTON4",
            Button5 = "BUTTON5",
        }
        if mouseMap[button] and autoButton then
            local binding = buildBindingKey(mouseMap[button])
            if binding then
                saveAutobattleKey(autoButton, binding)
            end
            return
        end
        closeKeybindCapture()
    end)
    catcher:Hide()
    keybindClickCatcher = catcher
    return catcher
end

local function buildBindingKey(key)
    if not key or modifierKeys[key] then
        return nil
    end
    if key == "ESCAPE" then
        return false
    end

    local parts = {}
    if IsAltKeyDown and IsAltKeyDown() then
        parts[#parts + 1] = "ALT"
    end
    if IsControlKeyDown and IsControlKeyDown() then
        parts[#parts + 1] = "CTRL"
    end
    if IsShiftKeyDown and IsShiftKeyDown() then
        parts[#parts + 1] = "SHIFT"
    end
    if IsMetaKeyDown and IsMetaKeyDown() then
        parts[#parts + 1] = "META"
    end
    parts[#parts + 1] = key
    return table.concat(parts, "-")
end

local bindingOwner

local function getBindingOwner()
    if not bindingOwner then
        bindingOwner = CreateFrame("Frame", "RematchAutobattleBindingOwner", UIParent)
    end
    return bindingOwner
end

local function notifyPetBattleScripts(binding)
    local addon = _G.PetBattleScripts
    if not addon then
        return
    end
    if type(addon.SetSetting) == "function" then
        pcall(addon.SetSetting, addon, "autoButtonHotKey", binding or "")
    end
    if type(addon.SendMessage) == "function" then
        pcall(addon.SendMessage, addon, "PET_BATTLE_SCRIPT_SETTING_CHANGED_autoButtonHotKey", "autoButtonHotKey", binding or "")
    end
    if type(addon.GetModule) == "function" then
        local ok, ui = pcall(addon.GetModule, addon, "UI.PetBattle", true)
        if ok and ui then
            if ui.UpdateHotKey then
                pcall(ui.UpdateHotKey, ui)
            elseif ui.UpdateAutoButtonHotKey then
                pcall(ui.UpdateAutoButtonHotKey, ui)
            end
        end
    end
end

applyAutobattleBinding = function(binding)
    if binding == nil then
        binding = rematch.settings.AutobattleHotKey
    end
    if binding == "" then
        binding = nil
    end
    rematch.settings.AutobattleHotKey = binding or ""

    -- Both override binding APIs and the script addon's hotkey callbacks may
    -- change protected bindings. pcall does not make these legal in combat.
    -- Keep the latest saved key and apply it once lockdown has ended.
    if InCombatLockdown() then
        pendingAutobattleBinding = true
        return
    end
    pendingAutobattleBinding = nil

    notifyPetBattleScripts(rematch.settings.AutobattleHotKey)

    local autoButton = getAutoButton()
    local owner = getBindingOwner()
    pcall(ClearOverrideBindings, owner)
    if autoButton then
        pcall(ClearOverrideBindings, autoButton)
    end

    local clickName = autoButton and autoButton.GetName and autoButton:GetName()
    if binding and clickName then
        pcall(SetOverrideBindingClick, owner, true, binding, clickName, "LeftButton")
        pcall(SetOverrideBindingClick, autoButton, true, binding, clickName, "LeftButton")
    end

    if autoButton and autoButton.HotKey then
        autoButton.HotKey:SetText(binding or "")
        fitHotKey(autoButton)
    elseif autoButton then
        fitHotKey(autoButton)
    end
end

saveAutobattleKey = function(autoButton, binding)
    applyAutobattleBinding(binding)
    closeKeybindCapture()
    return true
end

local function showKeybindCapture(autoButton, anchor)
    local scale = getControlScale()

    if not keybindCaptureFrame then
        local frame = CreateFrame("Frame", "RematchAutobattleKeybindCapture", UIParent)
        frame:Hide()
        frame:SetFrameStrata("DIALOG")
        frame:SetClampedToScreen(true)
        frame:EnableMouse(true)
        frame:EnableKeyboard(false)
        frame:EnableMouseWheel(true)
        if frame.SetPropagateKeyboardInput then
            frame:SetPropagateKeyboardInput(false)
        end

        frame.__rematchModernBorders = {}
        local background = frame:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        setTextureColor(background, colors.captureBackground)
        frame.Background = background

        createBorder(frame, "TOPLEFT", "TOPLEFT", 0, 0, "TOPRIGHT", "TOPRIGHT", 0, -1)
        createBorder(frame, "BOTTOMLEFT", "BOTTOMLEFT", 0, 1, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0)
        createBorder(frame, "TOPLEFT", "TOPLEFT", 0, -1, "BOTTOMLEFT", "BOTTOMLEFT", 1, 1)
        createBorder(frame, "TOPRIGHT", "TOPRIGHT", -1, -1, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 1)

        local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("CENTER")
        text:SetText("Set keybind.")
        text:SetTextColor(0.96, 0.97, 1, 1)
        local font, size, flags = text:GetFont()
        if font and size then
            frame.__rematchCaptureFont = {font, size, flags}
        end
        frame.Text = text

        frame:SetScript("OnKeyDown", function(self, key)
            if self.SetPropagateKeyboardInput then
                self:SetPropagateKeyboardInput(false)
            end
            local binding = buildBindingKey(key)
            if binding == false then
                closeKeybindCapture()
            elseif binding then
                saveAutobattleKey(self.autoButton, binding)
            end
        end)
        frame:SetScript("OnMouseWheel", function(self, delta)
            local binding = buildBindingKey(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
            if binding then
                saveAutobattleKey(self.autoButton, binding)
            end
        end)
        frame:SetScript("OnUpdate", function(self, elapsed)
            self.__rematchPulseElapsed = (self.__rematchPulseElapsed or 0) + elapsed
            self.__rematchDotElapsed = (self.__rematchDotElapsed or 0) + elapsed

            local pulseDuration = 2.8
            local pulse = (math.cos((self.__rematchPulseElapsed % pulseDuration)
                * math.pi * 2 / pulseDuration) + 1) / 2
            self:SetAlpha(0.56 + pulse * 0.44)

            if self.__rematchDotElapsed >= 0.55 then
                local steps = math.floor(self.__rematchDotElapsed / 0.55)
                self.__rematchDotElapsed = self.__rematchDotElapsed - steps * 0.55
                self.__rematchDotCount = ((self.__rematchDotCount - 1 + steps) % 3) + 1
                self.Text:SetText("Set keybind" .. string.rep(".", self.__rematchDotCount))
            end
        end)
        frame:SetScript("OnHide", function(self)
            self:EnableKeyboard(false)
            self:SetAlpha(1)
            self.autoButton = nil
            if keybindClickCatcher then
                keybindClickCatcher:Hide()
            end
        end)

        keybindCaptureFrame = frame
    end

    local catcher = ensureKeybindClickCatcher()
    local unified = rematch.battleActionBar and rematch.battleActionBar.GetFrame
        and rematch.battleActionBar:GetFrame()
    catcher:SetFrameLevel(math.max(0, (unified and unified:GetFrameLevel() or anchor:GetFrameLevel()) - 1))
    catcher:Show()

    keybindCaptureFrame.autoButton = autoButton
    keybindCaptureFrame.__rematchPulseElapsed = 0
    keybindCaptureFrame.__rematchDotElapsed = 0
    keybindCaptureFrame.__rematchDotCount = 1
    keybindCaptureFrame:SetAlpha(1)
    keybindCaptureFrame.Text:SetText("Set keybind.")
    keybindCaptureFrame:SetSize(94 * scale, 26 * scale)
    if keybindCaptureFrame.__rematchCaptureFont then
        keybindCaptureFrame.Text:SetFont(
            keybindCaptureFrame.__rematchCaptureFont[1],
            keybindCaptureFrame.__rematchCaptureFont[2] * scale,
            keybindCaptureFrame.__rematchCaptureFont[3]
        )
    end
    keybindCaptureFrame:ClearAllPoints()
    keybindCaptureFrame:SetPoint("BOTTOMLEFT", anchor, "TOPRIGHT", 5 * scale, 4 * scale)
    keybindCaptureFrame:Show()
    keybindCaptureFrame:EnableKeyboard(true)
end

local function getMenuBar()
    return rematch.battleActionBar and rematch.battleActionBar.GetFrame
        and rematch.battleActionBar:GetFrame() or controlFrame
end

local function ensureHotKeyDisplay(autoButton)
    if autoButton.__rematchHotKeyDisplay then
        return autoButton.__rematchHotKeyDisplay
    end

    local display = CreateFrame("Button", nil, controlFrame or autoButton)
    display:SetFrameLevel((controlFrame or autoButton):GetFrameLevel() + 2)
    display:EnableMouse(true)

    local text = display:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", 0, 0)
    text:SetTextColor(colors.keyText[1], colors.keyText[2], colors.keyText[3], 1)
    text:SetJustifyH("CENTER")
    display.Text = text

    display:SetScript("OnEnter", function(self)
        local full = self.__rematchFullBinding
        if not full or full == "" then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText(full)
        GameTooltip:Show()
    end)
    display:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    autoButton.__rematchHotKeyDisplay = display
    return display
end

local function ensurePlusButton(autoButton)
    if autoButton.__rematchPlusButton then
        return autoButton.__rematchPlusButton
    end

    local button = CreateFrame("Button", nil, controlFrame or autoButton)
    button:SetFrameLevel((controlFrame or autoButton):GetFrameLevel() + 3)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local plus = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    plus:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
    plus:SetPoint("CENTER", 0, 0)
    plus:SetText("+")
    plus:SetTextColor(colors.keyButtonText[1], colors.keyButtonText[2], colors.keyButtonText[3], 1)
    plus:SetJustifyH("CENTER")
    button.Text = plus

    button:SetScript("OnEnter", function(self)
        self.Text:SetTextColor(
            colors.keyButtonTextHover[1],
            colors.keyButtonTextHover[2],
            colors.keyButtonTextHover[3],
            1
        )
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Change Autobattle keybind")
        GameTooltip:AddLine("Left-click, then press a key or scroll the mouse wheel.", 0.85, 0.88, 0.92, true)
        GameTooltip:AddLine("Right-click to clear the keybind.", 0.85, 0.88, 0.92, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        self.Text:SetTextColor(
            colors.keyButtonText[1],
            colors.keyButtonText[2],
            colors.keyButtonText[3],
            1
        )
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            saveAutobattleKey(autoButton, "")
            return
        end
        GameTooltip:Hide()
        showKeybindCapture(autoButton, self)
    end)

    autoButton:HookScript("OnHide", closeKeybindCapture)
    autoButton.__rematchPlusButton = button
    autoButton.__rematchKeybindButton = button
    return button
end

local function layoutKeybindButton(autoButton)
    if not autoButton or not controlFrame then
        return
    end

    local scale = getControlScale()
    local plus = ensurePlusButton(autoButton)
    local display = ensureHotKeyDisplay(autoButton)
    local plusSize = PLUS_SIZE * scale
    local menu = getMenuBar() or controlFrame
    if not menu then
        return
    end
    local dividerX = (BUTTON_X.auto + BUTTON_WIDTHS.auto) * scale

    plus:SetParent(menu)
    plus:SetFrameLevel(menu:GetFrameLevel() + 8)
    plus:SetSize(plusSize, plusSize)
    plus:ClearAllPoints()
    plus:SetPoint("TOPRIGHT", menu, "TOPRIGHT", 0, 0)
    if plus.Text then
        plus.Text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", plusSize * 0.92, "OUTLINE")
        plus.Text:ClearAllPoints()
        plus.Text:SetPoint("CENTER", plus, "CENTER", 0, 0)
    end

    display:SetParent(controlFrame)
    display:SetFrameLevel(controlFrame:GetFrameLevel() + 2)
    display:ClearAllPoints()
    display:SetPoint("LEFT", controlFrame, "LEFT", dividerX, 0)
    display:SetPoint("RIGHT", controlFrame, "RIGHT", 0, 0)
    display:SetHeight(BUTTON_HEIGHT * scale)
    if display.Text then
        display.Text:ClearAllPoints()
        display.Text:SetPoint("CENTER", display, "CENTER", 0, 0)
        display.Text:SetJustifyH("CENTER")
    end

    fitHotKey(autoButton)

    if keybindCaptureFrame and keybindCaptureFrame:IsShown() and keybindCaptureFrame.autoButton == autoButton then
        showKeybindCapture(autoButton, plus)
    end
end

function module:LayoutKeybind()
    local autoButton = getAutoButton()
    if autoButton then
        layoutKeybindButton(autoButton)
    end
end

local function reserveHotKey(autoButton)
    local hotKey = autoButton and autoButton.HotKey
    if not hotKey then
        return
    end

    local label = autoButton:GetFontString()
    if label then
        label:ClearAllPoints()
        label:SetPoint("CENTER", autoButton, "CENTER", 0, 0)
        label:SetJustifyH("CENTER")
    end

    -- Pet Battle Scripts continues to own and update this FontString. It is
    -- retained as the binding data source but no longer occupies its own cell.
    hotKey:ClearAllPoints()
    hotKey:SetPoint("CENTER", autoButton, "CENTER", 0, 0)
    hotKey:SetAlpha(0)

    layoutKeybindButton(autoButton)

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
        if not IsShiftKeyDown() then
            return
        end

        GameTooltip:Hide()
        if rematch.battleActionBar and rematch.battleActionBar.StartMoving
            and rematch.battleActionBar:GetFrame() then
            rematch.battleActionBar:StartMoving()
        elseif controlFrame then
            controlFrame.__rematchMoving = true
            controlFrame:StartMoving()
        end
    end)

    button:HookScript("OnDragStop", function()
        if rematch.battleActionBar and rematch.battleActionBar.StopMoving
            and rematch.battleActionBar:GetFrame() then
            rematch.battleActionBar:StopMoving()
        elseif controlFrame and controlFrame.__rematchMoving then
            controlFrame:StopMovingOrSizing()
            controlFrame.__rematchMoving = false
            saveControlPosition()
        end
    end)

    button:HookScript("OnMouseWheel", function(_, delta)
        if IsControlKeyDown() then
            if rematch.battleActionBar and rematch.battleActionBar.ChangeScale
                and rematch.battleActionBar:GetFrame() then
                rematch.battleActionBar:ChangeScale(delta)
            else
                module:ChangeScale(delta)
            end
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
        applyAutobattleBinding()
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

        controlFrame.__rematchSeparators = {}
        for index = 1, 3 do
            local separator = controlFrame:CreateTexture(nil, "ARTWORK")
            setTextureColor(separator, colors.separator)
            controlFrame.__rematchSeparators[index] = separator
        end
    elseif #controlFrame.__rematchSeparators < 3 then
        for index = #controlFrame.__rematchSeparators + 1, 3 do
            local separator = controlFrame:CreateTexture(nil, "ARTWORK")
            setTextureColor(separator, colors.separator)
            controlFrame.__rematchSeparators[index] = separator
        end
    end

    local scale = getControlScale()
    controlFrame:SetScale(1)
    controlFrame:SetSize(TOTAL_WIDTH * scale, BUTTON_HEIGHT * scale)

    local separatorX = {
        BUTTON_WIDTHS.battleData,
        BUTTON_X.auto - 1,
        BUTTON_X.auto + BUTTON_WIDTHS.auto,
    }
    for index, separator in ipairs(controlFrame.__rematchSeparators) do
        separator:ClearAllPoints()
        if _G.PixelUtil and PixelUtil.SetPoint then
            PixelUtil.SetPoint(separator, "LEFT", controlFrame, "LEFT", separatorX[index] * scale, 0)
        else
            separator:SetPoint("LEFT", controlFrame, "LEFT", separatorX[index] * scale, 0)
        end
        setOnePixelWidth(separator)
        separator:SetHeight(22 * scale)
    end

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

function module:GetFrame()
    return controlFrame
end

function module:GetBaseSize()
    return TOTAL_WIDTH, BUTTON_HEIGHT
end

function module:Refresh(skipActionBarRefresh)
    -- Refresh reparents and anchors battle buttons as well as setting keys.
    if InCombatLockdown() then
        pendingControlRefresh = true
        return
    end
    pendingControlRefresh = nil

    local turnTimer = _G.PetBattleFrame and PetBattleFrame.BottomFrame and PetBattleFrame.BottomFrame.TurnTimer
    local passButton = turnTimer and turnTimer.SkipButton
    local battleDataButton = _G.RematchBattleDataButton
    if not passButton then
        return
    end

    local autoButton = _G.tdBattlePetScriptAutoButton or ensureOwnedAutoButton(passButton)

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
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, applyAutobattleBinding)
                else
                    applyAutobattleBinding()
                end
            end)
        end
        hidePetBattleScriptsArt()
        if rematch.settings.AutobattleHotKey == nil or rematch.settings.AutobattleHotKey == "" then
            local addon = _G.PetBattleScripts
            if addon and type(addon.GetSetting) == "function" then
                local existing = addon:GetSetting("autoButtonHotKey")
                if type(existing) == "string" and existing ~= "" then
                    rematch.settings.AutobattleHotKey = existing
                end
            end
        end
        applyAutobattleBinding()
        if _G.RematchAutoBattleFlag then
            RematchAutoBattleFlag:Hide()
        end
    end

    if not skipActionBarRefresh and rematch.battleActionBar and rematch.battleActionBar.Refresh then
        rematch.battleActionBar:Refresh()
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
eventFrame:RegisterEvent("PET_BATTLE_OPENING_DONE")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingAutobattleBinding then
            applyAutobattleBinding()
        end
        if pendingControlRefresh then
            scheduleRefresh()
        end
    else
        scheduleRefresh()
    end
end)

scheduleRefresh()
