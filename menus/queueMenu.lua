local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.queueMenu = {}
local qm = rematch.queueMenu
local pm = rematch.petMenu

rematch.events:Register(rematch.queueMenu,"PLAYER_LOGIN",function(self)

    -- menu for the queue button at top of queue panel
    local menu = {
        {text=L["Sort by:"], highlight=true},
        {text=L["Ascending Level"], radio=qm.IsActiveSort, sort=C.QUEUE_SORT_ASC, isChecked=qm.IsCurrentSort, func=qm.SetCurrentSort, icon="Interface\\AddOns\\Rematch\\textures\\badges-borders", iconCoords={0,0.125,0.375,0.5}},
        {text=L["Median Level"], radio=qm.IsActiveSort, sort=C.QUEUE_SORT_MID, isChecked=qm.IsCurrentSort, func=qm.SetCurrentSort, icon="Interface\\AddOns\\Rematch\\textures\\badges-borders", iconCoords={0.125,0.25,0.375,0.5}},
        {text=L["Descending Level"], radio=qm.IsActiveSort, sort=C.QUEUE_SORT_DESC, isChecked=qm.IsCurrentSort, func=qm.SetCurrentSort, icon="Interface\\AddOns\\Rematch\\textures\\badges-borders", iconCoords={0.25,0.375,0.375,0.5}},
        {spacer=true},
        {text=L["In Teams First"], check=qm.IsActiveSort, var="QueueSortInTeamsFirst", sort=C.QUEUE_SORT_TEAMS, isChecked=qm.IsFirstChecked, func=qm.SetFirstSort, icon="Interface\\AddOns\\Rematch\\textures\\badges-borders", iconCoords={0.5,0.625,0.125,0.25}},
        {text=L["Favorites First"], check=qm.IsActiveSort, var="QueueSortFavoritesFirst", sort=C.QUEUE_SORT_FAVORITES, isChecked=qm.IsFirstChecked, func=qm.SetFirstSort, icon="Interface\\AddOns\\Rematch\\textures\\badges-borders", iconCoords={0.625,0.75,0.375,0.5}},
        {text=L["Rares First"], check=qm.IsActiveSort, var="QueueSortRaresFirst", sort=C.QUEUE_SORT_RARITY, isChecked=qm.IsFirstChecked, func=qm.SetFirstSort, icon="Interface\\AddOns\\Rematch\\textures\\badges-borders", iconCoords={0.5,0.625,0.375,0.5}},
        {spacer=true},
        {text=L["Active Sort"], check=true, isChecked=qm.IsActiveSort, func=qm.ToggleActiveSort, tooltipBody=L["The queue will automatically order pets by the sort criteria in the menu options above. The order of pets may automatically change as they gain xp or get added/removed from the queue.\n\nYou cannot manually change the order of pets and still keep the queue actively sorted."]},
        {text=L["Pause Preferences"], check=true, isChecked=qm.IsPreferencesPaused, func=qm.TogglePreferencesPaused, tooltipBody=L["Suspend all criteria from default, team and group preferences.\n\nWhile preferences are paused, the top-most pet in the queue will be chosen if it can be loaded."]},
        {spacer=true},
        {text=L["Fill Queue"], func=qm.FillQueue, tooltipBody=L["Fill the leveling queue with one of each version of a pet that can level from the filtered pet list, that you don't have a level 25 copy or one in the queue already."]},
        {text=L["Fill Queue More"], hidden=qm.NotShowFillQueueMore, fillMore=true, func=qm.FillQueue, tooltipBody=L["Fill the leveling queue with one of each version of a pet that can level from the filtered pet list, regardless whether you have any at level 25 or one in the queue already."]},
        {text=L["Empty Queue"], isDisabled=qm.IsQueueEmpty, func=qm.EmptyQueue, tooltipBody=L["Remove all pets from the leveling queue."]},
        {spacer=true},
        {text=L["Export Queue"], isDisabled=qm.IsQueueEmpty, func=qm.ExportQueue, tooltipBody=format(L["Export all pets in the leveling queue for later importing.\n\n%sNote\124r: Rematch will make a best guess what to import, but there's no guarantee the exact same pets will import, especially after they've leveled. This works best without many duplicates."],C.HEX_WHITE)},
        {text=L["Import Queue"], func=qm.ImportQueue, tooltipBody=format(L["Import pets to the queue that have been previously exported.\n\n%sNote\124r: Rematch will make a best guess what to import, but there's no guarantee the exact same pets will import, especially after they've leveled. This works best without many duplicates."],C.HEX_WHITE)},
        {spacer=true},
        {text=L["Help"], icon="Interface\\Common\\help-i", isHelp=true, hidden=function() return settings.HideMenuHelp end, iconCoords={0.15,0.85,0.15,0.85}, tooltipBody=L["This is the leveling queue. Drag pets you want to level here.\n\nRight click any of the three battle pet slots and choose 'Put Leveling Pet Here' to mark it as a leveling slot you want controlled by the queue.\n\nWhile a leveling slot is active, the queue will fill the slot with the top-most pet in the queue. When this pet reaches level 25 (gratz!) it will leave the queue and the next pet in the queue will take its place.\n\nTeams saved with a leveling slot will reserve that slot for future leveling pets."]},
        {text=OKAY}
    }
    rematch.menus:Register("QueueMenu",menu)

    -- menu when you right-click a pet in the queue (some options/funcs copied from petMenus)
    local menu = {
        {title=qm.GetPetName},
        {text=L["Move To Top Of Queue"], func=qm.MoveToTopOfQueue},
        {text=L["Move Pet In Queue"], func=qm.MovePetInQueue},
        {text=L["Move To End Of Queue"], func=qm.MoveToEndOfQueue},
        {spacer=true},
        {text=qm.SummonOrDismissText, func=qm.SummonOrDismissFunc},
        {text=L["Set Notes"], func=qm.ShowNotes},
        {text=L["Find Teams"], isDisabled=qm.NotInTeam, func=qm.ListTeams},
        {text=BATTLE_PET_RENAME, func=qm.RenamePetFunc},
        {text=qm.SetOrRemoveFavoriteText, func=qm.SetOrRemoveFavoriteFunc},
        {text=BATTLE_PET_RELEASE, hidden=pm.PetNotReleasable, isDisabled=pm.PetIsSlotted, disabledTooltip=L["Slotted pets can't be released."], func=pm.ReleasePetFunc},
        {text=BATTLE_PET_PUT_IN_CAGE, hidden=pm.PetNotTradable, isDisabled=pm.CantCagePet, disabledTooltip=pm.CageDisableReason, func=pm.CagePetFunc},
        {spacer=true},
        {text=L["Remove from Leveling Queue"], func=qm.RemoveFromQueue},
        {spacer=true},
        {text=CANCEL},
    }
    rematch.menus:Register("QueueListMenu",menu)

    rematch.dialog:Register("EmptyQueue",{
        title = L["Empty Queue"],
        prompt = L["Empty queue?"],
        accept = YES,
        cancel = NO,
        layout = {"Text"},
        refreshFunc = function(self,info,subject,firstRun)
            self.Text:SetText(L["Are you sure you want to remove all pets from the leveling queue?"])
        end,
        acceptFunc = function(self,info,subject)
            wipe(settings.LevelingQueue)
            rematch.queue:Process()
        end,
    })

    rematch.dialog:Register("FillQueue",{
        title = L["Fill Queue"],
        prompt = L["Add these pets to the queue?"],
        accept = YES,
        cancel = NO,
        other = L["More"],
        layouts = {
            Default = {"Spacer","Text","Spacer2","CheckButton"},
            Many = {"Spacer","Text","Spacer2","Feedback","Spacer3","CheckButton"},
        },
        refreshFunc = function(self,info,subject,firstRun)
            local count = rematch.queue:FillQueue(subject.fillMore,true)
            self.Text:SetText(format(L["This will add %s%s\124r pets to the leveling queue."],C.HEX_WHITE,count))
            self.CheckButton:SetText(L["Don't Ask When Filling Queue"])
            self.Feedback:Set("warning",L["This is a lot of pets. You can be more selective by filtering pets."])
            rematch.dialog:ChangeLayout(count>50 and "Many" or "Default")
            rematch.dialog.OtherButton:SetEnabled(not subject.fillMore)
        end,
        acceptFunc = function(self,info,subject)
            if self.CheckButton:GetChecked() then
                settings.DontConfirmFillQueue = true
            end
            rematch.queue:FillQueue(subject.fillMore)
        end,
        otherFunc = function(self,info,subject)
            -- a dialog close happens after this otherFunc, so come back in a frame with a new dialog
            rematch.timer:Start(0,function()
                rematch.dialog:ShowDialog("FillQueue",{fillMore=true})
            end)
        end,
    })

    rematch.dialog:Register("StopActiveSort",{
        title = L["Active Sort Enabled"],
        prompt =L["Turn off Active Sort and move pet?"],
        accept = YES,
        cancel = NO,
        layout = {"Feedback","Text","CheckButton"},
        refreshFunc = function(self,info,subject,firstRun)
            self.Feedback:Set("warning",format(L["%s is already in the queue and Active Sort is enabled."],rematch.petInfo:Fetch(subject.petID).formattedName))
            self.Text:SetText(format(L["The queue controls the order of pets while it's actively sorted.\n\nTo move this pet within the queue, Active Sort needs to be turned off."],rematch.petInfo:Fetch(subject.petID).formattedName))
            self.CheckButton:SetText(L["Don't Ask To Stop Active Sort"])
        end,
        acceptFunc = function(self,info,subject)
            if self.CheckButton:GetChecked() then
                settings.DontConfirmActiveSort = true
            end
            settings.QueueActiveSort = false -- if active sort and in the queue, turn off active sort and move to new position
            rematch.queue:MoveIndex(rematch.queue:GetPetIndex(subject.petID),subject.newIndex)
            rematch.queue:BlingPetID(subject.petID)
            ClearCursor()
        end
    })

    -- dialog from right click menu Remove From Leveling Queue; petsPanel doesn't have one since the pet list doesn't shift around
    -- and it's easy to re-add if they don't want
    rematch.dialog:Register("RemoveFromQueue",{
        title = L["Remove From Queue"],
        accept = YES,
        cancel = NO,
        layout = {"Text","CheckButton"},
        refreshFunc = function(self,info,subject,firstRun)
            self.Text:SetText(format(L["Remove %s from the leveling queue?"],rematch.petInfo:Fetch(subject).formattedName))
            self.CheckButton:SetText(L["Don't Ask For Queue Removal"])
        end,
        acceptFunc = function(self,info,subject)
            if self.CheckButton:GetChecked() then
                settings.DontConfirmRemoveQueue = true
            end
            rematch.queue:RemovePetID(subject)
        end
    })

    rematch.dialog:Register("ExportQueue",{
        title = L["Export Queue"],
        accept = OKAY,
        layout = {"Text","MultiLineEditBox"},
        refreshFunc = function(self,info,subject,firstRun)
            if firstRun then
                self.Text:SetText(L["Press Ctrl+C to copy to clipboard"])
                self.MultiLineEditBox:SetText(rematch.queue:ExportQueue(),true)
                self.MultiLineEditBox:ScrollToTop()
            end
        end,
        changeFunc = function(self,info,subject)
            self.MultiLineEditBox:SetText(rematch.queue:ExportQueue(),true)
            self.MultiLineEditBox:ScrollToTop()
        end
    })

    rematch.dialog:Register("ImportQueue",{
        title = L["Import Queue"],
        accept = L["Import"],
        cancel = CANCEL,
        layouts = {
            Default = {"Text","MultiLineEditBox"},
            Valid = {"Text","MultiLineEditBox","ListData"},
            Invalid = {"Text","MultiLineEditBox","Feedback"},
        },
        refreshFunc = function(self,info,subject,firstRun)
            if firstRun then
                self.Text:SetText(L["Press Ctrl+V to paste from clipboard"])
                self.Feedback:Set("warning",L["This is not a valid queue import"])
                self.MultiLineEditBox:SetText("")
                rematch.dialog.AcceptButton:Disable()
            end
        end,
        changeFunc = function(self,info,subject)
            local numNew,numOld,numCant,numBad = rematch.queue:AnalyzeImport(self.MultiLineEditBox:GetText():trim())
            if not numNew then
                rematch.dialog:ChangeLayout("Default")
                rematch.dialog.AcceptButton:Disable()
            elseif (numNew+numOld+numCant)==0 then
                rematch.dialog:ChangeLayout("Invalid")
                rematch.dialog.AcceptButton:Disable()
            else
                local data = {}
                if numNew and numNew>0 then tinsert(data,{L["Pets to add to queue"],numNew}) end
                if numOld and numOld>0 then tinsert(data,{L["Pets already in queue"],numOld}) end
                if numCant and numCant>0 then tinsert(data,{L["Pets that can't level"],numCant}) end
                if numBad and numBad>0 then tinsert(data,{L["Invalid pets"],numBad}) end
                self.ListData:Set(data)
                rematch.dialog:ChangeLayout("Valid")
                rematch.dialog.AcceptButton:Enable()
                rematch.dialog:Resize() -- resize height (fixedWidth 0 prevents dialog from messing with width)
            end
        end,
        acceptFunc = function(self,info,subject)
            rematch.queue:ImportQueue(self.MultiLineEditBox:GetText():trim())
        end,
    })

end)

function qm:IsActiveSort()
    return settings.QueueActiveSort
end

function qm:ToggleActiveSort(arg1,arg2,arg3)
    settings.QueueActiveSort = not settings.QueueActiveSort
    rematch.queue:SortQueue(C.QUEUE_SORT_ALL)
    rematch.queue:Process()
    rematch.menus:Show("QueueMenu",rematch.queuePanel.Top.QueueButton) -- redo queue menu since radios/checks toggling (a refresh isn't enough)
end

function qm:IsCurrentSort()
    return settings.QueueSortOrder==self.sort
end

function qm:SetCurrentSort()
    settings.QueueSortOrder = self.sort
    if not settings.QueueActiveSort then
        rematch.queue:SortQueue(self.sort)
    else
        rematch.queue:SortQueue(C.QUEUE_SORT_ALL)
    end
    rematch.queue:Process()
end

function qm:IsFirstChecked()
    return settings[self.var]
end

function qm:SetFirstSort()
    if settings.QueueActiveSort then
        settings[self.var] = not settings[self.var]
        rematch.queue:SortQueue(C.QUEUE_SORT_ALL)
    else -- not actively sorting, do a one-time sort
        rematch.queue:SortQueue(self.sort)
    end
    rematch.queuePanel.List:Update()
    rematch.queue:Process()
end

function qm:IsPreferencesPaused()
    return settings.PreferencesPaused
end

function qm:TogglePreferencesPaused()
    rematch.preferences:TogglePause()
end

function qm:EmptyQueue()
    rematch.dialog:ShowDialog("EmptyQueue")
end

function qm:IsQueueEmpty()
    return #settings.LevelingQueue==0
end

function qm:FillQueue()
    if not settings.DontConfirmFillQueue then
        rematch.dialog:ShowDialog("FillQueue",{fillMore=self.fillMore})
    else
        rematch.queue:FillQueue(self.fillMore)
    end
end

function qm:NotShowFillQueueMore()
    return not settings.ShowFillQueueMore
end

function qm:GetPetName(petID)
    return rematch.petInfo:Fetch(petID).formattedName
end

function qm:MovePetInQueue(petID)
    C_PetJournal.PickupPet(petID)
end

function qm:SummonOrDismissText(petID)
    return C_PetJournal.GetSummonedPetGUID()==petID and PET_ACTION_DISMISS or SUMMON
end

function qm:SummonOrDismissFunc(petID)
    C_PetJournal.SummonPetByGUID(petID)
end

function qm:ShowNotes(petID)
    rematch.cardManager:HideCard(rematch.notes)
    rematch.cardManager:ShowCard(rematch.notes,petID)
    rematch.notes:SetFocus()
end

function qm:RenamePetFunc(petID)
    rematch.dialog:ShowDialog("RenameDialog",petID)
end

function qm:SetOrRemoveFavoriteText(petID)
    return rematch.petInfo:Fetch(petID).isFavorite and BATTLE_PET_UNFAVORITE or BATTLE_PET_FAVORITE
end

function qm:SetOrRemoveFavoriteFunc(petID)
    C_PetJournal.SetFavorite(petID,rematch.petInfo:Fetch(petID).isFavorite and 0 or 1)
    rematch.filters:ForceUpdate()
    rematch.frame:Update()
end

function qm:RemoveFromQueue(petID)
    if settings.DontConfirmRemoveQueue then
        rematch.queue:RemovePetID(petID)
    else
        rematch.dialog:ShowDialog("RemoveFromQueue",petID)
    end
end

function qm:MoveToTopOfQueue(petID)
    rematch.queue:MoveIndex(rematch.queue:GetPetIndex(petID),1)
    rematch.queue:BlingPetID(petID)
end

function qm:MoveToEndOfQueue(petID)
    rematch.queue:MoveIndex(rematch.queue:GetPetIndex(petID),#settings.LevelingQueue+1)
    rematch.queue:BlingPetID(petID)
end

function qm:ExportQueue()
    rematch.dialog:ShowDialog("ExportQueue")
end

function qm:ImportQueue()
    rematch.dialog:ShowDialog("ImportQueue")
end

function qm:NotInTeam(petID)
    local numTeams = rematch.petInfo:Fetch(petID).numTeams
    return not numTeams or numTeams==0
end

function qm:ListTeams(petID)
    if petID and petID:match(C.PET_ID_PATTERN) then
        rematch.layout:SummonView("teams")
        rematch.teamsPanel:SetSearch(petID)
    end
end