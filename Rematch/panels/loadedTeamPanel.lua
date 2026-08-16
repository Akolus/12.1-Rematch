local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.loadedTeamPanel = rematch.frame.LoadedTeamPanel
rematch.frame:Register("loadedTeamPanel")

function rematch.loadedTeamPanel:Update()
    -- if loaded team is not a valid team, unload it
    if settings.currentTeamID and not rematch.savedTeams[settings.currentTeamID] then
        settings.currentTeamID = nil
    end
    local teamID = settings.currentTeamID
    local team = rematch.savedTeams[teamID]
    self.teamID = teamID
    self.TeamButton.teamID = teamID

    local isPetLeveling
    for i=1,3 do
        if rematch.loadouts:GetSpecialSlotType(i)=="leveling" then
            isPetLeveling = true
            break
        end
    end

    -- PreferencesFrame is only shown if Show Extra Preferences Button enabled and a leveling slot is loaded
    if settings.ShowLoadedTeamPreferences and isPetLeveling then
        self.PreferencesFrame:Show()
        self.TeamButton:SetPoint("TOPLEFT",self.PreferencesFrame,"TOPRIGHT",2,0)
        if settings.PreferencesPaused then -- if preferences paused, red X version of blue gear icon
            self.PreferencesFrame.PreferencesButton:SetIcon("Interface\\AddOns\\Rematch\\textures\\badges-borderless",0.87890625,0.99609375,0.12890625,0.24609375)
        else -- preferences are not paused, regular blue gear icon
            self.PreferencesFrame.PreferencesButton:SetIcon("Interface\\AddOns\\Rematch\\textures\\badges-borderless",0.75390625,0.87109375,0.12890625,0.24609375)
        end
    else
        self.PreferencesFrame:Hide()
        self.TeamButton:SetPoint("TOPLEFT")
    end

    if teamID=="loadonly" then -- for loadonly, display notes only if team has notes
        if rematch.savedTeams.loadonly.notes then
            self.NotesFrame:Show()
            self.NotesFrame.NotesButton:SetIcon("Interface\\AddOns\\Rematch\\textures\\badges-borderless",0.62890625,0.74609375,0.12890625,0.24609375)
            self.TeamButton:SetPoint("TOPRIGHT",self.NotesFrame,"TOPLEFT",-2,0)
        else
            self.NotesFrame:Hide()
            self.TeamButton:SetPoint("TOPRIGHT")
        end
        self.TeamButton.Name:SetText(rematch.savedTeams.loadonly.name)
        self.TeamButton.Favorite:Hide()
    elseif teamID=="counter" then -- for counter, name team after target it's countering (if applicable)
        self.NotesFrame:Hide()
        self.TeamButton:SetPoint("TOPRIGHT")
        local name
        if team.targets and #team.targets==1 then -- this is a counter of a specific target
            name = format(L["Counter to %s"],rematch.utils:GetFormattedTargetName(team.targets[1]))
        else
            name = rematch.utils:GetFormattedTeamName(teamID) or BATTLE_PET_SLOTS
        end
        self.TeamButton.Name:SetText(name)
        self.TeamButton.Favorite:Hide()
    elseif teamID then -- this is likely a user team
        -- NotesFrame is always shown if a team is loaded
        self.NotesFrame:Show()
        if rematch.savedTeams[teamID].notes then -- team has notes, show normal note icon
            self.NotesFrame.NotesButton:SetIcon("Interface\\AddOns\\Rematch\\textures\\badges-borderless",0.62890625,0.74609375,0.12890625,0.24609375)
        else -- team doesn't have notes, show the icon with green + symbol to add a note
            self.NotesFrame.NotesButton:SetIcon("Interface\\AddOns\\Rematch\\textures\\badges-borderless",0.25390625,0.37109375,0.62890625,0.74609375)
        end
        self.TeamButton:SetPoint("TOPRIGHT",self.NotesFrame,"TOPLEFT",-2,0)
        self.TeamButton.Name:SetText(rematch.utils:GetFormattedTeamName(teamID))
        self.TeamButton.Favorite:SetShown(team.favorite and true or false)
    else -- no team is loaded
        self.NotesFrame:Hide()
        self.TeamButton:SetPoint("TOPRIGHT")
        self.TeamButton.Name:SetText(BATTLE_PET_SLOTS)
        self.TeamButton.Favorite:Hide()
    end
end

function rematch.loadedTeamPanel:BlingTeam()
    self:Update()
    self.TeamButton.Bling:Show()
end

function rematch.loadedTeamPanel:OnShow()
    rematch.events:Register(self,"REMATCH_TEAM_LOADED",self.BlingTeam,self)
end

function rematch.loadedTeamPanel:OnHide()
    rematch.events:Unregister(self,"REMATCH_TEAM_LOADED")
end

--[[ TeamButton]]

function rematch.loadedTeamPanel.TeamButton:OnEnter()
    rematch.textureHighlight:Show(self.Back)
    if not settings.HideTruncatedTooltips and self.Name:IsTruncated() then
        rematch.tooltip:ShowSimpleTooltip(self,nil,self.Name:GetText() or "","BOTTOM",self.Name,"TOP",0,-4,true)
    end
end

function rematch.loadedTeamPanel.TeamButton:OnLeave()
    rematch.textureHighlight:Hide()
    rematch.tooltip:Hide()
end

function rematch.loadedTeamPanel.TeamButton:OnMouseDown()
    rematch.textureHighlight:Hide()
end

function rematch.loadedTeamPanel.TeamButton:OnMouseUp()
    if self:IsMouseMotionFocus() then
        rematch.textureHighlight:Show(self.Back)
    end
end

function rematch.loadedTeamPanel.TeamButton:OnClick(button)
    if button=="RightButton" and self.teamID then
        rematch.menus:Show("LoadedTeamMenu",self,self.teamID,"cursor")
    elseif self.teamID then
        -- if reloading a random counter team, update team with a new set of random pets
        if self.teamID=="counter" then
            -- if no recent target, use the one saved in the last counter team, if any (it's ok if nil; a full random chosen then)
            local npcID = rematch.targetInfo.recentTarget or (rematch.savedTeams.counter.targets and rematch.savedTeams.counter.targets[1])
            rematch.randomPets:BuildCounterTeam(npcID)
        end
        rematch.loadTeam:LoadTeamID(self.teamID)
    end
end

--[[ NotesFrame ]]

function rematch.loadedTeamPanel.NotesFrame.NotesButton:OnEnter()
    rematch.cardManager:OnEnter(rematch.notes,self,self:GetParent():GetParent().teamID)
end

function rematch.loadedTeamPanel.NotesFrame.NotesButton:OnLeave()
    rematch.cardManager:OnLeave(rematch.notes,self,self:GetParent():GetParent().teamID)
end

function rematch.loadedTeamPanel.NotesFrame.NotesButton:OnClick(button)
    local teamID = self:GetParent():GetParent().teamID
    rematch.cardManager:OnClick(rematch.notes,self,teamID)
    if teamID and rematch.savedTeams[teamID] and not rematch.savedTeams[teamID].notes then
        rematch.notes:SetFocus() -- if no existing notes, set focus to start writing new one
    end
end

--[[ PreferencesFrame ]]

function rematch.loadedTeamPanel.PreferencesFrame.PreferencesButton:OnEnter()
    rematch.tooltip:ShowSimpleTooltip(self,L["Leveling Preferences"],rematch.preferences:GetTooltipBody())
end

function rematch.loadedTeamPanel.PreferencesFrame.PreferencesButton:OnLeave()
    rematch.tooltip:Hide()
end

function rematch.loadedTeamPanel.PreferencesFrame.PreferencesButton:OnClick(button)
    if button=="RightButton" then -- right click pauses/unpauses preferences
        rematch.preferences:TogglePause()
    else -- left click opens current preferences dialog to change preferences
        local teamID = settings.currentTeamID
        local groupID = teamID and rematch.savedTeams[teamID] and rematch.savedTeams[teamID].groupID
        rematch.dialog:ToggleDialog("CurrentPreferences",{teamID=teamID,groupID=groupID})
    end
end
