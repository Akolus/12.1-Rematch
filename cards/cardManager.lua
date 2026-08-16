local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings

rematch.cardManager = {}

--[[
    Pet Cards, Notes, Preferences, Win Record, potentially Team Cards all use this to handle card mouseover/click behavior.
    The normal behavior is that mouseover of a pet or button will wait a quarter of a second before showing the card.
    (This is so moving the mouse across the UI doesn't cause 30 different pets you're not interested in to flicker on screen.)
    Until the pet or button is clicked, the card behaves as a tooltip. Moving the mouse off the card will hide it. However,
    if a pet or button is clicked, the card is "locked" and remains on screen to be interactable. While the card is locked,
    the mouse entering/leaving other pets or buttons will not dismiss the card. This allows the user to mouseover or click
    elements within the card.  Either dismissing or clicking the pet/button again will "unlock" the card and return it to its
    tooltip behavior.

    To use, register a card's frame (such as Rematch.petCard) with functions for updating, locking and (if possible) pinning:

        rematch.cardManager:Register(cardname,frame,{
            update = function(self,subject), -- function to update the card (required)
            lockUpdate = function(self,subject), -- function to run when card locks/unlocks
            pinUpdate = function(self,subject), -- function to run when card is pinned/unpinned
            shouldShow = function(self,subject), -- function to return true if card should show
            noAnchor = boolean, -- if true, card manager will never attempt to anchor the card
            noHide = function(self,subject), -- function to return true if card should hide from HideAllCards
            noEscape = function(self,subject), -- function to return true if card should close from ESC
        })

        -- an example with self as rematch.petCard
        rematch.cardManager:Register("PetCard",self,{
            update = self.Update,
            lockUpdate = self.UpdateLock,
            pinUpdate = self.UpdatePinButton,
            shouldShow = self.ShouldShow
        })

    Unless a card is pinned, it will anchor to the pet/button that summoned the card. While pinned, it will remain in the
    place it was last dragged.  Pinning is only possible if pinUpdate has a value.

    The position of cards, pin status (and a setting whether a card can be pinned) are savedvars named after the cardname,
    or "PetCard" in the above example.

    To handle a tooltip-like card appearing beneath the mouse, it needs to make all clickable elements mouse-disabled while
    unlocked. Registering will do that automatically, but if you add new elements after the card is registered:

        rematch.cardManager:AddClickableElementToCard(frame,element)

    Now in your OnEnter/OnLeave/OnClick script handlers for the pet/buttons, call the appropriate function here:

        rematch.cardManager:OnEnter(frame,relativeTo,subject)
        rematch.cardManager:OnLeave(frame)
        rematch.cardManager:OnClick(frame,relativeTo,subject)

        In the above:
        - frame is the card's frame, such as Rematch.petCard
        - relativeTo is the button the card is summoned from (used as an anchor for unpinned cards)
        - subject is a card-specific value such as a petID or teamID

    This module doesn't handle any visible elements of the card. The update, lockUpdate and pinUpdate are callbacks for
    the card to handle that on its own.
]]

--[[
    cardInfo[frame] = {
        cardname=string, -- identifier for the card such as "PetCard" or "Notes"
        timer=func, -- the timer function to show the card in normal mode (created during Register)
        update=func, -- the card's function to update its content (passed in register)
        postFunc=func, -- function to run after the card has been updated and anchored
        lockUpdate=func, -- callback function when the card's lock status changes
        pinUpdate=func, -- callback function when the card's pin status changes
        shouldShow=func, -- callback function to determine if subject should show the card
        locked=boolean, -- whether the card is locked and interactable or unlocked and tooltip-like
        enteredRelativeTo=frame, -- the frame/button/texture the card attaches to (if unpinned)
        enteredSubject=string, -- an identifier for the content of the card (petID, teamKey, etc)
        lockedRelativeTo=frame, --
        lockedSubject=string, --
        savedvarCanPin, -- <cardname>CanPin setting that the card is pinnable
        savedvarIsPinned, -- <cardname>IsPinned setting for whether the card is pinned
        savedvarXPos, -- <cardname>XPos setting for the x pos of the pinned card (from TOPLEFT relativeTo BOTTOMLEFT of UIParent)
        savedvarYPos, -- <cardname>YPos setting for the y pos of the pinned card (from TOPLEFT relativeTo BOTTOMLEFT of UIParent)
        savedvarItemRefXPos, -- <cardname>ItemRefXPos setting for the x pos of the unattached/unpinned card (unpinnable)
        savedvarItemRefYPos, -- <cardname>ItemRefYPos setting for the y pox of the unattached/unpinned card (unpinnable)
        noAnchor=boolean, -- true to let calling functions handle anchoring
    }
]]
local cardInfo = {}

-- for AddAnchorExceptions to make an unpinned card anchor differently to a specific frame
-- eg: rematch.cardManager:AddAnchorException(rematch.petCard,PetBattleFrame.ActiveAlly,"TOPRIGHT",PetBattleFrame.ActiveAlly,"BOTTOMRIGHT")
local anchorExceptions = {}

-- name is the name of the card (the pinned/position savedvars will be made from this)
-- frame is a reference to the card's frame
-- update is the function(self,subject) that updates the contents of the card
-- neverPinnable whether the card should never be allowed to be pinned
--function rematch.cardManager:Register(cardname,frame,update,lockUpdate,pinUpdate,shouldShow,noAnchor)
function rematch.cardManager:Register(cardname,frame,def)
    -- assert a few important bits that will make everything explode in a fiery mess if incorrectly defined
    assert(type(cardname)=="string" and cardname:len()>0,"Invalid card cardname: '"..(cardname or "nil"))
    assert(not cardInfo[frame],"Frame for card "..cardname.." already registered.")
    assert(type(def.update)=="function","Attempt to register a cardManager without an update function.")
    for _,info in pairs(cardInfo) do
        assert(info.cardname~=cardname,"Card cardname "..cardname.." already registered.")
    end

    cardInfo[frame] = {
        cardname = cardname, -- string cardname of card to be used to build savedvariables
        update = def.update, -- function(self,subject) to update contents of the card
        lockUpdate = def.lockUpdate, -- function(self) to call when the lock status on the card changes
        pinUpdate = def.pinUpdate, -- function(self) to update the pin show/hide on the card
        shouldShow = def.shouldShow, -- function(self,subject) that returns true if card should be shown
        noAnchor = def.noAnchor, -- true to never anchor card so calling function can do it
        noHide = def.noHide, -- function(self,subject) that returns true if card should not hide in HideAllCards
        noEscape = def.noEscape, -- function(self,subject) that returns true if card should not hide from ESC key
        clickableElements = {}, -- every button, model, etc. with mouse enabled
        savedvarCanPin = cardname.."CanPin",
        savedvarIsPinned = cardname.."IsPinned",
        savedvarXPos = cardname.."XPos",
        savedvarYPos = cardname.."YPos",
        savedvarItemRefXPos = cardname.."ItemRefXPos",
        savedvarItemRefYPos = cardname.."ItemRefYPos",
        timer = function() -- rematch.timer func to display the card on a short delay (C.CARD_MANAER_DELAY)
            if cardInfo[frame].enteredSubject then
                frame:Show()
                def.update(frame,cardInfo[frame].enteredSubject)
                rematch.cardManager:UnlockCard(frame)
                rematch.cardManager:AnchorCard(frame)
            end
        end
    }

    -- create a button to capture ESC keys to close while card on screen
    frame.escButton = CreateFrame("Button",nil,frame)
    frame.escButton:SetScript("OnKeyDown",function(self,key) rematch.cardManager.OnKeyDown(self,self:GetParent(),key) end)

    rematch.cardManager:AddClickableElements(cardInfo[frame].clickableElements,frame) -- populates clickableElements
    rematch.cardManager:UnlockCard(frame,true)

    -- when card hides, clear itemRefMode if it was enabled
    frame:HookScript("OnHide",function(self)
        cardInfo[self].itemRefMode = nil
    end)
end

-- recursive function to add all mouse-enabled frames to the given cardInfo[frame].clickableElements
-- this should be called once when registered to know what frames to make mouse-transparent in the lock/unlock
function rematch.cardManager:AddClickableElements(clickableElements,frame)
    if frame:IsMouseEnabled() then
        tinsert(clickableElements,frame)
    end
    for _,child in pairs({frame:GetChildren()}) do
        rematch.cardManager:AddClickableElements(clickableElements,child)
    end
end

-- intended for use after a card is registered, this adds the given element to the card frame's clickableElements
function rematch.cardManager:AddClickableElementToCard(frame,element)
    local clickableElements = cardInfo[frame] and cardInfo[frame].clickableElements
    if clickableElements and element then
        tinsert(clickableElements,element)
    end
end

-- OnEnter:
--   "Normal": If card not shown, start timer to show card
--   "Fast": If card not shown, show card
--   "Click": Nothing
function rematch.cardManager:OnEnter(frame,relativeTo,subject)
    local behavior = settings.CardBehavior
    local info = cardInfo[frame]

    -- if card has a shouldShow function, and the function returns false, ignore this onEnter
    if not info or (info.shouldShow and not info.shouldShow(self,subject)) then
        return
    end

    info.enteredRelativeTo = relativeTo  -- what the card is attached to (if not pinned)
    info.enteredSubject = subject -- what content the card is displaying (petID, teamKey, etc.)

    if rematch.utils:GetUIJustChanged() then
        return -- if ui just reconfigured or menu/dialog disappeared, don't show this card
    end

    local frameNotLocked = not (frame:IsVisible() and info.locked)

    if behavior==C.MOUSE_SPEED_SLOW and frameNotLocked then
        rematch.timer:Start(C.CARD_MANAGER_DELAY_SLOW,info.timer)
    elseif behavior==C.MOUSE_SPEED_NORMAL and frameNotLocked then
        rematch.timer:Start(C.CARD_MANAGER_DELAY_NORMAL,info.timer)
    elseif behavior==C.MOUSE_SPEED_FAST and frameNotLocked then
        frame:Show()
        info.update(frame,info.enteredSubject)
        rematch.cardManager:UnlockCard(frame)
        rematch.cardManager:AnchorCard(frame)
    end
end

-- OnLeave:
--   "Normal": If card not shown and timer running to show card, stop timer
--             If card shown and not locked, hide card
--   "Fast": If card shown and not locked, hide card
--   "Click": Nothing
function rematch.cardManager:OnLeave(frame)
    local behavior = settings.CardBehavior
    local info = cardInfo[frame]

    if not info then
        return
    end

    info.enteredRelativeTo = nil
    info.enteredSubject = nil

    if behavior==C.MOUSE_SPEED_NORMAL or behavior==C.MOUSE_SPEED_SLOW then
        if not frame:IsVisible() and rematch.timer:IsRunning(info.timer) then
            rematch.timer:Stop(info.timer)
        elseif frame:IsVisible() and not info.locked then
            frame:Hide()
        end
    elseif behavior==C.MOUSE_SPEED_FAST then
        if frame:IsVisible() and not info.locked then
            frame:Hide()
        end
    end
end

-- OnClick:
--   "Normal": If card not shown and timer running, show and lock card
--             If card shown and locked and relativeTo or subject changed, re-anchor and update content
--             If card shown and unlocked, lock it
--             Else if card shown and locked, unlock it
--   "Fast":   If card shown and unlocked, lock it
--             Else if card shown and locked, unlock it
--   "Click":  If card shown and click subject == card subject, hide it
--             Else if card shown and click subject <> card subject, update subject
--             Else if card not shown, show it and lock it
-- (Note to self: DO NOT refactor to reduce duplicate code! There are three DIFFERENT behaviors here!)
function rematch.cardManager:OnClick(frame,relativeTo,subject)
    local behavior = settings.CardBehavior
    local info = cardInfo[frame]
    local isVisible = frame:IsVisible()

    -- handle special handling for a clicking a pet (could be a leveling/rarity stone or shift+click to link)
    if frame==rematch.petCard and rematch.utils:HandleSpecialPetClicks(subject) then
        return -- pet was linked, do nothing else and leave
    end

    -- if card has a shouldShow function, and the function returns false, ignore this
    if not info or (info.shouldShow and not info.shouldShow(frame,subject)) then
        return
    end

    -- if card is in itemRefMode and already on screen, hide it
    if isVisible and info.lockedSubject==subject and info.itemRefMode then
        frame:Hide()
        return
    end

    -- both normal and fast behavior share same behavior if card shown+locked+subject changed, shown+not locked, shown+locked
    if behavior==C.MOUSE_SPEED_NORMAL or behavior==C.MOUSE_SPEED_SLOW or behavior==C.MOUSE_SPEED_FAST then
        -- special case for normal where card is waiting to be shown (or it wasn't shown due to being dismissed and new pet clicked)
        if not isVisible then
            if rematch.timer:IsRunning(info.timer) then
                rematch.timer:Stop(info.timer)
            end
            info.lockedRelativeTo = relativeTo
            info.lockedSubject = subject
            frame:Show()
            info.update(frame,subject)
            rematch.cardManager:LockCard(frame)
            rematch.cardManager:AnchorCard(frame)
        elseif isVisible and info.locked and (not info.lockedSubject or info.lockedSubject==subject) then
            info.update(frame,subject)
            rematch.cardManager:UnlockCard(frame)
            return
        elseif isVisible and info.locked and (subject~=info.lockedSubject) then
            info.lockedRelativeTo = relativeTo
            info.lockedSubject = subject
            info.update(frame,subject)
            rematch.cardManager:AnchorCard(frame)
            if info.lockUpdate then
                info.lockUpdate(frame)
            end
        elseif isVisible and not info.locked then
            rematch.cardManager:LockCard(frame)
        elseif isVisible and info.locked then
            rematch.cardManager:UnlockCard(frame)
        end
    end
    if behavior==C.MOUSE_SPEED_CLICK then
        if isVisible and (not info.lockedSubject or subject==info.lockedSubject) then
            frame:Hide()
        elseif isVisible and subject~=info.lockedSubject then
            info.lockedRelativeTo = relativeTo
            info.lockedSubject = subject
            info.update(frame,subject)
            rematch.cardManager:AnchorCard(frame)
            if info.lockUpdate then
                info.lockUpdate(frame)
            end
        elseif not isVisible then
            info.lockedRelativeTo = relativeTo
            info.lockedSubject = subject
            frame:Show()
            info.update(frame,subject)
            rematch.cardManager:LockCard(frame)
            rematch.cardManager:AnchorCard(frame)
        end
    end
end

-- for the escButton to capture ESC keys: close the card if it's locked and key is ESC; otherwise pass it through
function rematch.cardManager:OnKeyDown(frame,key)
    local info = cardInfo[frame]
    if info.locked and key==GetBindingKey("TOGGLEGAMEMENU") and not rematch.utils:Evaluate(info.noEscape,self,info.lockedSubject) then
        frame:Hide()
        self:SetPropagateKeyboardInput(false)
    else
        self:SetPropagateKeyboardInput(true)
    end
end

-- cards are always movable, even if they can't be pinned
function rematch.cardManager:OnMouseDown()
    self:StartMoving()
end

-- when a card is moved, if it's pinnable, then save its position and call the card's updatePin function
function rematch.cardManager:OnMouseUp()
    local info = cardInfo[self]
    self:StopMovingOrSizing()
    if (info.pinUpdate and settings[info.savedvarCanPin]) or info.itemRefMode then
        local xpos,ypos = self:GetCenter()
        self:ClearAllPoints()
        self:SetPoint("CENTER",UIParent,"BOTTOMLEFT",xpos,ypos)
        if info.itemRefMode then
            settings[info.savedvarItemRefXPos] = xpos
            settings[info.savedvarItemRefYPos] = ypos
        else
            settings[info.savedvarXPos] = xpos
            settings[info.savedvarYPos] = ypos
            settings[info.savedvarIsPinned] = true
            info.pinUpdate(self) -- call the card's function to show the pin
        end
    end
end

-- when the card is locked, its chrome is displayed (alpha 1; all non-chrome elements of the card should be
-- forceAlpha="true"), buttons get mouse enabled, and it's now treated like a dialog
function rematch.cardManager:LockCard(frame,force)
    local info = cardInfo[frame]
    if not info.locked or force then
        frame:SetAlpha(1)
        info.lockedRelativeTo = info.enteredRelativeTo
        info.lockedSubject = info.enteredSubject
        info.locked = true
        for _,element in ipairs(cardInfo[frame].clickableElements) do
            element:EnableMouse(true)
        end
        if info.lockUpdate then
            info.lockUpdate(frame)
        end
    end
end

-- when the card is unlocked, its chrome is hidden (alpha 0), buttons get mouse disabled, and it's now like a tooltip
-- (mouse disabled so if the pet card appears under the mouse due to clamping, it doesn't spasm in onenter/leaves)
function rematch.cardManager:UnlockCard(frame,force)
    local info = cardInfo[frame]
    if info.locked or force then
        frame:SetAlpha(0)
        info.lockedRelativeTo = nil
        info.lockedSubject = nil
        info.locked = false
        for _,element in ipairs(cardInfo[frame].clickableElements) do
            element:EnableMouse(false)
        end
        if info.lockUpdate then
            info.lockUpdate(frame)
        end
    end
end

-- unpins a card and reanchors it to its relativeTo (the Pin complement happens in the OnMouseUp from moving the card)
function rematch.cardManager:Unpin(frame)
    local info = cardInfo[frame]
    settings[info.savedvarIsPinned] = false
    self:AnchorCard(frame)
    if info.pinUpdate then
        info.pinUpdate(frame)
    end
end


-- for outside use to determine whether card locked (to know whether to update it during mousewheel scroll for example)
function rematch.cardManager:IsCardLocked(frame)
    return cardInfo[frame].locked
end

-- returns true if the card can be pinned and if it's actually pinned
function rematch.cardManager:IsCardPinned(frame)
    local info = cardInfo[frame]
    return info.pinUpdate and settings[info.savedvarCanPin] and settings[info.savedvarIsPinned] and not info.itemRefMode
end

function rematch.cardManager:GetRelativeTo(frame)
    local info = cardInfo[frame]
    return info.enteredRelativeTo
end

-- when this is called BEFORE a card is shown, it will anchor the card independently of any frame; locked and unpinnable
-- but movable (it will store its position in savedvarItemRefXPos/YPos); this lasts until the card is hidden
function rematch.cardManager:SetItemRefMode(frame)
    cardInfo[frame].itemRefMode = true
end

-- when an unpinned card should anchor to a specific anchor, add an exception here
-- eg: rematch.cardManager:AddAnchorException(rematch.petCard,PetBattleFrame.ActiveAlly,"TOPRIGHT",PetBattleFrame.ActiveAlly,"BOTTOMRIGHT")
function rematch.cardManager:AddAnchorException(frame,relativeTo,...)
    if cardInfo[frame] then
        if not anchorExceptions[frame] then
            anchorExceptions[frame] = {}
        end
        anchorExceptions[frame][relativeTo] = {...}
    end
end

-- anchors the card to the relativeTo if not pinned, to the pin coordinates otherwise
-- (note: call this after a lock/unlock so it chooses the right relativeTo)
function rematch.cardManager:AnchorCard(frame)
    local info = cardInfo[frame]
    if info.noAnchor then
        return -- if this card has noAnchor set, then never anchor it
    end
    frame:ClearAllPoints()
    if info.itemRefMode then -- if in itemRefMode, anchor card at last known itemref (or center of screen if not known)
        local x,y = settings[info.savedvarItemRefXPos],settings[info.savedvarItemRefYPos]
        frame:SetPoint("CENTER",UIParent,(x and y) and "BOTTOMLEFT" or "CENTER",x or 0,y or 0)
    elseif rematch.cardManager:IsCardPinned(frame) and settings[info.savedvarXPos] and settings[info.savedvarYPos] then
        frame:SetPoint("CENTER",UIParent,"BOTTOMLEFT",settings[info.savedvarXPos],settings[info.savedvarYPos]) -- if card is pinned, anchor it at the saved position
    else -- if card is not pinned, anchor it relative to the relativeTo
        if not info.enteredRelativeTo then
            --info.enteredRelativeTo = GetMouseFocus()
        end
        local relativeTo = info.locked and info.lockedRelativeTo or info.enteredRelativeTo
        if relativeTo and anchorExceptions[frame] and anchorExceptions[frame][relativeTo] then
            -- if an anchor exception for this un-pinned card, use the exception
            frame:SetPoint(unpack(anchorExceptions[frame][relativeTo]))
        elseif relativeTo then
            local corner,opposite = rematch.utils:GetCorner(rematch.utils:GetFrameForReference(relativeTo),UIParent)
            -- adjusting y offset for top-anchored cards to account for the possibly-hidden titlebar height
            frame:SetPoint(corner,relativeTo,opposite,0,(corner=="TOPLEFT" or corner=="TOPRIGHT") and 24 or 0)
        else -- this card is being shown without a lockedRelativeTo or enteredRelativeTo
            frame:SetPoint("CENTER") -- fallback to center of screen
        end
    end
end

-- hides a single card (a normal frame:Hide() is okay too; this just stop any potential timer)
function rematch.cardManager:HideCard(frame)
    local info = cardInfo[frame]
    -- if card is waiting to be shown, stop waiting
    if info.timer and rematch.timer:IsRunning(info.timer) then
        rematch.timer:Stop(info.timer)
    end
    frame:Hide()
end

-- hides any cards that may be visible, such as during a frame configure
function rematch.cardManager:HideAllCards()
    for frame,info in pairs(cardInfo) do
        if not rematch.utils:Evaluate(info.noHide,self,info.lockedSubject) then
            rematch.cardManager:HideCard(frame)
        end
    end
end

-- when a card should be shown and locked without an OnEnter/OnLeave/OnClick
function rematch.cardManager:ShowCard(frame,subject)
    local info = cardInfo[frame]
    rematch.cardManager:HideCard(frame)
    info.lockedSubject = subject
    rematch.cardManager:OnClick(frame,rematch.frame,subject) -- rematch window used as reference
end
