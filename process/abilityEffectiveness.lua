local _, rematch = ...

-- Shared strong/weak presentation for the player's action bar and the enemy
-- ability bar. Blizzard already exposes the authoritative modifier; this module
-- only replaces the small corner badge with a full-icon directional gradient.

rematch.abilityEffectiveness = rematch.abilityEffectiveness or {}
local module = rematch.abilityEffectiveness

local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8X8"

local colors = {
    strongBottom = {0.05, 1.00, 0.24, 0.70},
    strongTop = {0.05, 0.74, 0.18, 0.03},
    weakBottom = {0.82, 0.04, 0.04, 0.03},
    weakTop = {1.00, 0.05, 0.05, 0.70},
}

local function safeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end

    local ok, a, b, c, d, e, f, g, h = pcall(func, ...)
    if not ok then
        return nil
    end
    return a, b, c, d, e, f, g, h
end

local function usable(value)
    return value ~= nil and (not issecretvalue or not issecretvalue(value))
end

local function makeColor(values)
    if CreateColor then
        return CreateColor(values[1], values[2], values[3], values[4])
    end
end

local function ensureOverlay(button, icon, mask)
    if button.__rematchEffectivenessOverlay then
        return button.__rematchEffectivenessOverlay
    end

    local overlay = button:CreateTexture(nil, "ARTWORK", nil, 7)
    overlay:SetAllPoints(icon or button)
    overlay:SetTexture(WHITE_TEXTURE)
    overlay:SetBlendMode("ADD")
    if mask and overlay.AddMaskTexture then
        overlay:AddMaskTexture(mask)
    end
    overlay:Hide()

    button.__rematchEffectivenessOverlay = overlay
    return overlay
end

local function setGradient(overlay, bottom, top)
    local bottomColor = makeColor(bottom)
    local topColor = makeColor(top)

    if overlay.SetGradient and bottomColor and topColor then
        local ok = pcall(overlay.SetGradient, overlay, "VERTICAL", bottomColor, topColor)
        if ok then
            return
        end
    end

    -- Current clients support SetGradient. This solid fallback keeps the hint
    -- usable if another client or test harness does not expose that API.
    overlay:SetColorTexture(bottom[1], bottom[2], bottom[3], math.max(bottom[4], top[4]) * 0.58)
end

function module:Set(button, modifier, noStrongWeakHints, icon, mask)
    if not button then
        return
    end

    local overlay = ensureOverlay(button, icon, mask)
    local mode

    if not noStrongWeakHints and usable(modifier) then
        if modifier > 1 then
            mode = "strong"
            setGradient(overlay, colors.strongBottom, colors.strongTop)
        elseif modifier < 1 then
            mode = "weak"
            setGradient(overlay, colors.weakBottom, colors.weakTop)
        end
    end

    button.__rematchEffectivenessMode = mode
    overlay:SetShown(mode ~= nil)
end

function module:Update(button, attackOwner, attackIndex, abilitySlot, defenseOwner, defenseIndex, icon, mask)
    if not C_PetBattles or not attackIndex or not defenseIndex then
        self:Set(button, nil, true, icon, mask)
        return
    end

    local _, _, _, _, _, _, attackType, noStrongWeakHints =
        safeCall(C_PetBattles.GetAbilityInfo, attackOwner, attackIndex, abilitySlot)
    local defenseType = safeCall(C_PetBattles.GetPetType, defenseOwner, defenseIndex)

    if not usable(attackType) or not usable(defenseType) or noStrongWeakHints then
        self:Set(button, nil, true, icon, mask)
        return
    end

    local modifier = safeCall(C_PetBattles.GetAttackModifier, attackType, defenseType)
    self:Set(button, modifier, false, icon, mask)
end
