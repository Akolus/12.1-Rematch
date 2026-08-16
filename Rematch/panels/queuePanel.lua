local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.queuePanel = rematch.frame.QueuePanel
rematch.frame:Register("queuePanel")

local queueIndexes = {} -- for autoscrollbox, list of numeric indexes into settings.LevelingQueue

rematch.events:Register(rematch.queuePanel,"PLAYER_LOGIN",function(self)
    self.Top.QueueButton:SetText(L["Queue"])

    -- in case something weird happens, set sort order to default ascending
    if settings.QueueSortOrder~=C.QUEUE_SORT_ASC and settings.QueueSortOrder~=C.QUEUE_SORT_DESC and settings.QueueSortOrder~=C.QUEUE_SORT_MID then
        settings.QueueSortOrder = C.QUEUE_SORT_ASC
    end
    self.showingActiveSort = -1 -- ensure this is different than QueueActiveSort on first update

    self.List:Setup({
        allData = queueIndexes,
        normalTemplate = "RematchNormalQueueListButtonTemplate",
        normalFill = self.FillNormal,
        normalHeight = 44,
        compactTemplate = "RematchCompactQueueListButtonTemplate",
        compactFill = self.FillCompact,
        compactHeight = 26,
        isCompact = settings.CompactQueueList,
        selects = {
            PetCard = {color={0.33,0.66,1}, parentKey="Back", padding=0, drawLayer="ARTWORK"},
            Moving = {color={0,0,0,0.65}, tint=true, drawLayer="ARTWORK"}
        },
        onScroll = function(self,percent) if not rematch.menus:IsMenuOpen("PetFilterMenu") and not rematch.menus:IsMenuOpen("QueueMenu") then rematch.menus:Hide() end end
    })

    self.List.Help:SetText(L["This is the leveling queue. Drag pets you want to level here.\n\nRight click any of the three battle pet slots and choose 'Put Leveling Pet Here' to mark it as a leveling slot you want controlled by the queue.\n\nWhile a leveling slot is active, the queue will fill the slot with the top-most pet in the queue. When this pet reaches level 25 (gratz!) it will leave the queue and the next pet in the queue will take its place.\n\nTeams saved with a leveling slot will reserve that slot for future leveling pets."])

end)

function rematch.queuePanel:Update()
    self.Top.Label:SetText(format(L["Leveling Pets: %s%d"],C.HEX_WHITE,#settings.LevelingQueue))

    if settings.PreferencesPaused then -- if preferences paused, red X version of blue gear icon
        self.PreferencesFrame.PreferencesButton:SetIcon("Interface\\AddOns\\Rematch\\textures\\badges-borderless",0.87890625,0.99609375,0.12890625,0.24609375)
    else -- preferences are not paused, regular blue gear icon
        self.PreferencesFrame.PreferencesButton:SetIcon("Interface\\AddOns\\Rematch\\textures\\badges-borderless",0.75390625,0.87109375,0.12890625,0.24609375)
    end

    -- minor reconfiguration if gaining/losing active sort: show/hide status bar
    if self.showingActiveSort~=settings.QueueActiveSort then
        if settings.QueueActiveSort then
            self.StatusBar:Show()
            self.List:SetPoint("TOPLEFT",self.StatusBar,"BOTTOMLEFT",0,-2)
        else
            self.StatusBar:Hide()
            self.List:SetPoint("TOPLEFT",self.PreferencesFrame,"BOTTOMLEFT",0,-2)
        end
        self.showingActiveSort = settings.QueueActiveSort
    end
    -- if active sort enabled, update to display which sort
    if settings.QueueActiveSort then
        local sortText,sortIcon
        if settings.QueueSortOrder==C.QUEUE_SORT_ASC then
            sortText = L["Ascending Level"]
            sortIcon = rematch.utils:GetBadgeAsText(24,18)
        elseif settings.QueueSortOrder==C.QUEUE_SORT_DESC then
            sortText = L["Descending Level"]
            sortIcon = rematch.utils:GetBadgeAsText(26,18)
        elseif settings.QueueSortOrder==C.QUEUE_SORT_MID then
            sortText = L["Median Level"]
            sortIcon = rematch.utils:GetBadgeAsText(25,18)
        end
        if sortText and sortIcon then
            self.StatusBar.Text:SetText(format(L["Active Sort:  %s %s%s"],sortIcon,C.HEX_WHITE,sortText))
        end
    end

    -- update queue
    rematch.queue:Update()

    -- if queue size has changed, recreated indexes
    if #queueIndexes ~= #settings.LevelingQueue then
        wipe(queueIndexes)
        for i=1,#settings.LevelingQueue do
            tinsert(queueIndexes,i)
        end
    end

    self:UpdateGlow(true) -- true to skip refresh since about to do an Update

    -- update autoscrollbox list
    self.List:Update()
    -- show help text if queue is empty and Hide Extra Help disabled
    self.List.Help:SetShown(#settings.LevelingQueue==0 and not settings.HideMenuHelp)

    -- if any queue-related dialog is on screen when queue updates, close it in case indexes change
    self:CloseQueueDialogs()

end

function rematch.queuePanel:UpdateGlow(skipRefresh)
    -- show GlowFrame is a pet is on cursor
    local petID,canLevel = rematch.utils:GetPetCursorInfo(true)
    self.List.GlowFrame:SetShown(canLevel)
    self.List:Select("Moving",rematch.queue:GetPetIndex(petID),skipRefresh)
end

function rematch.queuePanel:OnShow()
    rematch.events:Register(self,"REMATCH_TEAM_LOADED",self.Update,self)
    rematch.events:Register(self,"REMATCH_PET_PICKED_UP_ON_CURSOR",self.REMATCH_PET_PICKED_UP_ON_CURSOR,self)
    rematch.events:Register(self,"REMATCH_PET_DROPPED_FROM_CURSOR",self.REMATCH_PET_DROPPED_FROM_CURSOR,self)
    self:CloseQueueDialogs()
    self:UpdateGlow()
end

function rematch.queuePanel:OnHide()
    rematch.events:Unregister(self,"REMATCH_TEAM_LOADED")
    rematch.events:Unregister(self,"REMATCH_PET_PICKED_UP_ON_CURSOR")
    rematch.events:Unregister(self,"REMATCH_PET_DROPPED_FROM_CURSOR")
    self:CloseQueueDialogs()
end

-- we need to be a little careful that dialogs don't remain on the screen when the queue indexes can be changing
function rematch.queuePanel:CloseQueueDialogs()
    local openDialog = rematch.dialog:GetOpenDialog()
    if openDialog=="StopActiveSort" or openDialog=="RemoveFromQueue" or openDialog=="FillQueue" or openDialog=="EmptyQueue" then
        rematch.dialog:HideDialog()
    end
end

-- autoscrollbox fill
function rematch.queuePanel:FillNormal(index)
    local info = settings.LevelingQueue[index]
    if info then
        --self.forQueue = true
        local notPreferred = not rematch.preferences:IsPetPreferred(info.petID)
        self:Fill(info.petID,notPreferred)
        self:SetAlpha(notPreferred and 0.65 or 1)
    end
end

-- autoscrollbox fill
function rematch.queuePanel:FillCompact(index)
    local info = settings.LevelingQueue[index]
    if info then
        --self.forQueue = true
        local notPreferred = not rematch.preferences:IsPetPreferred(info.petID)
        self:Fill(info.petID,notPreferred)
        self:SetAlpha(notPreferred and 0.65 or 1)
    end
end

-- click of preferences button in topleft to edit or pause preferences for the loaded team
function rematch.queuePanel.PreferencesFrame.PreferencesButton:OnClick(button)
    if button=="RightButton" then -- right click pauses/unpauses preferences
        rematch.preferences:TogglePause()
    else -- left click opens current preferences dialog to change preferences
        local teamID = settings.currentTeamID
        local groupID = teamID and rematch.savedTeams[teamID] and rematch.savedTeams[teamID].groupID
        rematch.dialog:ToggleDialog("CurrentPreferences",{teamID=teamID,groupID=groupID})
    end
end

-- onenter of preferences button shows the tooltip
function rematch.queuePanel.PreferencesFrame.PreferencesButton:OnEnter()
    rematch.tooltip:ShowSimpleTooltip(self,L["Leveling Preferences"],rematch.preferences:GetTooltipBody())
end

-- onleave of preferences button
function rematch.queuePanel.PreferencesFrame.PreferencesButton:OnLeave()
    rematch.tooltip:Hide()
end

-- click of Queue button in topright to open the menu
function rematch.queuePanel.Top.QueueButton:OnClick()
    rematch.menus:Toggle("QueueMenu",self)
end

-- clear button on statusbar turns off active sort
function rematch.queuePanel.StatusBar.Clear:OnClick()
    settings.QueueActiveSort = false
    if rematch.menus:IsMenuOpen("QueueMenu") then
        rematch.menus:Hide()
    end
    rematch.queuePanel:Update()
end


--[[ queue drag and drop ]]

function rematch.queuePanel:REMATCH_PET_PICKED_UP_ON_CURSOR()
    local petID,canLevel = rematch.utils:GetPetCursorInfo(true)
    if canLevel then
        self.List.GlowFrame:Show()
        self.List:Select("Moving",rematch.queue:GetPetIndex(petID))
    end
    if rematch.dialog:GetOpenDialog()=="StopActiveSort" then
        rematch.dialog:HideDialog()
    end
end

function rematch.queuePanel:REMATCH_PET_DROPPED_FROM_CURSOR()
    self.List.GlowFrame:Hide()
    self.List:Select("Moving",nil)
    if rematch.dialog:GetOpenDialog()=="StopActiveSort" then
        rematch.dialog:HideDialog()
    end
end

function rematch.queuePanel.List.GlowFrame:OnShow()
    if rematch.layout:GetMode()==1 then
        self.GlowLine:SetWidth(C.LIST_BUTTON_WIDE_WIDTH-2)
    else
        self.GlowLine:SetWidth(C.LIST_BUTTON_NORMAL_WIDTH-2)
    end
    self.GlowLine:Hide()
    self.GlowLine.Animation:Play()
    rematch.queuePanel.List.CaptureButton:SetScript("OnClick",rematch.queuePanel.List.CaptureButton.OnClick)
    rematch.queuePanel.List.CaptureButton:SetScript("OnReceiveDrag",rematch.queuePanel.List.CaptureButton.OnClick) -- same as OnClick behavior
end

function rematch.queuePanel.List.GlowFrame:OnHide()
    rematch.queuePanel.List.CaptureButton:SetScript("OnClick",nil)
    rematch.queuePanel.List.CaptureButton:SetScript("OnReceiveDrag",nil)
end

function rematch.queuePanel.List.GlowFrame:OnUpdate(elapsed)
    local focus = GetMouseFoci()[1]
    if not focus then
        return -- while scrolling, focus becomes nil at times
    end
    if focus:GetObjectType()=="Texture" then
        focus = focus:GetParent() -- for script-enabled textures, get the parent listbutton
    end

    local cursorX,cursorY = GetCursorPosition()
    local scale = focus:GetEffectiveScale()
    local centerX,centerY = focus:GetCenter()

    local isMouseOver = MouseIsOver(self) -- is mouse over GlowFrame

    self.GlowLine.direction = nil -- potentially one of C.DRAG_DIRECTION_PREV/NEXT/END

    if MouseIsOver(self) then
        if focus and focus.petID then
            if (cursorY/scale)>centerY then -- if cursor is in top half of button, anchor to top
                self.GlowLine:SetPoint("CENTER",focus,"TOP")
                self.GlowLine.direction = C.DRAG_DIRECTION_PREV
            else -- otherwise anchor to bottom of button
                self.GlowLine:SetPoint("CENTER",focus,"BOTTOM")
                self.GlowLine.direction = C.DRAG_DIRECTION_NEXT
            end
            self.GlowLine:Show()
        elseif focus==rematch.queuePanel.List.CaptureButton then -- cursor is over capture area, anchor to top
            self.GlowLine:SetPoint("CENTER",focus,"TOP")
            self.GlowLine:Show()
        end

    else
        self.GlowLine:Hide()
    end
end

-- click of capture area adds a pet to the queue (OnReceiveDrag also uses this same function)
function rematch.queuePanel.List.CaptureButton:OnClick()
    local petID,canLevel = rematch.utils:GetPetCursorInfo(true)
    if petID and canLevel then
        rematch.queuePanel:ReceivePetID(petID,#settings.LevelingQueue+1)
    end
end

RematchQueueListButtonMixin = {}

-- click override for queue listbutton: rightbutton for menu, if a pet that can level on cursor, receive in queue, otherwise pet card click
function RematchQueueListButtonMixin:OnClick(button)
    local petID,canLevel = rematch.utils:GetPetCursorInfo(true)
    if rematch.petHerder:IsTargeting() then -- targeting with pet herder takes priority on clicks
        if button=="RightButton" then
            rematch.dialog:Hide()
        else
            rematch.petHerder:HerdPetID(self.petID)
        end
    elseif button=="RightButton" then
        rematch.menus:Show("QueueListMenu",self,self.petID,"cursor")
    elseif petID and canLevel then
        self:OnReceiveDrag()
    else
        rematch.cardManager:OnClick(rematch.petCard,self,self.petID)
    end
end

-- called from OnClick too if leveling pet on mouse
function RematchQueueListButtonMixin:OnReceiveDrag()
    local petID,canLevel = rematch.utils:GetPetCursorInfo(true)
    local direction = rematch.queuePanel.List.GlowFrame.GlowLine.direction
    if petID and canLevel then
        rematch.queuePanel:ReceivePetID(petID,self.data+max(0,direction))
    end
end

-- for both capture button and list buttons, this puts the petID at the newIndex (moving from oldIndex if already in queue)
function rematch.queuePanel:ReceivePetID(petID,newIndex)
    local isActiveSort = settings.QueueActiveSort
    local oldIndex = rematch.queue:GetPetIndex(petID) -- if already in queue, then this pet is moving from one position to another
    if not isActiveSort and not oldIndex then
        rematch.queue:InsertPetID(petID,newIndex) -- if not active sort and not in the queue, insert at position
    elseif not isActiveSort and oldIndex then
        rematch.queue:MoveIndex(oldIndex,newIndex) -- if not active sort and in the queue, move from old to new position
    elseif isActiveSort and not oldIndex then
        rematch.queue:InsertPetID(petID,newIndex) -- if active sort and not in the queue, simply add to queue and let it sort
        --rematch.queue:AddPetID(petID)
    elseif isActiveSort and oldIndex then
        if settings.DontConfirmActiveSort then -- if Don't Ask To Stop Active Sort is enabled, can stop active sort and move right away
            settings.QueueActiveSort = false -- if active sort and in the queue, turn off active sort and move to new position
            rematch.queue:MoveIndex(oldIndex,newIndex)
        else -- otherwise show a dialog and leave
            rematch.dialog:ShowDialog("StopActiveSort",{petID=petID,newIndex=newIndex})
            return
        end
    end
    rematch.queue:BlingPetID(petID)
    ClearCursor()
end