local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.bottombar = rematch.frame.BottomBar
rematch.frame:Register("bottombar")

rematch.events:Register(rematch.bottombar,"PLAYER_LOGIN",function(self)
    self.SummonButton:SetText(SUMMON)
    self.FindBattleButton:SetText(FIND_BATTLE)
    self.SaveAsButton:SetText(L["Save As"])
    self.SaveButton:SetText(SAVE)

    self.UseRematchCheckButton:SetText(L["Rematch"])
    self.UseRematchCheckButton.tooltipTitle = L["Remove Rematch From Journal"]
    self.UseRematchCheckButton.tooltipBody = L["Uncheck this to restore the default pet journal.\n\nYou can still use Rematch in its standlone window, accessed via key binding, /rematch command or from the Minimap button if enabled in options."]

    self.SummonButton.tooltipTitle = SUMMON
    self.SummonButton.tooltipBody = format("%s\n\n%s",BATTLE_PETS_SUMMON_TOOLTIP,L["You can also double-click a pet to summon or dismiss it."])
    self.FindBattleButton.tooltipTitle = FIND_BATTLE
    self.FindBattleButton.tooltipBody = BATTLE_PETS_FIND_BATTLE_TOOLTIP
    self.SaveAsButton.tooltipTitle = L["Save As..."]
    self.SaveAsButton.tooltipBody = L["Save the currently loaded pets to a new team."]
    self.SaveButton.tooltipTitle = SAVE
    self.SaveButton.tooltipBody = L["Quickly save the currently loaded pets and abilities to the loaded team."]
end)

function rematch.bottombar:Configure()
    local mode = rematch.layout:GetMode(C.CURRENT)
    local barWidth = self:GetWidth()
    if mode==3 then -- 3-panel mode: summon and find battle buttons match journal
        self.SummonButton:SetWidth(160)
        self.SummonButton:Show()
        self.SaveButton:SetWidth(140)
        self.SaveAsButton:SetWidth(140)
        self.FindBattleButton:SetWidth(140)
    elseif mode==2 then -- 2-panel mode: fit all four to fit
        local width = barWidth/4
        self.SummonButton:SetWidth(width)
        self.SummonButton:Show()
        self.SaveAsButton:SetWidth(width)
        self.SaveButton:SetWidth(width)
        self.FindBattleButton:SetWidth(width)
    elseif mode==1 then -- 1-panel mode: hide summon button, fit remaining 3 to fit
        local width = barWidth/3
        self.SummonButton:Hide()
        rematch.bottombar.SaveButton:SetWidth(width)
        rematch.bottombar.SaveAsButton:SetWidth(width)
        rematch.bottombar.FindBattleButton:SetWidth(width)
    end
    rematch.bottombar.UseRematchCheckButton:SetShown(mode==3 and rematch.journal:IsActive())
    rematch.bottombar.UseRematchCheckButton:SetChecked(true) -- always checked if journal view of rematch is visible
end

function rematch.bottombar:Update()
    -- update summon/dismiss panel button
    if rematch.petCard:IsVisible() and rematch.cardManager:IsCardLocked(rematch.petCard) then
        local petID = C_PetJournal.GetSummonedPetGUID()
        self.SummonButton:Enable()
        if rematch.petCard.petID==petID then
            self.SummonButton:SetText(PET_DISMISS)
            self.SummonButton.tooltipTitle = PET_DISMISS
        elseif rematch.petInfo:Fetch(rematch.petCard.petID).isOwned then
            self.SummonButton:SetText(BATTLE_PET_SUMMON)
            self.SummonButton.tooltipTitle = BATTLE_PET_SUMMON
        else
            self.SummonButton:Disable()
            self.SummonButton.tooltipTitle = BATTLE_PET_SUMMON
        end
    else
        self.SummonButton:Disable()
        self.SummonButton.tooltipTitle = BATTLE_PET_SUMMON
    end
    -- update find battle button
    if C_PetBattles.GetPVPMatchmakingInfo() then
        self.FindBattleButton:SetText(LEAVE_QUEUE)
    else
        self.FindBattleButton:SetText(FIND_BATTLE)
    end
    -- update save button (only enabled if a user team loaded)
    self.SaveButton:SetEnabled(rematch.savedTeams:IsUserTeam(settings.currentTeamID))
end

function rematch.bottombar:OnShow()
    rematch.events:Register(self,"PET_BATTLE_QUEUE_STATUS",self.PET_BATTLE_QUEUE_STATUS)
    rematch.events:Register(self,"REMATCH_TEAM_LOADED",self.Update)
end

function rematch.bottombar:OnHide()
    rematch.events:Unregister(self,"PET_BATTLE_QUEUE_STATUS")
    rematch.events:Unregister(self,"REMATCH_TEAM_LOADED")
end

function rematch.bottombar:PET_BATTLE_QUEUE_STATUS()
    rematch.frame:Update() -- need to update loadout slots as well as panel button
end

function rematch.bottombar.SummonButton:OnClick()
    self:GetScript("OnLeave")(self) -- force the mouse to leave to unhighlight
    if rematch.petCard.petID then
        C_PetJournal.SummonPetByGUID(rematch.petCard.petID)
        rematch.petCard:Hide()
    end
end

-- the "Save As" button summons a save dialog to potentially create a new team (if team renamed) or update some aspect of current
function rematch.bottombar.SaveAsButton:OnClick()
    rematch.saveDialog:SidelineLoadouts()
    -- if sidelining a loaded user team, add its teamID to subject
    if rematch.savedTeams:IsUserTeam(settings.currentTeamID) then
        rematch.dialog:ShowDialog("SaveTeam",{saveMode=C.SAVE_MODE_SAVEAS, teamID=settings.currentTeamID})
    else
        rematch.dialog:ShowDialog("SaveTeam",{saveMode=C.SAVE_MODE_SAVEAS})
    end
end

-- the "Save" button resaves the loaded team, potentially from a change in pets or abilities
function rematch.bottombar.SaveButton:OnClick()
    if not rematch.savedTeams:IsUserTeam(settings.currentTeamID) then
        return -- a user team is not loaded, do nothing
    end
    rematch.saveDialog:SidelineLoadouts()
    -- if pets are the same, immediately save the updates to the current team
    if rematch.utils:AreSame(rematch.savedTeams.sideline.pets,rematch.savedTeams[settings.currentTeamID].pets) then
        rematch.savedTeams[settings.currentTeamID] = rematch.savedTeams.sideline
        rematch.saveDialog:BlingLoadedTeam()
    else -- pets are different, confirm the save
        rematch.dialog:ShowDialog("SaveOverwrite",settings.currentTeamID)
    end
end

-- clicking the Rematch checkbutton on the bottombar means we're in journal mode; so always disabling.
-- there's another Rematch checkbutton on the PetJournal that does the opposite
function rematch.bottombar.UseRematchCheckButton:OnClick()
    self:SetChecked(true)
    rematch.settings.UseDefaultJournal = true
    rematch.frame:Hide()
    rematch.frame:SetParent(UIParent)
    PetJournal:Show()
    PetJournal_UpdatePetLoadOut() -- in case journal wasn't keeping up while rematch was doing stuff
end

function rematch.bottombar.FindBattleButton:OnClick()
    local queueState = C_PetBattles.GetPVPMatchmakingInfo()
    if queueState=="proposal" then
        C_PetBattles.DeclineQueuedPVPMatch()
    elseif queueState then
        C_PetBattles.StopPVPMatchmaking()
    else
        C_PetBattles.StartPVPMatchmaking()
    end
end