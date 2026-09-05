local _, rematch = ...

-- A compact replacement for Blizzard's wooden pet-battle bottom bar. The
-- original action buttons keep their scripts and state; only their parent,
-- layout and artwork are changed. Battle Data, Pass and Autobattle are embedded
-- in the unified menu, with a themed PvP turn-timer row above them, so one
-- Shift-drag/Ctrl-wheel interaction controls everything.

rematch.battleActionBar = rematch.battleActionBar or {}
local module = rematch.battleActionBar

local ICON_SIZE = 54
local ICON_SPACING = 9
local OUTER_PADDING = 8
local VERTICAL_PADDING = 4
-- Three pixels closer to the abilities than the previous layout.
local ROW_GAP = 4
local XP_BAR_HEIGHT = 8
local XP_BAR_GAP = 2
local TIMER_ROW_HEIGHT = 26
local TIMER_ROW_GAP = 3
local ABILITY_DIVIDER_OFFSET = 5
local MASK_TEXTURE = "Interface\\AddOns\\Rematch\\textures\\enemyAbilityMask"
local MIN_SCALE_PERCENT = 50
local MAX_SCALE_PERCENT = 200

local bar
local actionButtons = {}
local layingOut = false
local layoutScheduled = false
local actionLayoutHooked = false
local xpUpdateHooked = false
local passTimerHooked = false
local layoutActionBar
local scheduleLayout

local colors = {
    background = {0.028, 0.04, 0.055, 0.97},
    border = {0, 0, 0, 1},
    hover = {1, 1, 1, 0.14},
    divider = {0.18, 0.78, 1, 0.9},
    xp = {0.08, 0.72, 0.96, 0.96},
    xpTrack = {0.012, 0.025, 0.038, 0.96},
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
    hideFrameTextures(bottomFrame)
    hideFrameTextures(bottomFrame.FlowFrame)
    hideFrameTextures(bottomFrame.ArtFrame)

    if bottomFrame.Delimiter then
        bottomFrame.Delimiter:Hide()
    end

    -- Keep Blizzard's status-bar state alive so its value and visibility can
    -- drive the replacement, but make the original artwork fully invisible.
    if bottomFrame.xpBar then
        bottomFrame.xpBar:SetAlpha(0)
        if bottomFrame.xpBar.EnableMouse then
            bottomFrame.xpBar:EnableMouse(false)
        end
    end

    -- This is the isolated wooden plaque left above the modern bar in PvE.
    -- Alpha remains zero even when Blizzard calls SetShown(true) every battle.
    local turnTimer = bottomFrame.TurnTimer
    if turnTimer then
        -- Blizzard's timer is a large wooden plaque. Keep it alive (and its
        -- TimerText updating) as the data source for our themed row, but never
        -- draw the legacy artwork. SkipButton is reparented by battleControls,
        -- so it is unaffected by the timer frame's alpha.
        turnTimer:SetAlpha(0)
        if turnTimer.ArtFrame2 then
            hideTexture(turnTimer.ArtFrame2)
            turnTimer.ArtFrame2:Hide()
        end
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

local function createBorder(frame, point1, relativePoint1, x1, y1, point2, relativePoint2, x2, y2)
    local texture = frame:CreateTexture(nil, "BORDER")
    texture:SetPoint(point1, frame, relativePoint1, x1, y1)
    texture:SetPoint(point2, frame, relativePoint2, x2, y2)
    setColor(texture, colors.border)
end

local function getScalePercent()
    local percent = math.floor((tonumber(rematch.settings and rematch.settings.BattleControlsScale) or 100) + 0.5)
    return math.max(MIN_SCALE_PERCENT, math.min(MAX_SCALE_PERCENT, percent))
end

local function getScale()
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

local function savePosition()
    if not bar or not rematch.settings then
        return
    end

    local x, y = getCenterOffset(bar)
    if not x or not y then
        return
    end

    x = math.floor(x + 0.5)
    y = math.floor(y + 0.5)
    rematch.settings.BattleControlsX = x
    rematch.settings.BattleControlsY = y
    bar.__rematchCenterX = x
    bar.__rematchCenterY = y

    bar:ClearAllPoints()
    bar:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

local function ensureBar(bottomFrame)
    if bar then
        return bar
    end

    bar = CreateFrame("Frame", "RematchPetBattleActionBar", UIParent)
    bar:SetSize(OUTER_PADDING * 2, OUTER_PADDING * 2)
    bar:SetScale(1)
    bar:SetFrameStrata("HIGH")
    bar:SetFrameLevel((bottomFrame.GetFrameLevel and bottomFrame:GetFrameLevel() or 1) + 10)
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)

    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    setColor(background, colors.background)
    bar.__rematchBackground = background

    -- One physical pixel on each edge, with no decorative chrome.
    createBorder(bar, "TOPLEFT", "TOPLEFT", 0, 0, "TOPRIGHT", "TOPRIGHT", 0, -1)
    createBorder(bar, "BOTTOMLEFT", "BOTTOMLEFT", 0, 1, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0)
    createBorder(bar, "TOPLEFT", "TOPLEFT", 0, -1, "BOTTOMLEFT", "BOTTOMLEFT", 1, 1)
    createBorder(bar, "TOPRIGHT", "TOPRIGHT", -1, -1, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 1)

    local divider = bar:CreateTexture(nil, "ARTWORK")
    setColor(divider, colors.divider)
    divider:SetHeight(1)
    bar.AbilityDivider = divider

    local timerBackground = bar:CreateTexture(nil, "BORDER")
    -- Match the transparent utility buttons instead of introducing a second
    -- boxed panel inside the unified menu.
    timerBackground:SetColorTexture(0, 0, 0, 0)
    timerBackground:Hide()
    bar.TimerBackground = timerBackground

    local timerText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timerText:SetTextColor(0.92, 0.94, 0.96, 1)
    timerText:SetShadowColor(0, 0, 0, 1)
    timerText:SetShadowOffset(0, -1)
    local timerFont, timerFontSize, timerFontFlags = timerText:GetFont()
    if timerFont and timerFontSize then
        bar.__rematchTimerFont = {timerFont, timerFontSize, timerFontFlags}
    end
    timerText:Hide()
    bar.TimerText = timerText

    local timerDivider = bar:CreateTexture(nil, "ARTWORK")
    setColor(timerDivider, colors.divider)
    timerDivider:SetHeight(1)
    timerDivider:Hide()
    bar.TimerDivider = timerDivider

    local xpBar = CreateFrame("StatusBar", "RematchPetBattleXPBar", bar)
    xpBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    xpBar:SetStatusBarColor(colors.xp[1], colors.xp[2], colors.xp[3], colors.xp[4])
    local xpTrack = xpBar:CreateTexture(nil, "BACKGROUND")
    xpTrack:SetAllPoints()
    setColor(xpTrack, colors.xpTrack)
    xpBar.Track = xpTrack

    local xpText = xpBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    xpText:SetPoint("CENTER", xpBar, "CENTER", 0, 0)
    xpText:SetTextColor(0.94, 0.98, 1, 1)
    xpText:SetShadowColor(0, 0, 0, 1)
    xpText:SetShadowOffset(1, -1)
    local font, _, flags = xpText:GetFont()
    if font then
        xpText:SetFont(font, 11, "OUTLINE")
        xpBar.__rematchXPFont = {font, 11, flags}
    end
    xpBar.Text = xpText
    bar.XPBar = xpBar

    return bar
end

local function updateXPBar(bottomFrame)
    if not bar or not bar.XPBar then
        return
    end

    local source = bottomFrame and bottomFrame.xpBar
    if not source or not source.GetMinMaxValues or not source.GetValue then
        bar.XPBar.Text:SetText("")
        bar.XPBar:Hide()
        return
    end

    local minimum, maximum = source:GetMinMaxValues()
    local value = source:GetValue()
    minimum = tonumber(minimum) or 0
    maximum = tonumber(maximum) or 0
    value = tonumber(value) or minimum

    bar.XPBar:SetMinMaxValues(minimum, maximum)
    bar.XPBar:SetValue(value)
    bar.XPBar.Text:SetText(string.format(
        "%d/%d",
        math.floor(value + 0.5),
        math.floor(maximum + 0.5)
    ))
    bar.XPBar:SetShown(source:IsShown() and maximum > minimum)
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
    hideTexture(button.BetterIcon)
    hideTexture(button.pushed)
    hideTexture(button.hover)
end

local function beginMove()
    if not IsShiftKeyDown() or not bar then
        return
    end

    GameTooltip:Hide()
    bar.__rematchMoving = true
    bar:StartMoving()
end

local function endMove()
    if not bar or not bar.__rematchMoving then
        return
    end

    bar:StopMovingOrSizing()
    bar.__rematchMoving = false
    savePosition()
end

function module:ChangeScale(delta)
    if delta == 0 or not rematch.settings then
        return
    end

    local percent = getScalePercent()
    percent = math.max(MIN_SCALE_PERCENT, math.min(MAX_SCALE_PERCENT, percent + (delta > 0 and 1 or -1)))
    rematch.settings.BattleControlsScale = percent

    if rematch.battleControls and rematch.battleControls.Refresh then
        rematch.battleControls:Refresh(true)
    end
    self:Refresh()
end

local function installInteraction(button)
    if not button or button.__rematchUnifiedInteraction then
        return
    end
    button.__rematchUnifiedInteraction = true

    button:RegisterForDrag("LeftButton")
    button:EnableMouseWheel(true)
    button:HookScript("OnDragStart", beginMove)
    button:HookScript("OnDragStop", endMove)
    button:HookScript("OnMouseWheel", function(_, delta)
        if IsControlKeyDown() then
            module:ChangeScale(delta)
        end
    end)
end

local function styleActionButton(button)
    if not button then
        return
    end

    local scale = getScale()
    button:SetSize(ICON_SIZE * scale, ICON_SIZE * scale)
    hideButtonChrome(button)
    installInteraction(button)

    if button.__rematchModernActionButton then
        local hotKey = button.HotKey
        if hotKey and button.__rematchHotKeyFont then
            hotKey:ClearAllPoints()
            hotKey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -3 * scale, -3 * scale)
            hotKey:SetFont(
                button.__rematchHotKeyFont[1],
                button.__rematchHotKeyFont[2] * scale,
                button.__rematchHotKeyFont[3]
            )
        end
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
        hotKey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -3 * scale, -3 * scale)
        hotKey:SetFontObject(_G.NumberFontNormalSmallGray or _G.GameFontNormalSmall)
        local font, size, flags = hotKey:GetFont()
        if font and size then
            button.__rematchHotKeyFont = {font, size, flags}
            hotKey:SetFont(font, size * scale, flags)
        end
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


local function updateEffectiveness(bottomFrame)
    local effect = rematch.abilityEffectiveness
    if not effect or not C_PetBattles or not bottomFrame.abilityButtons then
        return
    end

    local ALLY = Enum.BattlePetOwner.Ally
    local ENEMY = Enum.BattlePetOwner.Enemy
    local allyIndex = C_PetBattles.GetActivePet(ALLY)
    local enemyIndex = C_PetBattles.GetActivePet(ENEMY)

    for slot = 1, 3 do
        local button = bottomFrame.abilityButtons[slot]
        if button then
            effect:Update(
                button,
                ALLY,
                allyIndex,
                slot,
                ENEMY,
                enemyIndex,
                getButtonIcon(button),
                button.__rematchActionMask
            )
        end
    end
end

layoutActionBar = function()
    if not bar then
        return
    end

    layoutScheduled = false

    if C_PetBattles and C_PetBattles.IsInBattle and not C_PetBattles.IsInBattle() then
        bar:Hide()
        return
    end

    layingOut = true

    local scale = getScale()
    local visibleButtons = {}
    for _, button in ipairs(actionButtons) do
        styleActionButton(button)
        button.__rematchActionManaged = true
        button:SetParent(bar)
        button:SetScale(1)
        button:SetFrameLevel(bar:GetFrameLevel() + 2)
        button:ClearAllPoints()
        if button:IsShown() then
            visibleButtons[#visibleButtons + 1] = button
        end
    end

    local controls = rematch.battleControls and rematch.battleControls.GetFrame
        and rematch.battleControls:GetFrame()
    local controlWidth, controlHeight = 0, 0
    if controls then
        controls:SetParent(bar)
        controls:SetScale(1)
        controls:SetFrameLevel(bar:GetFrameLevel() + 1)
        controlWidth = controls:GetWidth()
        controlHeight = controls:GetHeight()
    end

    local bottomFrame = _G.PetBattleFrame and PetBattleFrame.BottomFrame
    local turnTimer = bottomFrame and bottomFrame.TurnTimer
    local sourceTimerText = turnTimer and turnTimer.TimerText
    local timerValue = sourceTimerText and sourceTimerText:GetText()
    local timerShown = turnTimer and turnTimer:IsShown() and sourceTimerText
        and sourceTimerText:IsShown() and timerValue and timerValue ~= ""

    local count = #visibleButtons
    if count == 0 and not controls then
        bar:Hide()
        layingOut = false
        return
    end

    local actionWidth = count > 0 and (count * ICON_SIZE + (count - 1) * ICON_SPACING) * scale or 0
    local actionHeight = count > 0 and ICON_SIZE * scale or 0
    local gap = count > 0 and controls and ROW_GAP * scale or 0
    local horizontalPadding = OUTER_PADDING * scale
    local verticalPadding = VERTICAL_PADDING * scale
    local timerHeight = timerShown and TIMER_ROW_HEIGHT * scale or 0
    local timerGap = timerShown and controls and TIMER_ROW_GAP * scale or 0
    local xpReserve = count > 0 and (XP_BAR_HEIGHT + XP_BAR_GAP) * scale or 0
    local actionBottom = verticalPadding + xpReserve
    local width = math.max(actionWidth, controlWidth) + horizontalPadding * 2
    local height = timerHeight + timerGap + actionHeight + controlHeight + gap
        + verticalPadding + actionBottom

    bar:SetScale(1)
    bar:SetSize(width, height)

    if timerShown then
        turnTimer:SetAlpha(0)

        bar.TimerText:ClearAllPoints()
        bar.TimerText:SetPoint("TOPLEFT", bar, "TOPLEFT", horizontalPadding, -verticalPadding)
        bar.TimerText:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", -horizontalPadding, -(verticalPadding + timerHeight))
        bar.TimerText:SetText(timerValue)
        if bar.__rematchTimerFont then
            bar.TimerText:SetFont(
                bar.__rematchTimerFont[1],
                bar.__rematchTimerFont[2] * scale,
                bar.__rematchTimerFont[3]
            )
        end
        bar.TimerText:Show()

        bar.TimerBackground:ClearAllPoints()
        bar.TimerBackground:SetPoint("TOPLEFT", bar.TimerText, "TOPLEFT", 0, 0)
        bar.TimerBackground:SetPoint("BOTTOMRIGHT", bar.TimerText, "BOTTOMRIGHT", 0, 0)
        bar.TimerBackground:Show()

        bar.TimerDivider:ClearAllPoints()
        bar.TimerDivider:SetPoint("TOPLEFT", bar.TimerText, "BOTTOMLEFT", 0, -timerGap / 2)
        bar.TimerDivider:SetPoint("TOPRIGHT", bar.TimerText, "BOTTOMRIGHT", 0, -timerGap / 2)
        bar.TimerDivider:Show()
    else
        bar.TimerText:Hide()
        bar.TimerBackground:Hide()
        bar.TimerDivider:Hide()
    end

    if controls then
        controls:ClearAllPoints()
        controls:SetPoint("TOP", bar, "TOP", 0, -(verticalPadding + timerHeight + timerGap))
        if rematch.battleControls and rematch.battleControls.LayoutKeybind then
            rematch.battleControls:LayoutKeybind()
        end
    end

    if count > 0 then
        local startX = (width - actionWidth) / 2
        for index, button in ipairs(visibleButtons) do
            local x = startX + (index - 1) * (ICON_SIZE + ICON_SPACING) * scale
            button:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x, actionBottom)
        end
    end


    bar.AbilityDivider:ClearAllPoints()
    bar.AbilityDivider:SetPoint(
        "BOTTOMLEFT",
        bar,
        "BOTTOMLEFT",
        1,
        actionBottom + actionHeight + ABILITY_DIVIDER_OFFSET * scale
    )
    bar.AbilityDivider:SetPoint(
        "BOTTOMRIGHT",
        bar,
        "BOTTOMRIGHT",
        -1,
        actionBottom + actionHeight + ABILITY_DIVIDER_OFFSET * scale
    )
    bar.AbilityDivider:SetHeight(1)
    bar.AbilityDivider:SetShown(count > 0)

    bar.XPBar:ClearAllPoints()
    bar.XPBar:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 1, 1)
    bar.XPBar:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -1, 1)
    bar.XPBar:SetHeight(XP_BAR_HEIGHT * scale)
    if bar.XPBar.__rematchXPFont then
        bar.XPBar.Text:SetFont(
            bar.XPBar.__rematchXPFont[1],
            bar.XPBar.__rematchXPFont[2] * scale,
            "OUTLINE"
        )
    end

    if not bar.__rematchPositionInitialized then
        local savedX = rematch.settings and rematch.settings.BattleControlsX
        local savedY = rematch.settings and rematch.settings.BattleControlsY
        bar.__rematchCenterX = type(savedX) == "number" and savedX or 0
        bar.__rematchCenterY = type(savedY) == "number" and savedY or (14 + height / 2)
        bar.__rematchPositionInitialized = true
    end

    bar:ClearAllPoints()
    bar:SetPoint("CENTER", UIParent, "CENTER", bar.__rematchCenterX, bar.__rematchCenterY)
    bar:Show()
    layingOut = false

    if bottomFrame then
        updateEffectiveness(bottomFrame)
        updateXPBar(bottomFrame)
    end
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

function module:GetFrame()
    return bar
end

function module:StartMoving()
    beginMove()
end

function module:StopMoving()
    endMove()
end

function module:Refresh()
    local bottomFrame = _G.PetBattleFrame and PetBattleFrame.BottomFrame
    if not bottomFrame then
        return
    end

    hideOldBottomBar(bottomFrame)
    ensureBar(bottomFrame)
    if not bar.__rematchUnifiedInteraction then
        bar.__rematchUnifiedInteraction = true
        bar:EnableMouse(true)
        bar:EnableMouseWheel(true)
        bar:RegisterForDrag("LeftButton")
        bar:SetScript("OnDragStart", beginMove)
        bar:SetScript("OnDragStop", endMove)
        bar:SetScript("OnMouseWheel", function(_, delta)
            if IsControlKeyDown() then
                module:ChangeScale(delta)
            end
        end)
    end
    actionButtons = collectActionButtons(bottomFrame)

    for _, button in ipairs(actionButtons) do
        styleActionButton(button)
    end

    if not actionLayoutHooked and type(_G.PetBattleFrame_UpdateActionBarLayout) == "function" and hooksecurefunc then
        actionLayoutHooked = true
        hooksecurefunc("PetBattleFrame_UpdateActionBarLayout", scheduleLayout)
    end


    if not xpUpdateHooked and type(_G.PetBattleFrame_UpdateXpBar) == "function" and hooksecurefunc then
        xpUpdateHooked = true
        hooksecurefunc("PetBattleFrame_UpdateXpBar", function(petBattleFrame)
            updateXPBar(petBattleFrame and petBattleFrame.BottomFrame or bottomFrame)
        end)
    end

    if not passTimerHooked and type(_G.PetBattleFrame_UpdatePassButtonAndTimer) == "function"
        and hooksecurefunc then
        passTimerHooked = true
        hooksecurefunc("PetBattleFrame_UpdatePassButtonAndTimer", scheduleLayout)
    end

    scheduleLayout()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PET_BATTLE_OPENING_START")
eventFrame:RegisterEvent("PET_BATTLE_PET_CHANGED")
eventFrame:RegisterEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE")
eventFrame:RegisterEvent("PET_BATTLE_CLOSE")
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
