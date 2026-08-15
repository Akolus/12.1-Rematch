local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.battle = {}

-- this becoms the little notes button in the available spot of the battle UI's MicroButtonFrame
rematch.battle.NotesButton = CreateFrame("Button","RematchNotesMicroButton")

rematch.events:Register(rematch.battle,"PLAYER_LOGIN",function(self)
    if C_AddOns.IsAddOnLoaded("Blizzard_PetBattleUI") then -- if already loaded on login, run setup right away
        self:Setup()
    else -- otherwise register for battle ui to load before doing setup
        rematch.events:Register(self,"ADDON_LOADED",self.ADDON_LOADED)
    end
end)

-- watches for battle ui being loaded and calls a setup if so
function rematch.battle:ADDON_LOADED(addon)
    if addon=="Blizzard_PetBattleUI" then
        self:Setup()
        rematch.events:Unregister(self,"ADDON_LOADED")
    end
end

-- one-time setup after battle ui is loaded
function rematch.battle:Setup()

    for _,parentKey in ipairs({"ActiveAlly","ActiveEnemy","Ally2","Ally3","Enemy2","Enemy3"}) do
        local frame = PetBattleFrame[parentKey]
        frame:HookScript("OnEnter",self.UnitOnEnter)
        frame:HookScript("OnLeave",self.UnitOnLeave)
        frame:HookScript("OnClick",self.UnitOnClick)
    end

    -- add anchor exceptions for pet card on ActiveAlly and ActiveEnemy
    rematch.cardManager:AddAnchorException(rematch.petCard,PetBattleFrame.ActiveAlly,"TOP",PetBattleFrame.ActiveAlly,"BOTTOM",0,16)
    rematch.cardManager:AddAnchorException(rematch.petCard,PetBattleFrame.ActiveEnemy,"TOP",PetBattleFrame.ActiveEnemy,"BOTTOM",0,16)

    rematch.events:Register(self,"PET_BATTLE_FINAL_ROUND",self.PET_BATTLE_FINAL_ROUND)
    rematch.events:Register(self,"PET_BATTLE_CLOSE",self.PET_BATTLE_CLOSE)
    rematch.events:Register(self,"REMATCH_NOTES_CHANGED",self.REMATCH_NOTES_CHANGED)
    rematch.events:Register(self,"REMATCH_TEAM_LOADED",self.REMATCH_NOTES_CHANGED) -- this shares same function as notes changing

    -- set up notes micro button in battle UI to summon team notes
    local notesButton = self.NotesButton
    notesButton:SetParent(PetBattleFrame.BottomFrame.MicroButtonFrame)
    notesButton:SetSize(32,40)
    notesButton:SetPoint("BOTTOMRIGHT",10,-10)
    notesButton.Background = notesButton:CreateTexture(nil,"BACKGROUND")
    notesButton.Background:SetAtlas("UI-HUD-MicroMenu-ButtonBG-Up",true)
    notesButton.Background:SetPoint("CENTER")
    notesButton.Icon = notesButton:CreateTexture(nil,"ARTWORK")
    notesButton.Icon:SetTexture("Interface\\AddOns\\Rematch\\textures\\notesmicrobutton.blp")
    notesButton.Icon:SetSize(24,24)
    notesButton.Icon:SetPoint("CENTER")
    notesButton.Highlight = notesButton:CreateTexture(nil,"OVERLAY")
    notesButton.Highlight:SetBlendMode("ADD")
    notesButton.Highlight:SetTexture("Interface\\AddOns\\Rematch\\textures\\notesmicrobutton.blp")
    notesButton.Highlight:SetSize(24,24)
    notesButton.Highlight:SetPoint("CENTER",notesButton.Icon,"CENTER")
    notesButton.Highlight:SetAlpha(0.15)
    notesButton.Highlight:Hide()
    notesButton:SetScript("OnEnter",notesButton.OnEnter)
    notesButton:SetScript("OnLeave",notesButton.OnLeave)
    notesButton:SetScript("OnMouseDown",notesButton.OnMouseDown)
    notesButton:SetScript("OnMouseUp",notesButton.OnMouseUp)
    notesButton:SetScript("OnShow",notesButton.OnShow)
    notesButton:SetScript("OnClick",notesButton.OnClick)
    notesButton:SetShown(not settings.HideNotesButtonInBattle)
end

function rematch.battle.NotesButton:OnEnter()
    self.Highlight:Show()
    rematch.cardManager:OnEnter(rematch.notes,self,rematch.settings.currentTeamID)
end

function rematch.battle.NotesButton:OnLeave()
    self.Highlight:Hide()
    rematch.cardManager:OnLeave(rematch.notes,self,rematch.settings.currentTeamID)
end

function rematch.battle.NotesButton:OnMouseDown()
    if self:IsEnabled() then
        self.Background:SetPoint("CENTER",1,-1)
        self.Icon:SetPoint("CENTER",1,-1)
        self.Icon:SetVertexColor(0.45,0.45,0.45)
    end
end

function rematch.battle.NotesButton:OnMouseUp()
    if self:IsEnabled() then
        self.Background:SetPoint("CENTER")
        self.Icon:SetPoint("CENTER")
        self.Icon:SetVertexColor(0.9,0.9,0.9)
    end
end

function rematch.battle.NotesButton:OnShow()
    self:OnMouseUp()
    self:Update()
end

function rematch.battle.NotesButton:OnClick()
    rematch.cardManager:OnClick(rematch.notes,self,rematch.settings.currentTeamID)
end

-- needs to update when button shown, team unloaded, team saved, notes changed
function rematch.battle.NotesButton:Update()
    local teamID = rematch.settings.currentTeamID
    if rematch.savedTeams:IsUserTeam(teamID) then
        self.Icon:SetDesaturated(false)
        self.Icon:SetVertexColor(0.9,0.9,0.9,1)
        if rematch.savedTeams[teamID].notes then
            self.Icon:SetTexCoord(0,0.5,0,1)
            self.Highlight:SetTexCoord(0,0.5,0,1)
        else -- team is loaded but has no notes, use icon with green + on it
            self.Icon:SetTexCoord(0.5,1,0,1)
            self.Highlight:SetTexCoord(0.5,1,0,1)
        end
        self:Enable()
    else
        self.Icon:SetDesaturated(true)
        self.Icon:SetVertexColor(0.4,0.4,0.4,0.5)
        self.Icon:SetTexCoord(0,0.5,0,1)
        self.Highlight:Hide()
        self:Disable()
    end
end


-- from the given owner,index, return a petID, either the owned petID (if petOwner is ally), or "battle:2:index"
function rematch.battle:GetUnitPetID(petOwner,petIndex)
    -- if all ally 3 ally pets loaded, then we can use loadouts to get actual petID
    -- (if a pet is dead, then index 2 pet could be loadout slot 3; so can't easily get petID)
    -- TODO: petInfo is going to loadouts anyway; this is a bug to fix for future (kinda messy)
    if petOwner==Enum.BattlePetOwner.Ally and petIndex and C_PetBattles.GetNumPets(Enum.BattlePetOwner.Ally)==3 then
        return (rematch.loadouts:GetLoadoutInfo(petIndex))
    elseif petIndex then
        return format("battle:%d:%d",petOwner,petIndex) -- this will return an enemy battle:owner:index link
    end
end

function rematch.battle:UnitOnEnter()
    if settings.PetCardInBattle then
        PetBattlePrimaryUnitTooltip:Hide()
        rematch.cardManager:OnEnter(rematch.petCard,self,rematch.battle:GetUnitPetID(self.petOwner,self.petIndex))
    end
end

function rematch.battle:UnitOnLeave()
    if settings.PetCardInBattle then
        rematch.cardManager:OnLeave(rematch.petCard,self,rematch.battle:GetUnitPetID(self.petOwner,self.petIndex))
    end
end

function rematch.battle:UnitOnClick(button)
    if button~="RightButton" and settings.PetCardInBattle then
        rematch.cardManager:OnClick(rematch.petCard,self,rematch.battle:GetUnitPetID(self.petOwner,self.petIndex))
    end
end

-- as battle is ending, record if it was a pvp battle
function rematch.battle:PET_BATTLE_FINAL_ROUND(winner)
    self.wasInPVP = not C_PetBattles.IsPlayerNPC(Enum.BattlePetOwner.Enemy)
end

-- this is called in pairs, so don't use toggle without checking if it's visible
function rematch.battle:PET_BATTLE_CLOSE()
    if settings.ShowAfterBattle and not (self.wasInPVP and settings.ShowAfterPVEOnly) and not rematch.frame:IsVisible() then
        rematch.frame:Toggle(true)
        -- pvp pets don't actually take damage, so update frame after leaving battle
        rematch.timer:Start(C.QUEUE_PROCESS_WAIT,rematch.frame.Update)
    end
    if rematch.notes:IsVisible() and not rematch.notes.Content.ScrollFrame.EditBox:HasFocus() and not settings.KeepNotesOnScreen then
        rematch.cardManager:HideCard(rematch.notes)
    end
end

-- if notes change while in battle UI, then the notes micro button will potentially change
function rematch.battle:REMATCH_NOTES_CHANGED()
    if PetBattleFrame and PetBattleFrame.BottomFrame.MicroButtonFrame:IsVisible() then
        self.NotesButton:Update()
    end
end
