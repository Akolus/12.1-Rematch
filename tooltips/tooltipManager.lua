local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.tooltipManager = {}

--[[
    The normal behavior of cards is to wait a quarter of a second before displaying on mouseover, so the mouse can
    move across the UI without flashing a bunch of pets the user isn't interested in. The same principle is being
    applied to tooltips (including ability tooltips and other tooltips).

    Since tooltips are never interactable, so they don't lock or pin, the behavior is essentially just delaying to
    show and that's it.  So adding this behavior is simply starting a timer to show the tooltip and stopping the
    timer if the tooltip is being hidden.

    The function rematch.tooltipManager:AddBehavior(tooltip) will add this behavior to any frame given as a tooltip,
    though it should only be used for frames that are mouse disabled.

    Then any tooltip:Show() will wait a quarter of a second (or whatever the TooltipBehavior setting says) before
    showing the tooltip.

    It's up to the calling function to handle all anchoring and updating the contents of the tooltip.
]]


local tooltipInfo = {}

function rematch.tooltipManager:AddBehavior(tooltip)
    -- storing details of the tooltip as an entry in tooltipInfo
    tooltipInfo[tooltip] = {
        oldShow = tooltip.Show,
        oldHide = tooltip.Hide,
        timer = function(self)
            tooltipInfo[tooltip].oldShow(tooltip)
        end,
    }
    -- overriding tooltip's show behavior to make it wait (if that's defined behavior) to show the tooltip
    -- if now is true, immediately show the tooltip regardless of settings
    tooltip.Show = function(self,now)
        local timer = tooltipInfo[self].timer
        if rematch.timer:IsRunning(timer) then
            rematch.timer:Stop(timer)
        end
        if now then
            tooltipInfo[self].oldShow(self)
            self.fadeWait = C.TOOLTIP_FADE_WAIT
            self.fadeAlpha = C.TOOLTIP_FADE_ALPHA
        elseif settings.TooltipBehavior==C.MOUSE_SPEED_SLOW then
            rematch.timer:Start(C.CARD_MANAGER_DELAY_SLOW,timer)
        elseif settings.TooltipBehavior==C.MOUSE_SPEED_NORMAL then
            rematch.timer:Start(C.CARD_MANAGER_DELAY_NORMAL,timer)
        else -- if settings.TooltipBehavior=="Fast" then
            tooltipInfo[self].oldShow(self)
        end
        self:SetAlpha(1)
        if self.RedBorder then
            self.RedBorder:SetShown(now and true or false)
        end
    end
    -- overriding tooltip's hide behavior to stop any running timer and hide the tooltip
    tooltip.Hide = function(self)
        local timer = tooltipInfo[self].timer
        if rematch.timer:IsRunning(timer) then
            rematch.timer:Stop(timer)
        end
        tooltipInfo[self].oldHide(self)
        self:SetScript("OnUpdate",nil)
        if self.RedBorder then
            self.RedBorder:Hide()
        end
    end
end
