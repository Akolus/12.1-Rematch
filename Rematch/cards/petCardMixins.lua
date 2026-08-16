local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings

RematchPetCardTopButtonMixin = {}

function RematchPetCardTopButtonMixin:OnEnter()
    self.Highlight:Show()
    if not settings.PetCardNoMouseoverFlip then
        rematch.petCard.softFlip = true
        rematch.petCard:FlipCard()
    end
end

function RematchPetCardTopButtonMixin:OnLeave()
    self.Highlight:Hide()
    if not settings.PetCardNoMouseoverFlip then
        rematch.petCard.softFlip = false
        rematch.petCard:FlipCard()
    end
end

function RematchPetCardTopButtonMixin:OnMouseDown()
    self.Highlight:Hide()
end

function RematchPetCardTopButtonMixin:OnMouseUp()
    if self:IsMouseMotionFocus() then
        self.Highlight:Show()
    end
end

-- click of a top button will flip the card (unless it's a special type like leveling, random, ignored)
function RematchPetCardTopButtonMixin:OnClick()
    local petInfo = rematch.petInfo:Fetch(rematch.petCard.petID)
    if not petInfo.isSpecialType then
        rematch.petCard.hardFlip = not rematch.petCard.hardFlip
        rematch.petCard:FlipCard()
    end
end

RematchPetCardAbilityMixin = {}

function RematchPetCardAbilityMixin:OnEnter()
    self.Highlight:Show()
    rematch.textureHighlight:Show(self.Icon)
    rematch.menus:Hide()
    rematch.abilityTooltip:ShowTooltip(self,rematch.petCard.petID,self.abilityID,rematch.petCard)
end

function RematchPetCardAbilityMixin:OnLeave()
    self.Highlight:Hide()
    rematch.textureHighlight:Hide()
    rematch.abilityTooltip:Hide()
end

function RematchPetCardAbilityMixin:OnClick(button)
    if rematch.utils:HandleSpecialAbilityClicks(self.abilityID,rematch.petCard.petID) then
        return
    elseif button=="RightButton" then
        rematch.menus:Show("AbilityMenu",self,self.abilityID,"cursor")
    end
end

RematchPetCardStatusBarMixin = {}

function RematchPetCardStatusBarMixin:OnEnter()
    self.Text:Show()
end

function RematchPetCardStatusBarMixin:OnLeave()
    if not settings.PetCardAlwaysShowHPXPText then
        self.Text:Hide()
    end
end

RematchPetCardStatMixin = {}

-- stat buttons are created on demand, and need to be added to clickable elements for card manager
function RematchPetCardStatMixin:OnLoad()
    rematch.cardManager:AddClickableElementToCard(rematch.petCard,self)
    self:EnableMouse(false) -- start off transparent to mouse clicks
end

function RematchPetCardStatMixin:OnEnter()
    local info = rematch.petCardStats[self:GetID()]
    if info then
        self.Highlight:Show()
        if self.Icon then
            rematch.textureHighlight:Show(self.Icon)
        end
        local petInfo = rematch.petInfo:Fetch(rematch.petCard.petID)

        if info.enter then
            info.enter(self,petInfo)
        elseif info.altTooltip=="Breed" and (settings.PetCardMinimized or settings.PetCardHidePossibleBreeds) then -- special case for Breed stat, show BreedTable if possible breeds hidden
            rematch.petCard:ShowBreedTable(self)
        else
            local tooltipTitle = rematch.utils:Evaluate(rematch.utils:Evaluate(info.tooltipTitle,rematch.petCard,petInfo))
            local tooltipBody = rematch.utils:Evaluate(rematch.utils:Evaluate(info.tooltipBody,rematch.petCard,petInfo))
            if tooltipTitle then
                rematch.tooltip:ShowSimpleTooltip(self,tooltipTitle,tooltipBody)
            end
        end
    end
end

function RematchPetCardStatMixin:OnLeave()
    local info = rematch.petCardStats[self:GetID()]
    if info then
        self.Highlight:Hide()
        if self.Icon then
            rematch.textureHighlight:Hide()
        end
        rematch.petCard:HideBreedTable()
        if info.leave then
            info.leave(self,rematch.petInfo:Fetch(rematch.petCard.petID))
        end
    end
    rematch.tooltip:Hide()
end

function RematchPetCardStatMixin:OnMouseDown()
    local info = rematch.petCardStats[self:GetID()]
    if info then
        self.Highlight:Hide()
        if self.Icon then
            rematch.textureHighlight:Hide()
        end
    end
end

function RematchPetCardStatMixin:OnMouseUp()
    local info = rematch.petCardStats[self:GetID()]
    if info then
        self.Highlight:Show()
        if self.Icon then
            rematch.textureHighlight:Hide(self.Icon)
        end
    end
end

function RematchPetCardStatMixin:OnClick()
    local info = rematch.petCardStats[self:GetID()]
    if info and info.click then
        info.click(self,rematch.petInfo:Fetch(rematch.petCard.petID))
    end
end
