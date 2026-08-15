local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.dialog = RematchDialog

--[[
    dialogInfo properties

    title = string text to display in titlebar of dialog
    width = number width of canvas (will use default if none given)
    height = number height of canvas (will use default if none given)
    minHeight = minimum height of canvas if height not given
    prompt = text to display in the prompt at bottom of dialog
    cancel = text for the CancelButton
    cancelFunc = function(canvas,info,subject) to run when CancelButton is clicked
    accept = text for the AcceptButton
    acceptFunc = function(canvas,info,subject) to run when AcceptButton is clicked
    stayOnAccept = boolean whether to keep dialog up if AcceptButton clicked
    other = text for the OtherButton
    otherFunc = function(canvas,info,subject) to run when Other Button is clicked
    stayOnOther = boolean whether to keep dialog up if OtherButton clicked
    refreshFunc = function(canvas,info,subject,firstRun) to refresh dialog contents
    changeFunc = function(canvas,info,subject) called when a control in dialog changes from the user
    conditions = { -- condition across all layouts; for more complex differences, use different layouts
        "CheckButton" = function(canvas,info,subject) return true if CheckButton should show end,
        "Widget" = function(canvas,info,subject) return true if Widget should show end,
    }
    layouts = { -- for multi-layout dialogs
        ["Default"] = {"Text","Pet","etc"}, -- list of controls to use when dialog first opened
        ["AltLayout"] = {"Text","Pet","Feedback","etc"}, -- alternate layout for adding/removing controls
    },
    layout = {"Text","Pet","etc"} -- for single-layout dialogs,
    minimize = { -- only exists if dialog is minimizable
        nextState = string, -- either "minimize" or "maximize"; the minimize icon to display
        nextDialog = string, -- the dialog to open when the minimize/maximize button is clicked
    }

    To change the displayed title:
        rematch.dialog:SetTitle(text)

    On minimizable dialogs, if LayoutTabs are used, make sure the name of the tab is the same as the layout.
    (For instance, "Battles" layout should have a tab with a "Battles" tab identifier). It will attempt to
    return to the tab of the opened layout when it switches to the minimized/maximized dialog.

]]

local dialogInfo = {}
local openDialog -- name of the dialog that's currently open
local openLayout -- name of the dialog's layout currently applied
local lastLayout -- name of the dialog's previous layout (should be nil when dialog first shown)
local refreshHappening -- true of a refresh is happening (to ignore changes)
local applyLayout -- will be ApplyLayout function, to stop me from using it outside this module (use ChangeLayout instead!)

rematch.events:Register(rematch.dialog,"PLAYER_LOGIN",function(self)
    self.InsetBg:SetPoint("BOTTOMRIGHT",-6,C.BOTTOMBAR_HEIGHT+6)
    self:Reset()
    self.CloseButton:SetScript("OnKeyDown",self.CloseButton.OnKeyDown)
    self.MinimizeButton:SetScript("OnClick",function(self,button)
        if self.nextDialog then
            local layout = rematch.dialog:GetOpenLayout()
            local tabsShown = rematch.dialog.Canvas.LayoutTabs:IsVisible()
            rematch.dialog:ShowDialog(self.nextDialog)
            if rematch.dialog:GetOpenLayout()~=layout then
                if tabsShown then
                    rematch.dialog.Canvas.LayoutTabs:GoToTab(layout)
                else
                    rematch.dialog:ChangeLayout(layout)
                end
            end
        end
    end)
end)

function rematch.dialog:OnMouseDown()
    self:StartMoving()
end

function rematch.dialog:OnMouseUp()
    self:StopMovingOrSizing()
end

function rematch.dialog:Register(name,info)
    assert(type(name)=="string","Dialog "..(name or "nil").." has an invalid name")
    assert(type(info)=="table","Dialog "..name.." has no info table")
    info.name = name
    dialogInfo[name] = info
    dialogInfo[name].hasPrompt = info.prompt and true
    -- if single-layout table defined, make it Default of layouts table
    if info.layout then
        assert(type(select(2,next(info.layout)))~="table","Default layout for "..name.." is a nested table. Meant to use layouts?")
        info.layouts= {Default = CopyTable(info.layout)}
        info.layout = nil
    end
    -- assert that all parentKeys in the layouts are valid
    if info.layouts then
        for layoutName,layout in pairs(info.layouts) do
            for _,parentKey in ipairs(layout) do
                assert(self.Canvas[parentKey],"Dialog layout "..layoutName.." for "..name.." has an invalid control "..parentKey)
            end
        end
    end
end

-- returns definition of named dialog (or open one if no name given)
function rematch.dialog:GetDialogInfo(dialog)
    if dialog then
        return dialogInfo[dialog]
    elseif self:IsVisible() then
        return dialogInfo[openDialog]
    end
end

function rematch.dialog:GetOpenDialog()
    return rematch.dialog:IsVisible() and openDialog
end

function rematch.dialog:GetOpenLayout()
    return rematch.dialog:IsVisible() and openLayout or "Default"
end

-- returns the subject of the currently-opened dialog
function rematch.dialog:GetSubject()
    if openDialog and rematch.dialog:IsVisible() and dialogInfo[openDialog] then
        return dialogInfo[openDialog].subject
    end
end

-- if any dialog is open, close it by clicking the Cancel button (if on screen; hide directly otherwise)
-- this allows cancelFuncs to happen when dismissing a dialog
function rematch.dialog:HideDialog()
    if openDialog and rematch.dialog:IsVisible() then
        rematch.dialog.CancelButton:Click()
    else
        rematch.dialog:Hide()
    end
end

function rematch.dialog:ToggleDialog(name,subject,layoutTab)
    if openDialog==name and dialogInfo[name] and rematch.utils:AreSame(dialogInfo[name].subject,subject) then
        rematch.dialog:HideDialog()
    else
        rematch.dialog:ShowDialog(name,subject,layoutTab)
    end
end

function rematch.dialog:ShowDialog(name,subject,layoutTab)
    local info = dialogInfo[name]
    assert(info,"Dialog named "..(name or "nil").." doesn't exist.")
    if not info then return end
    rematch.utils:HideWidgets()
    rematch.dialog:Hide()
    openDialog = name
    lastLayout = nil
    -- add the info to the info space
    info.subject = subject
    info.layoutTab = layoutTab or "Default"
    -- setup title
    self.Title:SetText(info.title)
    -- setup prompt and adjust canvas size for the prompt
    local yoff = C.DIALOG_BOTTOM_MARGIN
    if info.hasPrompt then
        self.Prompt.Text:SetText(info.prompt)
        self.Prompt:Show()
        yoff = yoff + C.DIALOG_PROMPT_HEIGHT
    else
        self.Prompt:Hide()
    end
    self.Canvas:SetPoint("TOPLEFT",C.DIALOG_LEFT_MARGIN,-C.DIALOG_TOP_MARGIN)
    self.Canvas:SetPoint("BOTTOMRIGHT",-C.DIALOG_RIGHT_MARGIN,yoff)
    -- setup panel buttons
    self.CancelButton.Text:SetText(info.cancel)
    self.CancelButton:SetShown(info.cancel and true)
    self.AcceptButton.Text:SetText(info.accept)
    self.AcceptButton:SetShown(info.accept and true)
    self.OtherButton.Text:SetText(info.other)
    self.OtherButton:SetShown(info.other and true)
    self.MinimizeButton:SetShown(type(info.minimize)=="table")
    if type(info.minimize)=="table" then
        self.MinimizeButton:SetIcon(info.minimize.nextState)
        self.MinimizeButton.nextDialog = info.minimize.nextDialog
    end
    -- start with the Default layout
    self:ChangeLayout("Default",true)
    -- if info.layouts and info.layouts.Default then
    --     self:ApplyLayout("Default")
    -- end
    -- -- run first refresh
    -- if info.refreshFunc then
    --     refreshHappening = true
    --     self:StartRefresh()
    --     info.refreshFunc(self.Canvas,info,subject,true)
    -- end
    -- -- set up dialog size
    -- self:Resize()
    -- finally, show the dialog
    rematch.dialog:Show()
    -- if choosing to open in a layoutTab (dialog mixin) other than Default, go to it now
    if layoutTab and layoutTab~="Default" and self.Canvas.LayoutTabs:IsVisible() then
        self.Canvas.LayoutTabs:GoToTab(layoutTab)
    end
end

-- changes the currently-opened dialog to the given layoutName; firstRun is true if this is the first layout
-- being applied
function rematch.dialog:ChangeLayout(layoutName,firstRun)
    local info = dialogInfo[openDialog]
    if info.layouts[layoutName] and (openLayout~=layoutName or firstRun) then -- only attempt to change to a layout that exists and we're not already in
        applyLayout(self,layoutName)
        if info.refreshFunc then
            refreshHappening = true
            self:StartRefresh()
            info.refreshFunc(self.Canvas,info,info.subject,firstRun)
        end
        self:Resize()
    end
end

-- some dialogs may want to change the title displayed at the top
function rematch.dialog:SetTitle(text)
    self.Title:SetText(text)
end

-- clear out everything
function rematch.dialog:Reset()
    openDialog = nil
    openLayout = nil
    -- hide all children of the canvas
    for _,child in pairs({self.Canvas:GetChildren()}) do
        child:Hide()
        if type(child.Reset)=="function" then
            child.Reset(child) -- if element has a reset function, run it
        end
    end
    self.MinimizeButton:Hide()
    self.MinimizeButton.nextDialog = nil
    -- enable buttons that may have been disabled
    self.AcceptButton:Enable()
    self.OtherButton:Enable()
    self.CancelButton:Enable()
    -- clear tooltips on panel buttons (so far just OtherButton has one; add RematchTooltipScripts to Accept or Cancel if needed)
    self.OtherButton.tooltipTitle = nil
    self.OtherButton.tooltipBody = nil
end

-- call when the currently opened dialog needs to be refreshed
function rematch.dialog:Refresh()
    local info = dialogInfo[openDialog]
    if not info then return end
    if info.refreshFunc then
        self:StartRefresh()
        info.refreshFunc(self.Canvas,info,info.subject)
    end
end

-- when dialog hides, reset the dialog
function rematch.dialog:OnHide()
    self:Reset()
    rematch.utils:SetUIJustChanged()
    rematch.menus:Hide()
    PlaySound(C.SOUND_DIALOG_CLOSE)
end

function rematch.dialog:OnShow()
    PlaySound(C.SOUND_DIALOG_OPEN)
    -- if settings.DialogX and settings.DialogY then
    --     self:ClearAllPoints()
    --     self:SetPoint("CENTER",UIParent,"BOTTOMLEFT",settings.DialogX,settings.DialogY)
    -- end
end

-- if ESC is hit, close dialog via the cancel button
function rematch.dialog.CloseButton:OnKeyDown(key)
    if key==GetBindingKey("TOGGLEGAMEMENU") then
        -- if a teampicker list is expanded and CollapseOnEsc enabled, collapse list
        if settings.CollapseOnEsc and rematch.dialog.Canvas.TeamPicker.Picker.List:IsVisible() and rematch.dialog.Canvas.TeamPicker.Picker.List:IsAnyExpanded() then
            rematch.dialog.Canvas.TeamPicker.Picker.List:ToggleAllHeaders()
        else
            rematch.dialog.CancelButton:Click()
        end
        self:SetPropagateKeyboardInput(false)
    else
        self:SetPropagateKeyboardInput(true)
    end
end

-- takes a layout name (index into dialogInfo[openDialog].layouts) and displays the layout's controls on the canvas
-- (it's up to the refresh function to modify the controls)
function applyLayout(self,layoutName)
    local info = dialogInfo[openDialog]
    if not info then return end
    -- hide all children of the canvas
    for _,child in pairs({self.Canvas:GetChildren()}) do
        child:Hide()
    end
    local layout = info.layouts and info.layouts[layoutName]
    assert(type(layout)=="table","Layout "..(layoutName or "nil").. " doesn't exist for "..info.name)
    lastLayout = openLayout
    openLayout = layoutName
    local canvas = self.Canvas
    local lastControl
    for _,parentKey in pairs(layout) do
        if parentKey=="Help" and settings.HideMenuHelp then
            -- do nothing with "Help" while HideMenuHelp is enabled
        elseif info.conditions and type(info.conditions[parentKey])=="function" and not info.conditions[parentKey](self.Canvas,info,info.subject) then
            -- do nothing with parentKey if it has a condition and the condition isn't met (function returns false)
        else
            local control = canvas[parentKey]
            if control then
                if control.fixedWidth==0 then
                    -- don't touch width if fixedWidth is 0
                elseif control.fixedWidth then
                    control:SetWidth(control.fixedWidth)
                else
                    control:SetWidth((info.width or C.DIALOG_DEFAULT_WIDTH)-2*C.DIALOG_OUTER_PADDING)
                end
                control:ClearAllPoints()
                if not lastControl then
                    control:SetPoint("TOP",0,-C.DIALOG_OUTER_PADDING)
                else
                    control:SetPoint("TOP",lastControl,"BOTTOM",0,-C.DIALOG_INNER_PADDING)
                end
                lastControl = control
                control:Show()
            end
        end
    end
end

-- changes layout to the previous layout within the same dialog
function rematch.dialog:ReturnToPreviousLayout()
    local info = dialogInfo[openDialog]
    if not info then return end
    if lastLayout and info.layouts and info.layouts[lastLayout] then
        rematch.dialog:ChangeLayout(lastLayout)
    end
end

-- resizes the dialog (based on layout, defined height or default height of canvas)
function rematch.dialog:Resize()
    local width,height
    local info = dialogInfo[openDialog]
    if not info then return end
    -- width generally won't change for the life of the dialog
    width = max(info.width or C.DIALOG_DEFAULT_WIDTH,C.DIALOG_MIN_WIDTH)
    self:SetWidth(width + C.DIALOG_LEFT_MARGIN + C.DIALOG_RIGHT_MARGIN)
    local buttonWidth = (width+10)/3
    self.CancelButton:SetWidth(buttonWidth)
    self.AcceptButton:SetWidth(buttonWidth)
    self.OtherButton:SetWidth(buttonWidth)
    -- if using a layout, use it for height
    if info.layouts and openLayout and info.layouts[openLayout] then
        height = C.DIALOG_OUTER_PADDING*2
        for _,parentKey in pairs(info.layouts[openLayout]) do
            if parentKey=="Help" and settings.HideMenuHelp then
                -- don't add Help if HideMenuHelp enabled
            elseif info.conditions and type(info.conditions[parentKey])=="function" and not info.conditions[parentKey](self.Canvas,info,info.subject) then
                -- don't add parentKey if it has a condition and the condition isn't met (function returns false)
            else
                height = height + self.Canvas[parentKey]:GetHeight() + C.DIALOG_INNER_PADDING
            end
        end
        height = height - C.DIALOG_INNER_PADDING -- remove last inner padding
    else -- otherwise use a defined height or default if none defined
        height = info.height or C.DIALOG_DEFAULT_HEIGHT
    end
    height = max(height,C.DIALOG_MIN_HEIGHT)
    if info.minHeight and not info.height then
        height = max(height,info.minHeight)
    end
    --local left = self:GetLeft() -- storing topleft position before resize
    --local top = self:GetTop()
    self:SetHeight(height + C.DIALOG_TOP_MARGIN + (info.hasPrompt and C.DIALOG_PROMPT_HEIGHT or 0) + C.DIALOG_BOTTOM_MARGIN)
    --self:ClearAllPoints()
    --self:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",left,top) -- restore topleft so shifting height keeps topleft stable
end

-- any control that can change (editboxes, checkbuttons, etc) should call this to run the dialog's changeFunc
function rematch.dialog:OnChange(force)
    if refreshHappening then
        return -- ignoring changes happening during a refresh
    end
    local info = dialogInfo[openDialog]
    if not info then return end
    if info.changeFunc then
        info.changeFunc(rematch.dialog.Canvas,info,info.subject)
    end
end

-- called a frame after StartRefresh() to reset the refreshHappening flag
local function finishRefresh()
    refreshHappening = false
end

-- call this before a refresh starts to set the refreshHappening flag to true
function rematch.dialog:StartRefresh()
    refreshHappening = true
    rematch.timer:Start(0,finishRefresh) -- wait a frame to set it back to false
end
