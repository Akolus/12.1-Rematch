local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.journal = {}

local enteringCombat = false

-- PetJournal OnShow if UseDefaultJournal is false, then hide PetJournal and configure Rematch in its place with mode 3
-- frame OnHide if attached to journal, then unparent it and show PetJournal

rematch.events:Register(rematch.journal,"PLAYER_LOGIN",function(self)
    if not C_AddOns.IsAddOnLoaded("Blizzard_Collections") then -- if journal isn't already loaded, wait for it to load
        rematch.events:Register(rematch.journal,"ADDON_LOADED",rematch.journal.ADDON_LOADED)
    else -- if for some crazy reason journal is already loaded by another addon, go through the motions of it just being loaded
        rematch.journal:ADDON_LOADED("Blizzard_Collections")
    end
    rematch.events:Register(rematch.journal,"PLAYER_REGEN_DISABLED",rematch.journal.PLAYER_REGEN_DISABLED)
    rematch.events:Register(rematch.journal,"PLAYER_REGEN_ENABLED",rematch.journal.PLAYER_REGEN_ENABLED)

    -- hook of the "Click here to view in journal" on the floating battle pet "tooltip" (itemref) does a search for the species
    -- (there is a speciesID but not a specific petID (battlePetID is 0000etc) to show a pet card)
    FloatingBattlePetTooltip.JournalClick:HookScript("OnClick",function(self)
        if rematch.journal:IsActive() then
            local speciesName = rematch.petInfo:Fetch(self:GetParent().speciesID).speciesName
            if speciesName then
                speciesName = format("\"%s\"",speciesName)
                rematch.petsPanel.Top.SearchBox:SetText(speciesName)
                rematch.filters:SetSearch(speciesName)
                rematch.petsPanel:Update()
            end
        end
    end)

end)

-- rematch can't be on screen in combat; if we're in journal mode and we enter combat, hide rematch and restore default journal
function rematch.journal:PLAYER_REGEN_DISABLED()
    if rematch.journal:IsActive() then
        enteringCombat = true
        rematch.frame:Hide()
        rematch.frame:SetParent(UIParent)
        PetJournal:Show()
        enteringCombat = false
    end
    if PetJournal and PetJournal:IsVisible() then
        rematch.journal.UseRematchCheckButton:Disable()
    end
end

-- if we leave combat while journal on screen, show rematch (go through motions as if journal just shown)
function rematch.journal:PLAYER_REGEN_ENABLED()
    if PetJournal and PetJournal:IsVisible() then
        rematch.journal.UseRematchCheckButton:Enable()
        rematch.journal:PetJournalOnShow() -- go through motions as if journal just shown
    end
end

function rematch.journal:ADDON_LOADED(addon)
    if addon=="Blizzard_Collections" then
        rematch.events:Unregister(rematch.journal,"ADDON_LOADED")
        -- watching for an actual hide of PetJournal isn't sufficient; we want to watch for *intent* to hide;
        -- because rematch will have already hidden it and something may be trying to hide it again
        hooksecurefunc(PetJournal,"Show",rematch.journal.PetJournalOnShow)
        hooksecurefunc(PetJournal,"Hide",rematch.journal.PetJournalOnHide)
        hooksecurefunc(PetJournal,"SetShown",rematch.journal.PetJournalOnSetShown)
        -- but since rematch never hides CollectionsJournal itself, it's okay to watch for an actual hide
        CollectionsJournal:HookScript("OnHide",rematch.journal.PetJournalOnHide)

        -- for both the alert and floating battle pet tooltip (itemref) "Click here to view in journal"
        hooksecurefunc("PetJournal_SelectPet",function(self,petID)
            if rematch.journal:IsActive() then
                -- if any filters/search happening, clear them
                if not rematch.filters:IsAllClear() or not rematch.filters:IsClear("Search") then
                    rematch.filters:ClearAll()
                    local speciesName = rematch.petInfo:Fetch(petID).speciesName
                    local exactSearch = speciesName and '"'..speciesName..'"' or ""
                    rematch.filters:SetSearch(exactSearch)
                    rematch.petsPanel.Top.SearchBox:SetText(exactSearch)
                    rematch.petsPanel:Update()
                end
                -- then scroll to the petID and show its pet card
                rematch.petsPanel.List:ScrollDataIntoView(petID)
                local frame = rematch.petsPanel.List:GetDataFrame(petID)
                if frame then
                    rematch.cardManager:HideCard(rematch.petCard)
                    rematch.cardManager:OnEnter(rematch.petCard,frame,petID)
                    rematch.cardManager:OnClick(rematch.petCard,frame,petID)
                    rematch.petsPanel.List:Select("PetCard",petID)
                end

            end
        end)

        rematch.journal:DisablePriorUseRematchCheckButtons()
        rematch.journal.UseRematchCheckButton = CreateFrame("CheckButton",nil,PetJournal,"RematchCheckButtonTemplate,RematchTooltipScripts")
        local button = rematch.journal.UseRematchCheckButton
        button:SetText(L["Rematch"])
        button:SetPoint("LEFT",PetJournalSummonButton,"RIGHT",0,-1)
        button:SetScript("OnClick",function(self)
            self:SetChecked(false) -- this version of the checkbutton is when UseDefaultJournal is true, and always false
            rematch.settings.UseDefaultJournal = false
            rematch.journal.PetJournalOnShow(rematch.journal) -- mimic journal being shown to set everything up
        end)
        button.tooltipTitle = L["Use Rematch In Journal"]
        button.tooltipBody = L["Check this to restore Rematch to the journal.\n\nYou can always use Rematch in its standalone window, accessed via key binding, /rematch command or from the Minimap button if enabled in options."]
    end
end

-- takes over the pet journal by hiding PetJournal and putting rematch in its place
function rematch.journal:PetJournalOnShow()
    rematch.journal:DisablePriorUseRematchCheckButtons()
    if not settings.UseDefaultJournal and not InCombatLockdown() and not enteringCombat then
        PetJournal:Hide()
        rematch.frame:SetParent(CollectionsJournal)
        rematch.frame:SetFrameLevel(CollectionsJournal:GetFrameLevel()+600)
        rematch.frame:Configure(C.JOURNAL)
        rematch.journal.UseRematchCheckButton:Enable()
        rematch.frame:Show()
    elseif InCombatLockdown() or enteringCombat then
        rematch.journal.UseRematchCheckButton:Disable()
    end
end

function rematch.journal:PetJournalOnHide()
    if rematch.journal:IsActive() then
        rematch.frame:Hide()
        rematch.frame:SetParent(UIParent)
    end
end

-- this is the primary way PetJournal is shown/hidden, via CollectionsJournal tabs
function rematch.journal:PetJournalOnSetShown(shown)
    rematch.journal[shown and "PetJournalOnShow" or "PetJournalOnHide"](rematch.journal)
end

-- returns true if the journal is currently taken over by rematch
function rematch.journal:IsActive()
    return CollectionsJournal and rematch.frame:GetParent()==CollectionsJournal
end

-- temporary; to disable rematch 4 and rematch 5old journal Rematch checkbuttons
function rematch.journal:DisablePriorUseRematchCheckButtons()
    -- one-time setup of the Rematch checkbutton beside the summon button to enable rematch
    if UseRematchButton and not UseRematchButton.overriden then -- disable the 4.x Rematch checkbutton beside the summon button
        UseRematchButton:Hide()
        UseRematchButton:HookScript("OnShow",function(self) self:Hide() end)
        UseRematchButton.overriden = true
    end
end
