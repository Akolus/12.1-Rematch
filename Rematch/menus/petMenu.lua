local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.petMenu = {}
local pm = rematch.petMenu

rematch.events:Register(rematch.petMenu,"PLAYER_LOGIN",function(self)

    -- menu when you right-click a pet
    local menu = {
        {title=pm.GetPetName},
        {text=pm.SummonOrDismissText, hidden=pm.NotOwnedPet, func=pm.SummonOrDismissFunc},
        {text=L["Set Notes"], func=pm.ShowNotes},
        {text=L["Pet Tags"], hidden=pm.NotObtainablePet, subMenu="SetPetMarker"},
        {text=L["Find Similar"], hidden=pm.NotObtainablePet, func=pm.FindSimilarFunc},
        {text=L["Find Moveset"], hidden=pm.NotObtainablePet, func=pm.FindMovesetFunc},
        {text=L["Find Teams"], isDisabled=pm.NotInTeam, func=pm.ListTeams},
        {text=BATTLE_PET_RENAME, hidden=pm.NotOwnedPet, func=pm.RenamePetFunc},
        {text=pm.SetOrRemoveFavoriteText, hidden=pm.NotOwnedPet, func=pm.SetOrRemoveFavoriteFunc},
        {text=pm.HideOrShowPetText, hidden=pm.DontAllowHiddenPets, func=pm.HideOrShowPetFunc},
        {text=BATTLE_PET_RELEASE, hidden=pm.PetNotReleasable, isDisabled=pm.PetIsSlotted, disabledTooltip=L["Slotted pets can't be released."], func=pm.ReleasePetFunc},
        {text=BATTLE_PET_PUT_IN_CAGE, hidden=pm.PetNotTradable, isDisabled=pm.CantCagePet, disabledTooltip=pm.CageDisableReason, func=pm.CagePetFunc},
        {spacer=true, hidden=pm.PetCantLevel},
        {text=L["Start Leveling"], hidden=pm.PetLevelingOrCant, func=pm.StartQueueFunc},
        {text=pm.ToggleQueueText, hidden=pm.PetCantLevel, func=pm.ToggleQueueFunc},
        {spacer=true, hidden=pm.PetCantLevel},
        {text=CANCEL},
    }
    rematch.menus:Register("PetMenu",menu)

	local setPetMarkerMenu = {{title=L["Pet Tags"]}}
	for i=8,1,-1 do
		tinsert(setPetMarkerMenu,{text=pm.GetMarkerName, radio=true, icon="Interface\\TargetingFrame\\UI-RaidTargetingIcons", iconCoords=pm.GetIconCoords, key=i, isChecked=pm.IsMarkerChecked, func=pm.SetPetMarker, editButton=true, editFunc=pm.RenameMarker})
	end
    -- the "None" option is value 9 for filtering purposes (a nil entry like the PetMarkers[speciesID] setting would
    -- confuse the emptiness of the filter)
	tinsert(setPetMarkerMenu,{text=NONE, radio=true, icon="", key=9, isChecked=pm.IsMarkerChecked, func=pm.SetPetMarker})
    tinsert(setPetMarkerMenu,{text=L["Help"], stay=true, isHelp=true, hidden=function() return settings.HideMenuHelp end, icon="Interface\\Common\\help-i", iconCoords={0.15,0.85,0.15,0.85}, tooltipTitle=L["Pet Tags"], tooltipBody=format(C.HELP_TEXT_PET_TAGS,C.HEX_WHITE,rematch.utils:IconAsText("Interface\\WorldMap\\Gear_64Grey"),rematch.utils:GetBadgeAsText(21,16,true),rematch.utils:GetBadgeAsText(21,16,true))})
    tinsert(setPetMarkerMenu,{text=CANCEL})
	rematch.menus:Register("SetPetMarker",setPetMarkerMenu)

    -- dialog for RenamePetFunc
    local renameDialog = {
        title = BATTLE_PET_RENAME,
        accept = ACCEPT,
        cancel = CANCEL,
        other = PET_RENAME_DEFAULT_LABEL,
        prompt = L["Enter a new name"],
        layouts = {
            Default = {"Pet","EditBox"},
            Invalid = {"Pet","EditBox","Feedback"},
        },
        refreshFunc = function(self,info,subject,firstRun)
            self.Pet:Fill(subject)
            if firstRun then
                local petInfo = rematch.petInfo:Fetch(subject)
                self.EditBox:SetText(petInfo.name,true)
                rematch.dialog.OtherButton:SetEnabled(petInfo.customName and true or false)
            end
        end,
        changeFunc = function(self,info,subject)
            local name = self.EditBox:GetText():trim()
            -- doing some validation because it annoys me when I have to keep opening the dialog when a name is invalid
            -- unfortunately this won't catch all invalid names, but it will catch obvious criteria (length, numbers)
            local canAccept = true
            local showWarning = false
            if name:len()<2 then -- for very short names no need to warn (user may have cleared text and started typing)
                canAccept = false
            elseif name:len()>16 then
                canAccept = false
                showWarning = true
                self.Feedback:Set("warning",L["Pet name too long.\nMaximum 16 characters."])
            elseif name:match("[1234567890]") then
                canAccept = false
                showWarning = true
                self.Feedback:Set("warning",L["Invalid name.\nNo numbers allowed."])
            end
            rematch.dialog.AcceptButton:SetEnabled(canAccept)
            rematch.dialog:ChangeLayout(showWarning and "Invalid" or "Default")
        end,
        acceptFunc = function(self,info,subject)
            C_PetJournal.SetCustomName(subject,self.EditBox:GetText():trim())
        end,
        otherFunc = function(self,info,subject)
            C_PetJournal.SetCustomName(subject,"")
        end
    }
    rematch.dialog:Register("RenameDialog",renameDialog)

    -- dialog for HideOrShowPetFunc
    local hideDialog = {
        title = L["Hide Pet"],
        accept = YES,
        cancel = NO,
        prompt = L["Hide this pet?"],
        layout = {"Pet","Text","CheckButton"},
        refreshFunc = function(self,info,subject,firstRun)
            self.Pet:Fill(subject)
            local speciesName = rematch.petInfo:Fetch(subject).speciesName
            self.Text:SetText(format(L["Are you sure you want to hide all versions of %s%s\124r?\n\n%sHidden pets will not show up in the pet list or searches. You can view or unhide these pets from the 'Other' pet filter."],C.HEX_WHITE,speciesName,C.HEX_GREY))
            self.CheckButton:SetText(L["Don't Ask When Hiding Pets"])
            self.CheckButton:SetChecked(false) -- for this dialog to appear, this is false
        end,
        acceptFunc = function(self,info,subject)
            -- if "Don't Ask When Hiding Pets" checked, then update the setting
            if self.CheckButton:GetChecked() then
                settings.DontConfirmHidePets = true
                rematch.optionsPanel:Update()
            end
            local speciesID = rematch.petInfo:Fetch(subject).speciesID
            if speciesID then
                settings.HiddenPets[speciesID] = true
                rematch.filters:ForceUpdate()
                rematch.petsPanel:Update()
            end
        end,
    }
    rematch.dialog:Register("HidePetDialog",hideDialog)

    -- dialog for ReleasePetFunc
    local releaseDialog = {
        title = BATTLE_PET_RELEASE,
        accept = YES,
        cancel = NO,
        prompt = L["Release this pet?"],
        layout = {"Pet","Feedback"},
        refreshFunc = function(self,info,subject,firstRun)
            self.Pet:Fill(subject)
            local warning = L["Once released, this pet is gone forever!"]
            if rematch.petInfo:Fetch(subject).inTeams then
                warning = L["This pet is used in teams! "]..warning
            end
            self.Feedback:Set("warning",warning)
        end,
        acceptFunc = function(self,info,subject)
            C_PetJournal.ReleasePetByID(subject)
        end,
    }
    rematch.dialog:Register("ReleasePetDialog",releaseDialog)

    -- dialog for CagePetFunc
    local cageDialog = {
        title = BATTLE_PET_PUT_IN_CAGE,
        accept = YES,
        cancel = NO,
        prompt = L["Cage this pet?"],
        layouts = {
            Default = {"Pet","CheckButton"},
            InTeams = {"Pet","Feedback"},
        },
        refreshFunc = function(self,info,subject,firstRun)
            self.Pet:Fill(subject)
            self.CheckButton:SetText(L["Don't Ask When Caging Pets"])
            self.CheckButton:SetChecked(false)
            if rematch.petInfo:Fetch(subject).inTeams then
                self.Feedback:Set("warning",L["This pet is used in teams!"])
                rematch.dialog:ChangeLayout("InTeams")
            end
        end,
        acceptFunc = function(self,info,subject)
            if self.CheckButton:GetChecked() then
                settings.DontConfirmCaging = true
                rematch.optionsPanel:Update()
            end
            C_PetJournal.CagePetByID(subject)
        end,
    }
    rematch.dialog:Register("CagePetDialog",cageDialog)

end)

function rematch.petMenu:GetPetName(petID)
    return rematch.petInfo:Fetch(petID).formattedName
end

function rematch.petMenu:SummonOrDismissText(petID)
    return C_PetJournal.GetSummonedPetGUID()==petID and PET_ACTION_DISMISS or SUMMON
end

function rematch.petMenu:NotOwnedPet(petID)
    local petInfo = rematch.petInfo:Fetch(petID)
    return not (petInfo.isOwned and petInfo.idType=="pet")
end

function rematch.petMenu:NotObtainablePet(petID)
    return not rematch.petInfo:Fetch(petID).isObtainable
end

function rematch.petMenu:SummonOrDismissFunc(petID)
    C_PetJournal.SummonPetByGUID(petID)
end

function rematch.petMenu:RenamePetFunc(petID)
    rematch.dialog:ShowDialog("RenameDialog",petID)
end

function rematch.petMenu:SetOrRemoveFavoriteText(petID)
    return rematch.petInfo:Fetch(petID).isFavorite and BATTLE_PET_UNFAVORITE or BATTLE_PET_FAVORITE
end

function rematch.petMenu:SetOrRemoveFavoriteFunc(petID)
    C_PetJournal.SetFavorite(petID,rematch.petInfo:Fetch(petID).isFavorite and 0 or 1)
    rematch.filters:ForceUpdate()
    rematch.frame:Update()
end

function rematch.petMenu:HideOrShowPetText(petID)
    local speciesID = rematch.petInfo:Fetch(petID).speciesID
    return (speciesID and settings.HiddenPets[speciesID]) and L["Show Pet"] or L["Hide Pet"]
end

function rematch.petMenu:DontAllowHiddenPets(petID)
    return not settings.AllowHiddenPets
end

-- function for Hide/Show Pet
function rematch.petMenu:HideOrShowPetFunc(petID)
    local speciesID = rematch.petInfo:Fetch(petID).speciesID
    if speciesID then
        if settings.HiddenPets[speciesID] then -- if pet was hidden, then this is a Show Pet
            settings.HiddenPets[speciesID] = nil -- remove speciesID from hidden pets, showing it
        elseif not settings.DontConfirmHidePets then -- if Don't Ask When Hiding Pets unchecked, ask
            rematch.dialog:ShowDialog("HidePetDialog",petID)
            return -- no need to update list yet, leave
        else
            settings.HiddenPets[speciesID] = true
        end
        rematch.filters:ForceUpdate()
        rematch.petsPanel:Update()
    end
end

-- returns the color-coded name for a pet marker
function rematch.petMenu:GetMarkerName()
	if self.key and C.MARKER_COLORS[self.key] and _G["RAID_TARGET_"..self.key] then
		return "\124cff"..C.MARKER_COLORS[self.key]..(settings.PetMarkerNames[self.key] or _G["RAID_TARGET_"..self.key])
	end
end

-- returns texcoords for an icon
function rematch.petMenu:GetIconCoords()
	if C.COORDS_4X4[self.key] then
		return C.COORDS_4X4[self.key]
	end
end

-- returns true if "Cage Pet" should be hidden
function rematch.petMenu:PetNotTradable(petID)
    local petInfo = rematch.petInfo:Fetch(petID)
    return not petInfo.isOwned or not rematch.petInfo:Fetch(petID).isTradable
end

-- returns true if pet is injured or slotted and can't be caged
function rematch.petMenu:CantCagePet(petID)
    local petInfo = rematch.petInfo:Fetch(petID)
    return petInfo.isInjured or petInfo.isSlotted
end

-- returns the tooltip explaining why cage is disabled
function rematch.petMenu:CageDisableReason(petID)
    local petInfo = rematch.petInfo:Fetch(petID)
    return petInfo.isInjured and L["Injured pets cannot be caged."] or L["Slotted pets cannot be caged."]
end

-- if Don't Ask When Caging Pets is checked, immediately cages the pet; otherwise prompts with a dialog
function rematch.petMenu:CagePetFunc(petID)
    if not rematch.petInfo:Fetch(petID).inTeams and settings.DontConfirmCaging then
        C_PetJournal.CagePetByID(petID)
    else
        rematch.dialog:ShowDialog("CagePetDialog",petID)
    end
end

-- returns true if pet can't be released
function rematch.petMenu:PetNotReleasable(petID)
    local petInfo = rematch.petInfo:Fetch(petID)
    return not petInfo.isOwned or not C_PetJournal.PetCanBeReleased(petID)
end

function rematch.petMenu:PetIsSlotted(petID)
    return rematch.petInfo:Fetch(petID).isSlotted
end

function rematch.petMenu:ReleasePetFunc(petID)
    rematch.dialog:ShowDialog("ReleasePetDialog",petID)
end

function rematch.petMenu:FindSimilarFunc(petID)
    local speciesID = rematch.petInfo:Fetch(petID).speciesID
    if speciesID then
        rematch.filters:SetSimilarFilter(speciesID)
        rematch.filters:ForceUpdate()
        rematch.petsPanel:Update()
    end
end

function rematch.petMenu:FindMovesetFunc(petID)
    local speciesID = rematch.petInfo:Fetch(petID).speciesID
    if speciesID then
        rematch.filters:SetMovesetFilter(speciesID)
        rematch.filters:ForceUpdate()
        rematch.petsPanel:Update()
    end
end

function rematch.petMenu:SetPetMarker(petID)
    local speciesID = rematch.petInfo:Fetch(petID).speciesID
    if speciesID then
        if self.key>=1 and self.key<=8 then
            settings.PetMarkers[speciesID] = self.key
        else
            settings.PetMarkers[speciesID] = nil
        end
        rematch.filters:ForceUpdate()
        rematch.frame:Update()
    end
end

function rematch.petMenu:ShowNotes(petID)
    rematch.cardManager:HideCard(rematch.notes)
    rematch.cardManager:ShowCard(rematch.notes,petID)
    rematch.notes:SetFocus()
end


function rematch.petMenu:PetCantLevel(petID)
    return not rematch.queue:PetIDCanLevel(petID)
end

function rematch.petMenu:PetLevelingOrCant(petID)
    return not rematch.queue:PetIDCanLevel(petID) or rematch.petInfo:Fetch(petID).isLeveling
end

function rematch.petMenu:ToggleQueueText(petID)
    return rematch.queue:IsPetLeveling(petID) and L["Remove from Leveling Queue"] or L["Add to Leveling Queue"]
end

-- adds or removes petID to/from the leveling queue
function rematch.petMenu:ToggleQueueFunc(petID)
    if rematch.queue:PetIDCanLevel(petID) then
        if rematch.queue:IsPetLeveling(petID) then
            rematch.queue:RemovePetID(petID)
        else
            rematch.queue:AddPetID(petID)
        end
        rematch.queue:Process()
        rematch.queue:BlingPetID(petID)
    end
end

-- adds pet to top of leveling queue
function rematch.petMenu:StartQueueFunc(petID)
    rematch.queue:InsertPetID(petID,1)
    rematch.queue:Process()
    rematch.queue:BlingPetID(petID)
end

function rematch.petMenu:MovePetInQueue(petID)
    C_PetJournal.PickupPet(petID)
end

function rematch.petMenu:NotInTeam(petID)
    local numTeams = rematch.petInfo:Fetch(petID).numTeams
    return not numTeams or numTeams==0
end

function rematch.petMenu:ListTeams(petID)
    if petID and petID:match(C.PET_ID_PATTERN) then
        rematch.layout:SummonView("teams")
        rematch.teamsPanel:SetSearch(petID)
    end
end

function rematch.petMenu:RenameMarker()
	rematch.dialog:ShowDialog("RenamePetMarkerDialog",self.key)
end

function rematch.petMenu:IsMarkerChecked(petID)
    local marker = rematch.petInfo:Fetch(petID).marker
    return (not marker and self.key==9) or marker==self.key
end