local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.loadoutMenu = {}
local lm = rematch.loadoutMenu

rematch.events:Register(rematch.loadoutMenu,"PLAYER_LOGIN",function(self)

    -- for loadout menus, subect is info={slot=1-3, petID=petID in slot}

    -- menu for the SpecialButton to change the special slot type
    local specialMenu = {
        {title=lm.GetSlotName},
        {text=L["Put Leveling Pet Here"], specialType="leveling", petID=0, hidden=lm.IsSpecialEnabled, highlight=lm.IsSpecialEnabled, func=lm.SetSpecialSlot },
        {text=L["Stop Leveling This Slot"], specialType="leveling", hidden=lm.IsSpecialDisabled, highlight=lm.IsSpecialEnabled, func=lm.SetSpecialSlot },
        {text=L["Put Random Pet Here"], specialType="random", hidden=lm.IsSpecialEnabled, highlight=lm.IsSpecialEnabled, subMenu="SpecialSubMenu" },
        {text=L["Stop Randomizing This Slot"], specialType="random", hidden=lm.IsSpecialDisabled, highlight=lm.IsSpecialEnabled, func=lm.SetSpecialSlot },
        {text=L["Ignore This Slot"], specialType="ignored", petID="ignored", hidden=lm.IsSpecialEnabled, highlight=lm.IsSpecialEnabled, func=lm.SetSpecialSlot },
        {text=L["Stop Ignoring This Slot"], specialType="ignored", hidden=lm.IsSpecialDisabled, highlight=lm.IsSpecialEnabled, func=lm.SetSpecialSlot },
        {text=CANCEL},
    }
    rematch.menus:Register("SpecialMenu",specialMenu)

    -- submenu for SpecialMenu is a list of random types
    local specialSubMenu = {
        {text=L["Any Type"], var=0, icon="Interface\\Icons\\INV_Misc_Dice_02", iconCoords={0.075,0.925,0.075,0.925}, petID="random:0", func=lm.SetSpecialSlot },
        {text=BATTLE_PET_NAME_1, var=1, icon=lm.GetIcon, petID="random:1", func=lm.SetSpecialSlot },
        {text=BATTLE_PET_NAME_2, var=2, icon=lm.GetIcon, petID="random:2", func=lm.SetSpecialSlot },
        {text=BATTLE_PET_NAME_3, var=3, icon=lm.GetIcon, petID="random:3", func=lm.SetSpecialSlot },
        {text=BATTLE_PET_NAME_4, var=4, icon=lm.GetIcon, petID="random:4", func=lm.SetSpecialSlot },
        {text=BATTLE_PET_NAME_5, var=5, icon=lm.GetIcon, petID="random:5", func=lm.SetSpecialSlot },
        {text=BATTLE_PET_NAME_6, var=6, icon=lm.GetIcon, petID="random:6", func=lm.SetSpecialSlot },
        {text=BATTLE_PET_NAME_7, var=7, icon=lm.GetIcon, petID="random:7", func=lm.SetSpecialSlot },
        {text=BATTLE_PET_NAME_8, var=8, icon=lm.GetIcon, petID="random:8", func=lm.SetSpecialSlot },
        {text=BATTLE_PET_NAME_9, var=9, icon=lm.GetIcon, petID="random:9", func=lm.SetSpecialSlot },
        {text=BATTLE_PET_NAME_10, var=10, icon=lm.GetIcon, petID="random:10", func=lm.SetSpecialSlot },
    }
    rematch.menus:Register("SpecialSubMenu",specialSubMenu)


    local loadoutMenu = {
        {title=lm.GetPetName},
        {text=L["Put Leveling Pet Here"], specialType="leveling", petID=0, hidden=lm.IsSpecialEnabled, highlight=lm.IsSpecialEnabled, func=lm.SetSpecialSlot },
        {text=L["Stop Leveling This Slot"], specialType="leveling", hidden=lm.IsSpecialDisabled, highlight=lm.IsSpecialEnabled, func=lm.SetSpecialSlot },
        {text=L["Put Random Pet Here"], specialType="random", hidden=lm.IsSpecialEnabled, highlight=lm.IsSpecialEnabled, subMenu="SpecialSubMenu" },
        {text=L["Stop Randomizing This Slot"], specialType="random", hidden=lm.IsSpecialDisabled, highlight=lm.IsSpecialEnabled, func=lm.SetSpecialSlot },
        {text=L["Ignore This Slot"], specialType="ignored", petID="ignored", hidden=lm.IsSpecialEnabled, highlight=lm.IsSpecialEnabled, func=lm.SetSpecialSlot },
        {text=L["Stop Ignoring This Slot"], specialType="ignored", hidden=lm.IsSpecialDisabled, highlight=lm.IsSpecialEnabled, func=lm.SetSpecialSlot },
        {spacer=8},
        {text=function(self,info) return C_PetJournal.GetSummonedPetGUID()==info.petID and PET_ACTION_DISMISS or SUMMON end, func=function(self,info) C_PetJournal.SummonPetByGUID(info.petID) end},
        {text=L["Set Notes"], func=lm.SetNotes},
        {text=L["Find Similar"], func=lm.FindSimilar},
        {text=L["Find Teams"], isDisabled=function(self,info) local numTeams = rematch.petInfo:Fetch(info.petID).numTeams return not numTeams or numTeams==0 end, func=lm.ListTeams},
        {text=BATTLE_PET_RENAME, func=function(self,info) rematch.dialog:ShowDialog("RenameDialog",info.petID) end},
        {text=function(self,info) return rematch.petInfo:Fetch(info.petID).isFavorite and BATTLE_PET_UNFAVORITE or BATTLE_PET_FAVORITE end, func=lm.SetFavorite},
        {spacer=8},
        {text=CANCEL},
    }
    rematch.menus:Register("LoadoutMenu",loadoutMenu)

end)

-- returns slot number as a name "Battle Pet Slot 1/2/3"
function rematch.loadoutMenu:GetSlotName(info)
    return format(L["Battle Pet Slot %d"],info.slot)
end

-- returns name of the pet instead of the slot
function rematch.loadoutMenu:GetPetName(info)
    return rematch.petInfo:Fetch(info.petID).name
end

-- self.specialType is either "leveling", "random" or "ignored"
function rematch.loadoutMenu:IsSpecialEnabled(info)
    return rematch.loadouts:GetSpecialSlotType(info.slot)==self.specialType
end

-- self.specialType is either "leveling", "random" or "ignored"
function rematch.loadoutMenu:IsSpecialDisabled(info)
    return rematch.loadouts:GetSpecialSlotType(info.slot)~=self.specialType
end

-- gets the icon for the pet type where self.var is the pet type
function rematch.loadoutMenu:GetIcon()
    if self.var then
        return "Interface\\Icons\\Icon_PetFamily_"..PET_TYPE_SUFFIX[self.var]
    end
end

-- info.slot is the slot to slot the pet, self.petID is either a special petID (0 or "random:8") or nil for a normal pet
local excludePetIDs = {}
function rematch.loadoutMenu:SetSpecialSlot(info)
    if self.petID then
        local specialType = rematch.loadouts:GetSpecialPetIDType(self.petID)
        if specialType=="leveling" then
            rematch.loadouts:SlotPet(info.slot,self.petID)
        elseif specialType=="random" then
            local petType = tonumber(self.petID:match("^random:(%d+)"))
            wipe(excludePetIDs)
            for _,petID in ipairs({rematch.loadouts:GetOtherPetIDs(info.slot)}) do
                excludePetIDs[petID] = true
            end
            local randomPetID = rematch.randomPets:PickRandomPetID({petType=petType,excludePetIDs=excludePetIDs})
            rematch.loadouts:SlotPet(info.slot,randomPetID,self.petID)
        elseif specialType=="ignored" then
            rematch.loadouts:SlotPet(info.slot,self.petID)
        end
    else -- no petID given in menu, this is reverting to a normal slot, get the petID for whatever is slotted
        local petID = C_PetJournal.GetPetLoadOutInfo(info.slot)
        rematch.loadouts:SetSlotPetID(info.slot,petID)
    end
    rematch.queue:Process()
    rematch.frame:Update()
end

function rematch.loadoutMenu:FindSimilar(info)
    local speciesID = rematch.petInfo:Fetch(info.petID).speciesID
    if speciesID then
        rematch.layout:SummonView("pets") -- open pets panel if not already there (maximizes too if needed)
        rematch.filters:SetSimilarFilter(speciesID)
        rematch.filters:ForceUpdate()
        rematch.petsPanel:Update()
    end
end

function rematch.loadoutMenu:SetFavorite(info)
    C_PetJournal.SetFavorite(info.petID,rematch.petInfo:Fetch(info.petID).isFavorite and 0 or 1)
    rematch.filters:ForceUpdate()
    rematch.frame:Update()
end

function rematch.loadoutMenu:SetNotes(info)
    if info.petID then
        rematch.cardManager:ShowCard(rematch.notes,info.petID)
    end
end

function rematch.loadoutMenu:ListTeams(info)
    if info.petID and info.petID:match(C.PET_ID_PATTERN) then
        rematch.layout:SummonView("teams")
        rematch.teamsPanel:SetSearch(info.petID)
    end
end