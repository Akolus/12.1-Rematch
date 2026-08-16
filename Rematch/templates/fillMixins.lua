local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings


--[[ RematchFillPetMixin adds FillPet(petID) to fill in a pet ]]
-- self.neverDim = true if the pet should never be desaturated/tinted due to not owning it

RematchFillPetMixin = {}

-- common function to fill a pet icon, border, favorite, level and status
-- dim is true if the pet should be force greyed out (and not naturally greyed out for being a speciesID)
function RematchFillPetMixin:FillPet(petID,dim)
    local petInfo = rematch.petInfo:Fetch(petID)
    -- note to self: don't set self.petID = petID here; sometimes a battle:1:x petID is filled instead of actual petID

    local tint = not self.neverDim and petInfo.tint
    if dim then
        tint = "grey"
    end

     -- icon
    self.Icon:SetTexture(petInfo.needsFanfare and C.FANFARE_ICON or petInfo.icon)
    rematch.utils:TintTexture(self.Icon,tint)
    -- rarity border
    if not settings.HideRarityBorders and petInfo.color and petInfo.isSummonable and not dim then
        self.Border:SetVertexColor(petInfo.color.r,petInfo.color.g,petInfo.color.b)
    elseif tint=="red" then
        self.Border:SetVertexColor(1,0.25,0.25)
    else
        self.Border:SetVertexColor(0.5,0.5,0.5)
    end
    -- favorite
    if self.Favorite then
        if petInfo.isFavorite then
            self.Favorite:Show()
            rematch.utils:TintTexture(self.Favorite,tint)
        else
            self.Favorite:Hide()
        end
    end
    -- level bubble
    if self.Level then
        local level = petInfo.level
        if level and (level<25 or not settings.HideLevelBubbles) then
            local x = (level-1)%8*0.125
            local y = floor((level-1)/8)*0.25
            self.Level:SetTexCoord(x,x+0.125,y,y+0.25)
            self.Level:Show()
            rematch.utils:TintTexture(self.Level,tint)
        else
            self.Level:Hide()
        end
    end
    if self.LevelBubble then
        local level = petInfo.level
        if level and (level<25 or not settings.HideLevelBubbles) then
            self.LevelText:SetText(level)
            self.LevelBubble:Show()
            self.LevelText:Show()
        else
            self.LevelBubble:Hide()
            self.LevelText:Hide()
        end
    end
    -- status is the red haze effect for injured pets and red X for dead pets
    if self.Status then
        if petInfo.isDead then
            self.Status:SetTexCoord(0,0.3125,0,0.625)
            self.Status:Show()
        elseif petInfo.isInjured then
            self.Status:SetTexCoord(0.3125,0.625,0,0.625)
            self.Status:Show()
        else
            self.Status:Hide()
        end
    end
end

--[[ abilities ]]

-- shared by RematchFillAbilityBarMixin and RematchFillAbilityFlyoutMixin
-- fills a single ability for petID and ability slot with the abilityID; showing the 1/2 number if showNumbers is true
local function fillAbilitySlot(self,petID,abilityID,abilitySlot,showNumber)
    self.isUsable = false
    self.petID = petID
    self.abilityID = abilityID
    if not abilityID then
        self.Icon:SetTexture(C.EMPTY_ICON)
        self.Number:Hide()
        self.Level:Hide()
    else
        local petInfo = rematch.petInfo:Fetch(petID)
        -- if abilityID is a 1 or 2, and an abilitySlot is defined, get abilityID for the 1/2 for that slot
        if abilitySlot and (abilityID==1 or abilityID==2) then
            abilityID = petInfo.abilityList[abilitySlot + (abilityID==1 and 0 or 3)]
        end
        self.Icon:SetTexture((select(3,C_PetBattles.GetAbilityInfoByID(abilityID))) or C.EMPTY_ICON)

        local abilityIndex = petInfo.abilityList and rematch.utils:GetIndexByValue(petInfo.abilityList,abilityID)
        local abilityLevel = abilityIndex and petInfo.levelList and petInfo.levelList[abilityIndex]
        if showNumber then -- show the 1/2 if it should be shown
            self.Number:SetText(abilityIndex and (abilityIndex<=3 and "1" or "2") or "")
        end
        self.Number:SetShown(showNumber)

        if abilityLevel and petInfo.level and petInfo.level < abilityLevel then
            self.Icon:SetDesaturated(true)
            self.Icon:SetVertexColor(0.4,0.4,0.4)
            self.Number:SetTextColor(0.4,0.4,0.4)
            self.Level:SetText(abilityLevel)
            self.Level:Show()
        else
            self.Icon:SetDesaturated(false)
            self.Icon:SetVertexColor(1,1,1)
            self.Number:SetTextColor(1,1,1)
            self.Level:Hide()
            self.isUsable = true
        end

    end
end

--[[ RematchFillAbilityBarMixin adds FillAbilities(petID,ability1,ability2,ability3) to fill in a bar of abilities ]]
-- self.horizontal = true if abilities are horizontal (main loadouts); false if veritcal (mini loadouts, teams in dialogs)

RematchFillAbilityBarMixin = {}

function RematchFillAbilityBarMixin:FillAbilityBar(petID,ability1,ability2,ability3)
    -- update border (need at least first abilityID to be non-nil to use number insets)
    local showNumbers = settings.ShowAbilityNumbers and settings.ShowAbilityNumbersLoaded and ability1 and true or false
    if showNumbers and self.horizontal then -- horizontal with number insets
        self.AbilitiesBorder:SetTexCoord(0.5,0.9375,0.15625,0.296875)
    elseif showNumbers then -- vertical with number insets
        self.AbilitiesBorder:SetTexCoord(0.125,0.2265625,0.203125,0.5)
    elseif self.horizontal then -- horizontal plain
        self.AbilitiesBorder:SetTexCoord(0.5,0.9375,0,0.140625)
    else -- vertical plain
        self.AbilitiesBorder:SetTexCoord(0,0.1015625,0.203125,0.5)
    end
    fillAbilitySlot(self.Abilities[1],petID,ability1,1,showNumbers)
    fillAbilitySlot(self.Abilities[2],petID,ability2,2,showNumbers)
    fillAbilitySlot(self.Abilities[3],petID,ability3,3,showNumbers)
end

--[[ RematchFillAbilityFlyoutMixin fills the two abilities in a flyout based on petSlot abilitySlot ]]

RematchFillAbilityFlyoutMixin = {}

function RematchFillAbilityFlyoutMixin:FillAbilityFlyout(petSlot,abilitySlot)
    local petID,ability1,ability2,ability3 = C_PetJournal.GetPetLoadOutInfo(petSlot)
    local showNumbers = settings.ShowAbilityNumbers
    if showNumbers and self.horizontal then -- main loadout border with ability number insets
        self.Border:SetTexCoord(0.703125,0.875,0.3125,0.62890625)
    elseif showNumbers then -- mini loadout border with ability number insets
        self.Border:SetTexCoord(0.25,0.44921875,0.390625,0.4921875)
    elseif self.horizontal then -- main loadout border without ability number insets
        self.Border:SetTexCoord(0.5,0.671875,0.3125,0.62890625)
    else -- mini loadout border without ability number insets
        self.Border:SetTexCoord(0.25,0.44921875,0.28125,0.3828125)
    end
    local petInfo = rematch.petInfo:Fetch(petID)
    if petInfo.isValid then
        local flyoutAbility1 = petInfo.abilityList[abilitySlot]
        local flyoutAbility2 = petInfo.abilityList[abilitySlot+3]
        fillAbilitySlot(self.Abilities[1],petID,flyoutAbility1,nil,showNumbers)
        fillAbilitySlot(self.Abilities[2],petID,flyoutAbility2,nil,showNumbers)
        local abilityMatch = abilitySlot==1 and ability1 or abilitySlot==2 and ability2 or ability3
        self.AbilitySelecteds[1]:SetShown(flyoutAbility1==abilityMatch)
        self.AbilitySelecteds[2]:SetShown(flyoutAbility2==abilityMatch)
    else
        fillAbilitySlot(self.Abilities[1])
        fillAbilitySlot(self.Abilities[2])
    end
end

