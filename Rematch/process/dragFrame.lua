local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.dragFrame = RematchDragFrame

--[[ for dragging teams, groups (and maybe targets) ]]

rematch.events:Register(rematch.dragFrame,"PLAYER_LOGIN",function(self)

    -- confirmation to combine groups (move from one to another and delete old)
    -- note: there's no option to auto-confirm since this involves multiple teams, probably will be a rare event,
    -- and it would not give an option to not delete the old group
    rematch.dialog:Register("CombineGroups",{
        title = L["Combine Groups"],
        accept = YES,
        cancel = NO,
        prompt = L["Combine team groups?"],
        layout = {"Text","CheckButton","Help"},
        refreshFunc = function(self,info,subject,firstRun)
            -- neither group:favorites or group:none can be deleted, they can just be emptied
            local cantDelete = subject.fromID=="group:favorites" or subject.fromID=="group:none"
            local instructions = cantDelete and L["This will move all teams from %s to %s, leaving the %s group empty."] or L["This will move all teams from %s to %s and then delete the emptied %s group afterwards."]
            local fromName = rematch.utils:GetFormattedGroupName(subject.fromID)
            local toName = rematch.utils:GetFormattedGroupName(subject.toID)
            self.Text:SetText(format(instructions,fromName,toName,fromName))
            self.CheckButton:SetText(L["Don't Delete Empty Group"])
            self.Help:SetText(L["You can also selectively move many teams with the Team Herder tool from the Teams button"])
            self.CheckButton:SetChecked(settings.DontDeleteOnCombine or cantDelete)
            self.CheckButton:SetEnabled(not cantDelete)
        end,
        changeFunc = function(self,info,subject)
            settings.DontDeleteOnCombine = self.CheckButton:GetChecked()
        end,
        acceptFunc = function(self,info,subject)
            if subject.fromID~=subject.toID and rematch.savedGroups[subject.fromID] and rematch.savedGroups[subject.toID] then
                -- go through all teams and move any from fromID to toID
                for teamID,team in rematch.savedTeams:AllTeams() do
                    if team.groupID==subject.fromID then
                        if subject.toID=="group:favorites" then -- moving team to favorites, save homeID
                            team.homeID = team.groupID
                            team.favorite = true
                        elseif team.groupID=="group:favorites" then -- moving team out of favorites, nil homeID
                            team.homeID = nil
                            team.favorite = nil
                        end
                        team.groupID = subject.toID
                        if settings.EchoTeamDrag then
                            rematch.utils:Write(rematch.utils:GetFormattedTeamName(teamID),"moved to",rematch.utils:GetFormattedGroupName(subject.toID))
                        end
                    end
                end
                -- here all of teams should be out of subject.fromID group, delete group if checkbutton unchecked (and a deletable group)
                if not settings.DontDeleteOnCombine and subject.fromID~="group:favorites" and subject.fromID~="group:none" then
                    rematch.savedGroups:Delete(subject.fromID)
                end
                -- doing an immediate TeamsChanged
                rematch.savedTeams:TeamsChanged(true) -- true will update UI immediately
                rematch.teamsPanel.List:BlingData(subject.toID) -- bling the group teams were moved to
            end
        end
    })

end)

-- returns the type of thing on the cursor (C.CURSOR_TYPE_GROUP or C.CURSOR_TYPE_TEAM) and the groupID/teamID
-- if an actual item, spell or pet is on the cursor, this should return nil
function rematch.dragFrame:GetCursorInfo()
    return self.cursorType,self.cursorID
end

-- returns a C.DRAG_DIRECTION_PREV or C.DRAG_DIRECTION_NEXT
function rematch.dragFrame:GetCursorDirection()
    if self.GlowFrame.GlowLine:IsVisible() then
        return self.GlowFrame.GlowLine.direction
    end
end

function rematch.dragFrame:OnShow()
    SetCursor("ITEM_CURSOR")
    --self:GetScript("OnUpdate")(self,0)
end

function rematch.dragFrame:OnHide()
    self.cursorType = nil
    self.cursorID = nil
    SetCursor(nil)
    self.GlowFrame:Hide()
    rematch.teamsPanel.List:UnlockHeaders()
    rematch.teamsPanel.List:Select("Moving")
    rematch.teamsPanel.List.needsRefresh = true
    rematch.events:Unregister(self,"GLOBAL_MOUSE_UP")
end

function rematch.dragFrame:OnUpdate(elapsed)
    if GetCursorInfo() then -- something real was picked up on cursor
        self:Hide()
    elseif self:GetCursorInfo() then
        if not rematch.teamsPanel:IsVisible() then -- if not on teams panel, drop whatever group/team on cursor
            self:ClearCursor()
        else
            local x,y = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            self[self.cursorType==C.CURSOR_TYPE_GROUP and "Group" or "Team"]:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",x/scale,y/scale)
            SetCursor("ITEM_CURSOR")
        end
    end
end

function rematch.dragFrame:OnClick(button)
    self:ClearCursor()
end

-- OnReceiveDrag is unreliable because if a team/group is picked up and the list collapses, then no button receives
-- the drag. To work around this, when a team/group is picked up via dragging, GLOBAL_MOUSE_UP is registered, and
-- then a OnReceiveDrag is simulated based on what's beneath the mouse when the mouse button is released
function rematch.dragFrame:GLOBAL_MOUSE_UP()
    local focus = GetMouseFoci()[1]
    if focus then
        -- if mouse is over teamsPanel(GlowFrame) then any team/group combination safe to handle
        if MouseIsOver(self.GlowFrame) and rematch.teamsPanel:IsVisible() and (focus.groupID or focus.teamID or focus==rematch.teamsPanel.List.CaptureButton) then
            self:HandleReceiveDrag(focus)
        end
        -- but if mouse is over teamTabs it can only be a team on the cursor
        if MouseIsOver(rematch.teamTabs) and rematch.teamTabs:IsVisible() and focus.groupID and self:GetCursorInfo()==C.CURSOR_TYPE_TEAM then
            self:HandleReceiveDrag(focus)
        end
    end
    rematch.events:Unregister(self,"GLOBAL_MOUSE_UP")
end

--[[ pickup/clear ]]

function rematch.dragFrame:ClearCursor()
    self:Hide()
    rematch.teamsPanel.List:Select("Moving")
end

-- picks up a groupID onto the cursor; fromDrag is true if it was picked up from OnDragStart
function rematch.dragFrame:PickupGroup(groupID,fromDrag)
    ClearCursor()
    if rematch.savedGroups[groupID] then
        rematch.utils:HideWidgets()
        rematch.dialog:Hide()
        self.cursorType = C.CURSOR_TYPE_GROUP
        self.cursorID = groupID

        self.Group.Name:SetWidth(0) -- initially allow unbounded width
        self.Group.Name:SetText(rematch.utils:GetFormattedGroupName(groupID))
        local nameWidth = self.Group.Name:GetStringWidth()
        if nameWidth > 120 then
            self.Group.Name:SetWidth(120)
            nameWidth = 120
        end
        self.Group:SetWidth(nameWidth+6+4+18+4)
        self.Group.Icon:SetTexture(rematch.savedGroups[groupID].icon or C.EMPTY_ICON)
        self.Team:Hide()
        self.Group:Show()

        -- if not in teams tab, go to it
        if rematch.layout:GetMode()~=0 and rematch.layout:GetView()~="teams" then
            rematch.layout:ChangeView("teams")
        end
        -- if searching, clear search
        if rematch.teamsPanel.List:IsSearching() then
            rematch.teamsPanel.Top.SearchBox.Clear:Click()
        end
        -- collapse any expanded headers and lock them to prevent expanding
        rematch.teamsPanel.List:CollapseAllHeaders()
        rematch.teamsPanel.List:LockHeaders()

        self:Show() -- show dragFrame to begin dragging
        self:ShowGlowFrame(rematch.teamsPanel.List)
        PlaySound(C.SOUND_DRAG_START)
        if fromDrag and not settings.ClickToDrag then
            rematch.events:Register(self,"GLOBAL_MOUSE_UP",self.GLOBAL_MOUSE_UP)
        end
        rematch.teamsPanel.List:Select("Moving",groupID)
    end
end

-- picks up a teamID onto the cursor; fromDrag is true if it was picked up from OnDragStart
function rematch.dragFrame:PickupTeam(teamID,fromDrag)
    ClearCursor()
    if rematch.savedTeams[teamID] then
        rematch.utils:HideWidgets()
        rematch.dialog:Hide()
        self.cursorType = C.CURSOR_TYPE_TEAM
        self.cursorID = teamID

        for i=1,3 do
            local petID = rematch.savedTeams[teamID].pets[i]
            local petInfo = rematch.petInfo:Fetch(petID)
            self.Team.Pets[i]:SetTexture(petInfo.icon)
            self.Team.Pets[i]:SetDesaturated(petInfo.idType=="species")
        end
        self.Group:Hide()
        self.Team:Show()

        -- if searching, clear search and all headers
        if rematch.teamsPanel.List:IsSearching() then
            rematch.teamsPanel.Top.SearchBox.Clear:Click()
            rematch.teamsPanel.List:CollapseAllHeaders()
        else -- if not searching, collapse all other headers but keep data in view
            rematch.teamsPanel.List:CollapseAllButData(teamID)
        end
        -- lock headers so they can't be expanded/collapsed while dragging
        rematch.teamsPanel.List:LockHeaders()

        self:Show() -- show dragFrame to begin dragging
        self:ShowGlowFrame(rematch.teamsPanel.List)
        PlaySound(C.SOUND_DRAG_START)
        if fromDrag and not settings.ClickToDrag then
            rematch.events:Register(self,"GLOBAL_MOUSE_UP",self.GLOBAL_MOUSE_UP)
        end
        rematch.teamsPanel.List:Select("Moving",teamID)
    end
end

--[[ glow frame ]]

function rematch.dragFrame:ShowGlowFrame(parent)
    self.GlowFrame:SetPoint("TOPLEFT",parent,"TOPLEFT")
    self.GlowFrame:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT")
    self.GlowFrame.GlowLine:Hide()
    if rematch.layout:GetMode()==1 then
        self.GlowFrame.GlowLine:SetWidth(C.LIST_BUTTON_WIDE_WIDTH-2)
    else
        self.GlowFrame.GlowLine:SetWidth(C.LIST_BUTTON_NORMAL_WIDTH-2)
    end
    self.GlowFrame.GlowLine.Animation:Play()
    self.GlowFrame.GlowArea.Animation:Play()
    self.GlowFrame:SetScript("OnUpdate",self.GlowFrame.OnUpdate)
    self.GlowFrame:Show()
end

function rematch.dragFrame.GlowFrame:OnUpdate(elapsed)
    local cursorType,cursorID = rematch.dragFrame:GetCursorInfo()
    local focus = GetMouseFoci()[1]

    if not focus then
        return -- while scrolling, focus becomes nil at times
    end

    local cursorX,cursorY = GetCursorPosition()
    local scale = focus:GetEffectiveScale()
    local centerX,centerY = focus:GetCenter()

    local showGlowLine = false
    local showGlowArea = false
    local isMouseOver = MouseIsOver(self) -- is mouse over GlowFrame

    self.GlowLine.direction = nil -- potentially one of C.DRAG_DIRECTION_PREV/NEXT/END

    -- if group on cursor, and mouse is over a group, put GlowLine above/below group
    if cursorType==C.CURSOR_TYPE_GROUP and isMouseOver then
        if focus and focus.groupID then
            -- if group combine key modifier is down, then showGlowArea and not line
            if rematch.dragFrame:IsCombineGroupKeyUsed() then
                self.GlowArea:SetPoint("TOPLEFT",focus,"TOPLEFT")
                self.GlowArea:SetPoint("BOTTOMRIGHT",focus,"BOTTOMRIGHT")
                showGlowArea = true
            else -- combine key is not down, so we're reording groups
                -- if cursor is in top half of button, anchor to top
                if (cursorY/scale)>centerY then
                    self.GlowLine:SetPoint("CENTER",focus,"TOP")
                    self.GlowLine.direction = C.DRAG_DIRECTION_PREV
                else
                    self.GlowLine:SetPoint("CENTER",focus,"BOTTOM")
                    self.GlowLine.direction = C.DRAG_DIRECTION_NEXT
                end
                showGlowLine = true
            end
        elseif focus==rematch.teamsPanel.List.CaptureButton then -- if over capturebutton, then move glow to last button
            if not rematch.dragFrame:IsCombineGroupKeyUsed() then -- make sure combine key not down over capture button
                local lastListButton = rematch.teamsPanel.List:GetLastListButton()
                if lastListButton and lastListButton.groupID then
                    self.GlowLine:SetPoint("CENTER",lastListButton,"BOTTOM")
                else -- no last button, put glow at top of frame
                    self.GlowLine:SetPoint("CENTER",self,"TOP")
                end
                self.GlowLine.direction = C.DRAG_DIRECTION_END
                showGlowLine = true
            end
        end
    elseif cursorType==C.CURSOR_TYPE_TEAM and isMouseOver then
        if focus and focus.teamID then
            -- if cursor is in top half of button, anchor to top
            if (cursorY/scale)>centerY then
                self.GlowLine:SetPoint("CENTER",focus,"TOP")
                self.GlowLine.direction = C.DRAG_DIRECTION_PREV
            else
                self.GlowLine:SetPoint("CENTER",focus,"BOTTOM")
                self.GlowLine.direction = C.DRAG_DIRECTION_NEXT
            end
            showGlowLine = true
        elseif focus and focus.groupID then
            self.GlowArea:SetPoint("TOPLEFT",focus,"TOPLEFT")
            self.GlowArea:SetPoint("BOTTOMRIGHT",focus,"BOTTOMRIGHT")
            showGlowArea = true
        end
    end

    self.GlowLine:SetShown(showGlowLine)
    self.GlowArea:SetShown(showGlowArea)
end

--[[ HandleReceiveDrag ]]

-- handles the various ways things can receive drags (OnReceiveDrag, OnClick, OnMouseUp) and returns true if it was handled
-- button is the button that received the drag, and mouseButton is the LeftButton/RightButton/etc where appropriate
function rematch.dragFrame:HandleReceiveDrag(button,mouseButton)

    local cursorType,cursorID = self:GetCursorInfo()

    if not cursorType then -- nothing on cursor, nothing to handle
        return false
    end

    if mouseButton=="RightButton" then -- something on cursor, but right-clicked to drop it
        self:ClearCursor()
        return true
    end

    local direction = self:GetCursorDirection()

    if cursorType==C.CURSOR_TYPE_GROUP then -- a groupID is on the cursor
        if button.groupID then -- dropping group onto group
            PlaySound(C.SOUND_DRAG_STOP)
            rematch.dragFrame:ReceiveGroupToGroup(cursorID,button.groupID,direction)
            return true
        elseif direction==C.DRAG_DIRECTION_END then -- dropping group onto capture area
            PlaySound(C.SOUND_DRAG_STOP)
            rematch.dragFrame:ReceiveGroupToCapture(cursorID)
            return true
        end
    elseif cursorType==C.CURSOR_TYPE_TEAM then -- a teamID is on the cursor
        if button.groupID then -- dropping team onto group
            PlaySound(C.SOUND_DRAG_STOP)
            rematch.dragFrame:ReceiveTeamToGroup(cursorID,button.groupID)
            return true
        elseif button.teamID then -- dropping team onto team
            PlaySound(C.SOUND_DRAG_STOP)
            rematch.dragFrame:ReceiveTeamToTeam(cursorID,button.teamID,direction)
            return true
        end
    end

    return false -- if reached here, nothing was done, nothing handled
end

-- dropping groupID(cursorID) before/after a groupID
function rematch.dragFrame:ReceiveGroupToGroup(cursorID,groupID,direction)
    if cursorID==groupID then
        -- do nothing, trying to move a group before/after itself
        rematch.dragFrame:ClearCursor()
        rematch.teamsPanel.List:BlingData(cursorID)
    elseif rematch.dragFrame:IsCombineGroupKeyUsed() then -- if combining groups, show dialog
        rematch.dialog:ShowDialog("CombineGroups",{fromID=cursorID,toID=groupID})
        rematch.dragFrame:ClearCursor()
    elseif direction then
        -- remove cursorID from settings.GroupOrder
        rematch.utils:TableRemoveByValue(settings.GroupOrder,cursorID)
        -- and then put it before/after groupID
        if groupID then
            for i=1,#settings.GroupOrder do
                if settings.GroupOrder[i]==groupID then
                    if direction==C.DRAG_DIRECTION_PREV then
                        tinsert(settings.GroupOrder,i,cursorID)
                    elseif direction==C.DRAG_DIRECTION_NEXT then
                        tinsert(settings.GroupOrder,i+1,cursorID)
                    end
                    break
                end
            end
        end
        -- if no groupID or direction was C.DRAG_DIRECTION_END, add it back to end
        if not groupID or direction==C.DRAG_DIRECTION_END then
            tinsert(settings.GroupOrder,cursorID)
        end
        rematch.dragFrame:ClearCursor()
        rematch.teamsPanel:Update()
        rematch.teamTabs:Update()
        rematch.teamsPanel.List:BlingData(cursorID)
    end
end

-- dropping groupID(cursorID) onto the capture area/empty space after list
function rematch.dragFrame:ReceiveGroupToCapture(cursorID)
    self:ReceiveGroupToGroup(cursorID,nil,C.DRAG_DIRECTION_END)
end

-- dropping teamID(cursorID) onto groupID
function rematch.dragFrame:ReceiveTeamToGroup(cursorID,groupID,noBling)
    local teamName = rematch.utils:GetFormattedTeamName(cursorID)
    local team = rematch.savedTeams[cursorID]
    local teamMoved = false
    if team and team.groupID==groupID then
        -- do nothing, dragging team to group it already belongs to
        rematch.dragFrame:ClearCursor()
    elseif team then
        if groupID=="group:favorites" then
            team.homeID = team.groupID -- moving team to favorites, saved homeID
            team.favorite = true
        elseif team.groupID=="group:favorites" then
            team.homeID = nil -- moving team out of favorites, nil homeID
            team.favorite = nil
        end
        team.groupID = groupID
        rematch.dragFrame:ClearCursor()
        -- call TeamsChanged when moving teamID to new group so its group.teams can be handled/sorted
        rematch.savedTeams:TeamsChanged(true) -- true will update UI immediately
        teamMoved = true
    end
    if not noBling then
        rematch.teamsPanel.List:BlingData(groupID)
    end
    if settings.EchoTeamDrag and teamMoved then
        rematch.utils:Write(teamName,"moved to",rematch.utils:GetFormattedGroupName(groupID))
    end
end

-- dropping teamID(cursorID) before/after a teamID
function rematch.dragFrame:ReceiveTeamToTeam(cursorID,teamID,direction)
    local team = rematch.savedTeams[cursorID]
    local group = rematch.savedGroups[team.groupID]

    if cursorID==teamID then
        rematch.dragFrame:ClearCursor() -- team being moved before/after itself, do nothing
    else
        -- if team is sorted (alpha or wins), change to custom sort
        if group.sortMode==C.GROUP_SORT_ALPHA or group.sortMode==C.GROUP_SORT_WINS then
            group.sortMode = C.GROUP_SORT_CUSTOM
        end
        -- remove cursorID from settings.GroupOrder
        rematch.utils:TableRemoveByValue(group.teams,cursorID)
        -- and then put it before/after teamID
        if teamID then
            for i=1,#group.teams do
                if group.teams[i]==teamID then
                    if direction==C.DRAG_DIRECTION_PREV then
                        tinsert(group.teams,i,cursorID)
                    elseif direction==C.DRAG_DIRECTION_NEXT then
                        tinsert(group.teams,i+1,cursorID)
                    end
                    break
                end
            end
            rematch.dragFrame:ClearCursor()
            rematch.teamsPanel:Update() -- don't need to do a TeamsChanged really
        end
    end
    rematch.teamsPanel.List:BlingData(cursorID)
end

-- returns true if the modifier key assigned to the group combine key is down; or if key is given then whether that was a modifier key
function rematch.dragFrame:IsCombineGroupKeyUsed(key)
    local combineKey = settings.CombineGroupKey

    if not key then -- if no key given, then check if a modifier key is down
        key = (IsAltKeyDown() and "ALT") or (IsShiftKeyDown() and "SHIFT") or (IsControlKeyDown() and "CTRL")
    end

    if combineKey=="None" then
        return false -- if combineKey is "None", don't bother
    elseif combineKey=="Alt" then
        return key=="LALT" or key=="RALT" or key=="ALT"
    elseif combineKey=="Shift" then
        return key=="LSHIFT" or key=="RSHIFT" or key=="SHIFT"
    elseif combineKey=="Ctrl" then
        return key=="LCTRL" or key=="RCTRL" or key=="CTRL"
    end
end