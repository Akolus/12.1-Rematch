local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.miniLoadoutPanel = rematch.frame.MiniLoadoutPanel
rematch.frame:Register("miniLoadoutPanel")

function rematch.miniLoadoutPanel:Configure()
    local width = self:GetWidth() -- width can change for this panel (minimized 85px, 2-panel 92px, 1-panel 112px)
    local loadoutWidth = floor((width-4)/3+0.5) -- width of each of three loadouts, 2px gap between left/center and right/center
    local gap = floor((loadoutWidth-44-26)/3+0.5) -- gap between sides/middle for each loadout around pet and abilityBar
    for i=1,3 do
        self.Loadouts[i]:SetSize(loadoutWidth,C.PANEL_MINILOADOUT_HEIGHT)
        self.Loadouts[i].Icon:SetPoint("TOPLEFT",gap+2+1,-8-3) -- pet icon
        self.Loadouts[i].AbilityBar:SetPoint("TOPRIGHT",-gap,-8-1)
        self.Loadouts[i].neverDim = true -- never desaturate a loaded pet
    end
    -- due to potential rounding errors, centering middle loadout and positioning other two 2px to left and right
    self.Loadouts[2]:SetPoint("CENTER")
    self.Loadouts[1]:SetPoint("RIGHT",self.Loadouts[2],"LEFT",-2,0)
    self.Loadouts[3]:SetPoint("LEFT",self.Loadouts[2],"RIGHT",2,0)
end

function rematch.miniLoadoutPanel:Update()
    for i=1,3 do
        local petID,ability1,ability2,ability3,locked = C_PetJournal.GetPetLoadOutInfo(i)
        self.Loadouts[i].petID = petID
        if C_PetBattles.IsInBattle() then
            petID = "battle:1:"..i -- if in a pet battle, use the battle petID to get health updates during battle
        end
        self.Loadouts[i]:FillPet(petID)
        self.Loadouts[i].AbilityBar:FillAbilityBar(petID,ability1,ability2,ability3)
        self:FillStatusBars(self.Loadouts[i],petID)

        rematch.loadoutPanel:FillSpecial(self.Loadouts[i],i)

        local showGlow = rematch.utils:IsPetOnCursor()
        if showGlow then
            self.Loadouts[i].Animation:Play()
        else
            self.Loadouts[i].Animation:Stop()
        end
        self.Loadouts[i].Glow:SetShown(showGlow)
        self.Loadouts[i].LockOverlay:SetShown(rematch.utils:IsJournalLocked() or rematch.loadouts:IsSlotLocked(i))

        -- when slotting a pet, the loadouts are updated; if the mouse is over a loadout when that happens and the pet card
        -- is unlocked and visible, then we need to change pets the card is showing (using the OnEnter to let focus handle it)
        if self.Loadouts[i]:IsMouseOver() and rematch.petCard.petID~=petID and not rematch.cardManager:IsCardLocked(rematch.petCard) then
            local focus = GetMouseFoci()[1]
            if focus and focus.petID then
                focus:GetScript("OnEnter")(focus)
            end
        end
    end
    self.AbilityFlyout:Hide()
    self:UpdateGlow()

end

function rematch.miniLoadoutPanel:UpdateGlow()
    for i=1,3 do
        local showGlow = rematch.utils:IsPetOnCursor()
        if showGlow then
            self.Loadouts[i].Animation:Play()
        else
            self.Loadouts[i].Animation:Stop()
        end
        self.Loadouts[i].Glow:SetShown(showGlow)
    end
end

-- OnUpdate closes flyout after C.FLYOUT_OPEN_TIMER passes with mouse not on the flyout or ability that opened it
local flyoutTimer = 0
function rematch.miniLoadoutPanel.AbilityFlyout:OnUpdate(elapsed)
    if self.anchoredTo and (self.anchoredTo:IsMouseOver() or self:IsMouseOver()) then
        flyoutTimer = 0
    else
        flyoutTimer = flyoutTimer + elapsed
        if flyoutTimer > C.FLYOUT_OPEN_TIMER then
            self:Hide()
        end
    end
end

-- updates the two statusbars on the loadout slot
function rematch.miniLoadoutPanel:FillStatusBars(loadout,petID)
    if not petID then -- if there's no pet in this slot
        self:SetTopStatusBarShown(loadout,true)
        rematch.utils:UpdateStatusBar(loadout.TopStatusBar,0,100,C.MINILOADOUT_STATUSBAR_WIDTH,0,0,0)
        rematch.utils:UpdateStatusBar(loadout.BottomStatusBar,0,100,C.MINILOADOUT_STATUSBAR_WIDTH,0,0,0)
    else -- there's a pet slotted
        if C_PetBattles.IsInBattle() then
            petID = "battle:1:"..loadout:GetID()
        end
        local petInfo = rematch.petInfo:Fetch(petID)
        local health,maxHealth = petInfo.health,petInfo.maxHealth
        if petInfo.level==25 then -- this pet is max level, use bottom status bar for health and display a numerical health at top
            self:SetTopStatusBarShown(loadout,false)
            loadout.HealthText:SetText(petInfo.shortHealthStatus) -- display text health (Dead, 75% or 1400)
            rematch.utils:UpdateStatusBar(loadout.BottomStatusBar,health,maxHealth,C.MINILOADOUT_STATUSBAR_WIDTH,C.HP_BAR_COLOR.r,C.HP_BAR_COLOR.g,C.HP_BAR_COLOR.b)
        else -- this pet is under 25, use top statusbar for health and bottom for xp
            self:SetTopStatusBarShown(loadout,true)
            rematch.utils:UpdateStatusBar(loadout.TopStatusBar,health,maxHealth,C.MINILOADOUT_STATUSBAR_WIDTH,C.HP_BAR_COLOR.r,C.HP_BAR_COLOR.g,C.HP_BAR_COLOR.b)
            rematch.utils:UpdateStatusBar(loadout.BottomStatusBar,petInfo.xp,petInfo.maxXp,C.MINILOADOUT_STATUSBAR_WIDTH,C.XP_BAR_COLOR.r,C.XP_BAR_COLOR.g,C.XP_BAR_COLOR.b)
        end
    end
end

-- shows or hide the top status bar (and display heart icon and health text if not shown)
-- (should be called before UpdateStatusBar in case the TopStatusBar is hidden at 0 value)
function rematch.miniLoadoutPanel:SetTopStatusBarShown(loadout,show)
    loadout.TopStatusBarBack:SetShown(show)
    loadout.TopStatusBar:SetShown(show)
    loadout.TopStatusBarBorder:SetShown(show)
    loadout.HeartIcon:SetShown(not show)
    loadout.HealthText:SetShown(not show)
end

function rematch.miniLoadoutPanel:OnShow()
    rematch.events:Register(self,"REMATCH_LOADOUTS_CHANGED",self.Update)
    rematch.events:Register(self,"REMATCH_ABILITIES_CHANGED",self.Update)
    rematch.events:Register(self,"REMATCH_PET_PICKED_UP_ON_CURSOR",self.Update)
    rematch.events:Register(self,"REMATCH_PET_DROPPED_FROM_CURSOR",self.Update)
    rematch.events:Register(self,"PET_BATTLE_HEALTH_CHANGED",self.Update) -- health changing during battle
    rematch.events:Register(self,"REMATCH_TEAM_LOADED",self.REMATCH_TEAM_LOADED) -- team loaded, flash pets
    self:UpdateGlow()
end

function rematch.miniLoadoutPanel:OnHide()
    self.AbilityFlyout:Hide()
    rematch.events:Unregister(self,"REMATCH_LOADOUTS_CHANGED")
    rematch.events:Unregister(self,"REMATCH_ABILITIES_CHANGED")
    rematch.events:Unregister(self,"REMATCH_PET_PICKED_UP_ON_CURSOR")
    rematch.events:Unregister(self,"REMATCH_PET_DROPPED_FROM_CURSOR")
    rematch.events:Unregister(self,"PET_BATTLE_HEALTH_CHANGED")
    rematch.events:Unregister(self,"REMATCH_TEAM_LOADED")
end

-- when a team loads, update panel and flash the three loadout slots
function rematch.miniLoadoutPanel:REMATCH_TEAM_LOADED()
    self:Update()
    self:BlingLoadouts()
end

function rematch.miniLoadoutPanel:BlingLoadouts()
    for i=1,3 do
        self.Loadouts[i].Bling:Show()
    end
end

function rematch.miniLoadoutPanel:LoadoutOnEnter()
    rematch.textureHighlight:Show(self.Back,self.Icon)
    rematch.cardManager:OnEnter(rematch.petCard,self,self.petID)
end

function rematch.miniLoadoutPanel:LoadoutOnLeave()
    rematch.textureHighlight:Hide()
    rematch.cardManager:OnLeave(rematch.petCard,self,self.petID)
end

function rematch.miniLoadoutPanel:LoadoutOnMouseDown()
    if rematch.utils:IsJournalUnlocked() then
        rematch.textureHighlight:Hide()
    end
end

function rematch.miniLoadoutPanel:LoadoutOnMouseUp()
    if self:IsMouseMotionFocus() and rematch.utils:IsJournalUnlocked() then
        rematch.textureHighlight:Show(self.Back,self.Icon)
    end
end

function rematch.miniLoadoutPanel:LoadoutOnClick(button)
    if rematch.utils:IsJournalLocked() then
        rematch.cardManager:OnClick(rematch.petCard,self,self.petID)
    elseif button=="RightButton" then
        if rematch.petInfo:Fetch(self.petID).idType=="pet" then
            rematch.menus:Show("LoadoutMenu",self,{slot=self:GetID(),petID=self.petID},"cursor")
        end
    else
        if rematch.utils:IsPetOnCursor() then -- if pet is on the cursor then drop pet into this loadout
            rematch.miniLoadoutPanel.LoadoutOnReceiveDrag(self)
        else -- otherwise lock/unlock pet card
            rematch.cardManager:OnClick(rematch.petCard,self,self.petID)
        end
    end
end

function rematch.miniLoadoutPanel:LoadoutOnDoubleClick(button)
    if not settings.NoSummonOnDblClick then
        C_PetJournal.SummonPetByGUID(self.petID)
        rematch.petCard:Hide()
    end
end

function rematch.miniLoadoutPanel:LoadoutOnDragStart()
    if rematch.utils:IsJournalUnlocked() then
        local petInfo = rematch.petInfo:Fetch(self.petID)
        if petInfo.isOwned and petInfo.idType=="pet" then
            C_PetJournal.PickupPet(self.petID)
        end
    end
end

function rematch.miniLoadoutPanel:LoadoutOnReceiveDrag()
    if rematch.utils:IsJournalUnlocked() then
        local petID = rematch.utils:GetPetCursorInfo()
        if petID then
            ClearCursor()
            rematch.loadouts:SlotPet(self:GetID(),petID)
            rematch.petCard:Hide()
            rematch.miniLoadoutPanel.LoadoutOnEnter(self)
            PlaySound(C.SOUND_DRAG_STOP)
        end
    end
end

--[[ script handlers for special buttons at the top of loadout slots (leveling, random, ignored)

    these ended up being the same as the main loadout
]]

rematch.miniLoadoutPanel.SpecialOnEnter = rematch.loadoutPanel.SpecialOnEnter
rematch.miniLoadoutPanel.SpecialOnLeave = rematch.loadoutPanel.SpecialOnLeave
rematch.miniLoadoutPanel.SpecialOnMouseDown = rematch.loadoutPanel.SpecialOnMouseDown
rematch.miniLoadoutPanel.SpecialOnMouseUp = rematch.loadoutPanel.SpecialOnMouseUp
rematch.miniLoadoutPanel.SpecialOnClick = rematch.loadoutPanel.SpecialOnClick

--[[ script handlers for lock overlay same as main loadouts ]]

rematch.miniLoadoutPanel.LockOnEnter = rematch.loadoutPanel.LockOnEnter
rematch.miniLoadoutPanel.LockOnLeave = rematch.loadoutPanel.LockOnLeave