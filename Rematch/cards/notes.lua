local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.notes = RematchNotesCard

rematch.events:Register(rematch.notes,"PLAYER_LOGIN",function(self)

    -- register cardManager behavior
    rematch.cardManager:Register("Notes",self,{
        update = self.Update,
        lockUpdate = self.UpdateLock,
        noAnchor = true,
        noHide = function() return settings.KeepNotesOnScreen end,
        noEscape = function() return settings.KeepNotesOnScreen and settings.NotesNoEsc end,
    })

    -- this scrollbar adjustment may happen in update or configure (makes room for resize grip which isn't shown when position-locked)
    self.Content.ScrollFrame.ScrollBar:SetPoint("TOPLEFT",self.Content.ScrollFrame,"TOPRIGHT",0,-13)
    self.Content.ScrollFrame.ScrollBar:SetPoint("BOTTOMLEFT",self.Content.ScrollFrame,"BOTTOMRIGHT",0,28) -- 13 (align to bottom) + 15 (space for resize grip)
    self.Content.ScrollFrame.ScrollBar.trackBG:SetAlpha(0.25)
    self.Content.Bottom.DeleteButton:SetText(DELETE)
    self.Content.Bottom.UndoButton:SetText(L["Undo"])
    self.Content.Bottom.SaveButton:SetText(SAVE)
    rematch.notes.LockButton:Configure()

    rematch.dialog:Register("DeleteNotes",{
        title = L["Delete Notes"],
        accept = YES,
        cancel = NO,
        layout = {"Text","CheckButton"},
        refreshFunc = function(self,info,subject,firstRun)
            if rematch.utils:GetIDType(subject)=="team" then
                self.Text:SetText(format(L["Do you want to delete notes for team %s\124r?"],rematch.utils:GetFormattedTeamName(subject)))
            else
                local petInfo = rematch.petInfo:Fetch(subject)
                if petInfo.isValid then
                    self.Text:SetText(format(L["Do you want to delete notes for pet %s%s\124r?"],petInfo.color.hex,petInfo.name))
                end
            end
            self.CheckButton:SetText(L["Don't Ask When Deleting Notes"])
            self.CheckButton:SetChecked(false)
        end,
        acceptFunc = function(self,info,subject)
            rematch.notes:DeleteNotes(subject)
            if self.CheckButton:GetChecked() then
                settings.DontConfirmDeleteNotes = true
            end
        end
    })

    self:UpdateFont()

    self:SetScript("OnSizeChanged",self.OnSizeChanged)

end)

-- called on login and in options too
function rematch.notes:UpdateFont()
    self.Content.ScrollFrame.EditBox:SetFontObject(settings.NotesFont or "GameFontHighlight")
end

-- for lock button in topleft corner, update icon and hide resize grip while locked
function rematch.notes.LockButton:Configure()
    self:SetIcon(settings.LockNotesPosition and "lock" or "unlock")
    if settings.LockNotesPosition then
        rematch.notes.Content.ScrollFrame.ResizeGrip:Hide()
        rematch.notes.Content.ScrollFrame.ScrollBar:SetPoint("BOTTOMLEFT",rematch.notes.Content.ScrollFrame,"BOTTOMRIGHT",0,13)
    else
        rematch.notes.Content.ScrollFrame.ResizeGrip:Show()
        rematch.notes.Content.ScrollFrame.ScrollBar:SetPoint("BOTTOMLEFT",rematch.notes.Content.ScrollFrame,"BOTTOMRIGHT",0,28)
    end
end

function rematch.notes:Update(subject)
    self.teamID = nil
    self.petID = nil
    if type(subject)=="string" and rematch.savedTeams[subject] then -- this is a teamID
        local team = rematch.savedTeams[subject]
        if team then
            self.teamID = subject
            self.Content.Top.Name:SetText(rematch.utils:GetFormattedTeamName(subject))
            self.Content.Top.RightIcon:SetTexture(rematch.savedGroups[team.groupID or "group:none"].icon)
            self.Content.ScrollFrame.EditBox:SetText(team.notes or "")
            self.Content.ScrollFrame.EditBox:SetCursorPosition(0)
            self.originalNotes = team.notes -- note this can be nil
        end
    elseif subject then -- this is likely a petID
        local petInfo = rematch.petInfo:Fetch(subject)
        if petInfo.isValid then
            self.petID = subject
            local color = settings.ColorPetNames and petInfo.color
            self.Content.Top.Name:SetText(format("%s%s",color and color.hex or C.HEX_GOLD,petInfo.name))
            self.Content.Top.RightIcon:SetTexture(petInfo.icon)
            self.Content.ScrollFrame.EditBox:SetText(petInfo.notes or "")
            self.Content.ScrollFrame.EditBox:SetCursorPosition(0)
            self.originalNotes = petInfo.notes -- note this can be nil
        end
    end
    -- anchor notes if there is an anchor defined (otherwise use anchor in XML)
	if settings.NotesLeft then
		self:SetSize(settings.NotesWidth,settings.NotesHeight)
		self:ClearAllPoints()
		self:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",settings.NotesLeft,settings.NotesBottom)
	end
end

function rematch.notes:UpdateLock()
    -- while card unlocked, hide scrollbar and resize grip by setting their alpha to 0
    local isLocked = rematch.cardManager:IsCardLocked(self)
    self.Content.ScrollFrame.ScrollBar:SetAlpha(isLocked and 1 or 0)
    self.Content.ScrollFrame.ResizeGrip:SetAlpha(isLocked and 1 or 0)
end

-- sets focus to editbox
function rematch.notes:SetFocus()
    self.Content.ScrollFrame.EditBox:SetFocus(true)
end

function rematch.notes:ClearFocus()
    self.Content.ScrollFrame.EditBox.loseFocus = true
    self.Content.ScrollFrame.EditBox:ClearFocus()
end

--[[ editbox script handlers ]]

-- make sure editbox is a higher framelevel so it's not beneath focus grabber
function rematch.notes.Content.ScrollFrame.EditBox:OnShow()
    self:SetFrameLevel(self:GetParent():GetFrameLevel()+4)
end

-- when focus gained, show controls at bottom
function rematch.notes.Content.ScrollFrame.EditBox:OnEditFocusGained()
    rematch.notes.Content.ScrollFrame:SetPoint("BOTTOMRIGHT",-26,8+C.NOTES_CONTROLS_HEIGHT)
    rematch.notes.Content.Bottom:Show()
end

-- when focus lost, hide controls at bottom unless mouse is over bottom controls or resize button
function rematch.notes.Content.ScrollFrame.EditBox:OnEditFocusLost()
    if (MouseIsOver(rematch.notes.Content.Bottom) or MouseIsOver(rematch.notes.Content.ScrollFrame.ResizeGrip)) and not self.loseFocus then
        self:SetFocus(true)
    else
        self.loseFocus = nil
        rematch.notes.Content.ScrollFrame:SetPoint("BOTTOMRIGHT",-26,8)
        rematch.notes.Content.Bottom:Hide()
    end
end

function rematch.notes.Content.ScrollFrame.EditBox:OnEscapePressed()
    self.loseFocus = true -- if mouse is over bottom when hitting esc, don't grab focus back
    self:ClearFocus()
end

-- if focus grabber is clicked at all, it's because notes don't take up whole editBox; set cursor to end
function rematch.notes.Content.ScrollFrame.FocusGrabber:OnClick()
    local editBox = self:GetParent().EditBox
    editBox:SetCursorPosition(editBox:GetText():len())
    editBox:SetFocus(true)
end

--[[ resizing script handlers ]]

-- when parent notes frame changes size, adjust editbox width and bottom button widths
function rematch.notes:OnSizeChanged(width,height)
    rematch.notes.Content.ScrollFrame.EditBox:SetWidth(width-45)
    local buttonWidth = (width-10)/3
    rematch.notes.Content.Bottom.DeleteButton:SetWidth(buttonWidth)
    rematch.notes.Content.Bottom.UndoButton:SetWidth(buttonWidth)
    rematch.notes.Content.Bottom.SaveButton:SetWidth(buttonWidth)
end

-- resizing notes window from resize grip in lower right
function rematch.notes.Content.ScrollFrame.ResizeGrip:OnMouseDown()
    if not settings.LockNotesPosition then
        rematch.notes:StartSizing()
    end
end

function rematch.notes.Content.ScrollFrame.ResizeGrip:OnMouseUp()
    if not settings.LockNotesPosition then
        rematch.notes:StopMovingOrSizing()
        rematch.notes:SavePosition()
        rematch.notes:SetUserPlaced(false)
    end
end

--[[ window movement script handlers ]]

function rematch.notes:OnMouseDown()
    if not settings.LockNotesPosition then
        self:StartMoving()
    end
end

function rematch.notes:OnMouseUp()
    if not settings.LockNotesPosition then
        self:StopMovingOrSizing()
        self:SavePosition()
        self:SetUserPlaced(false)
    end
end

function rematch.notes.LockButton:OnClick()
    settings.LockNotesPosition = not settings.LockNotesPosition
    self:Configure()
end

function rematch.notes:SavePosition()
    settings.NotesLeft = self:GetLeft()
    settings.NotesBottom = self:GetBottom()
    settings.NotesWidth = self:GetWidth()
    settings.NotesHeight = self:GetHeight()
end

--[[ control buttons in bottom panel ]]

function rematch.notes.Content.Bottom.SaveButton:OnClick()
    local text = rematch.notes.Content.ScrollFrame.EditBox:GetText():trim()
    if rematch.notes.teamID then
        local teamID = rematch.notes.teamID
        if teamID and rematch.savedTeams:IsUserTeam(teamID) then
            if text:len()>0 then
                rematch.savedTeams[teamID].notes = text
            else
                rematch.savedTeams[teamID].notes = nil
            end
            rematch.frame:Update()
            rematch.notes:ClearFocus()
            rematch.events:Fire("REMATCH_NOTES_CHANGED",teamID)
        end
    elseif rematch.notes.petID then
        local speciesID = rematch.petInfo:Fetch(rematch.notes.petID).speciesID
        if speciesID then
            if text:len()>0 then
                settings.PetNotes[speciesID] = text
            else
                settings.PetNotes[speciesID] = nil
            end
            rematch.frame:Update()
            rematch.notes:ClearFocus()
            rematch.events:Fire("REMATCH_NOTES_CHANGED",speciesID)
        end
    end
end

function rematch.notes.Content.Bottom.UndoButton:OnClick()
    rematch.notes.Content.ScrollFrame.EditBox:SetText(rematch.notes.originalNotes or "")
    rematch.notes.Content.ScrollFrame.EditBox:SetCursorPosition(0)
end

function rematch.notes.Content.Bottom.DeleteButton:OnClick()
    rematch.notes:ClearFocus()
    rematch.cardManager:HideCard(rematch.notes)
    local subject = rematch.notes.teamID or rematch.notes.petID
    if not settings.DontConfirmDeleteNotes and rematch.notes.originalNotes then
        if subject then
            rematch.dialog:ShowDialog("DeleteNotes",subject)
        end
    else
        rematch.notes:DeleteNotes(subject)
    end
end

function rematch.notes:DeleteNotes(subject)
    if rematch.utils:GetIDType(subject)=="team" then
        local team = rematch.savedTeams[subject]
        if team then
            rematch.savedTeams[subject].notes = nil
            rematch.events:Fire("REMATCH_NOTES_CHANGED",subject)
        end
    elseif subject then
        local speciesID = rematch.petInfo:Fetch(subject).speciesID
        if speciesID then
            settings.PetNotes[speciesID] = nil
            rematch.events:Fire("REMATCH_NOTES_CHANGED",speciesID)
        end
    end
    rematch.frame:Update()
end

-- primarily for the keybind, shows/hides notes for the currently loaded team, if one loaded (it's ok if team has no notes)
function rematch.notes:Toggle()
    local teamID = rematch.settings.currentTeamID
    if rematch.savedTeams:IsUserTeam(teamID) then
        if rematch.notes:IsVisible() then
            rematch.cardManager:HideCard(rematch.notes)
        else
            rematch.cardManager:ShowCard(rematch.notes,teamID)
        end
    end
end