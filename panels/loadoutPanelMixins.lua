local _,rematch = ...
local L = rematch.localization
local C = rematch.constants

-- mixin for ability bar within a loadout slot and also for flyout abilities (if self.isFlyoutAbility is true)

RematchAbilityBarButtonMixin = {}

function RematchAbilityBarButtonMixin:OnEnter()
    if not self.isFlyoutAbility and not self.noClick and rematch.utils:IsJournalUnlocked() then
        local arrow = self:GetParent():GetParent():GetParent().FlyoutArrow
        arrow:SetParent(self) -- parent arrow to abilityBar that contains this ability
        if arrow.direction=="LEFT" then -- this is for the miniLoadoutPanel
            arrow:SetPoint("CENTER",self,"LEFT",-3,1)
        elseif arrow.direction=="BOTTOM" then -- this is for main loadout
            arrow:SetPoint("CENTER",self,"BOTTOM",2,-4)
        end
        arrow:Show()
    end
    rematch.textureHighlight:Show(self.Icon)
    rematch.abilityTooltip:ShowTooltip(self,self.petID,self.abilityID,rematch.frame)
end

function RematchAbilityBarButtonMixin:OnLeave()
    if not self.isFlyoutAbility and not self.noClick then
        local arrow = self:GetParent():GetParent():GetParent().FlyoutArrow
        arrow:Hide()
    end
    rematch.textureHighlight:Hide()
    rematch.abilityTooltip:Hide()
end

function RematchAbilityBarButtonMixin:OnMouseDown()
    if rematch.utils:IsJournalUnlocked() then
        rematch.textureHighlight:Hide()
    end
end

function RematchAbilityBarButtonMixin:OnMouseUp()
    if self:IsMouseMotionFocus() and rematch.utils:IsJournalUnlocked() then
        rematch.textureHighlight:Show(self.Icon)
    end
end

-- click of ability on ability bar or flyout
function RematchAbilityBarButtonMixin:OnClick(button)
    if self.noClick or rematch.utils:IsJournalLocked() then -- this is not part of an ability bar within or with a flyout, leave
        return
    elseif rematch.utils:HandleSpecialAbilityClicks(self.abilityID,self:GetParent().petID) then -- shift+click ability to chat
        return
    elseif button=="RightButton" then
        rematch.menus:Show("AbilityMenu",self,self.abilityID,"cursor")
        return
    elseif self.isFlyoutAbility then -- this is a flyout ability button
        local flyout = self:GetParent()
        -- load the ability into the flyout parent's GetID slot
        if self.isUsable and self.abilityID then
            local flyout = self:GetParent()
            C_PetJournal.SetAbility(flyout.petSlot,flyout.abilitySlot,self.abilityID)
            flyout:Hide()
            --rematch.frame:Update() -- don't use this, the addon should be watching for ability changes
        end
    else -- this is an ability button on an abilityBar
        local abilityBar = self:GetParent()
        local loadout = abilityBar:GetParent()
        local panel = loadout:GetParent()
        local flyout = panel.AbilityFlyout
        local petSlot = loadout:GetID()
        local petID = loadout.petID
        -- if clicking ability slot when flyout already opened for it, close flyout and leave
        if flyout.petSlot==petSlot and flyout.abilitySlot==self:GetID() and flyout:IsVisible() then
            flyout:Hide()
        else
            flyout.petSlot = petSlot
            flyout.abilitySlot = self:GetID()
            flyout.anchoredTo = self -- used by flyout's OnUpdate to know what opened the flyout
            flyout:SetParent(abilityBar)
            if flyout.horizontal then
                flyout:SetPoint("TOP",self,"BOTTOM",0,-3)
            else
                flyout:SetPoint("RIGHT",self,"LEFT",-1,0)
            end
            flyout:FillAbilityFlyout(petSlot,self:GetID())
            flyout:Show()
        end
    end
end

