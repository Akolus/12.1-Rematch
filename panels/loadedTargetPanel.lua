local _,rematch = ...

local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.loadedTargetPanel = rematch.frame.LoadedTargetPanel
rematch.frame:Register("loadedTargetPanel")

rematch.events:Register(rematch.loadedTargetPanel,"PLAYER_LOGIN",function(self)
    self.BigLoadSaveButton.Text:SetFontObject(GameFontNormal)
    self.MediumLoadButton.Text:SetFontObject(GameFontNormal)
    self.MediumLoadButton:SetText(L["Load"])
    self.SmallRandomButton.tooltipTitle = L["Load Random Pets"]
    self.SmallRandomButton.tooltipBody = L["Load a set of random high level pets. If the recent target's pets are known, random pets are preferred if they are strong vs and tough vs the opponent pets."]
    self.SmallTeamsButton.tooltipTitle = L["Edit Target"]
    self.SmallTeamsButton.tooltipBody = L["Add or remove teams from this target, or change the order of teams for this target."]
    self.SmallSaveButton.tooltipTitle = L["Save New Team"]
    self.SmallSaveButton.tooltipBody = L["Create a new team for this target with the currently loaded pets."]
end)

function rematch.loadedTargetPanel:Configure()
    if rematch.layout:GetSubview()=="target" then -- in a "mini" target view like minimized or one- or two-panel view
        self.Badge:Hide()
        self.Name:Hide()
        self.Underline:Hide()
        self.ClearButton:Hide()
        -- if mini target panel being shown, then switch to current npcID instead of recent target in bigger target panel
        self.blingNextUpdate = true -- always bling when mini target panel shown
        rematch.targetInfo.recentTarget = rematch.targetInfo.currentTarget
    else
        self.Badge:Show()
        self.Name:Show()
        self.Underline:Show()
    end
end

function rematch.loadedTargetPanel:Update()
    if self.npcID ~= rematch.targetInfo.recentTarget or not self.teamIndex then
        self.teamIndex = 1 -- if target has changed, reset teamIndex to first team of a target
    end
    self.npcID = rematch.targetInfo.recentTarget
    self.teamID = nil -- FillAllyTeam will set this

    local isMini = rematch.layout:GetSubview()=="target"
    local right = -8 -- offset from right for name/underline/clear

    -- for both mini targets and normal, display portrait if there's a recent target
    if self.npcID then
        local targetNpcID = UnitExists("target") and rematch.targetInfo:GetUnitNpcID("target")
        if targetNpcID and targetNpcID==self.npcID then -- we are actually targeting this, use unit portrait
            self.Portrait.npcID = self.npcID
            SetPortraitTexture(self.Portrait.Texture,"target")
        elseif self.Portrait.npcID~=self.npcID then -- otherwise use displayID portrait from the npcID if not actual recent target (that's already drawn)
            local displayID = rematch.targetInfo:GetNpcDisplayID(self.npcID)
            if displayID then
                SetPortraitTextureFromCreatureDisplayID(self.Portrait.Texture,displayID)
            end
        end
        self.Portrait:Show()

        local isSaved = rematch.savedTargets[self.npcID]
        local isWild = rematch.targetInfo:IsWildPet(self.npcID)
        local isNotable = rematch.targetInfo:IsNotable(self.npcID) or isWild

        if isMini then -- the mini target panel only displays ally team regardless if there's an enemy to show (no room)
            self.EnemyTeam:Hide()
            self.AllyTeam:SetPoint("LEFT",self.Portrait,"RIGHT",22,0)
            self.AllyTeam:Show()
            self:FillAllyTeam()
        elseif not isSaved and not isNotable then
            self.EnemyTeam:Hide()
            self.AllyTeam:Hide()
        elseif not isSaved and isNotable then
            self.EnemyTeam:Show()
            self.AllyTeam:Hide()
            self:FillEnemyTeam()
        elseif isSaved and not isNotable then
            self.EnemyTeam:Hide()
            self.AllyTeam:SetPoint("LEFT",self.Portrait,"RIGHT",22,0)
            self.AllyTeam:Show()
            self:FillAllyTeam()
        elseif isSaved and isNotable then
            self.EnemyTeam:Show()
            self.AllyTeam:SetPoint("LEFT",self.EnemyTeam,"RIGHT",20,0)
            self.AllyTeam:Show()
            self:FillEnemyTeam()
            self:FillAllyTeam()
        end

        -- display buttons based on whether target is notable or saved
        if isMini then -- for mini target panel which only displays for targets with a saved team, just show big load button
            self.BigLoadSaveButton:Show()
            self:SetBigLoadSaveButton(C.BUTTON_MODE_LOAD)
            self.MediumLoadButton:Hide()
            self.SmallRandomButton:Hide()
            self.SmallTeamsButton:Hide()
            self.SmallSaveButton:Hide()
        elseif not isSaved then -- if not saved, notable or not, show big save button and small teams button
            self.MediumLoadButton:Hide()
            self.SmallSaveButton:Hide()
            self.BigLoadSaveButton:Show()
            self:SetBigLoadSaveButton(C.BUTTON_MODE_SAVE)
            self.SmallRandomButton:Show()
            self.SmallTeamsButton:Show()
            self.SmallRandomButton:SetPoint("TOPRIGHT",-3,-3)
            right = right - (24-3) - (24-2)
        elseif not isNotable then -- if saved and not notable, big load button and two small save and teams button in topright
            self.MediumLoadButton:Hide()
            self.BigLoadSaveButton:Show()
            self:SetBigLoadSaveButton(C.BUTTON_MODE_LOAD)
            self.SmallRandomButton:Show()
            self.SmallTeamsButton:Show()
            self.SmallRandomButton:SetPoint("TOPRIGHT",-3,-3)
            self.SmallSaveButton:Show()
            right = right - (24-3) - (24-2) - (24-2)
        elseif isNotable then -- if saved and notable, then medium load button and two small save and teams buttons
            self.BigLoadSaveButton:Hide()
            self.MediumLoadButton:Show()
            self.SmallRandomButton:Show()
            self.SmallTeamsButton:Show()
            self.SmallRandomButton:SetPoint("TOPRIGHT",self.MediumLoadButton,"TOPLEFT",2,0)
            self.SmallSaveButton:Show()
            right = right - (24-3) - (24-2) - (24-2) - (68-2)
        end

    else
        self.Portrait:Hide()
        self.BigLoadSaveButton:Hide()
        self.MediumLoadButton:Hide()
        self.SmallSaveButton:Hide()
        self.SmallTeamsButton:Hide()
        self.SmallRandomButton:Hide()
        self.AllyTeam:Hide()
        self.EnemyTeam:Hide()
    end

    -- if an expanded view, update name and top matter
    if not isMini then
        self.Name:SetPoint("TOPRIGHT",right-14,-8)
        self.Underline:SetPoint("TOPRIGHT",right,-22)
        self.ClearButton:SetPoint("TOPRIGHT",right+2,-4)
        if self.npcID then
            self.Name:SetText(rematch.utils:GetFormattedTargetName(self.npcID))
            self.ClearButton:Show()
        else
            self.Name:SetText(L["No Target"])
            self.Portrait:Hide()
            self.ClearButton:Hide()
        end
    end

    -- finally, if blingNextUpdate is true, then bling the target
    if self.blingNextUpdate then
        self.Bling:Show()
        self.blingNextUpdate = nil
    end

end

-- for the shared load/save button, set for loading or saving
function rematch.loadedTargetPanel:SetBigLoadSaveButton(mode)
    local button = self.BigLoadSaveButton
    button.mode = mode
    if mode==C.BUTTON_MODE_LOAD then
        button:SetText(L["Load"])
        button.tooltipTitle = L["Load Team"]
        button.tooltipBody = L["Load the team saved to this target."]
    elseif mode==C.BUTTON_MODE_SAVE then
        button:SetText(L["Save"])
        button.tooltipTitle = L["Save New Team"]
        button.tooltipBody = L["Create a new team for this target with the currently loaded pets."]
    end
end

-- fills the enemy team with the target's pets, there can be 1 to 3 of them if this is called
function rematch.loadedTargetPanel:FillEnemyTeam()
    local npcID = self.npcID
    local numPets = rematch.targetInfo:GetNumPets(npcID)
    -- team border
    local coords = C.PET_BORDER_TEXCOORDS[C.TEAM_SIZE_NORMAL][numPets]
    if coords then
        self.EnemyTeam.Border:SetTexCoord(coords[1],coords[2],coords[3],coords[4])
        self.EnemyTeam:SetSize(coords[5],coords[6])
    end
    -- fill pets
    local pets = rematch.targetInfo:GetNpcPets(npcID)
    for i,petID in ipairs(pets) do
        local petInfo = rematch.petInfo:Fetch(petID)
        self.EnemyTeam.Pets[i].petID = petID
        self.EnemyTeam.Pets[i]:SetTexture(petInfo.icon)
        self.EnemyTeam.Pets[i]:SetDesaturated(false)
        self.EnemyTeam.Pets[i]:Show()
    end
    for i=#pets+1,3 do
        self.EnemyTeam.Pets[i]:Hide()
    end
end

-- fills the ally team with the user's pets from the team of the current teamIndex
function rematch.loadedTargetPanel:FillAllyTeam()
    local npcID = self.npcID
    local teams = rematch.savedTargets[npcID]
    if teams and #teams>0 then
        self.teamIndex = max(1,min(self.teamIndex,#teams))
        -- handle prev/next buttons
        self.AllyTeam.PrevTeamButton:SetShown(#teams>1)
        self.AllyTeam.NextTeamButton:SetShown(#teams>1)
        self.AllyTeam.PrevTeamButton:SetEnabled(self.teamIndex~=1)
        self.AllyTeam.NextTeamButton:SetEnabled(self.teamIndex~=#teams)
        -- team border
        local coords = C.PET_BORDER_TEXCOORDS[C.TEAM_SIZE_NORMAL][3] -- user teams always have 3 pets (even if not all valid)
        self.AllyTeam.Border:SetTexCoord(coords[1],coords[2],coords[3],coords[4])
        self.AllyTeam:SetSize(coords[5],coords[6])
        -- fill pets
        self.teamID = teams[self.teamIndex]
        local team = rematch.savedTeams[self.teamID]
        for i,petID in ipairs(team.pets) do
            local petInfo = rematch.petInfo:Fetch(petID)
            self.AllyTeam.Pets[i].teamID = self.teamID
            self.AllyTeam.Pets[i].petID = petID
            self.AllyTeam.Pets[i]:SetTexture(petInfo.icon)
            self.AllyTeam.Pets[i]:SetDesaturated(petInfo.idType=="species")
            self.AllyTeam.Pets[i]:Show()
            if petInfo.isDead then
                self.AllyTeam.Status[i]:SetTexCoord(0,0.3125,0,0.625)
                self.AllyTeam.Status[i]:Show()
            elseif petInfo.isInjured then
                self.AllyTeam.Status[i]:SetTexCoord(0.3125,0.625,0,0.625)
                self.AllyTeam.Status[i]:Show()
            else
                self.AllyTeam.Status[i]:Hide()
            end
        end
    end
end

function rematch.loadedTargetPanel:OnShow()
    rematch.events:Register(self,"REMATCH_TARGET_CHANGED",self.SetTarget)
end

function rematch.loadedTargetPanel:OnHide()
    rematch.events:Unregister(self,"REMATCH_TARGET_CHANGED")
end

-- if npcID is nill, set to current target; otherwise set to given npcID
function rematch.loadedTargetPanel:SetTarget(npcID,bling)
    if not npcID then -- if no npcID given this was likely from a targeting change, show team's pets first
        npcID = rematch.targetInfo.currentTarget
    else -- if npcID given this is likely from the targetsPanel, show target's pets first
        if type(npcID)=="string" then
            npcID = rematch.targetInfo:GetNpcID(npcID) -- if "target:123", get the numeric npcID
        end
    end
    if npcID then
        rematch.targetInfo:SetRecentTarget(npcID)
    end
    -- if settarget wanted to bling (from targetsPanel list) or this is a target with a saved team, bling it
    if bling or rematch.savedTargets[npcID] then
        self.blingNextUpdate = true
    end
    self:Update()
    if rematch.targetsPanel:IsVisible() then
        rematch.targetsPanel:Update()
    end
end

-- use this to clear target (SetTarget(nil) will just pick up current target)
function rematch.loadedTargetPanel:ClearTarget()
    rematch.targetInfo:SetRecentTarget(nil)
    self:Update()
end

-- for target subviews, target should only be shown if the target has a saved team
function rematch.loadedTargetPanel:ShouldShowTarget()
    local npcID = UnitExists("target") and rematch.targetInfo:GetUnitNpcID("target")
    if npcID and rematch.savedTargets[npcID] then
        local teams = rematch.savedTargets[npcID]
        if #teams==1 and teams[1]==settings.currentTeamID then
            return false -- if this target has one team that's already loaded, don't show target
        else
            return true -- if this target has more than one team or it's not already loaded, show target
        end
    end
    return false
end

function rematch.loadedTargetPanel.ClearButton:OnClick()
    self:GetParent():ClearTarget()
end

function rematch.loadedTargetPanel.AllyTeam.PrevTeamButton:OnClick()
    self:GetParent():GetParent().teamIndex = self:GetParent():GetParent().teamIndex - 1
    self:GetParent():GetParent():Update()
end

function rematch.loadedTargetPanel.AllyTeam.NextTeamButton:OnClick()
    self:GetParent():GetParent().teamIndex = self:GetParent():GetParent().teamIndex + 1
    self:GetParent():GetParent():Update()
end

-- click of the big load (or save) button
function rematch.loadedTargetPanel.BigLoadSaveButton:OnClick(button)
    local teamID = self:GetParent().teamID
    if self.mode==C.BUTTON_MODE_LOAD and teamID then
        rematch.loadTeam:LoadTeamID(self:GetParent().teamID)
    elseif self.mode==C.BUTTON_MODE_SAVE then
        rematch.loadedTargetPanel:SaveTeamForNpcID(self:GetParent().npcID)
    end
end

-- click of the smaller load button
function rematch.loadedTargetPanel.MediumLoadButton:OnClick(button)
    rematch.loadTeam:LoadTeamID(self:GetParent().teamID)
end

-- click of green paw to set teams for the target
function rematch.loadedTargetPanel.SmallTeamsButton:OnClick(button)
    local npcID = self:GetParent().npcID
    if npcID then
        rematch.targetMenu:SetTeams(npcID)
    end
end

function rematch.loadedTargetPanel.SmallRandomButton:OnClick(button)
    local npcID = self:GetParent().npcID
    if npcID then
        rematch.randomPets:BuildCounterTeam(npcID)
        rematch.loadTeam:LoadTeamID("counter")
    end
end

function rematch.loadedTargetPanel.SmallSaveButton:OnClick(button)
    rematch.loadedTargetPanel:SaveTeamForNpcID(self:GetParent().npcID)
end

function rematch.loadedTargetPanel:SaveTeamForNpcID(npcID)
    if npcID then
        rematch.saveDialog:SidelineLoadouts()
        rematch.savedTeams.sideline.name = rematch.savedTeams:GetUniqueName(rematch.targetInfo:GetNpcName(npcID))
        rematch.savedTeams.sideline.targets = {npcID}
        rematch.dialog:ShowDialog("SaveTeam",{saveMode=C.SAVE_MODE_SAVEAS})
    end
end