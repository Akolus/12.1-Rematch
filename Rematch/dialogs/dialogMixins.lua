local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings

--[[ Red panel buttons across bottom of dialog ]]

RematchDialogPanelButtonMixin = {}

function RematchDialogPanelButtonMixin:OnClick()
    local info = rematch.dialog:GetDialogInfo()
    if not info then
        return
    end
    -- for acceptFunc or otherFunc (if defined) run them before closing dialog in case any OnHides reset controls
    if self==rematch.dialog.AcceptButton and info.acceptFunc then
        info.acceptFunc(rematch.dialog.Canvas,info,info.subject)
        if info.stayOnAccept then
            return -- don't hide dialog if stayOnAccept defined
        end
    elseif self==rematch.dialog.OtherButton and info.otherFunc then
        info.otherFunc(rematch.dialog.Canvas,info,info.subject)
        if info.stayOnOther then
            return -- don't hide dialog if stayOnOther defined
        end
    end
    rematch.dialog:Hide()
    -- run cancelFunc after the dialog hides in case another dialog wants to be shown in this cancelFunc
    if self==rematch.dialog.CancelButton and info.cancelFunc then
        info.cancelFunc(rematch.dialog.Canvas,info,info.subject)
    end
end

--[[ Text, SmallText and Help dialog controls ]]

RematchDialogTextMixin = {}

function RematchDialogTextMixin:SetText(text)
    self.Text:SetText(text)
    self:SetHeight(self.Text:GetStringHeight())
end

function RematchDialogTextMixin:SetTextColor(r,g,b)
    self.Text:SetTextColor(r,g,b)
end

function RematchDialogTextMixin:Reset()
    if self==rematch.dialog.Canvas.Help then
        self.Text:SetTextColor(0.85,0.85,0.85)
    end
end

--[[ Feedback dialog control ]]

RematchDialogFeedbackMixin = {}

-- for Feedback widget with an icon+text, this function is called from canvas.Feedback:Set(icon,text)
-- and will set the icon to one for "warning", "info", "success", "failure" or "unknown" and color text appropriately
-- if icon is none of those, then it will use that icon and set text to white
function RematchDialogFeedbackMixin:Set(icon,text)
    if icon=="warning" then
        self.Icon:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
        self.Text:SetTextColor(1,0.5,0.25)
    elseif icon=="info" then
        self.Icon:SetTexture("Interface\\Common\\help-i")
        self.Text:SetTextColor(1,0.82,0)
    elseif icon=="success" then
        self.Icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        self.Text:SetTextColor(0,1,0)
    elseif icon=="failure" or icon=="invalid" then
        self.Icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
        self.Text:SetTextColor(1,0.25,0.25)
    elseif icon=="unknown" then
        self.Icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
        self.Text:SetTextColor(1,0.82,0)
    elseif icon=="mail" then
        self.Icon:SetTexture("Interface\\HelpFrame\\ReportLagIcon-Mail")
        self.Text:SetTextColor(0.533,0.733,1)
    else
        self.Icon:SetTexture(icon)
        self.Text:SetTextColor(0.9,0.9,0.9)
    end
    self.Text:SetText(text)
end

-- for dialogs that "hide" feedback by setting its alpha to 0, reset to make it visible for other dialogs
function RematchDialogFeedbackMixin:Reset()
    self:SetAlpha(1)
end

--[[ EditBox dialog control ]]

RematchDialogEditBoxMixin = {}

function RematchDialogEditBoxMixin:SetText(text,highlight)
    self.EditBox:SetText(text)
    if highlight then
        self.EditBox:HighlightText()
    end
end

function RematchDialogEditBoxMixin:SetTextColor(r,g,b)
    self.EditBox:SetTextColor(r,g,b)
end

function RematchDialogEditBoxMixin:SetLabel(text)
    self.Label:SetText(text)
end

function RematchDialogEditBoxMixin:GetText()
    return self.EditBox:GetText()
end

function RematchDialogEditBoxMixin:SetEnabled(enable)
    self.EditBox:SetEnabled(enable)
    if not enabled then
        self.EditBox:ClearHighlightText()
        self.EditBox.Clear:Hide()
    end
    for i=1,3 do
        self.EditBox.Back[i]:SetShown(enable)
    end
end

function RematchDialogEditBoxMixin:OnLoad()
    self.EditBox:SetScript("OnEscapePressed",function(self)
        rematch.dialog.CancelButton:Click()
    end)
    self.EditBox:SetScript("OnTabPressed",function(self)
        if rematch.dialog.Canvas.MultiLineEditBox:IsVisible() then
            rematch.dialog.Canvas.MultiLineEditBox:SetFocus(true)
        end
    end)
    self.EditBox:SetScript("OnEnterPressed",function(self)
        if rematch.dialog.AcceptButton:IsEnabled() then
            rematch.dialog.AcceptButton:Click()
        end
    end)
    self.EditBox:SetScript("OnTextChanged",function(self)
        rematch.dialog:OnChange() -- function to call the changeFunc
    end)
end

--[[ MultiLineEditBox dialog control ]]

RematchDialogMultiLineEditBoxMixin = {}

function RematchDialogMultiLineEditBoxMixin:SetText(text,highlight)
    if type(text)~="table" then
        self.ScrollFrame.EditBox:SetText(text or "")
        if highlight then
            self.ScrollFrame.EditBox:HighlightText()
        end
    else
        rematch.utils.SpoolText(self,self.ScrollFrame.EditBox,text,highlight)
    end
end

function RematchDialogMultiLineEditBoxMixin:GetText()
    return self.ScrollFrame.EditBox:GetText()
end

function RematchDialogMultiLineEditBoxMixin:SetFocus(getFocus)
    self.ScrollFrame.EditBox:SetFocus(getFocus)
end

function RematchDialogMultiLineEditBoxMixin:ScrollToTop()
    self.ScrollFrame.EditBox:SetCursorPosition(0)
end

function RematchDialogMultiLineEditBoxMixin:OnLoad()
    -- EditBox
    self.ScrollFrame.EditBox:SetScript("OnEscapePressed",function(self)
        rematch.dialog:Hide()
    end)
    self.ScrollFrame.EditBox:SetScript("OnTabPressed",function(self)
        self:Insert("  ")
    end)
    self.ScrollFrame.EditBox:SetScript("OnCursorChanged",function(self,x,y,w,h)
        ScrollingEdit_OnCursorChanged(self, x, y, w, h)
    end)
    self.ScrollFrame.EditBox:SetScript("OnUpdate",function(self,elapsed)
        ScrollingEdit_OnUpdate(self, elapsed, self:GetParent())
    end)
    self.ScrollFrame.EditBox:SetScript("OnTextChanged",function(self,userInput)
        if userInput then
            rematch.dialog.OnChange(self)
        end
    end)
    -- setup ScrollFrame
    local scrollBar = self.ScrollFrame.ScrollBar
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPRIGHT",4,-12)
    scrollBar:SetPoint("BOTTOMRIGHT",4,11)
    local up = _G[scrollBar:GetName().."ScrollUpButton"]
    local down = _G[scrollBar:GetName().."ScrollDownButton"]
    scrollBar.trackBG:SetColorTexture(0.03,0.03,0.03)
    scrollBar.trackBG:SetPoint("TOPLEFT",up,"TOPLEFT",0,-4)
    scrollBar.trackBG:SetPoint("BOTTOMRIGHT",down,"BOTTOMRIGHT",-1,4)
    up:SetPoint("TOP",0,13)
    down:SetPoint("BOTTOM",0,-13)
    -- ScrollFrame script handlers
    self.ScrollFrame:SetScript("OnSizeChanged",function(self,w)
        self.EditBox:SetWidth(w-23)
    end)
    self.ScrollFrame:SetScript("OnMouseDown",function(self)
        self.EditBox:SetFocus(true)
    end)
    self.ScrollFrame:SetScript("OnHide",function(self)
        self.PleaseWait:Hide()
    end)
end

function RematchDialogMultiLineEditBoxMixin:OnHide()
    self:SetHeight(C.DIALOG_MULTILINE_EDITBOX_HEIGHT)
end

--[[ CheckButton dialog control ]]

RematchDialogCheckButtonMixin = {}

function RematchDialogCheckButtonMixin:SetText(text)
    self.Check:SetText(text)
    self.Check:ClearAllPoints()
    self.Check:SetPoint("CENTER",2-(self.Check.Text:GetStringWidth()/2),0)
end

function RematchDialogCheckButtonMixin:SetChecked(isChecked)
    self.Check:SetChecked(isChecked)
end

function RematchDialogCheckButtonMixin:GetChecked()
    return self.Check:GetChecked()
end

function RematchDialogCheckButtonMixin:OnLoad()
    self.Check:SetScript("OnClick",function(self)
        rematch.dialog.OnChange(self)
    end)
end

function RematchDialogCheckButtonMixin:SetEnabled(isEnabled)
    self.Check:SetEnabled(isEnabled)
end

function RematchDialogCheckButtonMixin:Reset()
    self.Check:Enable()
    self.Check:SetChecked(false)
    self.Check.tooltipTitle = nil
    self.Check.tooltipBody = nil
end

--[[ Icon dialog control ]]

RematchDialogIconMixin = {}

function RematchDialogIconMixin:SetTexture(texture)
    self.Texture:SetTexture(texture)
end

function RematchDialogIconMixin:SetTexCoord(...)
    self.Texture:SetTexCoord(...)
end

--[[ ColorPicker dialog control ]]

RematchDialogColorPickerMixin = {}

function RematchDialogColorPickerMixin:OnLoad()
    self.Swatches[1]:SetColor() -- set first swatch to nil/default color
    local colors = {}
    -- add expansion colors first
    for i=0,#C.EXPANSION_COLORS do
        tinsert(colors,C.EXPANSION_COLORS[i])
    end
    -- add additional group colors
    for _,color in ipairs(C.COLOR_PICKER_COLORS) do
        tinsert(colors,color)
    end
    for i=1,#colors do
        self.Swatches[i+1] = CreateFrame("Button",nil,self,"RematchDialogColorPickerSwatchTemplate")
        if (i)%9==0 then
            self.Swatches[i+1]:SetPoint("TOPLEFT",self.Swatches[i-8],"BOTTOMLEFT",0,-4)
        else
            self.Swatches[i+1]:SetPoint("TOPLEFT",self.Swatches[i],"TOPRIGHT",4,0)
        end
        self.Swatches[i+1]:SetColor(colors[i])
    end
    self:SetHeight(ceil((#colors+1)/9)*24-4+8)
end

function RematchDialogColorPickerMixin:Update()
    for i=1,#self.Swatches do
        self.Swatches[i].Selected:SetShown(self.Swatches[i].color==self.color)
    end
end

function RematchDialogColorPickerMixin:Set(color)
    if not color then
        self:Reset()
    else
        self.color = color
        self:Update()
    end
end

function RematchDialogColorPickerMixin:Reset()
    self.color = nil
    self:Update()
end

-- Swatches in color picker dialog control

RematchDialogColorPickerSwatchTemplateMixin = {}

function RematchDialogColorPickerSwatchTemplateMixin:OnClick()
    self:GetParent().color = self.color
    self:GetParent():Update()
    rematch.dialog.OnChange(self:GetParent())
end

--[[ DropDown dialog control ]]

RematchDialogDropDownMixin = {}

function RematchDialogDropDownMixin:SetLabel(text)
    if self.Label then
        self.Label:SetText(text)
    end
end

function RematchDialogDropDownMixin:GetSelection()
    return self.DropDown:GetSelection()
end

--[[ RematchDialogPetMixin ]]

RematchDialogPetMixin = {}

function RematchDialogPetMixin:Fill(petID)
    self.ListButtonPet:Fill(petID)
end

--[[ RematchDialogTeamMixin ]]

RematchDialogTeamMixin = {}

function RematchDialogTeamMixin:Fill(teamID)
    self.ListButtonTeam:Fill(teamID)
end

--[[ LayoutTabs dialog control ]]

RematchDialogLayoutTabsMixin = {}

function RematchDialogLayoutTabsMixin:OnLoad()
    for _,tab in ipairs(self.Tabs) do
        tab:SetScript("OnClick",self.TabOnClick)
    end
end

-- takes an ordered list of {name,layout[,hasStuffFunc,clearStuffFunc]},{name,layout[,hasStuffFunc,clearStuffFunc]},etc (up to 4) and creates tabs
-- hasStuffFunc returns true if this tab has stuff to clear (blue highlight in tab)
-- clearStuffFunc clears the content in the tab
-- clicking one of the tabs changes to the associated named layout
function RematchDialogLayoutTabsMixin:SetTabs(layouts)
    assert(type(layouts)=="table" and type(layouts[1])=="table" and #layouts[1]>=2,"Invalid LayoutTabs. Must be {{tab_name, layout_name}, {tab_name, layout_name}, etc.}")
    self.layouts = layouts
    local numTabs = min(#layouts,#self.Tabs) -- maxing at 4 tabs
    for i=1,numTabs do
        self.Tabs[i].layout = layouts[i][2]
        self.Tabs[i]:SetText(layouts[i][1])
        self.Tabs[i]:SetSelected(i==1) -- first tab is always first one selected
        self.Tabs[i]:Show()
    end
    for i=numTabs+1,#self.Tabs do
        self.Tabs[i]:Hide()
    end
    self.RightBorder:SetPoint("BOTTOMLEFT",self.Tabs[numTabs],"BOTTOMRIGHT")
    self.Clear:SetScript("OnClick",function() -- note self is the mixin here using closure
        local tabNeedsCleared
        for i=1,#self.layouts do
            if rematch.dialog:GetDialogInfo().layoutTab==self.layouts[i][2] and type(self.layouts[i][3])=="function" and self.layouts[i][3](self:GetParent()) then
                tabNeedsCleared = i -- the current tab needs cleared
            end
        end
        -- if tabNeedsCleared define, only clear that tab; otherwise clear all tabs
        for i=tabNeedsCleared or 1,tabNeedsCleared or #self.layouts do
            if self.layouts[i][4] and type(self.layouts[i][4])=="function" then
                self.layouts[i][4](self:GetParent()) -- run the clearStuffFunc for the tab if defined
            end
        end
        self:Update()
    end)
end

function RematchDialogLayoutTabsMixin:TabOnClick()
    local tabs = self:GetParent().Tabs
    for i=1,#tabs do
        tabs[i]:SetSelected(self:GetID()==i)
    end
    rematch.menus:Hide()
    rematch.dialog:GetDialogInfo().layoutTab = self:GetParent().layouts[self:GetID()][2]
    rematch.dialog:ChangeLayout(self.layout)
end

-- goes to a layout tab by layoutname ("Default", "Preferences", etc; non-localized)
function RematchDialogLayoutTabsMixin:GoToTab(layoutTab)
    -- go through each layout and click the one named
    for i,tab in ipairs(self.layouts) do
        if tab[2]==layoutTab then
            self.Tabs[i]:Click()
        end
    end
end

-- hide the HasStuff blue highlight when layout tabs are hidden
function RematchDialogLayoutTabsMixin:OnHide()
    for _,tab in ipairs(self.Tabs) do
        tab.HasStuff:Hide()
    end
    self.Clear:Hide()
end

-- call in a dialog's OnChange to update the highlights and whether the clear button is shown
function RematchDialogLayoutTabsMixin:Update()
    local hasStuff = false
    for i=1,#self.layouts do
        if self.layouts[i][3] and type(self.layouts[i][3])=="function" and self.layouts[i][3](self:GetParent()) then
            self.Tabs[i].HasStuff:Show()
            hasStuff = true
        else
            self.Tabs[i].HasStuff:Hide()
        end
    end
    self.Clear:SetShown(hasStuff)
end

--[[ Small editboxes in preferences dialog control (min/max health/level) ]]

RematchDialogNumberEditBoxMixin = {}

function RematchDialogNumberEditBoxMixin:OnTextChanged()
    local text=self:GetText()
    local valid=text:gsub("[^\.0123456789]","")
    if text~=valid then
        self:SetText(valid)
    end
    self.Clear:SetShown(valid and valid:len()>0)
    rematch.dialog:OnChange()
end

function RematchDialogNumberEditBoxMixin:OnTabPressed()
    if self.tabNext and self:GetParent()[self.tabNext] then
        self:GetParent()[self.tabNext]:SetFocus()
    end
end

function RematchDialogNumberEditBoxMixin:OnEnterPressed()
    if rematch.dialog.AcceptButton:IsEnabled() then
        rematch.dialog.AcceptButton:Click()
    end
end

function RematchDialogNumberEditBoxMixin:AllowEdits(enabled)
    if enabled then
        self:Enable()
        self.Label:SetTextColor(1,0.82,0)
    else
        self:Disable()
        self.Label:SetTextColor(0.5,0.5,0.5)
        self:ClearHighlightText()
        self.Clear:Hide()
    end
end

--[[ Preferences dialog control ]]

RematchDialogPreferencesMixin = {}

function RematchDialogPreferencesMixin:OnLoad()
    -- labels
    self.LevelLabel:SetText(L["Level"])
    self.MinLevel.Label:SetText(L["Min:"])
    self.MaxLevel.Label:SetText(L["Max:"])
    self.HealthLabel:SetText(L["Health"])
    self.MinHealth.Label:SetText(L["Min:"])
    self.MaxHealth.Label:SetText(L["Max:"])
    self.AllowMM:SetText(format(L["%s %s or %s"],L["Allow any"],C.MAGIC_TEXT_ICON,C.MECHANICAL_TEXT_ICON))
    self.ExpectedDamage.Label:SetText(L["Expected Damage Taken:"])
    -- tooltips
    self.MinLevel.tooltipTitle = L["Minimum Level"]
    self.MinLevel.tooltipBody = L["This is the minimum level preferred for a leveling pet.\n\nLevels can be partial amounts. Level 4.33 is level 4 with 33% xp towards level 5."]
    self.MaxLevel.tooltipTitle = L["Maximum Level"]
    self.MaxLevel.tooltipBody = L["This is the maximum level preferred for a leveling pet.\n\nLevels can be partial amounts. Level 23.45 is level 23 with 45% xp towards level 24."]
    self.MinHealth.tooltipTitle = L["Minimum Health"]
    self.MinHealth.tooltipBody = L["This is the minimum health preferred for a leveling pet.\n\nThe queue will prefer leveling pets with at least this much health (adjusted by expected damage taken if any chosen)."]
    self.MaxHealth.tooltipTitle = L["Maximum Health"]
    self.MaxHealth.tooltipBody = L["This is the maximum health preferred for a leveling pet."]
    self.AllowMM.tooltipTitle = format(L["%s %s or %s"],L["Allow any"],C.MAGIC_TEXT_ICON,C.MECHANICAL_TEXT_ICON)
    self.AllowMM.tooltipBody = L["Allow low-health and low-level Magic or Mechanical pets to ignore the Minimum Health or Level, since their racials allow them to often survive a hit that would ordinarily kill them."]

    self.AllowMM:SetScript("OnClick",function(self)
        rematch.dialog:OnChange()
        PlaySound(C.SOUND_CHECKBUTTON)
    end)
end

-- sets the preferences control to the given values (unordered table of minHP, maxHP, minXP, maxXP, allowMM, expectedDD)
function RematchDialogPreferencesMixin:Set(values)
    if type(values)~="table" then
        values = {} -- nothing given, clear everything
    end
    self.MinHealth:SetText(tonumber(values.minHP) or "")
    self.MaxHealth:SetText(tonumber(values.maxHP) or "")
    self.MinLevel:SetText(tonumber(values.minXP) or "")
    self.MaxLevel:SetText(tonumber(values.maxXP) or "")
    self.AllowMM:SetChecked(values.allowMM and true)
    self.expectedDD = tonumber(values.expectedDD)
    self:UpdateExpectedDamage()
    rematch.dialog:OnChange()
end

-- returns the currently picked preferences in the control as an unordered table
-- if utable given, preferences will be stored in that table; otherwise a reused table returned
local preferencesResults = {} -- reused to minimize garbage creation; but be careful not to assign this table reference to anything!
function RematchDialogPreferencesMixin:Get(utable)
    local results = utable or preferencesResults
    wipe(results)
    results.minHP = tonumber(self.MinHealth:GetText())
    results.maxHP = tonumber(self.MaxHealth:GetText())
    results.minXP = tonumber(self.MinLevel:GetText())
    results.maxXP = tonumber(self.MaxLevel:GetText())
    results.allowMM = self.AllowMM:GetChecked() or nil
    results.expectedDD = self.expectedDD
    return results
end

-- if disable is true, desaturate all buttons
function RematchDialogPreferencesMixin:UpdateExpectedDamage()
    self.ExpectedDamage.Selected:Hide()
    for i=1,10 do
        if self.expectedDD==i and not self.isDisabled then
            self.ExpectedDamage.Selected:SetPoint("TOPLEFT",self.ExpectedDamage.Buttons[i],"TOPLEFT",-1,1)
            self.ExpectedDamage.Selected:SetPoint("BOTTOMRIGHT",self.ExpectedDamage.Buttons[i],"BOTTOMRIGHT",1,-1)
            self.ExpectedDamage.Selected:Show()
        end
        if not self.isDisabled then
            self.ExpectedDamage.Buttons[i]:SetDesaturated(self.expectedDD and self.expectedDD~=i)
        else
            self.ExpectedDamage.Buttons[i]:SetDesaturated(true)
        end
    end
end

-- returns true if any control has a value that needs cleared
function RematchDialogPreferencesMixin:IsAnyUsed()
    return (tonumber(self.MinHealth:GetText()) or tonumber(self.MaxHealth:GetText()) or tonumber(self.MinLevel:GetText()) or tonumber(self.MaxLevel:GetText()) or self.AllowMM:GetChecked() or self.expectedDD) and true or false
end

function RematchDialogPreferencesMixin:SetEnabled(enable)
    self.isDisabled = not enable
    self.MinLevel:AllowEdits(enable)
    self.MaxLevel:AllowEdits(enable)
    self.MinHealth:AllowEdits(enable)
    self.MaxHealth:AllowEdits(enable)
    self.AllowMM:SetEnabled(enable)
    if enable then
        self.LevelLabel:SetTextColor(1,0.82,0)
        self.HealthLabel:SetTextColor(1,0.82,0)
        self.AllowMM:SetText(format(L["%s %s or %s"],L["Allow any"],C.MAGIC_TEXT_ICON,C.MECHANICAL_TEXT_ICON))
        self.ExpectedDamage.Label:SetTextColor(1,0.82,0)
        self:UpdateExpectedDamage()
    else
        self.LevelLabel:SetTextColor(0.5,0.5,0.5)
        self.HealthLabel:SetTextColor(0.5,0.5,0.5)
        self.AllowMM:SetText(format(L["%s %s or %s"],L["Allow any"],C.MAGIC_DISABLED_TEXT_ICON,C.MECHANICAL_DISABLED_TEXT_ICON))
        self.ExpectedDamage.Label:SetTextColor(0.5,0.5,0.5)
        self:UpdateExpectedDamage()
    end
end

-- automatically called when dialog closes, re-enables preferences if it wasn't enabled
function RematchDialogPreferencesMixin:Reset()
    self:SetEnabled(true)
end

--[[ Preferences Expected Damage buttons ]]

RematchDialogExpectedDDMixin = {}

function RematchDialogExpectedDDMixin:OnEnter()
    if not self:GetParent():GetParent().isDisabled then
        rematch.textureHighlight:Show(self)
    end
    local minHP = tonumber(self:GetParent():GetParent().MinHealth:GetText())
    if not minHP then
        rematch.tooltip:ShowSimpleTooltip(self,L["Expected Damage Taken"],L["The minimum health of pets can be adjusted by the type of damage they are expected to receive."])
    else
        rematch.tooltip:ShowSimpleTooltip(self,format(L["Damage Expected: %s"],rematch.utils:PetTypeAsText(self.key)))
        rematch.tooltip:AddLine(format(L["Minimum Health: %d"],minHP))
        rematch.tooltip:AddLine(format(L["  For %s pets: \124cffffffff%d"],rematch.utils:PetTypeAsText(C.HINTS_OFFENSE[self.key][1]),minHP*1.5))
        rematch.tooltip:AddLine(format(L["  For %s pets: \124cffffffff%d"],rematch.utils:PetTypeAsText(C.HINTS_OFFENSE[self.key][2]),minHP*2/3))
        rematch.tooltip:Show()
    end
end

function RematchDialogExpectedDDMixin:OnLeave()
    rematch.textureHighlight:Hide()
    rematch.tooltip:Hide()
end

function RematchDialogExpectedDDMixin:OnMouseDown()
    if not self:GetParent():GetParent().isDisabled then
        rematch.textureHighlight:Hide()
    end
end

function RematchDialogExpectedDDMixin:OnMouseUp()
    if self:IsMouseMotionFocus() and not self:GetParent():GetParent().isDisabled then
        rematch.textureHighlight:Show(self)
        local preferences = self:GetParent():GetParent() -- texture -> ExpectedDamage -> Preferences
        if preferences.expectedDD==self.key then
            preferences.expectedDD = nil
        else
            preferences.expectedDD = self.key
        end
        preferences:UpdateExpectedDamage()
        rematch.dialog:OnChange()
    end
end

--[[ Read-Only Preferences for non-editable display of preferences ]]

RematchDialogPreferencesReadOnlyMixin = {}

function RematchDialogPreferencesReadOnlyMixin:OnLoad()
    -- labels
    self.LevelLabel:SetText(L["Level"])
    self.MinLevel.Label:SetText(L["Min:"])
    self.MaxLevel.Label:SetText(L["Max:"])
    self.HealthLabel:SetText(L["Health"])
    self.MinHealth.Label:SetText(L["Min:"])
    self.MaxHealth.Label:SetText(L["Max:"])
    self.ExpectedDamage.Label:SetText(L["Expected Damage Taken:"])
end

function RematchDialogPreferencesReadOnlyMixin:Set(values)
    if type(values)~="table" then
        values = {} -- nothing given, clear everything
    end
    local minHP = tonumber(values.minHP)
    rematch.utils:SetDimText(self.MinHealth.Label,not minHP)
    self.MinHealth.Text:SetText(minHP or "")
    local maxHP = tonumber(values.maxHP)
    rematch.utils:SetDimText(self.MaxHealth.Label,not maxHP)
    self.MaxHealth.Text:SetText(tonumber(values.maxHP) or "")
    local minXP = tonumber(values.minXP)
    rematch.utils:SetDimText(self.MinLevel.Label,not minXP)
    self.MinLevel.Text:SetText(minXP or "")
    local maxXP = tonumber(values.maxXP)
    rematch.utils:SetDimText(self.MaxLevel.Label,not maxXP)
    self.MaxLevel.Text:SetText(maxXP or "")
    rematch.utils:SetDimText(self.LevelLabel,not minXP and not maxXP)
    rematch.utils:SetDimText(self.HealthLabel,not minHP and not maxHP)

    rematch.utils:SetDimText(self.ExpectedDamage.Label,not values.expectedDD)
    self.ExpectedDamage.Selected:Hide()
    for i=1,10 do
        if values.expectedDD==i then
            self.ExpectedDamage.Selected:SetPoint("TOPLEFT",self.ExpectedDamage.Buttons[i],"TOPLEFT",-1,1)
            self.ExpectedDamage.Selected:SetPoint("BOTTOMRIGHT",self.ExpectedDamage.Buttons[i],"BOTTOMRIGHT",1,-1)
            self.ExpectedDamage.Selected:Show()
        end
        self.ExpectedDamage.Buttons[i]:SetDesaturated(values.expectedDD~=i)
    end
    if values.allowMM then
        self.AllowMM:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        self.AllowMMLabel:SetText(format(L["%s %s or %s"],L["Allow any"],C.MAGIC_TEXT_ICON,C.MECHANICAL_TEXT_ICON))
        self.AllowMMLabel:SetTextColor(1,0.82,0)
    else
        self.AllowMM:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
        self.AllowMMLabel:SetText(format(L["%s %s or %s"],L["Allow any"],C.MAGIC_DISABLED_TEXT_ICON,C.MECHANICAL_DISABLED_TEXT_ICON))
        self.AllowMMLabel:SetTextColor(0.5,0.5,0.5)
    end
    rematch.utils:SetDimText(self.AllowMMLabel,not values.allowMM)
end

--[[ IconPicker functions ]]

local iconRows = {} -- ordered list of indexes 1..n for each row of icons to display
local iconSearch = ""

RematchDialogIconPickerMixin = {}

function RematchDialogIconPickerMixin:OnLoad()
    self.SearchBox.Instructions:SetText(L["Search Icons"])

    self.List:Setup({
        allData = iconRows,
        normalTemplate = "RematchDialogIconPickerRowTemplate",
        normalFill = self.FillNormal,
        normalHeight = 26
    })

end

function RematchDialogIconPickerMixin:OnShow()
    self.SearchBox:SetScript("OnTextChanged",function() self:UpdateList() end)
    if self.SearchBox:GetText()~="" then
        self.SearchBox.Clear:Click()
    end
end

function RematchDialogIconPickerMixin:OnHide()
    self.SearchBox:SetScript("OnTextChanged",nil)
end

function RematchDialogIconPickerMixin:UpdateList()
    -- recreate a list of rows based on the number of icons (potentially reduced by a search happening)
    wipe(iconRows)
    iconSearch = self.SearchBox:GetText()
    for i=1,ceil(#rematch.allIcons:GetIcons(iconSearch)/7) do
        tinsert(iconRows,i)
    end
    self.List:Update()
end

function RematchDialogIconPickerMixin:FillNormal(row)
    local allIcons = rematch.allIcons:GetIcons(iconSearch)
    local numIcons = #allIcons
    local offset = (row-1)*7
    for i=1,#self.Icons do
        local index = offset + i
        if index <= numIcons then
            self.Icons[i]:SetTexture(allIcons[index])
            self.Icons[i].fileID = allIcons[index]
            self.Icons[i]:Show()
        else
            self.Icons[i].fileID = nil
            self.Icons[i]:Hide()
        end
    end
end

function RematchDialogIconPickerMixin:SetIcon(icon)
    self.Icon:SetTexture(icon)
    self.icon = icon
end

function RematchDialogIconPickerMixin:GetIcon()
    return self.icon or C.REMATCH_ICON
end

--[[ IconPicker Icon "button"(texture) script handlers ]]

RematchDialogIconPickerIconMixin = {}

function RematchDialogIconPickerIconMixin:OnEnter()
    rematch.textureHighlight:Show(self)
end

function RematchDialogIconPickerIconMixin:OnLeave()
    rematch.textureHighlight:Hide()
end

function RematchDialogIconPickerIconMixin:OnMouseDown()
    rematch.textureHighlight:Hide()
end

function RematchDialogIconPickerIconMixin:OnMouseUp()
    if self:IsMouseMotionFocus() then
        rematch.textureHighlight:Show(self)
        self:GetParent():GetParent():GetParent():GetParent():GetParent():SetIcon(self.fileID)
    end
end

--[[ TeamPicker is a control to list and pick teams or targets that contains a List autoscrollbox and a Picker autoscrollbox ]]

RematchDialogTeamPickerMixin = {}

function RematchDialogTeamPickerMixin:OnLoad()
    self.Lister.Top.AddButton:SetText(C.ADD_TEXT_ICON..L[" Add"])
    self.Lister.Top.DeleteButton:SetText(C.DELETE_TEXT_ICON..L[" Delete"])
    self.Lister.Top.UpButton:SetText(C.UP_TEXT_ICON..L[" Up"])
    self.Lister.Top.DownButton:SetText(C.DOWN_TEXT_ICON..L[" Down"])
    self.Picker.Top.CancelButton:SetText(CANCEL)

    self.teamList = {} -- ordered list of teamIDs or targetIDs for Lister
    self.listType = nil -- C.LIST_MODE_TEAMS, C.LIST_MODE_TARGETS or C.LIST_MODE_GROUPS
    self.selectedID = nil -- teamID or targetID that's selected in Lister
    self.pickList = {} -- ordered list of groupIDs/headerIDs and teamIDs/targetIDs for Picker
    self.pickHeaders = {} -- expanded headers for Picker

    -- setup autoScrollBox for Lister, the list of teams/targets/groups
    self.Lister.List:Setup({
        allData = self.teamList,
        normalTemplate = "RematchCompactTeamListButtonTemplate",
        normalFill = self.FillLister,
        normalHeight = 26,
        selects = {
            Selected = {color={1,0.82,0}, parentKey="Back", drawLayer="ARTWORK"},
        },
    })

    -- setup autoScrollBox
    self.Picker.List:Setup({
        allData = self.pickList,
        normalTemplate = "RematchCompactTeamListButtonTemplate",
        normalFill = self.FillPicker,
        normalHeight = 26,
        headerTemplate = "RematchHeaderTeamListButtonTemplate",
        headerFill = self.FillHeader,
        headerCriteria = self.IsHeader,
        headerHeight = 26,
        placeholderTemplate = "RematchPlaceholderListButtonTemplate",
        placeholderFill = self.FillPlaceholder,
        placeholderCriteria = self.IsPlaceholder,
        placeholderHeight = 26,
        expandedHeaders = self.pickHeaders,
        allButton = self.Picker.Top.AllButton,
        searchBox = self.Picker.Top.SearchBox,
        searchHit = self.PickerSearchHit,
        onScroll = rematch.menus.Hide,
    })
    for _,button in ipairs({"AddButton","DeleteButton","UpButton","DownButton"}) do
        self.Lister.Top[button]:SetScript("OnClick",self[button.."OnClick"])
    end
    self.Picker.Top.CancelButton:SetScript("OnClick",self.CancelButtonOnClick)
    -- deferred script handlers from autoscrollbox
    self.Lister.List.TeamOnClick = self.ListerButtonOnClick
    self.Picker.List.HeaderOnClick = self.PickerHeaderOnClick
    self.Picker.List.TeamOnClick = self.PickerButtonOnClick
end

function RematchDialogTeamPickerMixin:SetList(listType,teamList)
    assert(listType==C.LIST_TYPE_TEAM or listType==C.LIST_TYPE_TARGET or listType==C.LIST_TYPE_GROUP,"Invalid list type for dialog team list")
    assert(type(teamList)=="table","Invalid list for dialog team list")
    self.listType = listType
    wipe(self.teamList) -- making a copy of the table
    for _,id in ipairs(teamList) do
        tinsert(self.teamList,id)
    end
    self.Lister:Show()
    self.Picker:Hide()
    self.Lister.List:Select("Selected",nil,true) -- clear selected but don't refresh (following update will do that)
    self:UpdateLister()
end

function RematchDialogTeamPickerMixin:GetList()
    return CopyTable(self.teamList) -- don't pass a reference to this table to minimize anything messing it up
end

-- when dialog hides, this will wipe the lists/search
function RematchDialogTeamPickerMixin:Reset()
    wipe(self.teamList)
    wipe(self.pickList)
    wipe(self.pickHeaders)
    self.Picker.Top.SearchBox.Clear:Click()
end

-- for use with clear button on layout tabs, clears list and returns to lister
function RematchDialogTeamPickerMixin:Clear()
    wipe(self.teamList)
    self.Picker:Hide()
    self.Lister:Show()
    self:UpdateLister()
    rematch.dialog:OnChange()
end

--[[ Lister functions ]]

function RematchDialogTeamPickerMixin:FillLister(id)
    self:Fill(id)
end

-- updates the Lister list (if justButtons not true) and the Add/Delete/Up/Down buttons
function RematchDialogTeamPickerMixin:UpdateLister(justButtons)
    if not justButtons then
        self.Lister.List:Update()
    end
    -- enable/disable Delete/Up/Down buttons
    local selectedData = self.Lister.List:GetSelected("Selected")
    local enableDelete = selectedData and true or false -- if anything selected, delete enabled
    self.Lister.Top.DeleteButton:SetEnabled(enableDelete)
    self.Lister.Top.DeleteButton:SetText(format("%s %s",enableDelete and C.DELETE_TEXT_ICON or C.DELETE_DISABLED_TEXT_ICON,L["Delete"]))
    local enableUp = selectedData and self.teamList[1]~=selectedData -- if any but topmost data selected, up enabled
    self.Lister.Top.UpButton:SetEnabled(enableUp)
    self.Lister.Top.UpButton:SetText(format("%s %s",enableUp and C.UP_TEXT_ICON or C.UP_DISABLED_TEXT_ICON,L["Up"]))
    local enableDown = selectedData and self.teamList[#self.teamList]~=selectedData -- if any but bottommost data selected, down enabled
    self.Lister.Top.DownButton:SetEnabled(enableDown)
    self.Lister.Top.DownButton:SetText(format("%s %s",enableDown and C.DOWN_TEXT_ICON or C.DOWN_DISABLED_TEXT_ICON,L["Down"]))
end

-- click of a teamID/targetID in the Lister panel always selects the teamID/targetID and updates the list
function RematchDialogTeamPickerMixin:ListerButtonOnClick(button)
    if button~="RightButton" then
        local list = self:GetParent():GetParent():GetParent() -- the AutoScrollBox List
        local parent = list:GetParent():GetParent() -- the TeamPicker control
        list:Select("Selected",self.teamID or self.targetID)
        parent:UpdateLister(true) -- whole list doesn't need updated, just the buttons
    end
end

function RematchDialogTeamPickerMixin:AddButtonOnClick()
    local parent = self:GetParent():GetParent():GetParent() -- the TeamPicker control
    parent.Lister:Hide()
    parent.Picker:Show()
    if parent.listType==C.LIST_TYPE_TARGET then
        wipe(parent.pickList)
        rematch.targetsPanel:PopulateTargetList(parent.pickList)
    elseif parent.listType==C.LIST_TYPE_TEAM then
        rematch.teamsPanel:PopulateTeamList(parent.pickList)
    else
        wipe(parent.pickList)
    end
    parent.Picker.List:Update()
end

-- deletes the selected id from the teamList
function RematchDialogTeamPickerMixin:DeleteButtonOnClick()
    local list = self:GetParent():GetParent().List -- the AutoScrollBox List
    local parent = self:GetParent():GetParent():GetParent() -- the TeamPicker control
    local selectedData = list:GetSelected("Selected")
    local index = rematch.utils:GetIndexByValue(parent.teamList,selectedData)
    if index then
        rematch.utils:TableRemoveByValue(parent.teamList,selectedData)
        local newData = parent.teamList[max(index-1,1)] -- it's okay if it's nil (list empty)
        list:Select("Selected",newData,true) -- change selection to the previous teamID/targetID that remains
        parent:UpdateLister()
        rematch.dialog:OnChange()
    end
end

-- moves the selected id up the teamList
function RematchDialogTeamPickerMixin:UpButtonOnClick()
    local list = self:GetParent():GetParent().List -- the AutoScrollBox List
    local parent = self:GetParent():GetParent():GetParent() -- the TeamPicker control
    local selectedData = list:GetSelected("Selected")
    local index = rematch.utils:GetIndexByValue(parent.teamList,selectedData)
    if index>1 then
        local tempData = parent.teamList[index-1] -- swap values at index and index-1
        parent.teamList[index-1] = selectedData
        parent.teamList[index] = tempData
        parent:UpdateLister()
        rematch.dialog:OnChange()
    end
end

-- moves the selected id down the teamList
function RematchDialogTeamPickerMixin:DownButtonOnClick()
    local list = self:GetParent():GetParent().List -- the AutoScrollBox List
    local parent = self:GetParent():GetParent():GetParent() -- the TeamPicker control
    local selectedData = list:GetSelected("Selected")
    local index = rematch.utils:GetIndexByValue(parent.teamList,selectedData)
    if index < #parent.teamList then
        local tempData = parent.teamList[index+1] -- swap values at index and index+1
        parent.teamList[index+1] = selectedData
        parent.teamList[index] = tempData
        parent:UpdateLister()
        rematch.dialog:OnChange()
    end
end

-- click of Cancel in the Picker part of the control, returns to Lister frame
function RematchDialogTeamPickerMixin:CancelButtonOnClick()
    local parent = self:GetParent():GetParent():GetParent() -- the TeamPicker control
    parent.Picker:Hide()
    parent.Lister:Show()
end

--[[ Picker functions ]]

function RematchDialogTeamPickerMixin:FillPicker(id)
    self:Fill(id)
end

function RematchDialogTeamPickerMixin:FillHeader(id)
    self:Fill(id)
end

-- if listType is target, then picker is display teams and vice versa
function RematchDialogTeamPickerMixin:FillPlaceholder(id)
    local list = self:GetParent():GetParent():GetParent() -- the AutoScrollBox List
    local parent = list:GetParent():GetParent() -- the TeamPicker control
    if parent.listType==C.LIST_TYPE_TEAM then
        rematch.teamsPanel.FillPlaceholder(self,id)
    elseif parent.listType==C.LIST_TYPE_TARGET then
        rematch.targetsPanel.FillPlaceholder(self,id)
    end
end

function RematchDialogTeamPickerMixin:IsHeader(id)
    return type(id)=="string" and (id:match("^group:") or id:match("^header")) and true or false
end

function RematchDialogTeamPickerMixin:IsPlaceholder(id)
    return type(id)=="string" and id:match("^placeholder:") and true or false
end

function RematchDialogTeamPickerMixin:PickerHeaderOnClick()
    local list = self:GetParent():GetParent():GetParent() -- the AutoScrollBox List
    list:ToggleHeader(self.groupID or self.headerID)
end

function RematchDialogTeamPickerMixin:PickerButtonOnClick(button)
    local list = self:GetParent():GetParent():GetParent() -- the AutoScrollBox List
    local parent = list:GetParent():GetParent() -- the TeamPicker control
    local id = self.teamID or self.targetID
    if id then
        rematch.utils:TableInsertDistinct(parent.teamList,id)
        parent.Picker:Hide()
        parent.Lister:Show()
        parent.Lister.List:Select("Selected",id)
        parent:UpdateLister()
        parent.Lister.List:BlingData(id)
        rematch.dialog:OnChange()
    end
end

function RematchDialogTeamPickerMixin:PickerSearchHit(mask,id)
    local parent = self:GetParent():GetParent() -- the TeamPicker control
    if parent.listType==C.LIST_TYPE_TEAM then -- if list type is target, searching teams
        return rematch.teamsPanel.SearchHit(self,mask,id)
    elseif parent.listType==C.LIST_TYPE_TARGET then -- if list type is team, searching targets
        return rematch.targetsPanel.SearchHit(self,mask,id)
    else
        return false
    end
end

--[[ group picker ]]

RematchDialogGroupPickerMixin = {}

function RematchDialogGroupPickerMixin:OnLoad()
    self.Top.CancelButton.Text:SetText(CANCEL)
    self.Top.Label:SetText(L["Choose a group for this team"])

    self.Top.CancelButton:SetScript("OnClick",function(self)
        rematch.dialog:ChangeLayout(self:GetParent():GetParent().returnLayout or "Default")
    end)

    self.groupList = {} -- ordered list of groupIDs to list

    -- setup autoScrollBox for Lister, the list of teams/targets/groups
    self.List:Setup({
        allData = self.groupList,
        normalTemplate = "RematchDialogGroupPickerListButtonTemplate",
        normalFill = self.FillGroup,
        normalHeight = 26
    })
end

-- sets the layout to return to when group picked or cancelled
-- if noSideline is true then it also makes the list take up the whole control without a "Pick a team" cancel prompt
function RematchDialogGroupPickerMixin:SetReturn(layoutName,noSideline)
    self.returnLayout = layoutName
    self.noSideline = noSideline
    if noSideline then
        self.Top:Hide()
        self.List:SetPoint("TOPLEFT",self.Top,"TOPLEFT")
    else
        self.Top:Show()
        self.List:SetPoint("TOPLEFT",self.Top,"BOTTOMLEFT",0,-2)
    end
end

function RematchDialogGroupPickerMixin:Update()
    wipe(self.groupList)
    for _,groupID in ipairs(settings.GroupOrder) do
        tinsert(self.groupList,groupID)
    end
    self.List:Update()
end

function RematchDialogGroupPickerMixin:OnShow()
    self:Update()
    self.List:ScrollToTop()
end

function RematchDialogGroupPickerMixin:FillGroup(groupID)
    self.groupID = groupID
    self.Text:SetText(rematch.utils:GetFormattedGroupName(groupID))
    local group = groupID and rematch.savedGroups[groupID]
    self.Icon:SetTexture(group and group.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    local xoff = -22
    local badgesWidth = rematch.badges:AddBadges(self.Badges,"groups",groupID,"RIGHT",self.Icon,"LEFT",-2,-1,-1)
    xoff = xoff - badgesWidth
    self.Text:SetPoint("BOTTOMRIGHT",xoff,2)
end

RematchDialogGroupPickerListButtonMixin = {}

function RematchDialogGroupPickerListButtonMixin:OnEnter()
    rematch.textureHighlight:Show(self.Back)
end

function RematchDialogGroupPickerListButtonMixin:OnLeave()
    rematch.textureHighlight:Hide()
end

function RematchDialogGroupPickerListButtonMixin:OnMouseDown()
    rematch.textureHighlight:Hide()
end

function RematchDialogGroupPickerListButtonMixin:OnMouseUp()
    if self:IsMouseMotionFocus() then
        rematch.textureHighlight:Show(self.Back)
    end
end

-- this is used for the GroupPicker
function RematchDialogGroupPickerListButtonMixin:OnClick(button)
    if button~="RightButton" then
        local picker = self:GetParent():GetParent():GetParent():GetParent()
        if not picker.noSideline then
            rematch.savedTeams.sideline.groupID = self.groupID
        end
        settings.LastSelectedGroup = self.groupID
        rematch.dialog:OnChange()
        rematch.dialog:ChangeLayout(picker.returnLayout or "Default")
    end
end

--[[ combobox is a combination editbox and dropdown ]]

RematchDialogComboBoxMixin = {}

function RematchDialogComboBoxMixin:OnLoad()
    self.ComboBox.Text:SetScript("OnEscapePressed",function(self,...)
        rematch.dialog.CancelButton:Click()
    end)
    self.ComboBox.Text:SetScript("OnEnterPressed",function(self,...)
        if rematch.dialog.AcceptButton:IsEnabled() then
            rematch.dialog.AcceptButton:Click()
        end
    end)
    self.ComboBox.Text:SetScript("OnTextChanged",function(self,...)
        rematch.dialog:OnChange() -- function to call the changeFunc when text changes
    end)
end

function RematchDialogComboBoxMixin:SetText(text)
    self.ComboBox.Text:SetText(text)
end

function RematchDialogComboBoxMixin:GetText()
    return self.ComboBox.Text:GetText()
end

function RematchDialogComboBoxMixin:SetLabel(text)
    self.Label:SetText(text)
end

function RematchDialogComboBoxMixin:SetList(list)
    local menu = {}
    for index,text in ipairs(list) do
        tinsert(menu,{text=text,value=index})
    end
    self.ComboBox:BasicSetup(menu)
end

function RematchDialogComboBoxMixin:SetTextColor(r,g,b)
    self.ComboBox.Text:SetTextColor(r,g,b)
end


--[[ pet button with pet card mouse events ]]

RematchDialogPetButtonMixin = {}

function RematchDialogPetButtonMixin:OnEnter()
    rematch.textureHighlight:Show(self.Icon)
    rematch.cardManager:OnEnter(rematch.petCard,self,self.petID)
end

function RematchDialogPetButtonMixin:OnLeave()
    rematch.textureHighlight:Hide()
    rematch.cardManager:OnLeave(rematch.petCard,self,self.petID)
end

function RematchDialogPetButtonMixin:OnMouseDown()
    rematch.textureHighlight:Hide()
end

function RematchDialogPetButtonMixin:OnMouseUp()
    if self:IsMouseMotionFocus() then
        rematch.textureHighlight:Show(self.Icon)
    end
end

function RematchDialogPetButtonMixin:OnClick()
    rematch.cardManager:OnClick(rematch.petCard,self,self.petID)
end


--[[ pet with abilities is a single pet button with an ability bar]]

RematchDialogPetWithAbilitiesMixin = {}

-- fills the pet and abilities
function RematchDialogPetWithAbilitiesMixin:Fill(petID,ability1,ability2,ability3)
    self.Pet.petID = petID
    self.Pet:FillPet(petID)
    self.AbilityBar:FillAbilityBar(petID,ability1,ability2,ability3)
end

-- fills the pet and abilities from the given loadout slot
function RematchDialogPetWithAbilitiesMixin:FillFromLoadout(slot)
    self:Fill(C_PetJournal.GetPetLoadOutInfo(slot))
end

-- fills the pets and abilities from the given teamID slot
function RematchDialogPetWithAbilitiesMixin:FillFromTeamID(slot,teamID)
    local team = rematch.savedTeams[teamID]
    if team then
        self:Fill(team.pets[slot],rematch.petTags:GetAbilities(team.tags[slot]))
    else -- if team doesn't exist, make it an empty pet and abilities
        self:Fill("empty")
    end
end

--[[ team with abilities is 3 pets with abilities ]]

RematchDialogTeamWithAbilitiesMixin = {}

function RematchDialogTeamWithAbilitiesMixin:FillFromLoadout()
    for i=1,3 do
        self.Pets[i]:FillFromLoadout(i)
    end
end

function RematchDialogTeamWithAbilitiesMixin:FillFromTeamID(teamID)
    for i=1,3 do
        self.Pets[i]:FillFromTeamID(i,teamID)
    end
end

--[[ RematchDialogGroupSelectMixin ]]

RematchDialogGroupSelectMixin = {}

function RematchDialogGroupSelectMixin:OnLoad()
    self.Label:SetText(L["Group:"])
    self.Button:SetScript("OnEnter",function(self)
        for i=1,3 do
            self.Highlights[i]:Show()
        end
    end)
    self.Button:SetScript("OnLeave",function(self)
        for i=1,3 do
            self.Highlights[i]:Hide()
        end
    end)
    self.Button:SetScript("OnMouseDown",self.Button:GetScript("OnLeave"))
    self.Button:SetScript("OnMouseUp",function(self)
        if self:IsMouseMotionFocus() then
            self:GetScript("OnEnter")(self)
        end
    end)
    self.Button:SetScript("OnClick",function(self)
        rematch.dialog:ChangeLayout(self:GetParent().returnLayout or "GroupPick")
    end)
end

function RematchDialogGroupSelectMixin:Fill(groupID)
    groupID = groupID or "group:none"
    local group = rematch.savedGroups[groupID] or rematch.savedGroups["group:none"]
    self.Button.Name:SetText(rematch.utils:GetFormattedGroupName(groupID))
    self.Button.Icon:SetTexture(group.icon)
    local xoff = -22
    local badgesWidth = rematch.badges:AddBadges(self.Button.Badges,"groups",groupID,"RIGHT",self.Button.Icon,"LEFT",-2,-1,-1)
    xoff = xoff - badgesWidth
    self.Button.Name:SetPoint("RIGHT",xoff,-1)
end

-- sets the layout to return to when the button is clicked
function RematchDialogGroupSelectMixin:SetReturn(layoutName)
    self.returnLayout = layoutName
end

function RematchDialogGroupSelectMixin:Reset()
    self.returnLayout = nil
end

--[[ RematchDialogWinRecordMixin ]]

RematchDialogWinRecordMixin = {}

function RematchDialogWinRecordMixin:OnLoad()
    self.Wins.Label:SetText(format("%s%s ",C.HEX_GREEN,L["Wins:"]))
    self.Wins:SetJustifyH("CENTER")
    self.Losses.Label:SetText(format("%s%s ",C.HEX_RED,L["Losses:"]))
    self.Losses:SetJustifyH("CENTER")
    self.Draws.Label:SetText(format("%s%s ",C.HEX_GOLD,L["Draws:"]))
    self.Draws:SetJustifyH("CENTER")
end

-- updates the display of total battles and disables the minus buttons for stats at 0 (which are nil; winrecord never keeps a 0 value)
-- (this doesn't update editboxes, that's only done in a Set which also calls this)
function RematchDialogWinRecordMixin:Update()
    local winrecord = self:Get()
    self.WinsMinus:SetEnabled(winrecord.wins and true or false)
    self.LossesMinus:SetEnabled(winrecord.losses and true or false)
    self.DrawsMinus:SetEnabled(winrecord.draws and true or false)
    self.TotalBattles:SetText(format(L["Total Battles: %s%s"],C.HEX_WHITE,winrecord.battles>0 and winrecord.battles or L["None"]))

    if winrecord.battles>0 then
        local percent = floor(0.5+(winrecord.wins or 0)*100/winrecord.battles)
        self.WinRate:SetText(format(L["Win Rate: %d%%"],percent))
        if percent >= 60 then
            self.WinRate:SetTextColor(0.25,0.75,0.25)
        elseif percent <= 40 then
            self.WinRate:SetTextColor(1,0.25,0.25)
        else
            self.WinRate:SetTextColor(1,0.82,0)
        end
        self.WinRate:Show()
    else
        self.WinRate:Hide() -- don't show rate if there's no battles
    end
end

-- clicking a + or - beside one of the editboxes will increment/decrement the value in the editbox (empty of 0)
-- parentKey is either "Wins", "Losses" or "Draws"; modifier is either -1 or +1
function RematchDialogWinRecordMixin:AdjustEditBox(parentKey,modifier)
    local value = max(0,tonumber(self[parentKey]:GetText()) or 0) + modifier
    -- the OnTextChanged in the editbox will trigger an OnChange that does an Update
    self[parentKey]:SetText(value<1 and "" or value)
end

-- sets the winrecord control to the given values (unordered table of wins, losses, draws, battles)
function RematchDialogWinRecordMixin:Set(winrecord)
    if type(winrecord)~="table" then
        winrecord = {} -- nothing given, clear everything
    end
    self.Wins:SetText(winrecord.wins or "")
    self.Losses:SetText(winrecord.losses or "")
    self.Draws:SetText(winrecord.draws or "")
    rematch.dialog:OnChange()
end

-- returns the current winrecord values in the control as an unordered table
-- if utable given, winrecord will be stored in that table; otherwise a reused table returned
local winrecordResults = {} -- reused to minimize garbage creation; but be careful not to assign this table reference to anything!
function RematchDialogWinRecordMixin:Get(utable)
    local results = utable or winrecordResults
    wipe(results)
    results.wins = tonumber(self.Wins:GetText())
    results.losses = tonumber(self.Losses:GetText())
    results.draws = tonumber(self.Draws:GetText())
    results.battles = (results.wins or 0) + (results.losses or 0) + (results.draws or 0)
    return results
end

--[[ IncludeCheckButtons ]]

RematchDialogIncludeCheckButtons = {}

function RematchDialogIncludeCheckButtons:OnLoad()
    self.IncludePreferences:SetText(L["Include Preferences"])
    self.IncludeNotes:SetText(L["Include Notes"])
    self.IncludePreferences:SetScript("OnClick",function() rematch.dialog:OnChange() end)
    self.IncludeNotes:SetScript("OnClick",function() rematch.dialog:OnChange() end)
end

-- sets the check for settings and enables/disbaled for the given teamID (if any)
function RematchDialogIncludeCheckButtons:Update(teamID)
    self.IncludePreferences:SetChecked(settings.ExportIncludePreferences)
    self.IncludeNotes:SetChecked(settings.ExportIncludeNotes)
    self.IncludePreferences:SetEnabled(not teamID or (rematch.savedTeams[teamID] and rematch.savedTeams[teamID].preferences and true or false))
    self.IncludeNotes:SetEnabled(not teamID or (rematch.savedTeams[teamID] and rematch.savedTeams[teamID].notes and true or false))
end

--[[ RematchDialogListDataMixin ]]

RematchDialogListDataMixin = {}

-- data should be an ordered list with a sub-ordered list of values, for example:
-- { {"This is line 1",1},
--   {"This is second line","two"}
--   {"This line","III"}, etc. }
function RematchDialogListDataMixin:Set(data)
    local maxLabelWidth = 0
    local maxDataWidth = 0
    local height = 0
    for i,info in ipairs(data) do
        if not self.ListItems[i] then -- if a ListItem isn't made for this row yet, make one
            self.ListItems[i] = CreateFrame("Frame",nil,self,"RematchDialogListItemTemplate")
            self.ListItems[i]:SetPoint("TOPLEFT",self.ListItems[i-1],"BOTTOMLEFT")
            self.ListItems[i]:SetPoint("TOPRIGHT",self.ListItems[i-1],"BOTTOMRIGHT")
        end
        local item = self.ListItems[i]
        item:Show()
        item.Label:SetText(info[1])
        item.Data:SetText(info[2])
        maxLabelWidth = max(maxLabelWidth,item.Label:GetStringWidth())
        maxDataWidth = max(maxDataWidth,item.Data:GetStringWidth())
        height = height + floor(item:GetHeight()+0.5)
    end
    -- hide any leftover listitem frames
    for i=#data+1,#self.ListItems do
        self.ListItems[i]:Hide()
    end
    self:SetHeight(height)
    self:SetWidth(maxLabelWidth+maxDataWidth+8)
end

--[[ RematchDialogConflictRadiosMixin ]]

RematchDialogConflictRadiosMixin = {}

function RematchDialogConflictRadiosMixin:OnLoad()
    self.Label:SetText(L["When teams/groups share the same name:"])
    self.CreateCopyRadio:SetText(L["Create a new copy"])
    self.OverwriteRadio:SetText(L["Overwrite existing one"])
    self:SetWidth(max(self.CreateCopyRadio.Text:GetStringWidth(),self.OverwriteRadio.Text:GetStringWidth())+30)
end

function RematchDialogConflictRadiosMixin:Update()
    local overwrite = settings.ImportConflictOverwrite
    self.CreateCopyRadio:SetChecked(not overwrite)
    self.OverwriteRadio:SetChecked(overwrite)
end

function RematchDialogConflictRadiosMixin:SetImportConflictOverwrite(overwrite)
    settings.ImportConflictOverwrite = overwrite
    self:Update()
    rematch.dialog:OnChange()
end

function RematchDialogConflictRadiosMixin:IsOverwrite()
    return settings.ImportConflictOverwrite
end

--[[ RematchDialogMultiTeamMixin ]]

RematchDialogMultiTeamMixin = {}

-- takes an ordered list of teamIDs and displays the first one with option to select different teams
function RematchDialogMultiTeamMixin:SetTeams(teams,index)
    if type(teams)~="table" then
        teams = {}
        index = nil
    end
    self.teams = teams
    self.index = index
    self.PrevTeamButton:SetShown(#teams>1)
    self.NextTeamButton:SetShown(#teams>1)
    self.ListButtonTeam:SetPoint("BOTTOMRIGHT",#teams>1 and -22 or 0,0)
    self:Update()
end

function RematchDialogMultiTeamMixin:Update()
    local teamID = type(self.teams)=="table" and self.index and self.teams[self.index]
    local team = teamID and rematch.savedTeams[teamID]
    self.ListButtonTeam:SetShown(team and true or false)
    self.ListButtonTeam.teamID = teamID
    self.ListButtonTeam:Fill(teamID)
    -- regular team list button fill doesn't do status; do that here
    if team and team.pets then
        for i=1,3 do
            local petInfo = rematch.petInfo:Fetch(team.pets[i])
            if petInfo.isDead then
                self.ListButtonTeam.Status[i]:SetTexCoord(0,0.3125,0,0.625)
                self.ListButtonTeam.Status[i]:Show()
            elseif petInfo.isInjured then
                self.ListButtonTeam.Status[i]:SetTexCoord(0.3125,0.625,0,0.625)
                self.ListButtonTeam.Status[i]:Show()
            else
                self.ListButtonTeam.Status[i]:Hide()
            end
        end
    end
    self.PrevTeamButton:SetEnabled(self.index~=1)
    self.NextTeamButton:SetEnabled(self.index~=#self.teams)
end

function RematchDialogMultiTeamMixin:PrevTeam()
    self.index = max(self.index-1,1)
    self:Update()
end

function RematchDialogMultiTeamMixin:NextTeam()
    self.index = min(self.index+1,#self.teams)
    self:Update()
end

-- returns the currently-chosen teamID
function RematchDialogMultiTeamMixin:GetTeamID()
    local teamID = self.ListButtonTeam.teamID
    return rematch.savedTeams[teamID] and teamID
end

--[[ RematchDialogSliderMixin ]]

RematchDialogSliderMixin = {}

function RematchDialogSliderMixin:OnLoad()
    self.Slider:RegisterCallback("OnValueChanged",function(_,value)
        local oldValue = self.value
        self.value = value
        self:Update()
        -- for setting up changing callbacks
        if self.onValueChangedFunc and oldValue~=value then
            self.onValueChangedFunc(self,value)
        end
    end)
end

-- refreshFunc should call this to set up the slider and its label format and callback function
-- here steps is number of steps, so 50 to 200 with 5 increment would be
-- labelFormat is a string.format pattern for the label above the slider, such as "Scale: %d%%"
-- onValueChangedFunc will be called with (self,value) where self is the slider dialog control
function RematchDialogSliderMixin:Setup(value,minValue,maxValue,steps,labelFormat,onValueChangedFunc)
    self.Slider:Init(value,minValue,maxValue,steps)
    self.labelFormat = labelFormat or "%s"
    self.value = value -- initial value
    if type(onValueChangedFunc)=="function" then
        self.onValueChangedFunc = onValueChangedFunc
    end
    self:Update()
end

function RematchDialogSliderMixin:Update()
    local labelFormat = self.labelFormat or "%s"
    self.Label:SetText(format(labelFormat,self.value or ""))
end

function RematchDialogSliderMixin:Reset()
    self.onValueChanged = nil
end

--[[ RematchDialogBarChartMixin ]]

RematchDialogBarChartMixin = {}

-- sets the chart to display the given info, which is an ordered list of:
-- [1] = {icon="file", value=number, max=maxValue, r=red, g=green, b=blue}
function RematchDialogBarChartMixin:Set(info)
    local numBars = #info
    -- create new bars if any needed
    for i=2,numBars do
        if not self.Bars[i] then
            self.Bars[i] = CreateFrame("Frame",nil,self,"RematchDialogBarChartBarTemplate")
            self.Bars[i]:SetPoint("BOTTOMLEFT",self.Bars[i-1],"BOTTOMRIGHT")
        end
    end
    -- show only bars that should be shown
    for i,bar in ipairs(self.Bars) do
        bar:SetShown(i<=numBars)
        bar:SetWidth(250/numBars)
    end
    for i,info in ipairs(info) do
        self.Bars[i].Bar:SetVertexColor(info.r or 1,info.g or 1,info.b or 1)
        local value = info.value
        local maxValue = info.maxValue and max(0.1,info.maxValue) or 0.1
        local formattedValue = info.formattedValue and format(info.formattedValue,value) or value
        self.Bars[i].Bar:SetHeight(max(0.1,min(148,value*148/maxValue)))
        self.Bars[i].Value:SetText(formattedValue)
        --bar.Bar:SetHeight(random(148))

        self.Bars[i].Icon:SetTexture(info.icon)
        self.Bars[i].Icon.index = i
    end
end

--[[ RematchDialogBattleSummaryMixin ]]

RematchDialogBattleSummaryMixin= {}

-- fills the BattleSummary control with totals of all team battles and returns teamID of team that won the most
function RematchDialogBattleSummaryMixin:Fill(stats)
    if type(stats)=="table" then
        local battles = stats.battles or 0
        self.TotalBattles:SetText(format(L["%s%d\124r Battles for %s%d\124r Teams"],C.HEX_WHITE,battles,C.HEX_WHITE,stats.teams or 0))
        self.WinAmount:SetText(stats.wins)
        self.LossAmount:SetText(stats.losses)
        self.DrawAmount:SetText(stats.draws)
        self.WinPercent:SetText(battles>0 and floor(stats.wins*100/battles+0.5).."%" or "--")
        self.LossPercent:SetText(battles>0 and floor(stats.losses*100/battles+0.5).."%" or "--")
        self.DrawPercent:SetText(battles>0 and floor(stats.draws*100/battles+0.5).."%" or "--")
    end
end

--[[ RematchDialogBarChartIconMixin ]]

RematchDialogBarChartIconMixin = {}

function RematchDialogBarChartIconMixin:OnEnter()
    rematch.textureHighlight:Show(self)
    local openLayout = rematch.dialog:GetOpenLayout()
    local prefix = (openLayout=="Types" and "BATTLE_PET_NAME_") or (openLayout=="Sources" and "BATTLE_PET_SOURCE_")
    if prefix and self.index then
        rematch.tooltip:ShowSimpleTooltip(self,nil,_G[prefix..self.index] or "")
    end
end

function RematchDialogBarChartIconMixin:OnLeave()
    rematch.textureHighlight:Hide()
    rematch.tooltip:Hide()
end

--[[ RematchDialogTopTeamsMixin ]]

RematchDialogTopTeamsMixin = {}

-- teams is an ordered list of teams {teamID,totalWins,percentWins}
function RematchDialogTopTeamsMixin:Fill(teams)
    self.TeamsLabel:SetText(format(L["Top %d Winning Teams"],#teams))
    local height = 22
    for _,button in ipairs(self.Buttons) do
        button:Hide()
    end
    for i,info in pairs(teams) do
        if not self.Buttons[i] then
            self.Buttons[i] = CreateFrame("Button",nil,self,"RematchDialogTopTeamsListButtonTemplate")
            self.Buttons[i]:SetPoint("TOPLEFT",self.Buttons[i-1],"BOTTOMLEFT")
        end
        self.Buttons[i].teamID = info[1]
        local team = rematch.savedTeams[info[1]]
        self.Buttons[i].Rank:SetText(format("%d.",i))
        self.Buttons[i].Name:SetText(rematch.utils:GetFormattedTeamName(info[1]))
        self.Buttons[i].Wins:SetText(info[2])
        local percent = floor(info[3]*100+0.5)
        self.Buttons[i].Percent:SetText(percent.."%")
        local r,g,b = 1,0.82,0
        if percent >= 60 then
            r,g,b = 0.125,0.9,0.125
        elseif percent <= 40 then
            r,g,b = 1,0.28235,0.28235
        end
        self.Buttons[i].Wins:SetTextColor(r,g,b)
        self.Buttons[i].Percent:SetTextColor(r,g,b)
        for j=1,3 do
            local petInfo = rematch.petInfo:Fetch(team.pets[j])
            self.Buttons[i].Pets[j].petID = team.pets[j]
            self.Buttons[i].Pets[j]:SetTexture(petInfo.icon)
        end
        height=height+26
        self.Buttons[i]:Show()
    end
    self:SetHeight(height)
end

-- mouse events for TopTeam list buttons
RematchDialogTopTeamsListButtonMixin = {}

function RematchDialogTopTeamsListButtonMixin:OnEnter()
    rematch.textureHighlight:Show(self.Back)
    if not settings.HideTruncatedTooltips and self.Name:IsTruncated() then
        rematch.tooltip:ShowSimpleTooltip(self,nil,self.Name:GetText() or "","BOTTOM",self.Name,"TOP",0,5,true)
    end
end

function RematchDialogTopTeamsListButtonMixin:OnLeave()
    rematch.textureHighlight:Hide()
    rematch.tooltip:Hide()
end

function RematchDialogTopTeamsListButtonMixin:OnMouseDown()
    rematch.textureHighlight:Hide()
end

function RematchDialogTopTeamsListButtonMixin:OnMouseUp()
    if self:IsMouseMotionFocus() then
        rematch.textureHighlight:Show(self.Back)
    end
end

function RematchDialogTopTeamsListButtonMixin:OnClick(button)
    if rematch.savedTeams:IsUserTeam(self.teamID) then
        rematch.layout:SummonView("teams")
        rematch.teamsPanel.List:ScrollDataIntoView(self.teamID)
        rematch.teamsPanel.List:BlingData(self.teamID)
    end
end

-- mouse events for TopTeams pets in each list button
RematchDialogTopTeamsListPetButtonMixin = {}

function RematchDialogTopTeamsListPetButtonMixin:OnEnter()
    rematch.textureHighlight:Show(self,self:GetParent().Back)
    rematch.cardManager:OnEnter(rematch.petCard,self:GetParent(),self.petID) -- anchor to parent
end

function RematchDialogTopTeamsListPetButtonMixin:OnLeave()
    rematch.textureHighlight:Hide()
    rematch.cardManager:OnLeave(rematch.petCard,self:GetParent(),self.petID)
end

function RematchDialogTopTeamsListPetButtonMixin:OnMouseDown()
    rematch.textureHighlight:Hide()
end

function RematchDialogTopTeamsListPetButtonMixin:OnMouseUp()
    if self:IsMouseMotionFocus() then
        rematch.textureHighlight:Show(self,self:GetParent().Back)
        rematch.cardManager:OnClick(rematch.petCard,self:GetParent(),self.petID)
    end
end

--[[ PetHerderPickerMixin ]]

PetHerderPickerMixin = {}

function PetHerderPickerMixin:Update()
    for _,button in ipairs(self.Buttons) do
        local actionID = rematch.petHerder:GetActionID()
        if actionID then
            button:SetDesaturated(button.actionID~=actionID)
            if button.actionID==actionID then
                self.Selected:ClearAllPoints()
                self.Selected:SetPoint("TOPLEFT",button,"TOPLEFT",-3,3)
                self.Selected:Show()
            end
        else
            button:SetDesaturated(false)
            self.Selected:Hide()
        end
        -- while here, set up the Onclick for each button if it hasn't been defined yet
        if not button.OnClick then
            button.OnClick = self.ButtonOnClick
        end
    end
end

-- when dialog closes, reset actionID
function PetHerderPickerMixin:Reset()
    rematch.petHerder:SetActionID(nil)
end

-- click of one of the pet herder actions
function PetHerderPickerMixin:ButtonOnClick()
    local picker = self:GetParent()
    if self.actionID==rematch.petHerder:GetActionID() then
        rematch.petHerder:SetActionID(nil)
    else
        rematch.petHerder:SetActionID(self.actionID)
    end
    picker:Update()
    rematch.dialog:OnChange()
end

-- need to watch for something being picked up on the cursor while in pet herder targeting mode
-- while this dialog control is on screen
function PetHerderPickerMixin:OnShow()
    rematch.events:Register(self,"CURSOR_CHANGED",self.CURSOR_CHANGED)
    rematch.frame:Update()
end

function PetHerderPickerMixin:OnHide()
    rematch.events:Unregister(self,"CURSOR_CHANGED")
    SetCursor(nil)
    rematch.frame:Update()
end

function PetHerderPickerMixin:CURSOR_CHANGED()
    if rematch.dialog:GetOpenDialog()=="PetHerder" and GetCursorInfo() then
        rematch.dialog:Hide()
    end
end
