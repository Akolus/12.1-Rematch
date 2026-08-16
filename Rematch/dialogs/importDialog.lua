local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.importDialog = {}

rematch.events:Register(rematch.importDialog,"PLAYER_LOGIN",function(self)

    rematch.dialog:Register("ImportTeams",{
        title = L["Import Teams"],
        accept = SAVE,
        cancel = CANCEL,
        other = L["Load"],
        width = 290,
        minHeight = 232,
        layouts = {
            Default = {"Text","MultiLineEditBox","CheckButton","GroupSelect"},
            Invalid = {"Text","MultiLineEditBox","CheckButton","Feedback"},
            SingleTeam = {"Text","MultiLineEditBox","CheckButton","TeamWithAbilities","GroupSelect"},
            SingleTeamConflict = {"Text","MultiLineEditBox","CheckButton","GroupSelect","TeamWithAbilities","Feedback","ConflictRadios"},
            MultiTeam = {"Text","MultiLineEditBox","CheckButton","GroupSelect","ListData"},
            MultiTeamConflict = {"Text","MultiLineEditBox","CheckButton","GroupSelect","ListData","Feedback","ConflictRadios"},
            MultiGroup = {"Text","MultiLineEditBox","CheckButton","ListData"},
            MultiGroupConflict = {"Text","MultiLineEditBox","CheckButton","ListData","Feedback","ConflictRadios"},
            GroupPick = {"GroupPicker"}
        },
        conditions = {
            CheckButton = function(self,info,subject) -- only show breed checkbutton if there's a breed source
                return rematch.breedInfo:GetBreedSource() and true or false
            end,
        },
        refreshFunc = function(self,info,subject,firstRun)
            if firstRun then
                self.Text:SetText(L["Press Ctrl+V to paste from clipboard"])
                self.CheckButton:SetText(L["Prioritize Breed For Imports"])
                self.CheckButton.Check.tooltipBody = L["When importing teams, prefer pets that match the breed even if higher levels of other breeds are available."]
                self.CheckButton:SetChecked(settings.PrioritizeBreedOnImport)
                self.MultiLineEditBox:SetText("")
                if not settings.LastSelectedGroup or not rematch.savedGroups[settings.LastSelectedGroup] then
                    settings.LastSelectedGroup = "group:none"
                end
                if not settings.ImportRememberOverride then
                    settings.ImportConflictOverwrite = false
                end
                self.ConflictRadios:Update()
                self.GroupPicker:SetReturn("Default")
                rematch.importDialog.UpdateLayout(self)
            end
            self.GroupSelect:Fill(settings.LastSelectedGroup)
            local openLayout = rematch.dialog:GetOpenLayout()
            rematch.dialog.OtherButton:SetEnabled(openLayout=="SingleTeam" or openLayout=="SingleTeamConflict")
            rematch.dialog.OtherButton.tooltipTitle = L["Only Load This Team"]
            rematch.dialog.OtherButton.tooltipBody = L["This will only load the team and not save it.\n\nThis is for importing teams you intend to use just once. You can still save the team afterwards if you want to keep it."]
        end,
        changeFunc = function(self,info,subject)
            settings.PrioritizeBreedOnImport = self.CheckButton:GetChecked()
            rematch.importDialog.UpdateLayout(self)
        end,
        acceptFunc = function(self,info,subject)
            rematch.teamStrings:Import(self.MultiLineEditBox:GetText())
        end,
        otherFunc = function(self,info,subject)
            rematch.teamStrings:LoadOnly(self.MultiLineEditBox:GetText())
        end
    })

end)

-- this updates the dialog to the appropriate layout from an analysis of the import
-- note: self is the canvas (rematch.dialog.Canvas) and not rematch.import here
function rematch.importDialog:UpdateLayout()
    local import = self.MultiLineEditBox:GetText()
    local numGroups,numTeams,numConflicts,numBad = rematch.teamStrings:AnalyzeImport(import)
    local isEmpty = (numGroups+numTeams+numConflicts+numBad)==0
    local isInvalid = (numGroups+numTeams)==0 and numBad>0
    -- change layout depending on analysis of import string
    local openLayout = rematch.dialog:GetOpenLayout()
    if isEmpty then
        if openLayout~="Default" then
            self.GroupPicker:SetReturn("Default")
            rematch.dialog:ChangeLayout("Default")
        end
    elseif isInvalid then
        if openLayout~="Invalid" then
            self.Feedback:Set("warning",L["This is not a valid team import"])
            rematch.dialog:ChangeLayout("Invalid")
        end
    elseif numGroups>0 and numConflicts==0 then
        self.ListData:Set({{L["Groups to import"],numGroups},{L["Teams to import"],numTeams}})
        if openLayout~="MultiGroup" then
            rematch.dialog:ChangeLayout("MultiGroup")
        end
    elseif numGroups>0 and numConflicts>0 then
        self.ListData:Set({{"MultiGroupConflict",0}})
        self.ListData:Set({{L["Groups to import"],numGroups},{L["Teams to import"],numTeams},{L["Names already used"],numConflicts}})
        if openLayout~="MultiGroupConflict" then
            self.Feedback:Set("warning",L["Some teams or groups have names already used"])
            rematch.dialog:ChangeLayout("MultiGroupConflict")
        end
    elseif numTeams==1 and numConflicts==0 then
        if openLayout~="SingleTeam" then
            self.GroupPicker:SetReturn("SingleTeam")
            rematch.dialog:ChangeLayout("SingleTeam")
        end
        rematch.teamStrings:SidelineTeamString(import,"group:none")
        self.TeamWithAbilities:FillFromTeamID("sideline")
    elseif numTeams==1 and numConflicts>0 then
        if openLayout~="SingleTeamConflict" then
            self.GroupPicker:SetReturn("SingleTeamConflict")
            self.Feedback:Set("warning",L["This team has the same name as an existing team"])
            rematch.dialog:ChangeLayout("SingleTeamConflict")
        end
        rematch.teamStrings:SidelineTeamString(import,"group:none")
        self.TeamWithAbilities:FillFromTeamID("sideline")
    elseif numTeams>1 and numConflicts==0 then
        self.ListData:Set({{"MultiTeam",0}})
        self.ListData:Set({{L["Teams to import"],numTeams}})
        if openLayout~="MultiTeam" then
            self.GroupPicker:SetReturn("MultiTeam")
            rematch.dialog:ChangeLayout("MultiTeam")
        end
    elseif numTeams>1 and numConflicts>0 then
        self.ListData:Set({{L["Teams to import"],numTeams},{L["Teams with existing name"],numConflicts}})
        if openLayout~="MultiTeamConflict" then
            self.GroupPicker:SetReturn("MultiTeamConflict")
            self.Feedback:Set("warning",L["Some teams have the same name as existing teams"])
            rematch.dialog:ChangeLayout("MultiTeamConflict")
        end
    end
end