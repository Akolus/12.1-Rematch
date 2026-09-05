local _, rematch = ...

-- Rematch Battle Data Recorder
-- Records pet-battle team stats, raw combat-log messages, and round-by-round
-- health/active-pet snapshots for easy copy/paste.
--
-- Commands:
--   /rbd       Open the most recently recorded battle
--   /rbd live  Open the current battle recording
--   /rbd clear Clear the stored recording

rematch.battleData = rematch.battleData or {}
local module = rematch.battleData

local ALLY = Enum.BattlePetOwner.Ally
local ENEMY = Enum.BattlePetOwner.Enemy

local eventFrame = CreateFrame("Frame")
local current
local lastBattle
local exportFrame
local exportEditBox
local battleButton

local PET_TYPE_NAMES = {
    [1] = "Humanoid",
    [2] = "Dragonkin",
    [3] = "Flying",
    [4] = "Undead",
    [5] = "Critter",
    [6] = "Magic",
    [7] = "Elemental",
    [8] = "Beast",
    [9] = "Aquatic",
    [10] = "Mechanical",
}

local function safeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end
    local ok, a, b, c, d, e, f = pcall(func, ...)
    if not ok then
        return nil
    end
    return a, b, c, d, e, f
end

local function safeValue(value, fallback)
    if value == nil or issecretvalue(value) then
        return fallback
    end
    return value
end

local function petTypeName(petType)
    petType = safeValue(petType)
    return PET_TYPE_NAMES[petType] or tostring(petType or "?")
end

local function abilityInfo(owner, petIndex, slot)
    local id, name, icon, maxCooldown, description, numTurns, petType, noStrongWeakHints =
        safeCall(C_PetBattles.GetAbilityInfo, owner, petIndex, slot)

    return {
        id = safeValue(id),
        name = safeValue(name, "?"),
        cooldown = safeValue(maxCooldown, 0),
        type = safeValue(petType),
    }
end

local function getPet(owner, petIndex)
    local name = safeValue(safeCall(C_PetBattles.GetName, owner, petIndex), "?")
    local speciesID = safeValue(safeCall(C_PetBattles.GetPetSpeciesID, owner, petIndex))
    local level = safeValue(safeCall(C_PetBattles.GetLevel, owner, petIndex), "?")
    local health = safeValue(safeCall(C_PetBattles.GetHealth, owner, petIndex), "?")
    local maxHealth = safeValue(safeCall(C_PetBattles.GetMaxHealth, owner, petIndex), "?")
    local power = safeValue(safeCall(C_PetBattles.GetPower, owner, petIndex), "?")
    local speed = safeValue(safeCall(C_PetBattles.GetSpeed, owner, petIndex), "?")
    local petType = safeValue(safeCall(C_PetBattles.GetPetType, owner, petIndex))

    local pet = {
        index = petIndex,
        name = name,
        speciesID = speciesID,
        level = level,
        health = health,
        maxHealth = maxHealth,
        power = power,
        speed = speed,
        petType = petType,
        abilities = {},
    }

    for slot = 1, 3 do
        pet.abilities[slot] = abilityInfo(owner, petIndex, slot)
    end

    return pet
end

local function getTeam(owner)
    local team = {}
    local count = safeValue(safeCall(C_PetBattles.GetNumPets, owner), 3)
    if type(count) ~= "number" or count < 1 then
        count = 3
    end

    for i = 1, count do
        team[i] = getPet(owner, i)
    end
    return team
end

local function snapshotTeam(owner)
    local result = {}
    local active = safeValue(safeCall(C_PetBattles.GetActivePet, owner), 0)

    local count = safeValue(safeCall(C_PetBattles.GetNumPets, owner), 3)
    if type(count) ~= "number" or count < 1 then
        count = 3
    end

    for i = 1, count do
        local health = safeValue(safeCall(C_PetBattles.GetHealth, owner, i), "?")
        local maxHealth = safeValue(safeCall(C_PetBattles.GetMaxHealth, owner, i), "?")
        result[i] = {
            health = health,
            maxHealth = maxHealth,
            active = i == active,
        }
    end
    return result
end

local function takeSnapshot(label)
    if not current then
        return
    end

    current.snapshots[#current.snapshots + 1] = {
        round = current.round or 0,
        label = label or "snapshot",
        ally = snapshotTeam(ALLY),
        enemy = snapshotTeam(ENEMY),
    }
end

local function parseRound(message)
    if not message or issecretvalue(message) or not PET_BATTLE_COMBAT_LOG_NEW_ROUND then
        return nil
    end

    local pattern = PET_BATTLE_COMBAT_LOG_NEW_ROUND
        :gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1")
        :gsub("%%%%d", "(%%d+)")

    return tonumber(message:match(pattern))
end

local function cleanCombatLog(message)
    if not message or issecretvalue(message) then
        return nil
    end

    -- Preserve names, ability names and numbers while making the pasted output
    -- much easier to read outside WoW.
    local text = message
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|HbattlePetAbil:(%d+):[^|]*|h%[?([^%]|]+)%]?|h", "%2 [abilityID=%1]")
    text = text:gsub("|HbattlePetAbil:(%d+)[^|]*|h([^|]+)|h", "%2 [abilityID=%1]")
    text = text:gsub("|Hbattlepet:[^|]*|h([^|]+)|h", "%1")
    text = text:gsub("|T[^|]+|t", "")
    return text
end

local function startBattle()
    current = {
        started = date("%Y-%m-%d %H:%M:%S"),
        round = 0,
        allyTeam = getTeam(ALLY),
        enemyTeam = getTeam(ENEMY),
        logs = {},
        snapshots = {},
        result = "UNKNOWN",
    }

    takeSnapshot("BATTLE START")
end

local function updateBattleResult()
    if not current then
        return
    end

    local winner = safeValue(safeCall(C_PetBattles.GetWinner))
    if winner == ALLY then
        current.result = "WIN"
    elseif winner == ENEMY then
        current.result = "LOSS"
    end
end

local function finishBattle()
    if not current then
        return
    end

    takeSnapshot("BATTLE END")
    updateBattleResult()

    current.finished = date("%Y-%m-%d %H:%M:%S")
    lastBattle = current
    current = nil
end

local function appendCombatLog(message)
    if not current then
        return
    end

    local clean = cleanCombatLog(message)
    if not clean then
        return
    end

    local round = parseRound(message)
    if round then
        current.round = round
        takeSnapshot("ROUND " .. round .. " START")
    end

    current.logs[#current.logs + 1] = {
        round = current.round or 0,
        text = clean,
    }
end

local function petLine(prefix, pet)
    local result = {}
    result[#result + 1] = string.format(
        "%s#%d %s | SpeciesID: %s | Family: %s | Level: %s | HP: %s/%s | Power: %s | Speed: %s",
        prefix,
        pet.index,
        tostring(pet.name),
        tostring(pet.speciesID or "?"),
        petTypeName(pet.petType),
        tostring(pet.level),
        tostring(pet.health),
        tostring(pet.maxHealth),
        tostring(pet.power),
        tostring(pet.speed)
    )

    for slot = 1, 3 do
        local a = pet.abilities[slot]
        result[#result + 1] = string.format(
            "    Ability %d: %s | ID: %s | Family: %s | Cooldown: %s",
            slot,
            tostring(a.name or "?"),
            tostring(a.id or "?"),
            petTypeName(a.type),
            tostring(a.cooldown or 0)
        )
    end

    return table.concat(result, "\n")
end

local function snapshotPetState(team, originalTeam)
    local parts = {}
    for i, state in ipairs(team or {}) do
        local pet = originalTeam and originalTeam[i]
        local name = pet and pet.name or ("Pet " .. i)
        parts[#parts + 1] = string.format(
            "%s#%d %s: %s/%s%s",
            state.active and "*" or " ",
            i,
            tostring(name),
            tostring(state.health),
            tostring(state.maxHealth),
            state.active and " [ACTIVE]" or ""
        )
    end
    return table.concat(parts, " | ")
end

local function buildExport(data)
    if not data then
        return "No pet battle has been recorded yet."
    end

    local out = {}

    out[#out + 1] = "=== REMATCH BATTLE DATA ==="
    out[#out + 1] = "Started: " .. tostring(data.started or "?")
    out[#out + 1] = "Finished: " .. tostring(data.finished or "(battle still active)")
    out[#out + 1] = "Result: " .. tostring(data.result or "UNKNOWN")
    out[#out + 1] = "Rounds observed: " .. tostring(data.round or 0)
    out[#out + 1] = ""

    out[#out + 1] = "=== PLAYER TEAM ==="
    for _, pet in ipairs(data.allyTeam or {}) do
        out[#out + 1] = petLine("", pet)
    end
    out[#out + 1] = ""

    out[#out + 1] = "=== ENEMY TEAM ==="
    for _, pet in ipairs(data.enemyTeam or {}) do
        out[#out + 1] = petLine("", pet)
    end
    out[#out + 1] = ""

    out[#out + 1] = "=== ROUND SNAPSHOTS ==="
    for _, snap in ipairs(data.snapshots or {}) do
        out[#out + 1] = string.format("[%s | round=%s]", tostring(snap.label), tostring(snap.round))
        out[#out + 1] = "  PLAYER: " .. snapshotPetState(snap.ally, data.allyTeam)
        out[#out + 1] = "  ENEMY : " .. snapshotPetState(snap.enemy, data.enemyTeam)
    end
    out[#out + 1] = ""

    out[#out + 1] = "=== RAW COMBAT LOG ==="
    local lastRound
    for _, entry in ipairs(data.logs or {}) do
        if entry.round ~= lastRound then
            out[#out + 1] = ""
            out[#out + 1] = "--- ROUND " .. tostring(entry.round) .. " ---"
            lastRound = entry.round
        end
        out[#out + 1] = entry.text
    end

    out[#out + 1] = ""
    out[#out + 1] = "=== END REMATCH BATTLE DATA ==="

    return table.concat(out, "\n")
end


local function ensureBattleButton()
    if not rematch:IsCustomBattleUIEnabled() then
        return
    end
    if battleButton or not PetBattleFrame or not PetBattleFrame.BottomFrame or not PetBattleFrame.BottomFrame.TurnTimer then
        return
    end

    local skipButton = PetBattleFrame.BottomFrame.TurnTimer.SkipButton
    if not skipButton then
        return
    end

    battleButton = CreateFrame("Button", "RematchBattleDataButton", skipButton:GetParent(), "UIPanelButtonTemplate")
    battleButton:SetSize(88, skipButton:GetHeight())
    battleButton:SetText("Battle Data")
    battleButton:SetFrameLevel(skipButton:GetFrameLevel() + 1)

    battleButton:SetScript("OnClick", function()
        module:Show(C_PetBattles.IsInBattle() and "live" or "last")
    end)

    battleButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Rematch Battle Data")
        GameTooltip:AddLine("Open the current or most recent pet-battle recording.", 1, 1, 1, true)
        GameTooltip:AddLine("Use Ctrl+A and Ctrl+C in the window to copy everything.", 0.2, 1, 0.2, true)
        GameTooltip:Show()
    end)

    battleButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Place it immediately to the LEFT of the Pass button.
    battleButton:ClearAllPoints()
    battleButton:SetPoint("RIGHT", skipButton, "LEFT", -2, 0)

    battleButton:SetShown(C_PetBattles.IsInBattle())
end

local function updateBattleButton()
    ensureBattleButton()
    if not battleButton then
        return
    end

    local inBattle = C_PetBattles.IsInBattle()
    battleButton:SetShown(inBattle)
    battleButton:SetEnabled(inBattle and (current ~= nil or lastBattle ~= nil))
end

local function ensureExportFrame()
    if exportFrame then
        return
    end

    exportFrame = CreateFrame("Frame", "RematchBattleDataExportFrame", UIParent, "BackdropTemplate")
    exportFrame:SetSize(760, 640)
    exportFrame:SetPoint("CENTER")
    exportFrame:SetFrameStrata("DIALOG")
    exportFrame:SetClampedToScreen(true)
    exportFrame:SetMovable(true)
    exportFrame:EnableMouse(true)
    exportFrame:RegisterForDrag("LeftButton")
    exportFrame:SetScript("OnDragStart", exportFrame.StartMoving)
    exportFrame:SetScript("OnDragStop", exportFrame.StopMovingOrSizing)

    exportFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    local title = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("Rematch Battle Data")

    local hint = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", title, "BOTTOM", 0, -6)
    hint:SetText("Ctrl+A, Ctrl+C to copy everything")

    local close = CreateFrame("Button", nil, exportFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)

    local scroll = CreateFrame("ScrollFrame", "RematchBattleDataScrollFrame", exportFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 24, -58)
    scroll:SetPoint("BOTTOMRIGHT", -42, 48)

    exportEditBox = CreateFrame("EditBox", nil, scroll)
    exportEditBox:SetMultiLine(true)
    exportEditBox:SetAutoFocus(false)
    exportEditBox:SetFontObject(ChatFontNormal)
    exportEditBox:SetWidth(676)
    exportEditBox:SetTextInsets(4, 4, 4, 4)
    exportEditBox:SetScript("OnEscapePressed", function()
        exportFrame:Hide()
    end)
    exportEditBox:SetScript("OnTextChanged", function(self)
        scroll:UpdateScrollChildRect()
    end)
    scroll:SetScrollChild(exportEditBox)

    local selectAll = CreateFrame("Button", nil, exportFrame, "UIPanelButtonTemplate")
    selectAll:SetSize(120, 24)
    selectAll:SetPoint("BOTTOMLEFT", 24, 16)
    selectAll:SetText("Select All")
    selectAll:SetScript("OnClick", function()
        exportEditBox:SetFocus()
        exportEditBox:HighlightText()
    end)

    local currentButton = CreateFrame("Button", nil, exportFrame, "UIPanelButtonTemplate")
    currentButton:SetSize(130, 24)
    currentButton:SetPoint("LEFT", selectAll, "RIGHT", 8, 0)
    currentButton:SetText("Current Battle")
    currentButton:SetScript("OnClick", function()
        exportEditBox:SetText(buildExport(current or lastBattle))
        exportEditBox:SetCursorPosition(0)
    end)

    local lastButton = CreateFrame("Button", nil, exportFrame, "UIPanelButtonTemplate")
    lastButton:SetSize(120, 24)
    lastButton:SetPoint("LEFT", currentButton, "RIGHT", 8, 0)
    lastButton:SetText("Last Battle")
    lastButton:SetScript("OnClick", function()
        exportEditBox:SetText(buildExport(lastBattle))
        exportEditBox:SetCursorPosition(0)
    end)

    local refreshButton = CreateFrame("Button", nil, exportFrame, "UIPanelButtonTemplate")
    refreshButton:SetSize(100, 24)
    refreshButton:SetPoint("LEFT", lastButton, "RIGHT", 8, 0)
    refreshButton:SetText("Refresh")
    refreshButton:SetScript("OnClick", function()
        exportEditBox:SetText(buildExport(current or lastBattle))
        exportEditBox:SetCursorPosition(0)
    end)

    exportFrame:Hide()
end

function module:Show(which)
    ensureExportFrame()

    local data
    if which == "live" then
        data = current or lastBattle
    else
        data = lastBattle or current
    end

    exportEditBox:SetText(buildExport(data))
    exportEditBox:SetCursorPosition(0)
    exportFrame:Show()
end

function module:GetCurrent()
    return current
end

function module:GetLast()
    return lastBattle
end

function module:GetExport(which)
    local data = which == "live" and current or (lastBattle or current)
    return buildExport(data)
end

function module:Clear()
    current = nil
    lastBattle = nil
end

SLASH_REMATCHBATTLEDATA1 = "/rbd"
SlashCmdList.REMATCHBATTLEDATA = function(msg)
    msg = (msg or ""):lower():trim()

    if msg == "clear" then
        module:Clear()
        print("|cff33ff99Rematch Battle Data:|r cleared.")
    elseif msg == "live" then
        module:Show("live")
    else
        module:Show("last")
    end
end

eventFrame:RegisterEvent("PET_BATTLE_OPENING_START")
eventFrame:RegisterEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE")
eventFrame:RegisterEvent("PET_BATTLE_PET_CHANGED")
eventFrame:RegisterEvent("PET_BATTLE_OVER")
eventFrame:RegisterEvent("PET_BATTLE_CLOSE")
eventFrame:RegisterEvent("CHAT_MSG_PET_BATTLE_COMBAT_LOG")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PET_BATTLE_OPENING_START" then
        -- Battle data is not always fully populated on the exact opening event.
        C_Timer.After(0, function()
            if C_PetBattles.IsInBattle() then
                startBattle()
                updateBattleButton()
            end
        end)

    elseif event == "CHAT_MSG_PET_BATTLE_COMBAT_LOG" then
        appendCombatLog(...)

    elseif event == "PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE" then
        takeSnapshot("ROUND PLAYBACK COMPLETE")
        updateBattleButton()

    elseif event == "PET_BATTLE_PET_CHANGED" then
        takeSnapshot("PET CHANGED")
        updateBattleButton()

    elseif event == "PET_BATTLE_OVER" then
        updateBattleResult()
        takeSnapshot("BATTLE OVER")
        updateBattleButton()

    elseif event == "PET_BATTLE_CLOSE" then
        finishBattle()
        updateBattleButton()
    end
end)

-- Create/update the battle button after login and whenever this file loads while
-- already inside a pet battle.
C_Timer.After(0, function()
    updateBattleButton()
end)
