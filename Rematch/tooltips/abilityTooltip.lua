local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.abilityTooltip = RematchAbilityTooltip

rematch.events:Register(rematch.abilityTooltip,"PLAYER_LOGIN",function(self)
	local font,size,flag = self.Top.Name:GetFont()
	self.Top.Name:SetFont(font,size+2,flag)

    self.Hints.StrongVs:SetText(L["Vs"])
    self.Hints.WeakVs:SetText(L["Vs"])

    rematch.tooltipManager:AddBehavior(self) -- add delay behavior to the ability tooltip
end)

-- updates the content of the ability tooltip; petID needed because parsed description varies based on pet's stats
-- returns true if a valid ability is shown
function rematch.abilityTooltip:Update(petID,abilityID)
    local petInfo = rematch.petInfo:Fetch(petID)
    if petInfo.isSpecialType or not petInfo.abilityList or #petInfo.abilityList==0 or not abilityID then
        return -- leave if this isn't a pet with abilities or an ability isn't given
    end
    local _,name,icon,maxCooldown,unparsedDescription,numTurns,petType,noHints = C_PetBattles.GetAbilityInfoByID(abilityID)
    local suffix = PET_TYPE_SUFFIX[petType]
    if not suffix then
        return -- leave if this type isn't known (should never happen)
    end
    -- now to let the default UI do the heavy lifting: create a parsed tooltip that we'll scrape values from
    local tooltip = FloatingPetBattleAbilityTooltip
    -- get the pet's stats (will affect parsed description), using 100/0/0 if no stats defined
    local maxHealth,power,speed = petInfo.maxHealth or 100, petInfo.power or 0, petInfo.speed or 0
    -- generate a parsed tooltip based on the abilityID and given stats
    FloatingPetBattleAbility_Show(abilityID,maxHealth,power,speed)

    -- at this point, default tooltip is filled in. now copy default's work

    -- update top
    self.Top.Name:SetText(name)
    self.Top.AbilityIcon:SetTexture(icon)
    self.Top.TypeIcon:SetTexture("Interface\\Icons\\Icon_PetFamily_"..suffix)

    -- update details
    local yoff = -C.ABILITY_TOOLTIP_OUTER_PADDING

    local hasDuration = tooltip.Duration:IsVisible()
    if hasDuration then
        self.Details.Duration:SetText(tooltip.Duration:GetText())
        self.Details.Duration:SetPoint("TOP",0,yoff)
        self.Details.Duration:Show()
        yoff = yoff - self.Details.Duration:GetStringHeight() - C.ABILITY_TOOLTIP_INNER_PADDING
    else
        self.Details.Duration:Hide()
    end

    local hasCooldown = tooltip.MaxCooldown:IsVisible()
    if hasCooldown then
        self.Details.Cooldown:SetText(tooltip.MaxCooldown:GetText())
        self.Details.Cooldown:SetPoint("TOP",0,yoff)
        self.Details.Cooldown:Show()
        yoff = yoff - self.Details.Cooldown:GetStringHeight() - C.ABILITY_TOOLTIP_INNER_PADDING
    else
        self.Details.Cooldown:Hide()
    end

    local hasDescription = tooltip.Description:GetText()
    if hasDescription then
        self.Details.Description:SetText(tooltip.Description:GetText())
        self.Details.Description:SetPoint("TOP",0,yoff)
        self.Details.Description:Show()
        yoff = yoff - self.Details.Description:GetStringHeight() - C.ABILITY_TOOLTIP_INNER_PADDING
    else
        self.Details.Description:Hide()
    end

    if settings.ShowAbilityID then
        self.Details.AbilityID:SetText(format(L["\124TInterface\\WorldMap\\Gear_64Grey:16:16:0:0:64:64:8:56:6:57\124t %sAbility ID: %d"],C.HEX_GREY,abilityID))
        self.Details.AbilityID:SetPoint("TOP",0,yoff-2)
        self.Details.AbilityID:Show()
        yoff = yoff - self.Details.AbilityID:GetStringHeight() - C.ABILITY_TOOLTIP_INNER_PADDING
    else
        self.Details.AbilityID:Hide()
    end

    local backHeight = -yoff + C.ABILITY_TOOLTIP_OUTER_PADDING
    local backSize = min(self:GetWidth()-8,backHeight-8)

    if settings.AbilityBackground=="Icon" and backSize>32 then
        self.Details.IconBackground:SetTexture(icon)
        self.Details.FadeMask:SetSize(backSize,backSize)
        self.Details.IconBackground:SetSize(backSize,backSize)
        self.Details.IconBackground:Show()
    else
        self.Details.IconBackground:Hide()
    end

    if settings.AbilityBackground=="Type" and backSize>32 then
        self.Details.TypeBackground:SetTexture("Interface\\PetBattles\\PetIcon-"..suffix)
        self.Details.TypeBackground:SetSize(backSize,backSize)
        self.Details.TypeBackground:Show()
    else
        self.Details.TypeBackground:Hide()
    end

    -- update hints (strong vs and weak vs types; if shown at all)
    if noHints then -- on heals and buffs, the hints section is now shown
        self.Hints:Hide()
        self.Details:SetPoint("BOTTOM",0,4)
    else
        self.Hints:Show()
        self.Details:SetPoint("BOTTOM",self.Hints,"TOP")
        self.Hints.StrongType:SetTexture(tooltip.StrongAgainstType1:GetTexture())
        self.Hints.WeakType:SetTexture(tooltip.WeakAgainstType1:GetTexture())
    end

    tooltip:Hide() -- default tooltip's work is done; hide it

    -- finally, resize based on height of content
    height = self.Top:GetHeight() + -yoff + C.ABILITY_TOOLTIP_OUTER_PADDING + (noHints and 0 or self.Hints:GetHeight()) + 2
    self:SetHeight(height)

    return true -- if we made it here, the ability was valid
end

-- shows the ability tooltip for petID/abilityID anchored to anchorTo; with reference being the frame
-- to reference for which corner to anchor to (rematch.frame, rematch.dialog, etc.)
function rematch.abilityTooltip:ShowTooltip(anchorTo,petID,abilityID,reference)
    if not reference then
        reference = UIParent
    end
    if rematch.abilityTooltip:Update(petID,abilityID) then
        local corner,opposite = rematch.utils:GetCorner(rematch.utils:GetFrameForReference(reference),UIParent)
        rematch.abilityTooltip:ClearAllPoints()
        rematch.abilityTooltip:SetPoint(corner,anchorTo,opposite)
        rematch.abilityTooltip:Show()
    end
end
