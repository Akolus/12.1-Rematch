local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.loadouts = {}

-- add hooks to loadouts/abilities

-- pets that are slotted should use this so KeepCompanion can handle restoring/dismissing the summoned pet
-- slot: number 1-3 to slot the pet
-- petID: a genuine BattlePet-0-x petID or a special petID (0, "random:8", "ignored") to slot
-- specialPetID: the special petID (0, "random:8", etc) if a BattlePet-0-x is being slotted on behalf a special petID
-- stableSlots: true if special slots should not move with their pets (for queue process)
local keptCompanion -- petID to restore (can be nil to dismiss) after a summons
function rematch.loadouts:SlotPet(slot,petID,specialPetID,stableSlots)
    if rematch.loadouts:CantSwapPets() then
        return -- can't swap pets, leave
    end
    -- if a pet is being slotted while in a post-battle wait to swap pets, stop the timer
    rematch.main:StopPostBattleTimer()
    local petInfo = rematch.petInfo:Fetch(petID)
    -- if KeepCompanion enabled, note the pet summoned and start a timer to check back
    if settings.KeepCompanion then
        -- this doesn't check for slot 1 only because SlotPet(2,petID) can swap slots 1 and 2
        if not rematch.timer:IsRunning(rematch.loadouts.RestoreKeptCompanion) then -- only if not already mid-swap
            keptCompanion = C_PetJournal.GetSummonedPetGUID()
        end
        rematch.timer:Start(0.5,rematch.loadouts.RestoreKeptCompanion)
    end
    if petInfo.isSpecialType then -- a special type is being directly slotted
        settings.SpecialSlots[slot] = petID -- this is either a leveling, random or ignored slot
    else -- a non-special petID is being slotted
        -- when a queue process is happening (especially when one slot changes to normal) don't move leveling slots around
        if not stableSlots then
            -- first see if pet being slotted exists in another slot (so special slot can move with it)
            local priorSlot
            for i=1,3 do
                if i~=slot and C_PetJournal.GetPetLoadOutInfo(i)==petID then
                    priorSlot = i
                end
            end
            if priorSlot then -- if two loaded pets are being swapped, swap their special slots too if any
                local temp = settings.SpecialSlots[slot]
                settings.SpecialSlots[slot] = settings.SpecialSlots[priorSlot]
                settings.SpecialSlots[priorSlot] = temp
            else -- if pets are not being swapped and a petID being slotted, this is a petID and not a special slot
                settings.SpecialSlots[slot] = nil -- this is probably a standard petID slotted (or could be empty/invalid)
            end
        end
        -- if a special petID is being slotted with an actual pet (specialPetID is true), assign it
        if specialPetID and rematch.loadouts:IsPetIDSpecial(specialPetID) then
            settings.SpecialSlots[slot] = specialPetID
        end
        C_PetJournal.SetPetLoadOutInfo(slot,petID)
    end
    -- if there's any leveling pets slotted, then process the queue to rearrange pets if needed
    for i=1,3 do
        if settings.SpecialSlots[i]==0 then
            rematch.queue:Process()
        end
    end
end

-- for loadteam or other cases where the slot types need to be asserted
function rematch.loadouts:SetSlotPetID(slot,petID)
    local petInfo = rematch.petInfo:Fetch(petID)
    if petInfo.isSpecialType then
        settings.SpecialSlots[slot] = petID
    else
        settings.SpecialSlots[slot] = nil
    end
end

-- started from above SlotPet, waits until GCD is over and either restores the previously summoned pet or dismisses if none out
function rematch.loadouts:RestoreKeptCompanion()
    -- if still in GCD from the swap (or happened to go into combat during the swap) wait a little longer
    local info = C_Spell.GetSpellCooldown(C.GCD_SPELL_ID)
    if info.startTime~=0 or InCombatLockdown() then
        rematch.timer:Start(0.5,rematch.loadouts.RestoreKeptCompanion)
    else -- done swapping
        local petID = C_PetJournal.GetSummonedPetGUID()
        if petID ~= keptCompanion then
            C_PetJournal.SummonPetByGUID(keptCompanion or petID)
            rematch.timer:Start(0.5,rematch.loadouts.RestoreKeptCompanion) -- come back in 1/2 a second to make sure swap succeeded
        end
    end
end

-- returns true/false if this slot is special (leveling, random, ignored)
function rematch.loadouts:IsSlotSpecial(slot)
    return settings.SpecialSlots[slot] and true or false
end

-- returns true/false if this petID is special
function rematch.loadouts:IsPetIDSpecial(petID)
    return petID==0 or petID=="ignored" or (type(petID)=="string" and petID:match("^random"))
end

-- returns the petID of the slot, which can be a special petID, and abilities
function rematch.loadouts:GetSlotInfo(slot)
    if settings.SpecialSlots[slot] then
        return settings.SpecialSlots[slot]
    else
        return self:GetLoadoutInfo(slot)
    end
end

-- returns the special slot type ("leveling", "random" or "ignored")
function rematch.loadouts:GetSpecialSlotType(slot)
    if settings.SpecialSlots[slot] then
        local petID = self:GetSlotInfo(slot) -- only want first value
        return rematch.loadouts:GetSpecialPetIDType(petID)
    end
end

-- returns the special petID type ("leveling", "random" or "ignored"), or nil if none
function rematch.loadouts:GetSpecialPetIDType(petID)
    if petID==0 then
        return "leveling"
    elseif type(petID)=="string" and petID:match("^random") then
        return "random"
    elseif petID=="ignored" then
        return "ignored"
    else
        return nil
    end
end

-- returns the actually-slotted pet and abilities for the given slot (and whether slot is locked)
function rematch.loadouts:GetLoadoutInfo(slot)
    if type(slot)=="number" and slot>0 and slot<4 then
        return C_PetJournal.GetPetLoadOutInfo(slot)
    end
end

-- returns the two petIDs in slots other than the slot given
function rematch.loadouts:GetOtherPetIDs(slot)
    if type(slot)=="number" and slot>0 and slot<4 then
        local other1 = C_PetJournal.GetPetLoadOutInfo(slot%3+1)
        local other2 = C_PetJournal.GetPetLoadOutInfo((slot+1)%3+1)
        return other1,other2
    end
end

-- returns true if the slot is locked (for new players who've not yet fully unlocked pet battles)
function rematch.loadouts:IsSlotLocked(slot)
    if type(slot)=="number" and slot>0 and slot<4 then
        local _,_,_,_,locked = C_PetJournal.GetPetLoadOutInfo(slot)
        return locked
    end
end

-- returns the localized text and spell/achievement link for the slot being unlearned/locked for new pet battlers
-- slot 1 is a spell (), slots 2 and 3 are achievements ()
function rematch.loadouts:GetSlotLockedDetails(slot)
    local text = slot and _G["BATTLE_PET_UNLOCK_HELP_"..slot]
    local link, spellID, achievementID
    if text then
        text = text:gsub("\n"," ")
        spellID = slot==1 and 119467
        achievementID = (slot==2 and 7433) or (slot==3 and 6566)
        link = (spellID and C_Spell.GetSpellLink(spellID)) or (achievementID and GetAchievementLink(achievementID))
    end
    return text, link, spellID, achievementID
end


-- returns true if in a state where we can't swap pets (if journal locked or in pvp queue or in a battle or in combat or player not in world)
function rematch.loadouts:CantSwapPets()
    return (rematch.utils:IsJournalLocked() or C_PetBattles.IsInBattle() or InCombatLockdown() or not rematch.main:IsPlayerInWorld()) and true or false
end

-- returns true if any slotted pet is below level 25
function rematch.loadouts:NotAllMaxLevel()
    for i=1,3 do
        local petInfo = rematch.petInfo:Fetch((rematch.loadouts:GetLoadoutInfo(i)))
        if petInfo.level and petInfo.level>0 and petInfo.level<25 then
            return true
        end
    end
    return false
end