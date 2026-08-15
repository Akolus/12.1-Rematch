local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings

RematchTypeBarTabMixin = {}

function RematchTypeBarTabMixin:OnEnter()
    if not self.isSelected then
        self.Text:SetTextColor(1,1,1)
        self.Highlight:Show()
    end
end

function RematchTypeBarTabMixin:OnLeave()
    if self.isSelected then
        self.Text:SetTextColor(1,1,1)
    else
        self.Text:SetTextColor(1,0.82,0)
    end
    self.Highlight:Hide()
end

function RematchTypeBarTabMixin:OnMouseDown()
    if not self.isSelected then -- only do a push effect on unselected tabs
        self.Text:SetPoint("CENTER",-1,-2)
    end
end

function RematchTypeBarTabMixin:OnMouseUp()
    self.Text:SetPoint("CENTER",0,-1)
end

function RematchTypeBarTabMixin:OnClick()
    settings.TypeBarTab = self.id
    self:GetParent():Update()
end
