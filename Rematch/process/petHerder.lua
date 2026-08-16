local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.petHerder = {}

-- one of "cage", "favorite", "leveling", "marker:1"-"marker:8" and "marker:0"
local actionID

-- sets dialog text based on whether an action chosen in the PetHerderPicker dialog
local function updateDialogText()
    local canvas = rematch.dialog.Canvas
    local actionID = rematch.petHerder:GetActionID()
    if actionID then
        canvas.Text:SetText(rematch.utils:GetFormattedActionName(actionID))
        canvas.Text2:SetText(L["Now click on pets in the pet list to use this action on the pets"])
        canvas.Text2:SetTextColor(1,0.82,0)
        canvas.Help:SetTextColor(0.85,0.85,0.85)
    else
        canvas.Text:SetText(L["Pick an action to use on multiple pets"])
        canvas.Text2:SetText(L["Then click on pets in the pet list to use this action on the pets"])
        canvas.Text2:SetTextColor(0.5,0.5,0.5)
        canvas.Help:SetTextColor(0.5,0.5,0.5)
    end
end

rematch.events:Register(rematch.petHerder,"PLAYER_LOGIN",function(self)

	rematch.dialog:Register("PetHerder",{
		title = L["Pet Herder"],
		accept = L["Done"],
		layouts = {
			Default = {"Text","PetHerderPicker","Text2","Help"},
			Cage = {"Text","PetHerderPicker","Text2","CheckButton","Help"}
		},
		refreshFunc = function(self,info,subject,firstRun)
			if firstRun then
                ClearCursor()
				--rematch.layout:SummonView("pets")
                updateDialogText()
                rematch.petHerder:SetActionID(nil)
				self.PetHerderPicker:Update()
				self.CheckButton:SetText(L["Allow caging pets in a team"])
				self.Help:SetText(L["When the cursor changes to a \124TInterface\\Cursor\\Crosshairs:16\124t over a pet, click the pet to use the chosen action"])
			end
		end,
		changeFunc = function(self,info,subject)
            updateDialogText()
			local actionID = rematch.petHerder:GetActionID()
			local dialogLayout = rematch.dialog:GetOpenLayout()
			if actionID=="cage" and dialogLayout~="Cage" then
				rematch.dialog:ChangeLayout("Cage")
			elseif actionID~="cage" and dialogLayout~="Default" then
				rematch.dialog:ChangeLayout("Default")
			else -- selecting/unselecting an action may change elements enough to need a resize
				rematch.dialog:Resize()
                rematch.frame:Update() -- also may need to show/hide badges
			end
		end,
	})

end)

-- sets the local actionID (typically from PetHerderPicker dialog)
function rematch.petHerder:SetActionID(newActionID)
    actionID = newActionID or nil
end

-- returns the action chosen in the PerHerderPicker dialog control (or nil if no action chosen)
function rematch.petHerder:GetActionID()
    return actionID
end

-- returns true if dialog is up and an action chosen
function rematch.petHerder:IsTargeting()
    return self:GetActionID() and rematch.dialog:GetOpenDialog()=="PetHerder"
end

-- meant to be called in a pet's OnEnter (so there is a pet under the mouse), makes the crosshairs dimmed if
-- the pet can't be targeted with the current action
function rematch.petHerder:SetCursorForPetID(petID)
    local actionID = rematch.petHerder:GetActionID()
    local petInfo = rematch.petInfo:Fetch(petID)
    if not petID then
        SetCursor(nil)
    elseif (actionID=="leveling" and petInfo.isOwned and petInfo.canBattle and petInfo.level and petInfo.level<25) or (actionID=="cage" and petInfo.isOwned and petInfo.isTradable and not petInfo.isInjured and not petInfo.isSlotted and (not petInfo.inTeams or rematch.dialog.Canvas.CheckButton:GetChecked())) or (actionID=="favorite" and petInfo.idType=="pet") or (actionID=="marker:0" and petInfo.marker) or (actionID~="leveling" and actionID~="cage" and actionID~="favorite" and actionID~="marker:0") then
        SetCursor("Interface\\Cursor\\Crosshairs")
    else
        SetCursor("Interface\\Cursor\\UnableCrosshairs")
    end
end

-- called from the OnClick of a petID, performs the chosen action if there is one
function rematch.petHerder:HerdPetID(petID)
    local actionID = rematch.petHerder:GetActionID()
    local petInfo = rematch.petInfo:Fetch(petID)
    local speciesID = petInfo.speciesID

    if not actionID or not petInfo.isValid then
        return
    end

    local markerID = tonumber(actionID:match("marker:(%d+)"))

    local needsUpdate -- change to true if a pet has an action that may reflect as a change in the pet list
    local warning -- change to a tooltipBody to display at the cursor when an action can't be completed

    if actionID=="cage" then
        if petInfo.idType~="pet" then
            warning = L["You don't own this pet"]
        elseif petInfo.isInjured then
            warning = L["Injured pets can't be caged"]
        elseif petInfo.isSlotted then
            warning = L["Slotted pets can't be caged"]
        elseif not petInfo.isTradable then
            warning = L["This pet is not tradable"]
        elseif petInfo.inTeams and not rematch.dialog.Canvas.CheckButton:GetChecked() then
            warning = L["This pet is in a team"]
        else
            C_PetJournal.CagePetByID(petID)
        end
    elseif actionID=="favorite" then
        if petInfo.idType~="pet" then
            warning = L["You don't own this pet"]
        else
            C_PetJournal.SetFavorite(petID,petInfo.isFavorite and 0 or 1)
            needsUpdate = true
        end
    elseif actionID=="leveling" then
        if petInfo.idType~="pet" then
            warning = L["You don't own this pet"]
        elseif not (petInfo.isOwned and petInfo.canBattle and petInfo.level and petInfo.level<25) then
            warning = L["This pet can't level"]
        elseif petInfo.isLeveling then
            rematch.queue:RemovePetID(petID)
            needsUpdate = true
        else
            rematch.queue:AddPetID(petID)
            needsUpdate = true
        end
    elseif actionID=="marker:0" and speciesID then
        if petInfo.marker then
            settings.PetMarkers[speciesID] = nil
            needsUpdate = true
        else
            warning = L["This pet has no pet tag"]
        end
    elseif markerID and markerID>=1 and markerID<=8 and speciesID then
        if petInfo.marker==markerID then
            settings.PetMarkers[speciesID] = nil
        else
            settings.PetMarkers[speciesID] = markerID
        end
        needsUpdate = true
    end

    -- if an action couldn't be done and has a warning, show it as a tooltip at the cursor
    if warning then
        rematch.tooltip:ShowSimpleTooltip(self,nil,warning,"cursor")            
    end
    -- if an action requires an update to the pet list/queue/UI, udpate it
    if needsUpdate then
        rematch.filters:ForceUpdate()
        rematch.frame:Update()   
    end

end