local _, rematch = ...

-- Rematch Enemy Ability Bar
-- WoW 12.1 compatibility module.
-- Shows the active enemy pet's abilities and manually tracks enemy PvE cooldowns.
-- Includes an in-game configuration window. Open it with: /reab

rematch.enemyAbilityBar = rematch.enemyAbilityBar or {}
local module = rematch.enemyAbilityBar

local ENEMY = Enum.BattlePetOwner.Enemy
local abilityButtons = {}
local casts = {}
local currentRound = 0
local bar
local configFrame
local eventFrame = CreateFrame("Frame")
local applyLayout

local MIN_SCALE_PERCENT = 50
local MAX_SCALE_PERCENT = 200

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------

local function getSettings()
    return {
        iconSize = rematch.settings.EnemyAbilityIconSize or 42,
        spacing = rematch.settings.EnemyAbilitySpacing or 6,

        cooldownFontObject = rematch.settings.EnemyAbilityCooldownFont or "GameFontNormalSmall",
        cooldownFontSize = rematch.settings.EnemyAbilityCooldownFontSize or 12,
        cooldownX = rematch.settings.EnemyAbilityCooldownX or 0,
        cooldownY = rematch.settings.EnemyAbilityCooldownY or 0,

        remainingFontObject = "GameFontNormalLarge",
        remainingFontSize = rematch.settings.EnemyAbilityRemainingFontSize or 16,

        barX = 0,
        barY = 28,
        savedBarX = rematch.settings.EnemyAbilityBarX,
        savedBarY = rematch.settings.EnemyAbilityBarY,
    }
end

local function getScalePercent()
    local percent = math.floor((tonumber(rematch.settings.EnemyAbilityScale) or 100) + 0.5)
    return math.max(MIN_SCALE_PERCENT, math.min(MAX_SCALE_PERCENT, percent))
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

local function changeScale(delta)
    if delta == 0 then
        return
    end

    local percent = getScalePercent()
    percent = math.max(MIN_SCALE_PERCENT, math.min(MAX_SCALE_PERCENT, percent + (delta > 0 and 1 or -1)))
    rematch.settings.EnemyAbilityScale = percent

    if applyLayout then
        applyLayout()
    end
end

local function setDefaultAnchor(db)
    bar:ClearAllPoints()
    if PetBattleFrame and PetBattleFrame.BottomFrame then
        bar:SetPoint("BOTTOM", PetBattleFrame.BottomFrame, "TOP", db.barX, db.barY)
    else
        bar:SetPoint("CENTER", UIParent, "CENTER", db.barX, -160 + db.barY)
    end
end

local fontChoices = {
    {name="Friz Quadrata", object="GameFontNormalSmall"},
    {name="Friz Quadrata Large", object="GameFontNormalLarge"},
    {name="Number Font", object="NumberFontNormal"},
    {name="Number Font Large", object="NumberFontNormalLarge"},
}

local function getFontChoiceName(object)
    for _, info in ipairs(fontChoices) do
        if info.object == object then
            return info.name
        end
    end
    return object or "Default"
end

local function applyFont(fontString, fontObjectName, size)
    local fontObject = _G[fontObjectName] or GameFontNormalSmall
    fontString:SetFontObject(fontObject)

    local font = fontString:GetFont()
    if font then
        fontString:SetFont(font, size, "OUTLINE")
    end

    fontString:SetTextColor(1, 1, 1, 1)
    fontString:SetShadowColor(0, 0, 0, 1)
    fontString:SetShadowOffset(0, 0)
end

-- ---------------------------------------------------------------------------
-- Battle/cooldown state
-- ---------------------------------------------------------------------------

local function ensurePetTable(index)
    if not casts[index] then
        casts[index] = {}
    end
    return casts[index]
end

local function resetBattle()
    wipe(casts)
    currentRound = 0
end

local function getRemainingCooldown(enemyIndex, slot, abilityID, baseCooldown)
    local petCasts = casts[enemyIndex]
    local cast = petCasts and petCasts[slot]

    if not cast or cast.id ~= abilityID then
        return 0
    end

    local remaining = (baseCooldown or 0) + cast.turn - currentRound
    return max(0, remaining)
end

-- ---------------------------------------------------------------------------
-- Ability buttons / bar
-- ---------------------------------------------------------------------------

local function createAbilityButton(parent, index)
    local db = getSettings()

    local button = CreateFrame("Button", nil, parent)
    button:SetSize(db.iconSize, db.iconSize)
    button.abilitySlot = index

    button.Icon = button:CreateTexture(nil, "ARTWORK")
    button.Icon:SetAllPoints()
    button.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- Rounded-square mask. Keep exactly one mask on the icon.
    button.IconMask = button:CreateMaskTexture()
    button.IconMask:SetAllPoints(button.Icon)
    button.IconMask:SetTexture(
        "Interface\\AddOns\\Rematch\\textures\\enemyAbilityMask",
        "CLAMPTOBLACKADDITIVE",
        "CLAMPTOBLACKADDITIVE"
    )
    button.Icon:AddMaskTexture(button.IconMask)

    button.CooldownText = button:CreateFontString(nil, "OVERLAY")
    button.CooldownText:SetPoint("CENTER", 0, 0)
    applyFont(button.CooldownText, db.remainingFontObject, db.remainingFontSize)

    button.MaxCooldownText = button:CreateFontString(nil, "OVERLAY")
    button.MaxCooldownText:SetPoint("TOPRIGHT", db.cooldownX, db.cooldownY)
    applyFont(button.MaxCooldownText, db.cooldownFontObject, db.cooldownFontSize)

    button:SetScript("OnEnter", function(self)
        if not self.abilityID then
            return
        end

        local enemyIndex = C_PetBattles.GetActivePet(ENEMY)
        if enemyIndex and enemyIndex > 0
            and PetBattleAbilityTooltip_SetAbility
            and PetBattleAbilityTooltip_Show
            and PetBattlePrimaryAbilityTooltip then

            PetBattleAbilityTooltip_SetAbility(ENEMY, enemyIndex, self.abilitySlot)
            PetBattleAbilityTooltip_Show("TOPLEFT", self, "TOPRIGHT", 8, 0)
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.abilityName or ("Ability "..self.abilityID), 1, 1, 1)

        if self.description and self.description ~= "" then
            GameTooltip:AddLine(self.description, nil, nil, nil, true)
        end

        if self.baseCooldown and self.baseCooldown > 0 then
            GameTooltip:AddLine("Cooldown: "..self.baseCooldown.." rounds", 1, 0.82, 0)
        end

        if self.remaining and self.remaining > 0 then
            GameTooltip:AddLine("Remaining: "..self.remaining.." rounds", 1, 0.25, 0.25)
        end

        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        if PetBattlePrimaryAbilityTooltip then
            PetBattlePrimaryAbilityTooltip:Hide()
        end
        GameTooltip:Hide()
    end)

    button:RegisterForDrag("LeftButton")
    button:EnableMouseWheel(true)
    button:SetScript("OnDragStart", function(self)
        if not IsShiftKeyDown() or not bar then
            return
        end

        if PetBattlePrimaryAbilityTooltip then
            PetBattlePrimaryAbilityTooltip:Hide()
        end
        GameTooltip:Hide()

        bar.__rematchMoving = true
        bar:StartMoving()
    end)

    button:SetScript("OnDragStop", function()
        if not bar or not bar.__rematchMoving then
            return
        end

        bar:StopMovingOrSizing()
        bar.__rematchMoving = false

        local barX, barY = getCenterOffset(bar)
        if barX and barY then
            rematch.settings.EnemyAbilityBarX = math.floor(barX + 0.5)
            rematch.settings.EnemyAbilityBarY = math.floor(barY + 0.5)
            bar.__rematchCenterX = rematch.settings.EnemyAbilityBarX
            bar.__rematchCenterY = rematch.settings.EnemyAbilityBarY
        end
    end)

    button:SetScript("OnMouseWheel", function(_, delta)
        if IsControlKeyDown() then
            changeScale(delta)
        end
    end)

    return button
end

applyLayout = function()
    if not bar then
        return
    end

    local db = getSettings()
    local scale = getScalePercent() / 100
    local centerX = type(db.savedBarX) == "number" and db.savedBarX or bar.__rematchCenterX
    local centerY = type(db.savedBarY) == "number" and db.savedBarY or bar.__rematchCenterY

    -- Establish the original default center once, then use a screen-centered
    -- anchor for every layout. Resizing the icons can therefore expand evenly
    -- in all directions without moving the bar.
    if type(centerX) ~= "number" or type(centerY) ~= "number" then
        local baseWidth = db.iconSize * 3 + db.spacing * 2
        bar:SetScale(1)
        bar:SetSize(baseWidth, db.iconSize)
        setDefaultAnchor(db)
        centerX, centerY = getCenterOffset(bar)
        centerX = centerX or 0
        centerY = centerY or (-160 + db.barY)
    end

    bar.__rematchCenterX = centerX
    bar.__rematchCenterY = centerY

    for i = 1, 3 do
        local button = abilityButtons[i]
        button:SetSize(db.iconSize * scale, db.iconSize * scale)

        button:ClearAllPoints()
        if i == 1 then
            button:SetPoint("LEFT", bar, "LEFT", 0, 0)
        else
            button:SetPoint("LEFT", abilityButtons[i-1], "RIGHT", db.spacing * scale, 0)
        end

        button.MaxCooldownText:ClearAllPoints()
        button.MaxCooldownText:SetPoint("TOPRIGHT", db.cooldownX * scale, db.cooldownY * scale)

        applyFont(button.MaxCooldownText, db.cooldownFontObject, db.cooldownFontSize * scale)
        applyFont(button.CooldownText, db.remainingFontObject, db.remainingFontSize * scale)
    end

    local width = (db.iconSize * 3 + db.spacing * 2) * scale
    bar:SetScale(1)
    bar:SetSize(width, db.iconSize * scale)

    bar:ClearAllPoints()
    bar:SetPoint("CENTER", UIParent, "CENTER", centerX, centerY)
end

local updateBar

local function ensureBar()
    if bar then
        return
    end

    bar = CreateFrame("Frame", "RematchEnemyAbilityBar", UIParent)
    bar:SetFrameStrata("HIGH")
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    bar:EnableMouse(true)

    -- Pet-selection visibility can change without a convenient addon event.
    -- Poll very lightly so the ability bar disappears/reappears immediately.
    bar.selectionPoll = 0
    bar.wasPetSelectShown = false
    bar:SetScript("OnUpdate", function(self, elapsed)
        self.selectionPoll = self.selectionPoll + elapsed
        if self.selectionPoll < 0.05 then
            return
        end
        self.selectionPoll = 0

        if not C_PetBattles.IsInBattle() then
            return
        end

        local shown = C_PetBattles.ShouldShowPetSelect
            and C_PetBattles.ShouldShowPetSelect()
            or false

        if shown ~= self.wasPetSelectShown then
            self.wasPetSelectShown = shown
            if shown then
                self:Hide()
            else
                updateBar()
            end
        end
    end)

    for i = 1, 3 do
        abilityButtons[i] = createAbilityButton(bar, i)
    end

    applyLayout()
    bar:Hide()
end

updateBar = function()
    ensureBar()

    if not C_PetBattles.IsInBattle() then
        bar:Hide()
        return
    end

    -- Hide the enemy ability bar while Blizzard's pet-selection UI is open.
    -- This prevents overlap with the choose-a-pet menu during swaps/deaths.
    if C_PetBattles.ShouldShowPetSelect and C_PetBattles.ShouldShowPetSelect() then
        bar:Hide()
        return
    end

    local enemyIndex = C_PetBattles.GetActivePet(ENEMY)
    if not enemyIndex or enemyIndex == 0 then
        bar:Hide()
        return
    end

    local hasAbility = false

    for slot = 1, 3 do
        local button = abilityButtons[slot]
        local abilityID, name, icon, baseCooldown, description =
            C_PetBattles.GetAbilityInfo(ENEMY, enemyIndex, slot)

        if abilityID then
            hasAbility = true

            local remaining = getRemainingCooldown(enemyIndex, slot, abilityID, baseCooldown)

            button.abilityID = abilityID
            button.abilityName = name
            button.description = description
            button.baseCooldown = baseCooldown or 0
            button.remaining = remaining

            button.Icon:SetTexture(icon)
            button.Icon:SetDesaturated(remaining > 0)

            if remaining > 0 then
                button.CooldownText:SetText(remaining)
                button.CooldownText:Show()
            else
                button.CooldownText:SetText("")
                button.CooldownText:Hide()
            end

            if baseCooldown and baseCooldown > 0 then
                button.MaxCooldownText:SetText(baseCooldown)
                button.MaxCooldownText:Show()
            else
                button.MaxCooldownText:SetText("")
                button.MaxCooldownText:Hide()
            end

            button:Show()
        else
            button.abilityID = nil
            button:Hide()
        end
    end

    bar:SetShown(hasAbility)
end

-- ---------------------------------------------------------------------------
-- Combat log tracking
-- ---------------------------------------------------------------------------

local function isEnemyCastMessage(message)
    local isHeal = ACTION_SPELL_HEAL and message:find(ACTION_SPELL_HEAL, 1, true)
    local mentionsEnemy = message:find(_G.ENEMY or "Enemy", 1, true)

    if isHeal then
        return mentionsEnemy and true or false
    end

    return not mentionsEnemy
end

local function processCombatLog(message)
    if not message or issecretvalue(message) then
        return
    end

    if PET_BATTLE_COMBAT_LOG_NEW_ROUND then
        local pattern = PET_BATTLE_COMBAT_LOG_NEW_ROUND:gsub("%%d", "(%%d+)")
        local round = message:match(pattern)
        if round then
            currentRound = tonumber(round) or currentRound
            updateBar()
            return
        end
    end

    local abilityID = tonumber(message:match("|HbattlePetAbil:(%d+)"))
    if not abilityID or not isEnemyCastMessage(message) then
        return
    end

    local enemyIndex = C_PetBattles.GetActivePet(ENEMY)
    if not enemyIndex or enemyIndex == 0 then
        return
    end

    for slot = 1, 3 do
        local id = C_PetBattles.GetAbilityInfo(ENEMY, enemyIndex, slot)
        if id == abilityID then
            local petCasts = ensurePetTable(enemyIndex)
            petCasts[slot] = {
                id = abilityID,
                turn = currentRound,
            }
            updateBar()
            return
        end
    end
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

eventFrame:RegisterEvent("PET_BATTLE_OPENING_START")
eventFrame:RegisterEvent("PET_BATTLE_PET_CHANGED")
eventFrame:RegisterEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE")
eventFrame:RegisterEvent("PET_BATTLE_CLOSE")
eventFrame:RegisterEvent("CHAT_MSG_PET_BATTLE_COMBAT_LOG")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PET_BATTLE_OPENING_START" then
        resetBattle()
        C_Timer.After(0, function()
            applyLayout()
            updateBar()
        end)

    elseif event == "PET_BATTLE_CLOSE" then
        resetBattle()
        if bar then
            bar:Hide()
        end

    elseif event == "CHAT_MSG_PET_BATTLE_COMBAT_LOG" then
        processCombatLog(...)

    elseif event == "PET_BATTLE_PET_CHANGED" or event == "PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE" then
        updateBar()
    end
end)

function module:ApplySettings()
    applyLayout()
    updateBar()
end

module.Update = updateBar
module.Reset = resetBattle
module.ApplyLayout = applyLayout
