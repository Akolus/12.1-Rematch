local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.interact = {}

local lastInteract -- npcID that was last interacted
local pendingInteract -- if something targeting while mouseover/soft interact, the mode (C.INTERACT_PROMPT) waiting to run

-- priority list of settings if multiple enabled, only first one remains enabled
local interactPriority = {"InteractOnMouseover","InteractOnSoftInteract","InteractOnTarget"}

rematch.events:Register(rematch.interact,"PLAYER_LOGIN",function(self)

    -- subject is npcID, dialog with a target's team(s) and a Load button to load it
    rematch.dialog:Register("PromptToLoadDialog",{
        title = L["Prompt To Load"],
        accept = L["Load"],
        cancel = CANCEL,
        layout = {"Text","MultiTeam"},
        prompt = L["Load this team?"],
        refreshFunc = function(self,info,subject,firstRun)
            if firstRun then
                local name = rematch.utils:GetFormattedTargetName(subject)
                if not name or name==C.CACHE_RETRIEVING then
                    name = L["This target"]
                end
                self.Text:SetText(format(L["%s has a saved team"],name))
                self.MultiTeam:SetTeams(rematch.savedTargets:GetTeams(subject))
            end
        end,
        acceptFunc = function(self,info,subject)
            local teamID = self.MultiTeam:GetTeamID()
            if teamID then
                rematch.interact:LoadTeamID(teamID)
            end
        end
    })

    self:Update()
end)

-- registers/unregisters events based on interact settings
function rematch.interact:Update()

    -- only one interact can be possible at a time; priority mouseover > soft > target
    local foundInteract = false
    for _,var in ipairs(interactPriority) do
        if not settings[var] or foundInteract then
            settings[var] = C.INTERACT_NONE
        elseif settings[var]~=C.INTERACT_NONE then
            foundInteract = true
        end
    end

    -- all interacts register for target changes
    if not foundInteract then
        rematch.events:Unregister(self,"REMATCH_TARGET_CHANGED")
    else
        rematch.events:Register(self,"REMATCH_TARGET_CHANGED",self.REMATCH_TARGET_CHANGED)
    end
    -- Re-evaluate an already-targeted NPC when a team is created/imported/updated.
    -- This fixes imports made while standing at a dungeon pet-battle target.
    rematch.events:Register(self,"REMATCH_TEAMS_CHANGED",self.REMATCH_TEAMS_CHANGED)

    -- register for mouseover interact
    if settings.InteractOnMouseover==C.INTERACT_NONE then
        rematch.events:Unregister(self,"UPDATE_MOUSEOVER_UNIT")
    else
        rematch.events:Register(self,"UPDATE_MOUSEOVER_UNIT",self.UPDATE_MOUSEOVER_UNIT)
    end
    -- register for soft target interact
    if settings.InteractOnSoftInteract==C.INTERACT_NONE then
        rematch.events:Unregister(self,"PLAYER_SOFT_INTERACT_CHANGED")
    else
        rematch.events:Register(self,"PLAYER_SOFT_INTERACT_CHANGED",self.PLAYER_SOFT_INTERACT_CHANGED)
    end
end

-- returns true if something should happen with the given npcID
-- When teams are created/imported while the player is already targeting an NPC,
-- REMATCH_TARGET_CHANGED does not naturally fire again. Re-check the current target
-- after Rematch finishes rebuilding savedTargets so the newly imported team is noticed.
function rematch.interact:REMATCH_TEAMS_CHANGED()
    local npcID = rematch.targetInfo and rematch.targetInfo.currentTarget
    if not npcID then
        return
    end

    -- Allow the same target to be evaluated again now that its saved-team list changed.
    lastInteract = nil

    -- Run the normal target interaction path so Prompt/Window/Autoload behavior
    -- remains exactly the same as if the player had just targeted this NPC.
    self:REMATCH_TARGET_CHANGED()
end

function rematch.interact:ShouldInteract(npcID)
    if not npcID then
        return false -- not targeting anything, don't interact
    end
    if npcID==lastInteract and not settings.InteractAlways then
        return false -- already interacted with this target, don't interact
    end
    local teams = rematch.savedTargets[npcID]
    if not teams then
        return false -- no teams for this target, don't interact
    end
    if InCombatLockdown() then
        return false -- in combat (can't swap pets in combat), don't interact
    end
    local currentTeamID = settings.currentTeamID
    if settings.InteractAlways then
        local teams,index = rematch.savedTargets:GetTeams(npcID)
        if index and (settings.InteractAlwaysEvenLoaded or teams[index]~=currentTeamID) then
            return true -- if Interact Always enabled and a different team would load, interact
        end
    end
    if currentTeamID and tContains(teams,currentTeamID) then
        return false -- a team for this target is already loaded, don't interact
    end
    -- if we reached here, then there is a target with saved teams not already loaded, we should interact
    return true
end

-- call this instead of rematch.loadTeam:LoadTeamID() so it can handle the post-loading interact options
function rematch.interact:LoadTeamID(teamID)
    if settings.InteractShowAfterLoad and not rematch.frame:IsVisible() then
        rematch.events:Register(self,"REMATCH_TEAM_LOADED",self.AfterTeamLoaded)
    end
    rematch.loadTeam:LoadTeamID(teamID)
end

-- fired after a team loaded from an interaction; show the preferred window mode (can be Journal, Maximized or Minimized)
function rematch.interact:AfterTeamLoaded()
    if not rematch.frame:IsVisible() and settings.InteractShowAfterLoad then
        local anyInjured = false
        for i=1,3 do
            anyInjured = anyInjured or rematch.petInfo:Fetch((rematch.loadouts:GetLoadoutInfo(i))).isInjured
        end
        if anyInjured or not settings.InteractOnlyWhenInjured then
            rematch.frame:Toggle(true)
            -- if any pets were injured, flash their status
            for slot=1,3 do
                local petInfo = rematch.petInfo:Fetch(rematch.loadouts:GetLoadoutInfo(slot))
                if petInfo.isInjured then
                    if rematch.miniLoadoutPanel:IsVisible() then
                        rematch.miniLoadoutPanel.Loadouts[slot].InjuredFlash:Play()
                    else
                        rematch.loadoutPanel.Loadouts[slot].Pet.InjuredFlash:Play()
                    end
                end
            end
        end
    end
    rematch.events:Unregister(self,"REMATCH_TEAM_LOADED")
end

-- triggered when InteractOnTarget is not INTERACT_NONE and player's target changes
-- (rematch.targetInfo.currentTarget is the current numeric npcID targeted; nil for no target; nil for a player target)
function rematch.interact:REMATCH_TARGET_CHANGED()
    local npcID = rematch.targetInfo.currentTarget
    if not rematch.interact:ShouldInteract(npcID) then
        return
    end
    lastInteract = npcID
    local mode = pendingInteract
    if not mode or mode == C.INTERACT_NONE then
        if settings.InteractOnTarget and settings.InteractOnTarget ~= C.INTERACT_NONE then
            mode = settings.InteractOnTarget
        elseif settings.InteractOnSoftInteract and settings.InteractOnSoftInteract ~= C.INTERACT_NONE then
            mode = settings.InteractOnSoftInteract
        else
            mode = settings.InteractOnMouseover
        end
    end
    if mode == C.INTERACT_PROMPT then
        rematch.dialog:ShowDialog("PromptToLoadDialog",npcID)
    elseif mode == C.INTERACT_WINDOW and not rematch.frame:IsVisible() then
        rematch.frame:Toggle(true)
    elseif mode == C.INTERACT_AUTOLOAD then
        local teams,index = rematch.savedTargets:GetTeams(npcID)
        if index and teams[index] then
            rematch.interact:LoadTeamID(teams[index])
        end
    end
    pendingInteract = nil
end

-- triggered when InteractOnMouseover is not INTERACT_DONE and mouseover changes
function rematch.interact:UPDATE_MOUSEOVER_UNIT()
    local npcID = rematch.targetInfo:GetUnitNpcID("mouseover")
    if not rematch.interact:ShouldInteract(npcID) then
        return
    end
    -- special rule for mouseover interact: if current actual target is an npc with a saved team, don't react to mouseover
    -- for cases like darkmoon faire or garrison where multiple targets can be on screen at once
    local currentTarget = rematch.targetInfo.currentTarget
    if currentTarget and rematch.savedTargets[currentTarget] then
        pendingInteract = settings.InteractOnMouseover
        return
    end
    lastInteract = npcID
    if settings.InteractOnMouseover==C.INTERACT_PROMPT then
        rematch.dialog:ShowDialog("PromptToLoadDialog",npcID)
    elseif settings.InteractOnMouseover==C.INTERACT_WINDOW and not rematch.frame:IsVisible() then
        rematch.frame:Toggle(true)
    elseif settings.InteractOnMouseover==C.INTERACT_AUTOLOAD then
        local teams,index = rematch.savedTargets:GetTeams(npcID)
        if index and teams[index] then
            rematch.interact:LoadTeamID(teams[index])
        end
    end
end

function rematch.interact:PLAYER_SOFT_INTERACT_CHANGED(...)
    local npcID = rematch.targetInfo:GetUnitNpcID("softinteract")
    if not rematch.interact:ShouldInteract(npcID) then
        return
    end
    -- special rule for soft interact: if current actual target is an npc with a saved team, don't react to soft interact
    -- for cases like darkmoon faire or garrison where multiple targets can be on screen at once
    local currentTarget = rematch.targetInfo.currentTarget
    if currentTarget and rematch.savedTargets[currentTarget] then
        pendingInteract = settings.InteractOnSoftInteract
        return
    end
    lastInteract = npcID
    if settings.InteractOnSoftInteract==C.INTERACT_PROMPT then
        rematch.dialog:ShowDialog("PromptToLoadDialog",npcID)
    elseif settings.InteractOnSoftInteract==C.INTERACT_WINDOW and not rematch.frame:IsVisible() then
        rematch.frame:Toggle(true)
    elseif settings.InteractOnSoftInteract==C.INTERACT_AUTOLOAD then
        local teams,index = rematch.savedTargets:GetTeams(npcID)
        if index and teams[index] then
            rematch.interact:LoadTeamID(teams[index])
        end
    end
end