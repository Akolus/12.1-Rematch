local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings

--[[ RematchCommonPetListButtonMixin for both normal and compact list buttons ]]

RematchCommonPetListButtonMixin = {}

function RematchCommonPetListButtonMixin:OnEnter()
    rematch.textureHighlight:Show(self.Back)
    rematch.cardManager:OnEnter(rematch.petCard,self,self.petID)
    if self.forQueue then
        local petID,canLevel = rematch.utils:GetPetCursorInfo(true)
        if petID and not canLevel then
            rematch.tooltip:ShowSimpleTooltip(self,nil,L["This pet cannot level.\n\nIt can't be added to the leveling queue."],"cursor")
        end
    end
    -- if pet herder is up and action chosen, then we're targeting a pet to do something
    if rematch.petHerder:IsTargeting() then
        rematch.petHerder:SetCursorForPetID(self.petID)
    end
end

function RematchCommonPetListButtonMixin:OnLeave()
    rematch.textureHighlight:Hide()
    if GetMouseFoci()[1]~=self.Icon then -- don't dismiss card if moving onto pet button
        rematch.cardManager:OnLeave(rematch.petCard,self,self.petID)
    end
    SetCursor(nil)
    rematch.dialog.Canvas.PetHerderPicker.petID = nil
    rematch.tooltip:Hide()
end

function RematchCommonPetListButtonMixin:OnMouseDown()
    rematch.textureHighlight:Hide()
end

function RematchCommonPetListButtonMixin:OnMouseUp(button)
    if self:IsMouseMotionFocus() then
        rematch.textureHighlight:Show(self.Back)
    end
end

function RematchCommonPetListButtonMixin:OnClick(button)
    if rematch.petHerder:IsTargeting() then -- targeting with pet herder takes priority on clicks
        if button=="RightButton" then
            rematch.dialog:Hide()
        else
            rematch.petHerder:HerdPetID(self.petID)
        end
    elseif rematch.petInfo:Fetch(self.petID).needsFanfare then -- for wrapped pets, show pet card (maximized)
        if settings.PetCardMinimized then
            settings.PetCardMinimized = false
            rematch.petCard:Configure()
            rematch.petCard:Update()
        end
        rematch.cardManager:OnClick(rematch.petCard,self,self.petID)
    elseif button=="RightButton" and not self.noPickup then -- on right-click summon menu
        rematch.menus:Show("PetMenu",self,self.petID,"cursor")
    else -- all else show/lock/unlock card
        rematch.cardManager:OnClick(rematch.petCard,self,self.petID)
    end
end

function RematchCommonPetListButtonMixin:OnDoubleClick()
    if self.forQueue and settings.QueueDoubleClick then
        local oldIndex = rematch.queue:GetPetIndex(self.petID)
        if oldIndex and #settings.LevelingQueue>1 then
            rematch.queue:MoveIndex(oldIndex,1)
            rematch.queue:BlingPetID(self.petID)
        end
        rematch.petCard:Hide()
    elseif not settings.NoSummonOnDblClick and rematch.petInfo:Fetch(self.petID).isOwned then
        C_PetJournal.SummonPetByGUID(self.petID)
        rematch.petCard:Hide()
    end
end

function RematchCommonPetListButtonMixin:OnDragStart()
    local petInfo = rematch.petInfo:Fetch(self.petID)
    if petInfo.isOwned and petInfo.idType=="pet" and not self.noPickup then
        C_PetJournal.PickupPet(self.petID)
    end
end

--[[ RematchNormalPetListButtonMixin for normal list buttons ]]

RematchNormalPetListButtonMixin = {}

function RematchNormalPetListButtonMixin:Fill(petID,dim)
    local petInfo = rematch.petInfo:Fetch(petID)
    self.petID = petID
    local notesWidth, breedWidth = 0,0
    local tint = dim and "grey" or petInfo.tint

    -- fill pet icon and its related textures (border, favorite, level, status)
    self.Icon.petID = petID
    self:FillPet(petID,dim)
    -- type fill type decal on the right
    local petType = petInfo.petType
    if petType then
		local x = ((petType-1)%4)*0.25
		local y = floor((petType-1)/4)*0.25
        self.TypeDecal:SetTexCoord(x,x+0.25,y,y+0.171875)
        self.TypeDecal:Show()
        rematch.utils:TintTexture(self.TypeDecal,tint)
    else
        self.TypeDecal:Hide()
    end

    -- notes button is always in the same place, a 20x20 button at -3,-3 from topright
    if not settings.HideNotesBadges and petInfo.hasNotes then
        self.NotesButton:Show()
        notesWidth = 24
    else
        self.NotesButton:Hide()
        notesWidth = 2
    end

    -- breed
    if petInfo.breedName and (not settings.HideBreedsLists or self.alwaysShowBreed) then
        self.Breed:SetFontObject(settings.LargerBreedText and "GameFontNormal" or "GameFontNormalSmall")
        self.Breed:SetText(petInfo.breedName)
        self.Breed:Show()
        breedWidth = 28 -- breed is centered at bottomright -14,12; so width is 14*2 = 28
    else
        self.Breed:Hide()
    end

    -- place badges
    local badgeXoff = -1-notesWidth -- right xoffset is depending on notes shown
    local badgesWidth = rematch.badges:AddBadges(self.Badges,"pets",petID,"TOPRIGHT",self,"TOPRIGHT",badgeXoff,-8,-1)

    local left = 50 -- in normal mode, names begin 50px from left due to icon and a little padding for level bubble
    local right = -(4 + max(notesWidth+badgesWidth,breedWidth))

    -- this will likely be re-anchored, but setting now to get height of name
    self.PetName:SetPoint("TOPLEFT",left,-2)
    self.PetName:SetPoint("TOPRIGHT",right,-2)
    -- set height and text of pet name
    self.PetName:SetText(petInfo.name)

    local height = self.PetName:GetStringHeight()

    if petInfo.customName then
        self.SpeciesName:SetText(petInfo.speciesName)
        height = height + self.SpeciesName:GetStringHeight() + 1
        self.SpeciesName:Show()
    else
        self.SpeciesName:Hide()
    end

    self.PetName:SetPoint("TOPLEFT",left,-((44-height)/2))
    self.PetName:SetPoint("TOPRIGHT",right,-((44-height)/2))

    -- finally color the name
    if tint=="red" then
        self.PetName:SetTextColor(1,0.25,0.25)
    elseif tint=="grey" then
        self.PetName:SetTextColor(0.75,0.75,0.75)
    elseif settings.ColorPetNames and petInfo.color then
        self.PetName:SetTextColor(petInfo.color.r,petInfo.color.g,petInfo.color.b)
    else
        self.PetName:SetTextColor(1,0.82,0)
    end
end

--[[ RematchCompactPetListButtonMixin for compact list buttons ]]

RematchCompactPetListButtonMixin = {}

function RematchCompactPetListButtonMixin:Fill(petID,dim)
    local petInfo = rematch.petInfo:Fetch(petID)
    self.petID = petID
    local right = -37 -- offset from right edge for name/badges
    local tint = dim and "grey" or petInfo.tint

    -- fill pet icon and its related textures (border, favorite, level, status)
    self.petID = petID
    self.Icon.petID = petID
    self:FillPet(petID,dim)
    -- type fill type decal on the right
    local petType = petInfo.petType
    if petType then
		local x = ((petType-1)%4)*0.25
		local y = floor((petType-1)/4)*0.25
        self.TypeDecal:SetTexCoord(x,x+0.25,y,y+0.171875)
        self.TypeDecal:Show()
        rematch.utils:TintTexture(self.TypeDecal,tint)
    else
        self.TypeDecal:Hide()
    end

    if petInfo.breedName and not settings.HideBreedsLists then
        self.Breed:SetFontObject(settings.LargerBreedText and "GameFontHighlight" or "GameFontHighlightSmall")
        self.Breed:SetText(petInfo.breedName)
        self.Breed:Show()
    else
        self.Breed:Hide()
    end

    -- show notes button
    if not settings.HideNotesBadges and petInfo.hasNotes then
        self.NotesButton:Show()
        self.Badges[1]:SetPoint("RIGHT",self.NotesButton,"LEFT",-2,0)
        right = right - 20 - 2
    else
        self.NotesButton:Hide()
        self.Badges[1]:SetPoint("RIGHT",right,0)
    end

    -- place badges
    local badgeXoff = right -- right xoffset is depending on notes shown
    local badgesWidth = rematch.badges:AddBadges(self.Badges,"pets",petID,"TOPRIGHT",self,"TOPRIGHT",badgeXoff,-7,-1)

    right = right - badgesWidth

    -- name
    self.PetName:SetPoint("RIGHT",right,0)
    self.PetName:SetText(petInfo.name)

    -- finally color the name
    if tint=="red" then
        self.PetName:SetTextColor(1,0.25,0.25)
    elseif tint=="grey" then
        self.PetName:SetTextColor(0.75,0.75,0.75)
    elseif settings.ColorPetNames and petInfo.color then
        self.PetName:SetTextColor(petInfo.color.r,petInfo.color.g,petInfo.color.b)
    else
        self.PetName:SetTextColor(1,0.82,0)
    end
end

--[[ RematchPetPickupIconMixin ]]

RematchPetPickupIconMixin = {}

function RematchPetPickupIconMixin:OnEnter()
    rematch.textureHighlight:Show(self,self:GetParent().Back)
    rematch.cardManager:OnEnter(rematch.petCard,self:GetParent(),self.petID)
end

function RematchPetPickupIconMixin:OnLeave()
    rematch.textureHighlight:Hide()
    if GetMouseFoci()[1]~=self:GetParent() then -- don't dismiss card if moving onto pet button
        rematch.cardManager:OnLeave(rematch.petCard,self:GetParent(),self.petID)
    end
    -- if mouse went down while in this texture and never went up before it left, pet is being dragged
    if rematch.textureDrag:IsDragging() and not GetCursorInfo() then
        C_PetJournal.PickupPet(self.petID)
    end
end

function RematchPetPickupIconMixin:OnMouseDown(button)
    rematch.textureHighlight:Hide()
end

function RematchPetPickupIconMixin:OnMouseUp(button)
    if self:IsMouseMotionFocus() then
        rematch.textureHighlight:Show(self,self:GetParent().Back)
        local parent = self:GetParent()
        local petID = parent.petID
        local petInfo = rematch.petInfo:Fetch(petID)

        -- if pet is wrapped, then show/lock card to unwrap it
        if petInfo.needsFanfare then
            if settings.PetCardMinimized then
                settings.PetCardMinimized = false
                rematch.petCard:Configure()
                rematch.petCard:Update()
            end
            rematch.cardManager:OnClick(rematch.petCard,self,self.petID)
            return
        end

        -- special case for dropping a pet onto a queue pet icon with a pet on cursor
        if not rematch.textureDrag:IsDragging() then
            local cursorPetID,cursorCanLevel = rematch.utils:GetPetCursorInfo(true)
            if parent.forQueue and cursorPetID and cursorCanLevel then
                parent.OnReceiveDrag(parent)
                return
            end
        end

        if button=="RightButton" and not self.noPickup then -- on right-click summon menu
            rematch.menus:Show(self:GetParent().forQueue and "QueueListMenu" or "PetMenu",self,petID,"cursor")
        elseif petInfo.isOwned and petInfo.idType=="pet" and not self:GetParent().noPickup then
            -- ordinarily handled in card manager clicks: if casting leveling/rarity stone or shift-clicking pet
            if rematch.utils:HandleSpecialPetClicks(petID) then
                return
            end
            C_PetJournal.PickupPet(petID)
        end
    end
end
