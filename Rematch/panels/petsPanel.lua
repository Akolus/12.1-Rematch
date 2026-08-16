local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.petsPanel = rematch.frame.PetsPanel
rematch.frame:Register("petsPanel")

local petList = {} -- ordered list of petIDs to display

-- details of the three typebar tabs
local typebarTabInfo = {
    [1] = {L.TYPEBAR_TAB_TYPE,1,1,0.5,"Types",C.TYPEBAR_TAB_TYPE},
    [2] = {L.TYPEBAR_TAB_STRONG_VS,0,1,0,"Strong",C.TYPEBAR_TAB_STRONG_VS},
    [3] = {L.TYPEBAR_TAB_TOUGH_VS,1,0,0,"Tough",C.TYPEBAR_TAB_TOUGH_VS}
}

rematch.events:Register(rematch.petsPanel,"PLAYER_LOGIN",function(self)
    self.Top.SearchBox.Instructions:SetText(L["Search Pets"])
    self.Top.FilterButton:SetText(FILTER)

    -- setup autoScrollBox
    -- (note: not using autoscrollbox's search for petsPanel since search results sorted by relevance and other stuff)
    self.List:Setup({
        allData = petList,
        normalTemplate = "RematchNormalPetListButtonTemplate",
        normalFill = self.FillNormal,
        normalHeight = 44,
        compactTemplate = "RematchCompactPetListButtonTemplate",
        compactFill = self.FillCompact,
        compactHeight = 26,
        isCompact = settings.CompactPetList,
        selects = {
            Summoned = {color={1,0.82,0}, parentKey="Back", padding=0, drawLayer="ARTWORK"},
            PetCard = {color={0.33,0.66,1}, parentKey="Back", padding=0, drawLayer="ARTWORK"}
        },
        onScroll = function(self,percent) if not rematch.menus:IsMenuOpen("PetFilterMenu") then rematch.menus:Hide() end end
    })

    -- when searchbox clear button clicked, also clear search filter and update (editbox only updates panel on userInput)
    self.Top.SearchBox.Clear:HookScript("OnClick",function()
        rematch.filters:SetSearch("")
        rematch.petsPanel:Update()
    end)

    -- if logging in with search filters enabled, put the search text in the search box
    if not rematch.filters:IsClear("Search") or not rematch.filters:IsClear("Stats") then
        self.Top.SearchBox:SetText(settings.Filters.RawSearchText)
    end

    -- setup typebar
    for i=1,3 do -- setup typebar tabs' text and selected color
        self.Top.TypeBar.Tabs[i].Text:SetText(typebarTabInfo[i][1])
        self.Top.TypeBar.Tabs[i].Selected:SetVertexColor(typebarTabInfo[i][2],typebarTabInfo[i][3],typebarTabInfo[i][4],0.75)
        self.Top.TypeBar.Tabs[i].id = typebarTabInfo[i][6]
    end
    for i=1,10 do -- setup typebar buttons
        self.Top.TypeBar.Buttons[i].key = i
        self.Top.TypeBar.Buttons[i].OnClick = self.Top.TypeBar.TypeButtonOnClick
    end

    -- rematch.petsPanel.Top.TypeBar.Level25Button.tooltipTitle = L["Max Level Filter"]
    -- rematch.petsPanel.Top.TypeBar.Level25Button.tooltipBody = format(L["%s Level 25 pets\n%s Level 25 \124cff2090fdrare\124r pets"],C.LMB_TEXT_ICON,C.RMB_TEXT_ICON)

    rematch.events:Register(self,"REMATCH_PETS_CHANGED",self.Update)
end)

function rematch.petsPanel:Configure()
    self.Top.ToggleButton:SetDirection(settings.UseTypeBar and "up" or "down",0,0)
    self.Top:SetHeight(settings.UseTypeBar and C.PETPANEL_TOP_EXPANDED_HEIGHT or C.PETPANEL_TOP_COLLAPSED_HEIGHT)
    self.Top.TypeBar:SetShown(settings.UseTypeBar)
end

function rematch.petsPanel:Update()
    wipe(petList)
    for _,petID in ipairs(rematch.filters:RunFilters()) do
        tinsert(petList,petID)
    end
    self.Top.TypeBar:Update()
    if not rematch.filters:IsAllClear() then
        self.ResultsBar:Show()
        self.ResultsBar:Update()
        self.List:SetPoint("TOPLEFT",self.ResultsBar,"BOTTOMLEFT",0,-2)
    else
        self.ResultsBar:Hide()
        self.List:SetPoint("TOPLEFT",self.Top,"BOTTOMLEFT",0,-2)
        self.Top.SearchBox:SetText("")
    end
    self.List:Select("Summoned",C_PetJournal.GetSummonedPetGUID(),true)
    self.List:Update()
end

-- for updating the list visuals (such as summoned/selected pets changing) without any data changing
function rematch.petsPanel:Refresh()
    self.List:Select("Summoned",C_PetJournal.GetSummonedPetGUID(),true)
    self.List:Refresh()
end

-- while petsPanel on screen, refresh the list when a pet is summoned/dismissed for the summoned yellow overlay
function rematch.petsPanel:OnShow()
    rematch.events:Register(self,"COMPANION_UPDATE",self.Refresh)
end

function rematch.petsPanel:OnHide()
    rematch.events:Unregister(self,"COMPANION_UPDATE")
end

-- callback to fill normal-sized petlistbuttons
function rematch.petsPanel:FillNormal(petID)
    self:Fill(petID)
end

-- callback to fill compact-sized petlistbuttons
function rematch.petsPanel:FillCompact(petID)
    self:Fill(petID)
end

-- click of toggle button in topleft to open/close typebar
function rematch.petsPanel.Top.ToggleButton:OnClick()
    settings.UseTypeBar = not settings.UseTypeBar
    rematch.petsPanel:Configure()
    PlaySound(C.SOUND_HEADER_CLICK)
end

-- click of filter button in topright to summon filter menu
function rematch.petsPanel.Top.FilterButton:OnClick(button)
    if rematch.dialog:GetOpenDialog()~="PetHerder" then
        rematch.dialog:HideDialog()
    end
    rematch.menus:Toggle("PetFilterMenu",self)
end

--[[ typebar ]]

local tabInfo = {multiCheck=10} -- for use in petFilterMenu methods, reused table to define group/key
function rematch.petsPanel.Top.TypeBar:Update()
    -- make sure the current TypeBarTab is valid and set it to default "Pet Type" if not
    if type(settings.TypeBarTab)~="number" or settings.TypeBarTab<C.TYPEBAR_TAB_TYPE or settings.TypeBarTab>C.TYPEBAR_TAB_TOUGH_VS then
        settings.TypeBarTab=C.TYPEBAR_TAB_TYPE
    end
    self.Clear:Hide() -- only show clear button if anything to clear
    -- update current tab
    local currentTab = settings.TypeBarTab
    for i,tab in ipairs(self.Tabs) do
        local isSelected = currentTab==tab.id
        tab.isSelected = isSelected
        tab.Selected:SetShown(isSelected)
        tab.Text:SetPoint("CENTER",0,-1)
        if isSelected then
            tab.Text:SetTextColor(1,1,1)
        else
            tab.Text:SetTextColor(1,0.82,0)
        end
        tabInfo.group = typebarTabInfo[i][5] -- for petFilterMenus, set it to tab's group ("Types","Strong","Tough")
        local hasStuff = rematch.petFilterMenu.GroupUsed(tabInfo)
        tab.HasStuff:SetShown(hasStuff)
        if hasStuff then -- a tab has stuff to clear, so show clear button
            self.Clear:Show()
        end
    end
    -- change border texture to the current tab
    local yoff = (currentTab-1)*64/256
    self.TabbedBorder:SetTexCoord(0,0.521484375,yoff,0.2109375+yoff)
    -- depending on which tab we're on, select the types that are "checked"
    tabInfo.group = typebarTabInfo[currentTab][5] -- switch tab group to current tab
    for i=1,10 do
        tabInfo.key = i
        local isSelected = rematch.petFilterMenu.GetChecked(tabInfo)
        self.Selecteds[i]:SetShown(isSelected)
        self.Selecteds[i]:SetVertexColor(typebarTabInfo[currentTab][2],typebarTabInfo[currentTab][3],typebarTabInfo[currentTab][4],0.75)
        -- if at least one pet type is checked, desaturated unchecked ones
        self.Buttons[i]:SetDesaturated(rematch.petFilterMenu.GroupUsed(tabInfo) and not isSelected)
    end
    -- update Level25Button, highlighted when only the Level filter is max level (key=4)
    if rematch.filters:HasJust("Level",4) then
        self.Level25Highlight:Show()
        self.Clear:Show()
        if rematch.filters:HasJust("Rarity",4) then -- and if rare selected, make level 25 blue
            self.Level25Button:SetTexCoord(0.875,1,.75,1)
        else
            self.Level25Button:SetTexCoord(0,0.125,0.75,1)
        end
    else
        self.Level25Highlight:Hide()
        self.Level25Button:SetTexCoord(0,0.125,0.75,1)
    end
end

-- click of one of the 10 pet type buttons on the type bar; it uses the petFilterMenu toggle to handle
-- shift/alt+click behavior and reset when all 10 are checked
function rematch.petsPanel.Top.TypeBar:TypeButtonOnClick(button)
    tabInfo.group = typebarTabInfo[settings.TypeBarTab][5] -- current tab's group: Types, Strong or Tough
    tabInfo.key = self.key -- 1 through 10
    rematch.petFilterMenu.ToggleChecked(tabInfo)
    rematch.menus:Hide()
end

-- the level 25 button will toggle a Level filter just for max-level (key=4)
function rematch.petsPanel.Top.TypeBar.Level25Button:OnClick(button)
    local isFilteringLevel25 = rematch.filters:HasJust("Level",4) -- true if 4th level option (max level) set
    local isFilteringRare = rematch.filters:HasJust("Rarity",4) -- true if 4th rarity option (rare) set
    rematch.filters:Clear("Level")
    rematch.filters:Clear("Rarity")
    if button=="RightButton" and not (isFilteringLevel25 and isFilteringRare) then
        rematch.filters:Set("Level",4,true)
        rematch.filters:Set("Rarity",4,true)
    elseif not isFilteringLevel25 then
        rematch.filters:Set("Level",4,true)
    end
    rematch.menus:Hide()
    rematch.petsPanel:Update()
end

-- clicking the clear button to the right of the tabs will clear the current tab if it has anything;
-- or clear all tabs if the current tab is empty
function rematch.petsPanel.Top.TypeBar.Clear:OnClick()
    tabInfo.group = typebarTabInfo[settings.TypeBarTab][5] -- current tab's group: Types, Strong or Tough
    if rematch.petFilterMenu.GroupUsed(tabInfo) then
        rematch.petFilterMenu.ResetGroup(tabInfo)
    else
        for i=1,3 do
            tabInfo.group = typebarTabInfo[i][5]
            rematch.petFilterMenu.ResetGroup(tabInfo)
        end
        rematch.filters:Clear("Level")
        rematch.filters:Clear("Rarity")
        rematch.petsPanel:Update()
    end
    rematch.menus:Hide()
end

--[[ SearchBox ]]

function rematch.petsPanel.Top.SearchBox:OnTextChanged(userInput)
    local text = self:GetText()
    -- only run a filter if the user made the change
    if userInput then
        rematch.filters:SetSearch(text)
        rematch.petsPanel:Update()
    end
    -- regardless whether user changed input, update clear/instructions based on presence of text
    local hasText = text and text:trim():len()>0
    self.Clear:SetShown(hasText)
    self.Instructions:SetShown(not hasText)
end


--[[ ResultsBar ]]

function rematch.petsPanel.ResultsBar:Update()
    self.NumPets:SetText(format(L["Pets: %s%d"],C.HEX_WHITE,#petList))
    local filterList,onlySearch = rematch.filters:GetFilterList()
    self.Filters:SetText(format(L["Filters: %s%s"],C.HEX_WHITE,filterList))
    -- the "Don't Reset Search With Filters" option prevents ClearAll from clearing search, but we want to see the count of pets
    -- so display a results bar still when search is the only filter, but hide the Clear button too
    if onlySearch and settings.ResetExceptSearch then
        self.Clear:Hide()
        self.Filters:SetPoint("RIGHT",-10,0)
    else
        self.Clear:Show()
        self.Filters:SetPoint("RIGHT",-25,0)
    end
end

function rematch.petsPanel.ResultsBar.Clear:OnClick()
    rematch.filters:ClearAll()
    rematch.petsPanel:Update()
    rematch.menus:RefreshMenus()
end
