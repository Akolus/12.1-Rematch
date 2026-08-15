local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.panelTabs = rematch.frame.PanelTabs
rematch.frame:Register("panelTabs")

-- ordered list of frame references to created tabs
local knownTabs = {}

-- all tabs are attached to a parent panelTabs frame that's anchored to rematch.frame. this table is the SetPoint for each settings.Anchor value
local anchors = {
    BOTTOMLEFT = {"TOPLEFT",rematch.frame,"BOTTOMLEFT",6,2},
    BOTTOM = {"TOP",rematch.frame,"BOTTOM",-1,2},
    BOTTOMRIGHT = {"TOPRIGHT",rematch.frame,"BOTTOMRIGHT",-8,2},
    TOPRIGHT = {"BOTTOMRIGHT",rematch.frame,"TOPRIGHT",-8,-2},
    TOP = {"BOTTOM",rematch.frame,"TOP",-1,-2},
    TOPLEFT = {"BOTTOMLEFT",rematch.frame,"TOPLEFT",6,-2},
}

function rematch.panelTabs:Register(layoutName)
    local def = rematch.layout:GetDefinition(layoutName)
    if not def or not def.tab then
        return -- this layout has no tab
    end
    -- look for an already existing tab for this view and add the mode it's enabled for
    for _,tab in ipairs(knownTabs) do
        if def.view==tab.view then
            tab.modes[def.mode] = true
            return
        end
    end
    -- no tabs for the layout's view exists if we reached this point, create one
    local tab = CreateFrame("Button",nil,rematch.panelTabs,"RematchPanelTabTemplate")
    tab.Text:SetText(def.tab)
    tab.view = def.view
    tab.modes = {}
    tab.modes[def.mode] = true
    tab:SetScript("OnClick",self.TabOnClick)
    tinsert(knownTabs,tab)
end

-- positions the panelTabs based on the settings.Anchor and also positions/shows each tab based on the view
-- (it's assumed the rematch.frame width is already set prior to this configure; which it is in rematch.frame:Configure())
function rematch.panelTabs:Configure()
    self:ClearAllPoints()
    local anchor = rematch.journal:IsActive() and "BOTTOMRIGHT" or settings.PanelTabAnchor
    self.tabsAtTop = anchor:match("^TOP") and true
    if anchors[anchor] then
        self:SetPoint(anchors[anchor][1],anchors[anchor][2],anchors[anchor][3],anchors[anchor][4],anchors[anchor][5])
    else
        assert(false,"Invalid anchor setting: "..tostring(settings.Anchor))
    end
    local mode = rematch.layout:GetMode(C.CURRENT)
    local maximizedMode = rematch.layout:GetMode(C.MAXIMIZED)
    local xoffset = 0
    for i,tab in ipairs(knownTabs) do
        local showTab = false
        tab.isTopTab = self.tabsAtTop -- tabs at top are flipped upside down
        if tab.modes[mode] and xoffset+C.PANEL_TAB_SPACING < rematch.frame:GetWidth() then -- if tab belongs to this mode and there's room, show it
            showTab = true
        elseif mode==0 then -- minimized view has special handling for tabs
            if tab.view=="teams" or tab.view=="queue" or tab.view=="options" then -- these three tabs always shown in minimized view
                showTab = true
            elseif tab.view=="pets" and maximizedMode==3 then -- don't show pets tab while minimized if maximized view is 3-panel mode (pets tab isn't in 3-panel view)
                showTab = false
            elseif tab.view=="targets" and maximizedMode==3 then -- show targets tab while minimized if maximized view is 3-panel mode (pets tab isn't in 3-panel view)
                showTab = true
            elseif tab.view=="pets" and settings.PreferPetsTab then -- if maximized has pets tab and PreferPetsTab option checked, show it (instead of Targets)
                showTab = true
            elseif tab.view=="targets" then -- otherwise show targets tab if PreferPetsTab is not checked
                showTab = not settings.PreferPetsTab
            end
        end
        -- if tab exists for the current mode; or we're minimized and tab is one of the sanctioned ones (and it's not pet tab when maximized is mode 3)
        --if tab.modes[mode] or (mode==0 and (tab.view=="pets" or tab.view=="teams" or tab.view=="queue" or tab.view=="options") and (tab.view~="pets" or rematch.layout:GetMode(C.MAXIMIZED)~=3)) then
        if showTab then
            tab:SetPoint("TOPLEFT",self,"TOPLEFT",xoffset,0)
            xoffset = xoffset + C.PANEL_TAB_SPACING
            tab:Show()
        else
            tab:Hide()
        end
    end
    if xoffset>0 then -- if any tabs were set up, update set parent frame width and update the tabs
        self:SetWidth(xoffset)
        self:Show()
    else
        self:Hide()
    end
end

-- updates appearance of panel tabs to make tab of current view selected
function rematch.panelTabs:Update()
    local view = rematch.layout:GetView(C.CURRENT) -- this is "pets" "teams" etc (view without mode or subview)
    for _,tab in ipairs(knownTabs) do
        tab.isSelected = view==tab.view
        tab:Update()
    end
end

-- click of a panel tab can toggle minimize current view or move to another view
function rematch.panelTabs:TabOnClick()
    if rematch.layout:GetMode(C.CURRENT)==0 then -- we're minimized
        rematch.frame:ToggleMinimized(rematch.layout:GetMode(C.MAXIMIZED).."-"..self.view) -- go to view of tab clicked in the last-used maximized mode
    elseif rematch.layout:GetView(C.CURRENT)==self.view and not rematch.journal:IsActive() then -- not minimized but clicking current tab, so minimize
        -- only minimize if Standalone Window Options: Don't Minimize With Panel Tabs is unchecked
        if not settings.DontMinTabToggle then
            rematch.frame:ToggleMinimized()
        end
    elseif rematch.layout:GetView(C.CURRENT)~=self.view then -- not minimized and clicking a different tab, change to that view
        rematch.layout:ChangeView(self.view)
        PlaySound(C.SOUND_PANEL_TAB)
    end
end