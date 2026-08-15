local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.preferences = {}

local currentPreferences = {} -- combination of group and team preferences, if any

-- returns true if the given preference table contains anything
local function isPreferenceUsed(preference)
    return (preference and next(preference)) and true or false
end

rematch.events:Register(rematch.preferences,"PLAYER_LOGIN",function(self)

    rematch.dialog:Register("CurrentPreferences",{
        title = L["Current Leveling Preferences"],
        accept = SAVE,
        cancel = CANCEL,
        --minHeight = 250,
        layouts = {
            Default = {"LayoutTabs","Text","SmallText","Line","PreferencesReadOnly","Help"},
            Global = {"LayoutTabs","Text","SmallText","Line","Preferences","Help"},
            Group = {"LayoutTabs","Text","SmallText","Line","Preferences","Help"},
            Team = {"LayoutTabs","Text","SmallText","Line","Preferences","Help"}
        },
        refreshFunc = function(self,info,subject,firstRun)
            if firstRun then
                -- making a copy of current group, team and default preferences for editing (reference would modify original)
                self.Preferences.currentPreferences = CopyTable(rematch.preferences:GetCurrentPreferences() or {})
                self.Preferences.groupPreferences = CopyTable(rematch.preferences:GetGroupPreferences(subject.groupID) or {})
                self.Preferences.teamPreferences = CopyTable(rematch.preferences:GetTeamPreferences(subject.teamID) or {})
                self.Preferences.defaultPreferences = CopyTable(settings.DefaultPreferences)
                self.LayoutTabs:SetTabs({
                    {L["Current"],"Default"},
                    {L["Team"],"Team",function() return isPreferenceUsed(self.Preferences.teamPreferences) end,function() wipe(self.Preferences.teamPreferences) rematch.dialog:Refresh() end},
                    {L["Group"],"Group",function() return isPreferenceUsed(self.Preferences.groupPreferences) end,function() wipe(self.Preferences.groupPreferences) rematch.dialog:Refresh() end},
                    {L["Default"],"Global",function() return isPreferenceUsed(self.Preferences.defaultPreferences) end,function() wipe(self.Preferences.defaultPreferences) rematch.dialog:Refresh() end}
                })
            end
            -- these run every refresh (above is only on first run)
            local openLayout = rematch.dialog:GetOpenLayout()
            local isUserTeam = rematch.savedTeams:IsUserTeam(subject.teamID)
            local textColor = ((openLayout=="Group" or openLayout=="Team") and not isUserTeam) and C.HEX_GREY or C.HEX_GOLD
            if openLayout=="Default" then
                self.Text:SetText(L["Current Leveling Preferences"])
                self.SmallText:SetText(L["Combined team, group and default preferences"])
                rematch.preferences:CombinePreferences(self.Preferences.currentPreferences,self.Preferences.teamPreferences,self.Preferences.groupPreferences,self.Preferences.defaultPreferences)
                self.PreferencesReadOnly:Set(self.Preferences.currentPreferences)
                self.Help:SetText(L["Leveling preferences choose which pets are picked first in the leveling queue. All criteria are optional."])
            elseif openLayout=="Group" then
                self.Text:SetText(format("%s%s",textColor,L["Loaded Team's Group Preferences"]))
                self.SmallText:SetText(isUserTeam and rematch.utils:GetFormattedGroupName(subject.groupID) or format("%s%s",C.HEX_RED,L["No saved team loaded"]))
                self.Preferences:Set(self.Preferences.groupPreferences)
                self.Preferences:SetEnabled(isUserTeam)
                self.Help:SetText(L["Group preferences are saved to the loaded team's group and override default preferences."])
            elseif openLayout=="Team" then
                self.Text:SetText(format("%s%s",textColor,L["Loaded Team Preferences"]))
                self.SmallText:SetText(isUserTeam and rematch.utils:GetFormattedTeamName(subject.teamID) or format("%s%s",C.HEX_RED,L["No saved team loaded"]))
                self.Preferences:Set(self.Preferences.teamPreferences)
                self.Preferences:SetEnabled(isUserTeam)
                self.Help:SetText(L["Team preferences are saved to the loaded team and override default and group preferences."])
            elseif openLayout=="Global" then
                self.Text:SetText(L["Default Preferences"])
                self.SmallText:SetText(L["Base preferences regardless of team loaded"])
                self.Preferences:Set(self.Preferences.defaultPreferences)
                self.Preferences:SetEnabled(true)
                self.Help:SetText(L["Default preferences are always active (unless paused) regardless of team loaded."])
            end
            self.LayoutTabs:Update()
        end,
        changeFunc = function(self,info,subject)
            local openLayout = rematch.dialog:GetOpenLayout()
            if openLayout=="Group" then
                self.Preferences:Get(self.Preferences.groupPreferences)
            elseif openLayout=="Team" then
                self.Preferences:Get(self.Preferences.teamPreferences)
            elseif openLayout=="Global" then
                self.Preferences:Get(self.Preferences.defaultPreferences)
            end
            self.LayoutTabs:Update()
        end,
        acceptFunc = function(self,info,subject)
            local team = subject.teamID and rematch.savedTeams[subject.teamID]
            if team then
                if isPreferenceUsed(self.Preferences.teamPreferences) then
                    team.preferences = CopyTable(self.Preferences.teamPreferences)
                else
                    team.preferences = nil
                end
            end
            local group = subject.groupID and rematch.savedGroups[subject.groupID]
            if group then
                if isPreferenceUsed(self.Preferences.groupPreferences) then
                    group.preferences = CopyTable(self.Preferences.groupPreferences)
                else
                    group.preferences = nil
                end
            end
            -- default preferences always has a table, even if empty
            settings.DefaultPreferences = CopyTable(self.Preferences.defaultPreferences)
            -- in case user switched to team panel
            rematch.timer:Start(0,rematch.frame.Update,rematch.frame)
            rematch.queue:Process()
        end
    })

    -- if current preferences dialog is up when a team loads/unloads, close the dialog (to avoid confusion about the previously loaded team's preferences)
    rematch.events:Register(self,"REMATCH_TEAM_LOADED",function(self,event,...)
        if rematch.dialog:GetOpenDialog()=="CurrentPreferences" then
            rematch.dialog:HideDialog()
        end
    end)

end)

-- returns a combination of group and team preferences, if any, or an empty table if neither
function rematch.preferences:GetCurrentPreferences(teamID)
    wipe(currentPreferences)

    if not teamID then
        teamID = settings.currentTeamID
    end

    if isPreferenceUsed(settings.DefaultPreferences) then
        for k,v in pairs(settings.DefaultPreferences) do
            currentPreferences[k] = v
        end
    end

    local teamPreferences = rematch.preferences:GetTeamPreferences(teamID)
    if isPreferenceUsed(teamPreferences) then
        for k,v in pairs(teamPreferences) do
            currentPreferences[k] = v
        end
    end

    local groupPreferences = rematch.preferences:GetGroupPreferences(teamID and rematch.savedTeams[teamID] and rematch.savedTeams[teamID].groupID)
    if isPreferenceUsed(groupPreferences) then
        for k,v in pairs(groupPreferences) do
            currentPreferences[k] = v
        end
    end

    return currentPreferences
end

-- combines group and team preferences into the combinePreferences table
function rematch.preferences:CombinePreferences(combinedPreferences,teamPreferences,groupPreferences,defaultPreferences)
    assert(type(combinedPreferences)=="table" and type(teamPreferences)=="table" and type(groupPreferences)=="table" and type(defaultPreferences)=="table","Can't combine preferences without all preference tables.")
    wipe(combinedPreferences)
    -- apply default preferences first
    for k,v in pairs(defaultPreferences) do
        combinedPreferences[k] = v
    end
    -- possibly overwritten by group preferences
    for k,v in pairs(groupPreferences) do
        combinedPreferences[k] = v
    end
    -- possibly overwritten by team preferences last
    for k,v in pairs(teamPreferences) do
        combinedPreferences[k] = v
    end
end

-- returns true if there are any preferences for default, current teamID or current teamID's groupID, false otherwise
function rematch.preferences:HasCurrentPreferences()

    if isPreferenceUsed(settings.DefaultPreferences) then
        return true -- a default preference is used
    end

    if isPreferenceUsed(rematch.preferences:GetTeamPreferences(settings.currentTeamID)) then
        return true -- a team preference is used
    end

    if isPreferenceUsed(rematch.preferences:GetGroupPreferences(settings.currentTeamID and rematch.savedTeams[settings.currentTeamID] and rematch.savedTeams[settings.currentTeamID].groupID)) then
        return true -- a group preference is used
    end

    return false -- no preferences are used
end

-- returns the preferences for the teamID, or nil if none
function rematch.preferences:GetTeamPreferences(teamID)
    if teamID and rematch.savedTeams[teamID] then
        return rematch.savedTeams[teamID].preferences
    end
end

-- returns the preferences for the groupID, or nil if none
function rematch.preferences:GetGroupPreferences(groupID)
    if groupID and rematch.savedGroups[groupID] then
        return rematch.savedGroups[groupID].preferences
    end
end

-- returns the body of a tooltip for the current preferences
function rematch.preferences:GetTooltipBody()
    local preferences = self:GetCurrentPreferences()
    local anyUsed = false

    local body

    if not settings.HideMenuHelp then
        body = L["Leveling preferences choose which pets are picked first in the leveling queue.\n\n"]
    else
        body = "\n"
    end

    -- add current preferences to tooltip
    body = body..format("%s%s\124r\n",C.HEX_WHITE,L["Current Preferences:"])

    if preferences.minXP then
        body = body..format("%s: %s%s\124r\n",L["Minimum level"],C.HEX_WHITE,preferences.minXP)
    end
    if preferences.maxXP then
        body = body..format("%s: %s%s\124r\n",L["Maximum level"],C.HEX_WHITE,preferences.maxXP)
    end
    if preferences.minHP then
        body = body..format("%s: %s%s\124r\n",L["Minimum health"],C.HEX_WHITE,preferences.minHP)
        if preferences.allowMM then
            body = body..format(format(L["  Allow any %s or %s\n"],rematch.utils:PetTypeAsText(6,16),rematch.utils:PetTypeAsText(10,16)))
        end
        if preferences.expectedDD then
            body = body..format(format(L["  Expected damage taken: %s\n"],rematch.utils:PetTypeAsText(preferences.expectedDD,16)))
        end
    end
    if preferences.maxHP then
        body = body..format("%s: %s%s\124r\n",L["Maximum health"],C.HEX_WHITE,preferences.maxHP)
    end

    -- if no current preferences, then add a "None" under Current Preferences:
    if not rematch.preferences:HasCurrentPreferences() then
        body = body..L["None\n"]
    end

    local verb = L["Pause"]
    if settings.PreferencesPaused then
        body = body..format(L["\n%sPreferences are currently paused. \124rRight-click this button to resume preferences.\n"],C.HEX_RED)
        verb = L["Resume"]
    end

    -- add LMB/RMB text
    body = body..format(L["\n%s %sEdit Preferences\n%s %s Preferences"],C.LMB_TEXT_ICON,C.HEX_BLUE,C.RMB_TEXT_ICON,verb)

    return body
end

-- pauses preferences if paused is true; resumes otherwise
function rematch.preferences:SetPaused(paused)
    settings.PreferencesPaused = paused and true or false
    --  update queue panel and possibly loaded team panel
    if rematch.queuePanel:IsVisible() then
        rematch.queuePanel:Update()
    end
    if settings.ShowLoadedTeamPreferences and rematch.loadedTeamPanel:IsVisible() then
        rematch.loadedTeamPanel:Update()
    end
end

-- toggles the preferences paused
function rematch.preferences:TogglePause()
    rematch.preferences:SetPaused(not settings.PreferencesPaused)
    if rematch.menus:IsMenuOpen("QueueMenu") then
        rematch.menus:RefreshMenus() -- in case menu is open and something outside menu toggled it, update menu
    end
    rematch.queue:Process()
    -- if mouse is over a preferences button when it was clicked, then update its tooltip
    local focus = GetMouseFoci()[1]
    if focus and focus.isPreferencesButton then
        focus:OnEnter()
    end
end

-- returns true if the given petID passes the criteria of the given preferences (or current if no preferences given)
function rematch.preferences:IsPetPreferred(petID,preferences)

    if not preferences then
        preferences = self:GetCurrentPreferences()
    end
    -- this should not be rematch.petInfo but a
    local petInfo = rematch.altInfo:Fetch(petID) -- using altInfo so it doesn't clobber petInfo from upstream
    local preferred = petInfo.level and petInfo.isOwned and petInfo.isSummonable -- assume the pet is preferred if it's owned and has a level

    if settings.PreferencesPaused then
        return preferred -- if preferences paused, all owned pets are preferred
    end

    if settings.QueueSkipDead then
        if petInfo.isDead then
            preferred = false -- if Prefer Living Pets enabled, skip this dead pet
        elseif settings.QueuePreferFullHP and petInfo.isInjured then
            preferred = false -- if At Full Health suboption enabled, skip in jured pet
        end
    end

    if preferred then -- don't need to check stats if pet is not owned
        if preferences.minHP then
            if preferences.allowMM and (petInfo.petType==6 or petInfo.petType==10) then
                -- if allowMM, magic and mechanical pets remain preferred regardless of health
            else
                local health = petInfo.maxHealth
                if preferences.expectedDD then
                    if C.HINTS_OFFENSE[preferences.expectedDD][1]==petInfo.petType then
                        health = health * 1.5 -- the expected damage is strong vs this type, require higher health
                    elseif C.HINTS_OFFENSE[preferences.expectedDD][2]==petInfo.petType then
                        health = health * 2/3 -- this expected damage is weak vs this type, require less health
                    end
                end
                if petInfo.maxHealth < preferences.minHP then
                    preferred = false -- if health is lower than minHP, pet is not preferred
                end
            end
        end
        if preferences.maxHP and petInfo.maxHealth > preferences.maxHP then
            preferred = false -- if health is higher than maxHP, pet is not preferred
        end
        if preferences.minXP and petInfo.fullLevel < preferences.minXP then
            if not (preferences.allowMM and (petInfo.petType==6 or petInfo.petType==10)) then -- except for allowMM and magic or mechanical
                preferred = false -- if level is lower than minXP, pet is not preferred
            end
        end
        if preferences.maxXP then
            local level = petInfo.fullLevel
            if preferences.maxXP == floor(preferences.maxXP) then -- for whole-number maxXP preference
                level = floor(level) -- compare to whole-number pet level
            end
            if level > preferences.maxXP then
                preferred = false
            end
        end
    end

    return preferred
end