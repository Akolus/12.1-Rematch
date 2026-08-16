local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.teamMenu = {}
local tm = rematch.teamMenu

--[[ this is a place to hold common functions used across multiple team menus ]]

rematch.events:Register(rematch.teamMenu,"PLAYER_LOGIN",function(self)

    -- menu when you right-click a group in the team list
    local groupMenu = {
        {title=tm.GetGroupName},
        {text=L["Create New Group"], func=function(groupID) tm:EditGroup() end}, -- EditGroup needs nil to create new group
        {text=L["Edit Group"], func=tm.EditGroup},
        {text=L["Move Group"], func=tm.MoveGroup},
        {text=L["Delete Group"], isDisabled=tm.IsUndeletable, disabledTooltip=L["This is a system group that cannot be deleted."], func=tm.DeleteGroup},
        {text=L["Export Group"], func=tm.ExportGroup},
        {spacer=true},
        {text=L["Import Teams"], func=tm.ImportGroupTeams},
        {text=L["Delete Teams"], isDisabled=tm.IsGroupEmpty, disabledTooltip=L["This group has no teams."], func=tm.DeleteGroupTeams},
        {spacer=true},
        {text = tm.HideShowGroupTabText, hidden=tm.IsHideShowGroupTabHidden, isDisabled=tm.IsHideShowGroupTabDisabled, disabledTooltip=tm.HideShowGroupTabDisabledTooltip, func=tm.HideShowGroupTab},
        {text=CANCEL},
    }
    rematch.menus:Register("GroupMenu",groupMenu)

    -- menu when you right-click a team in the team list
    local teamMenu = {
        {title=tm.GetTeamName},
        {text=L["Unload Team"], hidden=tm.IsTeamNotLoaded, func=tm.UnloadTeam},
        {text=L["Edit Team"], func=tm.EditTeam},
        {text=L["Set Notes"], func=tm.SetNotes},
        {text=L["Move Team"], func=tm.MoveTeam},
        {text=tm.SetOrRemoveFavoriteText, func=tm.SetOrRemoveFavorite},
        {text=L["Load Target"], hidden=tm.HasNoTargets, func=tm.LoadSavedTarget, subMenu="TeamLoadTargetMenu", subMenuFunc=tm.BuildLoadTargetSubMenu},
        {text=L["Edit Target"], hidden=tm.HasNoTargets, func=tm.EditSavedTarget, subMenu="TeamEditTargetMenu", subMenuFunc=tm.BuildEditTargetSubMenu},
        {text=L["Share"], subMenu="ShareTeamMenu"},
        {text=L["Delete Team"], func=tm.DeleteTeam},
        {text=CANCEL},
    }
    rematch.menus:Register("TeamMenu",teamMenu)

    local shareTeamMenu = {
        {text=L["Plain Text"], isPlainText=true, func=tm.ExportTeam},
        {text=L["Export Team"], func=tm.ExportTeam},
        {text=L["Send Team"], isDisabled=tm.IsShareDisabled, disabledTooltip=L["Sending teams is disabled due to Disabling Sharing in options.\n\nYou can still export and import teams, however."], func=tm.SendTeam},
        {text=CANCEL}
    }
    rematch.menus:Register("ShareTeamMenu",shareTeamMenu)

    -- menu for the Teams button at the top of the panel
    local teamsButtonMenu = {
        {text=L["Create New Group"], func=tm.EditGroup},
        {text=L["Team Herder"], func=tm.TeamHerder},
        {text=L["Import Teams"], func=tm.ImportTeams},
        {text=L["Backup All Teams"], func=tm.BackupAllTeams},
        {text=L["Help"], stay=true, isHelp=true, hidden=function() return settings.HideMenuHelp end, icon="Interface\\Common\\help-i", iconCoords={0.15,0.85,0.15,0.85}, tooltipTitle=L["Teams and Groups"], tooltipBody=format(L["Teams can be organized into an unlimited number of collapsible groups. You can create new groups with %sCreate New Group\124r in this menu. Up to %d groups can be shown as tabs to act as bookmarks to these groups.\n\nBoth teams and groups can be rearranged with drag and drop. To easily move many teams to another group, use %sTeam Herder\124r in this menu.\n\nTeams with a %s beside their name contain at least one target.\nTeams with a %s beside their name contain a leveling preference.\nPets or targets with a %s beside their name belong to at least one team."],C.HEX_WHITE,C.MAX_TEAM_TABS,C.HEX_WHITE,rematch.utils:GetBadgeAsText(27,14,true),rematch.utils:GetBadgeAsText(14,14,true),rematch.utils:GetBadgeAsText(12,14,true))},
        {text=OKAY},
    }
    rematch.menus:Register("TeamsButtonMenu",teamsButtonMenu)

    -- menu from the right-click of the loadedTeamPanel TeamButton
    local loadedTeamMenu = {
        {title=tm.GetTeamName},
        {text=L["Unload Team"], func=tm.UnloadTeam},
        {text=L["Edit Team"], hidden=tm.IsNotUserTeam, func=tm.EditTeam},
        {text=L["Set Notes"], hidden=tm.IsNotUserTeam, func=tm.SetNotes},
        {text=tm.SetOrRemoveFavoriteText, hidden=tm.IsNotUserTeam, func=tm.SetOrRemoveFavorite},
        {text=L["Load Target"], hidden=tm.HasNoTargets, func=tm.LoadSavedTarget, subMenu="TeamLoadTargetMenu", subMenuFunc=tm.BuildLoadTargetSubMenu},
        {text=L["Edit Target"], hidden=tm.HasNoTargets, func=tm.EditSavedTarget, subMenu="TeamEditTargetMenu", subMenuFunc=tm.BuildEditTargetSubMenu},
        {text=L["Share"], subMenu="ShareTeamMenu"},
        {text=CANCEL}
    }
    rematch.menus:Register("LoadedTeamMenu",loadedTeamMenu)

    -- submenus have just title, subMenuFuncs fill them in
    rematch.menus:Register("TeamEditTargetMenu",{{title=L["Targets"]}})
    rematch.menus:Register("TeamLoadTargetMenu",{{title=L["Targets"]}})

    -- dialog for editing a team group
    rematch.dialog:Register("EditGroup",{
        title = L["New Group"],
        accept = SAVE,
        cancel = CANCEL,
        minHeight = 230, --314, -- 250
        layouts = {
            Default={"LayoutTabs","EditBox","ColorPicker","DropDown","CheckButton","Help"},
            Icon={"LayoutTabs","IconPicker"},
            Preferences={"LayoutTabs","Text","Line","Preferences","Help"},
        },
        refreshFunc = function(self,info,subject,firstRun)
            if firstRun then
                local group = subject and rematch.savedGroups[subject]
                if group then
                    self.ColorPicker:Set(group.color)
                else
                    self.ColorPicker:Reset()
                end
                local name = group and group.name or L["New Group"]
                rematch.dialog:SetTitle(name)
                self.EditBox:SetText(name,true)
                self.EditBox:SetTextColor(rematch.utils:HexToRGB(self.ColorPicker.color))
                self.EditBox:SetEnabled(not (subject=="group:favorites"))
                self.LayoutTabs:SetTabs({
                    {L["Group"],"Default"},
                    {L["Icon"],"Icon"},
                    {L["Preferences"],"Preferences",function() return self.Preferences:IsAnyUsed() end,function() self.Preferences:Set({}) end}
                })
                self.EditBox:SetLabel(L["Group Name:"])
                self.DropDown:SetLabel(L["Sort:"])
                self.DropDown.DropDown:BasicSetup({
                    {text=L["By Name"], value=C.GROUP_SORT_ALPHA, tooltipTitle=L["Sort By Name"], tooltipBody=L["Sort teams in this group alphabetically."]},
                    {text=L["By Wins"], value=C.GROUP_SORT_WINS, tooltipTitle=L["Sort By Wins"], tooltipBody=L["Sort teams in this group by how many times the team has won, if win records are tracked."]},
                    {text=L["Custom Sort"], value=C.GROUP_SORT_CUSTOM, tooltipTitle=L["Custom Sort"], tooltipBody=L["Sort teams in this group manually. New teams to this group are added to the end."]}
                })
                self.DropDown.DropDown:SetSelection(group and group.sortMode or C.GROUP_SORT_ALPHA)
                self.CheckButton:SetText(L["Show Tab For This Group"])
                self.CheckButton.Check.tooltipTitle = L["Show Tab For This Group"]
                local numTeamTabs = rematch.savedGroups:GetNumTeamTabs()
                self.CheckButton.Check.tooltipBody = format(L["Up to %d groups can be chosen to display as tabs along the right side of the Rematch window.\n\n%s%d of %d\124r possible tabs are shown."],C.MAX_TEAM_TABS,numTeamTabs<C.MAX_TEAM_TABS and C.HEX_WHITE or C.HEX_RED,numTeamTabs,C.MAX_TEAM_TABS)
                if numTeamTabs >= C.MAX_TEAM_TABS and (not group or not group.showTab) then
                    self.CheckButton.Check.tooltipBody = self.CheckButton.Check.tooltipBody..L["\n\nYou will need to hide another group's tab before you can show a tab for this group."]
                end
                self.IconPicker:SetIcon(group and group.icon or C.REMATCH_ICON)
                self.Preferences:Set(group and group.preferences or {})
                rematch.dialog.AcceptButton:Enable()
            end
            -- these run every refresh (above is only on first run)
            local openLayout = rematch.dialog:GetOpenLayout()
            if openLayout=="Default" then
                self.Help:SetText(format(L["Groups are categories you create for organizing your teams. Unlimited groups can be made but only %d can be shown as tabs."],C.MAX_TEAM_TABS))
            elseif openLayout=="Preferences" then
                self.Help:SetText(L["Leveling preferences choose which pets are picked first in the leveling queue. All criteria are optional."])
                self.Text:SetText(L["Group Leveling Preferences"])
            end
            local showTab = subject and rematch.savedGroups[subject] and rematch.savedGroups[subject].showTab and true or false
            self.CheckButton:SetChecked(showTab)
            self.CheckButton:SetEnabled(showTab or rematch.savedGroups:GetNumTeamTabs()<C.MAX_TEAM_TABS)
            self.LayoutTabs:Update()
        end,
        changeFunc = function(self,info,subject)
            self.EditBox:SetTextColor(rematch.utils:HexToRGB(self.ColorPicker.color))
            rematch.dialog.AcceptButton:SetEnabled(self.EditBox:GetText():trim():len()>0)
            self.LayoutTabs:Update()
        end,
        acceptFunc = function(self,info,subject)
            local group = subject and rematch.savedGroups[subject]
            local name = self.EditBox:GetText():trim() or L["New Group"]
            if not group then
                group = rematch.savedGroups:Create(name)
            end
            group.name = name
            group.color = self.ColorPicker.color
            if group.sortMode~=self.DropDown:GetSelection() then
                group.sortMode = self.DropDown:GetSelection()
                rematch.savedGroups:Sort(subject)
            end
            group.icon = self.IconPicker:GetIcon()
            if self.Preferences:IsAnyUsed() then
                group.preferences = CopyTable(self.Preferences:Get()) -- preferences dialog returns a reused table; make a copy!
            else
                group.preferences = nil
            end
            group.showTab = self.CheckButton:GetChecked() or nil
            if rematch.layout:GetView()~="teams" then
                rematch.layout:ChangeView("teams")
            end
            rematch.teamsPanel:Update()
            rematch.teamsPanel.List:BlingData(group.groupID)
            rematch.teamTabs:Update()
            rematch.loadedTeamPanel:Update()
        end
    })

    rematch.dialog:Register("DeleteGroup",{
        title = L["Delete Group"],
        accept = YES,
        cancel = NO,
        prompt = L["Delete this group?"],
        layouts = {
            Default = {"Text","CheckButton"},
            Warning = {"Text","CheckButton","Feedback"}
        },
        refreshFunc = function(self,info,subject,firstRun)
            local group = subject and rematch.savedGroups[subject]
            if group then
                if firstRun then
                    self.CheckButton:SetText(L["Also delete teams in this group"])
                    self.Feedback:Set("warning",format(L["All teams in this group will be deleted. %sThis cannot be undone!\124r"],C.HEX_WHITE))
                    self.CheckButton:SetChecked(false)
                end
                if self.CheckButton:GetChecked() then
                    self.Text:SetText(format(L["Are you sure you want to delete the group %s and all teams within it?"],rematch.utils:GetFormattedGroupName(subject)))
                else
                    self.Text:SetText(format(L["Are you sure you want to delete the group %s? All of its teams will be moved to the %s group."],rematch.utils:GetFormattedGroupName(subject),rematch.utils:GetFormattedGroupName("group:none")))
                end
            end
        end,
        changeFunc = function(self,info,subject)
            local group = subject and rematch.savedGroups[subject]
            if group then
                if self.CheckButton:GetChecked() then
                    rematch.dialog:ChangeLayout("Warning")
                else
                    rematch.dialog:ChangeLayout("Default")
                end
            end
        end,
        acceptFunc = function(self,info,subject)
            if self.CheckButton:GetChecked() then -- if 'Also delete teams in this group' checked
                for teamID,team in rematch.savedTeams:AllTeams() do
                    if team.groupID==subject then
                        rematch.savedTeams[teamID] = nil -- delete team
                    end
                end
            end
            -- the following delete will move teams to Ungrouped Teams (if any remain)
            rematch.savedGroups:Delete(subject)
            rematch.savedGroups:Update() -- just in case anything weird happened
            rematch.teamsPanel:Update()
        end
    })

    rematch.dialog:Register("DeleteGroupTeams",{
        title = L["Delete Group Teams"],
        accept = YES,
        cancel = NO,
        layout = {"Text","Feedback"},
        refreshFunc = function(self,info,subject,firstRun)
            self.Text:SetText(format(L["There are %s%d\124r teams in the group %s."],C.HEX_WHITE,#rematch.savedGroups[subject].teams,rematch.utils:GetFormattedGroupName(subject)))
            self.Feedback:Set("warning",format(L["%sAre you sure you want to %sdelete\124r these teams? This cannot be undone."],C.HEX_GOLD,C.HEX_WHITE))
        end,
        acceptFunc = function(self,info,subject)
            for teamID,team in rematch.savedTeams:AllTeams() do
                if team.groupID==subject then
                    rematch.savedTeams[teamID] = nil -- delete team
                end
            end
            rematch.savedGroups:Update()
            rematch.teamsPanel:Update()
            rematch.teamsPanel.List:BlingData(subject)
        end
    })

    rematch.dialog:Register("DeleteTeam",{
        title = L["Delete Team"],
        accept = YES,
        cancel = NO,
        layout = {"Feedback","Team","CheckButton"},
        refreshFunc = function(self,info,subject,firstRun)
            --self.Text:SetText("Are you sure you want to delete this team?")
            self.Feedback:Set("warning",format(L["%sAre you sure you want to %sdelete\124r this team? This cannot be undone."],C.HEX_GOLD,C.HEX_WHITE))
            self.CheckButton:SetChecked(false)
            self.CheckButton:SetText(L["Don't Ask When Deleting Teams"])
            self.Team:Fill(subject)
        end,
        acceptFunc = function(self,info,subject)
            if self.CheckButton:GetChecked() then
                settings.DontConfirmDeleteTeams = true
            end
            rematch.savedTeams:DeleteTeam(subject)
        end
    })

    -- subject is {teamID=teamID, isPlainText=true/false} where isPlainText is true to export in plain text (really)
    rematch.dialog:Register("ExportSingleTeam",{
        title = L["Export Team"],
        accept = OKAY,
        layout = {"Text","MultiLineEditBox","IncludeCheckButtons"},
        refreshFunc = function(self,info,subject,firstRun)
            if firstRun then
                self.Text:SetText(L["Press Ctrl+C to copy to clipboard"])
                self.IncludeCheckButtons:Update(subject.teamID)
                local export = subject.isPlainText and rematch.teamStrings:ExportPlainTextTeam(subject.teamID) or rematch.teamStrings:ExportTeam(subject.teamID)
                self.MultiLineEditBox:SetText(export or "",true)
                self.MultiLineEditBox:ScrollToTop()
            end
        end,
        changeFunc = function(self,info,subject)
            settings.ExportIncludePreferences = self.IncludeCheckButtons.IncludePreferences:GetChecked()
            settings.ExportIncludeNotes = self.IncludeCheckButtons.IncludeNotes:GetChecked()
            local export = subject.isPlainText and rematch.teamStrings:ExportPlainTextTeam(subject.teamID) or rematch.teamStrings:ExportTeam(subject.teamID)
            self.MultiLineEditBox:SetText(export or "",true)
            self.MultiLineEditBox:ScrollToTop()
        end
    })

    -- subject is a groupID to export a group and its teams, or nil to export all teams (backup)
    rematch.dialog:Register("ExportMultipleTeams",{
        title = L["Export Teams"],
        accept = OKAY,
        layout = {"Text","MultiLineEditBox","IncludeCheckButtons"},
        refreshFunc = function(self,info,subject,firstRun)
            if firstRun then
                self.Text:SetText(L["Press Ctrl+C to copy to clipboard"])
                self.IncludeCheckButtons:Update()
                local teamStrings = subject and rematch.teamStrings:ExportGroup(subject) or rematch.teamStrings:ExportAll()
                self.MultiLineEditBox:SetText(teamStrings,true)
            end
        end,
        changeFunc = function(self,info,subject)
            if settings.ExportIncludePreferences~=self.IncludeCheckButtons.IncludePreferences:GetChecked() or settings.ExportIncludeNotes~=self.IncludeCheckButtons.IncludeNotes:GetChecked() then
                settings.ExportIncludePreferences = self.IncludeCheckButtons.IncludePreferences:GetChecked()
                settings.ExportIncludeNotes = self.IncludeCheckButtons.IncludeNotes:GetChecked()
                local teamStrings = subject and rematch.teamStrings:ExportGroup(subject) or rematch.teamStrings:ExportAll()
                self.MultiLineEditBox:SetText(teamStrings,true)
            end
        end
    })

end)

-- returns unformatted name of group
function rematch.teamMenu:GetGroupName(groupID)
    local group = rematch.savedGroups[groupID]
    return group.name or L["New Group"]
end

function rematch.teamMenu:GetTeamName(teamID)
    local team = rematch.savedTeams[teamID]
    return team.name or L["New Team"]
end

-- summon EditGroup dialog
function rematch.teamMenu:EditGroup(groupID)
    rematch.dialog:ShowDialog("EditGroup",groupID)
end

-- returns true if group can't be deleted (favorites or ungrouped teams)
function rematch.teamMenu:IsUndeletable(groupID)
    return groupID=="group:favorites" or groupID=="group:none"
end

-- summon DeleteGroup dialog
function rematch.teamMenu:DeleteGroup(groupID)
    rematch.dialog:ShowDialog("DeleteGroup",groupID)
end

-- dummon DeleteTeam dialog
function rematch.teamMenu:DeleteTeam(teamID)
    if not settings.DontConfirmDeleteTeams then
        rematch.dialog:ShowDialog("DeleteTeam",teamID)
    else
        rematch.savedTeams:DeleteTeam(teamID)
    end
end

-- returns "Show Tab" or group's tab is not shown; "Hide Tab" otherwise
function rematch.teamMenu:HideShowGroupTabText(groupID)
    local group = rematch.savedGroups[groupID]
    return group.showTab and L["Hide Tab"] or L["Show Tab"]
end

-- if Never Show Team Tabs enabled, then never show options to show or hide tabs too
function rematch.teamMenu:IsHideShowGroupTabHidden(groupID)
    return settings.NeverTeamTabs
end

-- returns true if max groups are tabs
function rematch.teamMenu:IsHideShowGroupTabDisabled(groupID)
    local group = rematch.savedGroups[groupID]
    if group.showTab then
        return false -- always make hiding the tab enabled
    else
        return rematch.savedGroups:GetNumTeamTabs() >= C.MAX_TEAM_TABS -- disable if at team tab limit
    end
end

-- tooltip to explain why Show Tab is disabled
function rematch.teamMenu:HideShowGroupTabDisabledTooltip(groupID)
    return format(L["%s%d of %d\124r tabs are currently shown.\n\nBefore the tab for this group can be shown, another one needs to be hidden."],C.HEX_WHITE,rematch.savedGroups:GetNumTeamTabs(),C.MAX_TEAM_TABS)
end

-- shows or hides team tab for the groupID
function rematch.teamMenu:HideShowGroupTab(groupID)
    local group = rematch.savedGroups[groupID]
    if group.showTab then
        group.showTab = nil
    elseif rematch.savedGroups:GetNumTeamTabs()<C.MAX_TEAM_TABS then
        group.showTab = true
    end
    rematch.teamTabs:Update()
end

function rematch.teamMenu:MoveGroup(groupID)
    if groupID then
        rematch.dragFrame:PickupGroup(groupID)
    end
end

function rematch.teamMenu:MoveTeam(teamID)
    if teamID then
        rematch.dragFrame:PickupTeam(teamID)
    end
end

function rematch.teamMenu:SetOrRemoveFavoriteText(teamID)
    local team = teamID and rematch.savedTeams[teamID]
    return (team and team.favorite) and L["Remove Favorite"] or L["Set Favorite"]
end

function rematch.teamMenu:SetOrRemoveFavorite(teamID)
    local team = teamID and rematch.savedTeams[teamID]
    if team and team.favorite then
        team.groupID = team.homeID or "group:none"
        team.homeID = nil
        team.favorite = nil
    else
        team.homeID = team.groupID
        team.groupID = "group:favorites"
        team.favorite = true
    end
    rematch.savedTeams:TeamsChanged()
end

function rematch.teamMenu:UnloadTeam(teamID)
    rematch.loadTeam:UnloadTeam()
end

function rematch.teamMenu:SetNotes(teamID)
    rematch.cardManager:HideCard(rematch.notes)
    rematch.cardManager:ShowCard(rematch.notes,teamID)
    rematch.notes:SetFocus()
end

function rematch.teamMenu:IsNotUserTeam(teamID)
    return not rematch.savedTeams:IsUserTeam(teamID)
end

function rematch.teamMenu:EditTeam(teamID)
    if rematch.savedTeams:IsUserTeam(teamID) then
        rematch.saveDialog:SidelineTeamID(teamID)
        rematch.dialog:ShowDialog("SaveTeam",{saveMode=C.SAVE_MODE_EDIT, teamID=teamID})
    end
end

function rematch.teamMenu:IsTeamNotLoaded(teamID)
    return settings.currentTeamID~=teamID
end

function rematch.teamMenu:ExportTeam(teamID)
    if rematch.menus:IsMenuOpen("LoadedTeamMenu") then -- if this is the export from the loadedTeamPanel Share -> Export
        rematch.saveDialog:SidelineLoadouts(newTeam) -- then export pets actually loaded
        rematch.dialog:ShowDialog("ExportSingleTeam",{teamID="sideline", isPlainText=self.isPlainText})
    else -- otherwise export teamID
        rematch.dialog:ShowDialog("ExportSingleTeam",{teamID=teamID, isPlainText=self.isPlainText})
    end
end

function rematch.teamMenu:ExportGroup(groupID)
    rematch.dialog:ShowDialog("ExportMultipleTeams",groupID)
end

function rematch.teamMenu:BackupAllTeams()
    rematch.dialog:ShowDialog("ExportMultipleTeams")
end

function rematch.teamMenu:ImportTeams()
    rematch.dialog:ShowDialog("ImportTeams")
end

function rematch.teamMenu:ImportGroupTeams(groupID)
    if rematch.savedGroups[groupID] then
        settings.LastSelectedGroup = groupID
    end
    rematch.dialog:ShowDialog("ImportTeams")
end

function rematch.teamMenu:SendTeam(teamID)
    rematch.dialog:ShowDialog("SendTeam",{teamID=teamID})
end

function rematch.teamMenu:TeamHerder()
    rematch.dialog:Register("TeamHerder",{
        title = L["Team Herder"],
        accept = L["Done"],
        layouts = {
            Default = {"Text","GroupPicker"},
            Herding = {"Text","GroupSelect","Help"}
        },
        refreshFunc = function(self,info,subject,firstRun)
            self.GroupPicker:SetReturn("Herding",true) -- GroupPicker will return to "Herding" layout
            self.GroupSelect:SetReturn("Default") -- GroupSelect will return to "Default" layout
            self.GroupSelect:Fill(settings.LastSelectedGroup or "group:none")
            if rematch.dialog:GetOpenLayout()=="Default" then
                self.Text:SetText(L["Pick a group to move teams to:"])
            else
                self.Text:SetText(L["While this window is on screen, click a team in the team list to move it to this group:"])
                self.Help:SetText(L["When the cursor changes to a \124TInterface\\Cursor\\Crosshairs:16\124t over a team, click to move the team to the selected group."])
            end
        end,
    })
    rematch.dialog:ShowDialog("TeamHerder")
end

function rematch.teamMenu:IsShareDisabled(teamID)
    return settings.DisableShare
end

function rematch.teamMenu:HasNoTargets(teamID)
    local team = rematch.savedTeams[teamID]
    return not team or not team.targets or #team.targets==0
end

function rematch.teamMenu:BuildTargetSubMenu(teamID,menu,func)
    local def = rematch.menus:GetDefinition(menu)
    -- remove any existing targets
    for i=#def,2,-1 do
        tremove(def,i)
    end
    local targets = rematch.savedTeams[teamID] and rematch.savedTeams[teamID].targets
    if targets and #targets>0 then
        for _,npcID in ipairs(targets) do
            local name = rematch.utils:GetFormattedTargetName(npcID)
            if name==C.CACHE_RETRIEVING then -- name is not cached, need to rebuild this in a bit

            end
            tinsert(def,{text=name,npcID=npcID,func=func})
        end
    else
        tinsert(def,{text=L["No targets :("]})
    end
    tinsert(def,{text=CANCEL})
    rematch.menus:Register(menu,def)
end

-- called just before the Edit Targets submenu is shown to rebuild menu for team's targets
function rematch.teamMenu:BuildEditTargetSubMenu(teamID)
    rematch.teamMenu:BuildTargetSubMenu(teamID,"TeamEditTargetMenu",tm.EditTeamTarget)
end

function rematch.teamMenu:EditTeamTarget(teamID,targetID)
    rematch.targetMenu:SetTeams(targetID or self.npcID)
end

function rematch.teamMenu:BuildLoadTargetSubMenu(teamID)
    rematch.teamMenu:BuildTargetSubMenu(teamID,"TeamLoadTargetMenu",tm.LoadTeamTarget)
end

function rematch.teamMenu:LoadTeamTarget(teamID,targetID)
    rematch.layout:SummonView("teams")
    -- if in single panel mode, expand so the loaded team shows
    if rematch.layout:GetMode()==1 then
        rematch.layout:ChangeMode(2)
    end
    rematch.loadedTargetPanel:SetTarget(targetID or self.npcID,true)
end

-- click of the Load Target menu option will load the first target (this menu option opens a submenu of targets)
function rematch.teamMenu:LoadSavedTarget(teamID)
    local targets = rematch.savedTeams[teamID] and rematch.savedTeams[teamID].targets
    if #targets>0 then
        rematch.teamMenu:LoadTeamTarget(teamID,targets[1])
    end
    rematch.menus:Hide()
end

function rematch.teamMenu:EditSavedTarget(teamID)
    local targets = rematch.savedTeams[teamID] and rematch.savedTeams[teamID].targets
    if #targets>0 then
        rematch.teamMenu:EditTeamTarget(teamID,targets[1])
    end
    rematch.menus:Hide()
end

function rematch.teamMenu:IsGroupEmpty(groupID)
    local group = rematch.savedGroups[groupID]
    return not group or not group.teams or #group.teams==0
end

function rematch.teamMenu:DeleteGroupTeams(groupID)
    rematch.dialog:ShowDialog("DeleteGroupTeams",groupID)
end
