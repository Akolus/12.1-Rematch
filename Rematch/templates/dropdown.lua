local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
rematch.dropdown = {}

--[[

    RematchDropDownTemplate is a dropdown template that's 24px high and any width. The dropdown choices are
    presented in a Rematch-generated menu (see menus\menus.lua) that can be managed automatically by the dropdown
    if the BasicSetup is used or with full control by the menu functions.

    BasicSetup use:

        -- creates a dropdown with three options ("One","Two","Etc") and prints the numerical value of the option when chosen
        local dropdown = CreateFrame("Button", nil, UIParent, "RematchDropDownTemplate")
        dropdown:BasicSetup({{text="One",value=1}, {text="Two",value=2}, {text="Etc",value=0}},
                            function(value) print(value,"chosen") end)

        Note: In BasicSetup, EVERY menu item must have a text (displayed in menu/dropdown) and a value (arbitrary value
              associated with the text.) Highlighting is already handled and the function to run when an option is chosen
              is the second parameter of BasicSetup, taking the chosen value as its only argument. icon/iconCoords and
              tooltipTitle/Body are supported.
              If dropdown.forComboBox is true, then menu highlight matches entered text instead of value

    When more control is needed (such as submenus or non-option choices available), this is the equivalent of above:

        local dropdown = CreateFrame("Button", nil, UIParent, "RematchDropDownTemplate")
        dropdown.value = 1
        local function showHighlight(self)
            return self.value == dropdown.value
        end
        local function onSelection(self)
            dropdown.value = self.value
            print(self.value,"chosen")
        end
        local menu = {
            {text="One", value=1, highlight=showHighlight, func=onSelection},
            {text="Two", value=2, highlight=showHighlight, func=onSelection},
            {text="Etc", value=0, highlight=showHighlight, func=onSelection}
        }
        dropdown:SetMenu(menu)
        dropdown:SetSelection("value",1)

]]

local currentMenuID = 1 -- each menu gets a unique identifier, used for the name "DropDownMenu"..currentMenuID

--[[ local functions ]]

-- fetches the menu's table associated with the dropdown (self)
local function getMenu(self)
    return rematch.menus:GetDefinition(self.menuName)
end

-- sets the text (and optionally icon) to display in the dropdown; iconCoords (optional too) is an ordered
-- list of SetTexCoord values (left,right,top,bottom)
local function setDropDownText(self,text,icon,iconCoords)
    self.Text:SetText(text)
    if icon then
        self.Text:SetPoint("TOPLEFT",23,0)
        self.Icon:SetTexture(icon)
        if iconCoords then
            self.Icon:SetTexCoord(iconCoords[1],iconCoords[2],iconCoords[3],iconCoords[4])
        else -- like menu, no iconCoords means it will trim slightly in to cut off icon border
            self.Icon:SetTexCoord(0.075,0.925,0.075,0.925)
        end
        self.Icon:Show()
    else
        self.Text:SetPoint("TOPLEFT",self.forComboBox and 6 or 8,0)
        self.Icon:Hide()
    end
end

-- this is a postFunc added to all menu items, to update the dropdown's displayed text/icon and set the
-- selectedValue for basic dropdowns; self is the info of the menu item and subject is the dropdown itself
local function postMenuItemOnClick(self,subject)
    setDropDownText(subject,self.text,self.icon,self.iconCoords)
    subject.selectedValue = self.value
end

--[[ mixin ]]

RematchDropDownMixin = {}

-- sets up basic dropdown behavior:
-- info = {{text="option 1",value="opt1",icon="path\texture1.blp",iconCoords={left,right,top,bottom},tooltipTitle="etc",tooltipBody="etc"},
--         {text="option 2",value="opt2",icon="path\texture2.blp",iconCoords={left,right,top,bottom}}, etc}
-- func = function(dropdown,chosen value)
function RematchDropDownMixin:BasicSetup(menu,func)
    local dropdown = self -- for referencing within menu functions (where self is the info of the chosen selection
    -- build menu and functions from the given info and func
    local function dropdownFunc(self) if func then func(self.value) end end -- passes only the chosen value to func in second parameter
    local function dropdownHighlight(self)
        if dropdown.forComboBox then -- for comboboxes, highlight matching text
            return self.text==dropdown.Text:GetText()
        else -- for normal dropdowns, highlight matching value
            return self.value==dropdown.selectedValue
        end
    end -- highlight selectedValue
    for i,info in ipairs(menu) do
        assert(info.value and info.text,"All dropdown menu entries must have a value and text. See templates\\dropdown.lua.")
        info.func = dropdownFunc
        info.highlight = dropdownHighlight
        if i==1 then
            self.selectedValue = info.value -- pickup first value as default
        end
    end

    self:SetMenu(menu)
    self:SetSelection("value",self.selectedValue)

end

-- sets the menu to the dropdown that will appear when the dropdown is clicked
function RematchDropDownMixin:SetMenu(menu)
    if not self.menuName then -- first time registering a menu, create a new name
        self.menuName = format("DropDownMenu%d",rematch.utils:GetNewMenuID())
    end
    for _,menuItem in ipairs(menu) do
        menuItem.postFunc = postMenuItemOnClick
    end
    rematch.menus:Register(self.menuName,menu)
end

-- sets the text/icon displayed in the dropdown to the choice where the given key is the given value; for instance
-- a {anchor="BOTTOMRIGHT",etc=..} will select this with SetSelection("anchor","BOTTOMRIGHT")
-- if no second parameter is given, then it will assume this is a "value" key for basic dropdowns
function RematchDropDownMixin:SetSelection(key,value)
    if value==nil then -- this is likely a basic dropdown where the key is "value"
        value = key
        key = "value"
    end
    if self.menuName then
        local menu = getMenu(self)
        for _,info in ipairs(menu) do
            if info[key]==value then
                self.selectedValue = value
                setDropDownText(self,info.text,info.icon,info.iconCoords)
                return
            end
        end
    end
    -- if we reached here, there was an attempt to set to a value that doesn't exist, throw an exception
    assert(false,"value '"..(value or "nil").."' doesn't exist for '"..(key or "nil").."' in dropdown menu")
end

-- returns the currently selected value
function RematchDropDownMixin:GetSelection()
    return self.selectedValue
end

function RematchDropDownMixin:OnEnter()
    rematch.textureHighlight:Show(self.DropDownButton,self.Left,self.Right,self.Middle)
end

function RematchDropDownMixin:OnLeave()
    rematch.textureHighlight:Hide()
end

function RematchDropDownMixin:OnMouseDown()
    rematch.textureHighlight:Hide()
end

function RematchDropDownMixin:OnMouseUp()
    if self:IsMouseMotionFocus() then
        rematch.textureHighlight:Show(self.DropDownButton,self.Left,self.Right,self.Middle)
    end
end

-- called when the dropdown is clicked (the right button is highlighted but the whole dropdown box counts for clicks)
-- it toggles a menu just beneath the control that's at least as wide as the dropdown
function RematchDropDownMixin:OnClick(button)
    if self.menuName then
        local menu = getMenu(self)
        if menu and menu[1] then -- make menu width be at least dropdown's width
            menu[1].minWidth = self:GetWidth()-(C.MENU_FRAME_PADDING*2)
        end
        -- one of the self parameter is the subject, the dropdown itself; so PostMenuItemClick can use it
        rematch.menus:Toggle(self.menuName,self,self,"TOPRIGHT",self,"BOTTOMRIGHT",0,2)
        PlaySound(C.SOUND_CHECKBUTTON)
    end
end

-- if dropdown hidden by a collapsing header or other reason, menu attached to it should hide too
function RematchDropDownMixin:OnHide()
    rematch.menus:Hide()
end
