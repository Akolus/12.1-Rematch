local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.optionsPanel = rematch.frame.OptionsPanel
rematch.frame:Register("optionsPanel")

-- ordered list of indexes into rematch.optionsList to display
local optionIndexes = {}
-- indexed by var, sub-tables of ordered list of option indexes that are dependent on this index (for search hits)
searchDependencies = {}

-- indexed by dropdown setting name (var in optionsList), the listbutton control made for the setting
local dropDownFrames = {}

rematch.events:Register(rematch.optionsPanel,"PLAYER_LOGIN",function(self)
    self.Top.SearchBox.Instructions:SetText(L["Search Options"])
    -- expanded headers savedvar
    if type(settings.ExpandedOptionsHeaders)~="table" then
        settings.ExpandedOptionsHeaders = {}
    end

    -- when no breed addon loaded, then remove breed options (do any list removal before autoscrollbox setup)
    if not rematch.breedInfo:IsAnyBreedAddOnLoaded() then
        for index=#rematch.optionsList,1,-1 do
            local info = rematch.optionsList[index]
            if info.group==18 then -- remove all entries in Breed Options
                tremove(rematch.optionsList,index)
                if info.type=="header" then -- and nil its expanded header if it was open
                    settings.ExpandedOptionsHeaders[index] = nil
                end
            end
            -- remove "Always Hide Possible Breeds" from Pet Card Options or "Prioritize Breed On Import" on Team Options
            if info.var=="PetCardHidePossibleBreeds" or info.var=="PrioritizeBreedOnImport" then
                tremove(rematch.optionsList,index)
            end
        end
    end

    -- if soft target is not fully enabled (SoftTargetInteract is 3) then hide soft target dropdown
    if GetCVar("SoftTargetInteract")~="3" then
        for index=#rematch.optionsList,1,-1 do
            local info = rematch.optionsList[index]
            if info.var=="InteractOnSoftInteract" then
                tremove(rematch.optionsList,index)
            end
        end
        settings.InteractOnSoftInteract = C.INTERACT_NONE
    end

    -- for autoScrollBox, using the indexes into optionsList
    for index in ipairs(rematch.optionsList) do
        tinsert(optionIndexes,index)
    end
    -- for search hits, build dependency references
    for index,info in ipairs(rematch.optionsList) do
        if info.dependency then
            if not searchDependencies[info.dependency] then
                searchDependencies[info.dependency] = {}
            end
            tinsert(searchDependencies[info.dependency],index)
        end
    end
    -- setup autoScrollBox
    self.List:Setup({
        allData = optionIndexes,
        normalTemplate = "RematchOptionsNormalTemplate",
        normalFill = self.FillNormal,
        normalHeight = 26,
        headerTemplate = "RematchOptionsHeaderTemplate",
        headerFill = self.FillHeader,
        headerCriteria = self.HeaderCriteria,
        headerHeight = 26,
        expandedHeaders = settings.ExpandedOptionsHeaders,
        allButton = self.Top.AllButton,
        searchBox = self.Top.SearchBox,
        searchHit = self.SearchHit,
    })
    -- setup widgets
    for widget,setup in pairs(self.widgetSetup) do
        setup(self[widget])
    end
    -- go through all options and if any have runOnLogin set, then run their functions (named func is a member of rematch.optionPanel.funcs)
    for _,info in ipairs(rematch.optionsList) do
        if info.runOnLogin and rematch.optionsPanel.funcs[info.runOnLogin] then
            rematch.optionsPanel.funcs[info.runOnLogin](self,info)
        end
    end

    -- register CustomScaleDialog
    rematch.dialog:Register("CustomScaleDialog",{
        title = L["Use Custom Scale"],
        accept = SAVE,
        cancel = CANCEL,
        other = RESET,
        layout = {"Text","Slider"},
        refreshFunc = function(self,info,subject,firstRun)
            if firstRun then
                self.Text:SetText(L["The standalone window can be scaled from 50% to 200% of its normal size:"])
                self.Slider:Setup(settings.CustomScaleValue or 100,50,200,30,"%d%%",function(self,value)
                    settings.CustomScaleValue=value
                    rematch.frame:UpdateScale()
                    rematch.optionsPanel:Update()
                end)
                self.originalValue = settings.CustomScaleValue
            end
        end,
        otherFunc = function(self,info,subject)
            settings.CustomScaleValue = 100
            rematch.frame:UpdateScale()
            rematch.optionsPanel:Update()
        end,
        cancelFunc = function(self,info,subject)
            settings.CustomScaleValue = self.originalValue
            rematch.frame:UpdateScale()
            rematch.optionsPanel:Update()
        end
    })

    rematch.dialog:Register("ExportOptions",{
        title = L["Export Options"],
        accept = OKAY,
        layout = {"Text","MultiLineEditBox","Help"},
        refreshFunc = function(self,info,subject,firstRun)
            self.Text:SetText(L["Press Ctrl+C to copy to clipboard"])
            self.Help:SetText(L["This is intended to help troubleshoot issues.\n\nMany options interact with other options. When reporting a problem this can help recreate the issue."])
            self.MultiLineEditBox:SetText(subject or "",true)
            self.MultiLineEditBox:ScrollToTop()
        end,
        changeFunc = function(self,info,subject)
            self.MultiLineEditBox:SetText(subject or "",true)
            self.MultiLineEditBox:ScrollToTop()
        end
    })

    rematch.dialog:Register("ImportOptions",{
        title = L["Import Options"],
        accept = L["Import"],
        cancel = CANCEL,
        layout = {"Text","SmallText","MultiLineEditBox","Feedback"},
        refreshFunc = function(self,info,subject,firstRun)
            self.Text:SetText(L["Press Ctrl+V to paste from clipboard"])
            self.SmallText:SetText(format(L["This will reset most options, set them to values pasted here, then reload the UI. %sUse this at your own risk!\124r Tinkering with these values can cause Rematch to become unstable and require a full reset."],C.HEX_RED))
            self.Feedback:Set("warning",L["This will reset most options!\nThis cannot be undone!"])
            rematch.dialog.AcceptButton:Disable()
            self.MultiLineEditBox:SetText("")
        end,
        changeFunc = function(self,info,subject)
            local import = (self.MultiLineEditBox:GetText() or ""):trim()
            if import:len()>0 and not import:match("[A-Za-z0-9_]+=[A-Za-z0-9_%s]+") then
                self.Feedback:Set("warning","Invalid options")
                rematch.dialog.AcceptButton:Disable()
            else
                self.Feedback:Set("warning",L["This will reset most options!\nThis cannot be undone!"])
                rematch.dialog.AcceptButton:SetEnabled(import:len()>0)
            end
        end,
        acceptFunc = function(self,info,subject)
            local import = (self.MultiLineEditBox:GetText() or ""):trim()
            if import:len()>0 then
                rematch.optionsPanel:ImportOptions(import)
            end
        end
    })

    rematch.dialog:Register("ResetOptions",{
        title = L["Reset Options"],
        accept = YES,
        cancel = NO,
        prompt = L["Restore all options to default?"],
        layout = {"Icon","Text","Feedback"},
        refreshFunc = function(self,info,subject,firstRun)
            self.Icon:SetTexture("Interface\\ICONS\\Ability_Creature_Cursed_02")
            self.Icon:SetTexCoord(0.075,0.925,0.075,0.925)
            self.Text:SetText(L["This will restore all options in Rematch to default values and reload the UI.\n\nThis includes all settings in the Options panel but does not include teams, leveling queue or notes."])
            self.Feedback:Set("warning",L["Warning: This cannot be undone!"])
        end,
        acceptFunc = function(self,info,subject)
            for k,v in pairs(settings:GetDefaults()) do
                if type(v)~="table" then
                    settings[k] = v
                end
            end
            ReloadUI()
        end,
    })

end)

local function clearWidget(self)
    if self.widget and self.widget:GetParent()==self then
        self.widget:ClearAllPoints()
        self.widget:SetParent(rematch.optionsPanel)
        self.widget:Hide()
        self.widget = nil
    end
end

-- updates the options panel
function rematch.optionsPanel:Update()
    self.List:Update()
    for widget,update in pairs(self.widgetUpdate) do
        update(self[widget])
    end
end

-- returns the dropdown listbutton frame for the given variable, creating and initializing it if needed
function rematch.optionsPanel:GetDropDownFrame(var)
    local frame = var and dropDownFrames[var]
    if frame then
        return frame
    elseif var then -- frame for this dropdown doesn't exist, go get its details and build it
        for _,info in ipairs(rematch.optionsList) do
            if info.var==var then
                frame = CreateFrame("Button",nil,self,"RematchOptionsDropDownTemplate")
                if info.tooltip then
                    frame.tooltipTitle = info.text
                    frame.tooltipBody = info.tooltip
                end
                frame.Label:SetText(info.text..":")
                frame.DropDown:BasicSetup(info.menu,function(value)
                    settings[var] = value
                    if info.func and self.funcs[info.func] then
                        self.funcs[info.func](frame,value)
                    end
                    if info.update then
                        rematch.frame:Update()
                    end
                end)
                frame.DropDown:SetSelection(settings[var])
                dropDownFrames[var] = frame
                return frame
            end
        end
    end
end

-- when a dropdown affects other dropdowns, this should be called on those others to change their value
function rematch.optionsPanel:UpdateDropDown(var)
    local frame = var and dropDownFrames[var]
    if frame then
        frame.DropDown:SetSelection(settings[var])
    end
end

-- returns true if the index is a header
function rematch.optionsPanel:HeaderCriteria(index)
    local info = rematch.optionsList[index]
    return info and info.type=="header" or false
end

-- fills a header button with details at index
function rematch.optionsPanel:FillHeader(index)
    self.index = index
    self.info = rematch.optionsList[index]
    if not self.info then return end
    self.Text:SetText(self.info.text)
    self:SetBack()
    self:SetExpanded(rematch.optionsPanel.List:IsHeaderExpanded(index),rematch.optionsPanel.List:IsSearching())
end

-- fills a normal (non-header) button with details at the index
function rematch.optionsPanel:FillNormal(index)
    self.index = index
    self.info = rematch.optionsList[index]
    if not self.info then return end
    if self.info.type=="check" then
        self.Check:Show()
        self.Text:Show()
        clearWidget(self)
        local xoff = settings[self.info.var] and 0.25 or 0
        self.Check:SetTexCoord(0+xoff,0.25+xoff,0.5,0.75)
        self.Check:SetDesaturated(self.info.dependency and not settings[self.info.dependency])
        self.Check:SetPoint("LEFT",self.info.dependency and 16 or 0,0)
        self.dependencyUnchecked = self.info.dependency and not settings[self.info.dependency]

        if settings[self.info.var]==nil then -- temporary, when a default doesn't exist for this setting, make it red
            self.Text:SetTextColor(1,0.5,0.5)
        elseif self.dependencyUnchecked then -- dependent option disabled, grey this one
            self.Text:SetTextColor(0.5,0.5,0.5)
        else -- for everything else, white text
            self.Text:SetTextColor(0.9,0.9,0.9)
        end
        self.Text:SetPoint("LEFT",self.Check,"RIGHT",2,0)
        self.Text:SetText(self.info.text)
    elseif self.info.type=="text" then
        self.Check:Hide()
        self.Text:Show()
        clearWidget(self)
        self.Text:SetTextColor(0.9,0.9,0.9)
        self.Text:SetPoint("LEFT",6,0)
        self.Text:SetText(self.info.text)
    elseif self.info.type=="dropdown" then
        self.Check:Hide()
        self.Text:Hide()
        clearWidget(self)
        local dropdown = rematch.optionsPanel:GetDropDownFrame(self.info.var)
        dropdown:ClearAllPoints()
        dropdown:SetParent(self)
        dropdown:SetAllPoints(true)
        dropdown:Show()
        self.widget = dropdown
    elseif self.info.type=="widget" then
        self.Check:Hide()
        self.Text:Hide()
        clearWidget(self)
        local widget = rematch.optionsPanel[self.info.parentKey]
        widget:ClearAllPoints()
        widget:SetParent(self)
        widget:SetAllPoints(true)
        widget:Show()
        self.widget = widget
    end
end

function rematch.optionsPanel:SearchHit(mask,index)
    local info = rematch.optionsList[index]
    if info.text and rematch.utils:match(mask,info.text,info.tooltip) then
        return true -- this option was a search hit
    end
    -- while this option didn't match, see if it has dependants that do
    if info.var and searchDependencies[info.var] then
        for _,dependant in ipairs(searchDependencies[info.var]) do
            if rematch.optionsPanel.SearchHit(self,mask,dependant) then
                return true -- if at least one dependant was a hit, list this dependency
            end
        end
    end
    return false
end

RematchOptionsListButtonMixin = {}

function RematchOptionsListButtonMixin:OnEnter()
    if self.info and not self.dependencyUnchecked and (not rematch.optionsPanel.List:IsSearching() or self.info.type~="header") then
        if self.info.type=="header" then
            rematch.textureHighlight:Show(self.Back,self.ExpandIcon)
        elseif self.info.type=="check" then
            rematch.textureHighlight:Show(self.Check)
        end
    end
    if self.info and self.info.tooltip then
        if self.info.type=="check" then
            rematch.tooltip:ShowSimpleTooltip(self,self.info.text,self.info.tooltip)
        end
    end
end

function RematchOptionsListButtonMixin:OnLeave()
    rematch.textureHighlight:Hide()
    rematch.tooltip:Hide()
end

function RematchOptionsListButtonMixin:OnMouseDown()
    rematch.textureHighlight:Hide()
end

function RematchOptionsListButtonMixin:OnMouseUp()
    if self:IsMouseMotionFocus() then
        self:OnEnter()
    end
end

-- onclick shared by header and non-header
function RematchOptionsListButtonMixin:OnClick()
    if not self.info or self.dependencyUnchecked then
        return -- don't click anything unknown or if dependency unchecked
    end
    if self.info.type=="header" then
        rematch.optionsPanel.List:ToggleHeader(self.index)
        PlaySound(C.SOUND_HEADER_CLICK)
    elseif self.info.type=="check" then
        if settings[self.info.var]==nil then
            return -- for settings in development; don't update settings that don't have a default (they'll be colored red)
        end
        settings[self.info.var] = not settings[self.info.var]
        if self.info.func then -- if there's a function to run, run that
            rematch.optionsPanel.funcs[self.info.func](self)
        end
        if self.info.update then -- if not and whole UI should be updated
            rematch.frame:Update()
        else -- otherwise just update options panel
            rematch.optionsPanel:Update()
        end
        PlaySound(C.SOUND_CHECKBUTTON)
    end
end

--[[ option funcs (to run when an option changes) ]]

rematch.optionsPanel.funcs = {}

function rematch.optionsPanel.funcs:CustomBattleUI()
    print(L["Rematch: Battle UI preference saved. Type /reload to apply the change."])
end


function rematch.optionsPanel.funcs:InteractOnTarget(value)
    if value~=C.INTERACT_NONE then
        settings.InteractOnSoftInteract = C.INTERACT_NONE
        settings.InteractOnMouseover = C.INTERACT_NONE
        rematch.optionsPanel:UpdateDropDown("InteractOnSoftInteract")
        rematch.optionsPanel:UpdateDropDown("InteractOnMouseover")
    end
    rematch.interact:Update()
end

function rematch.optionsPanel.funcs:InteractOnSoftInteract(value)
    if value~=C.INTERACT_NONE then
        settings.InteractOnTarget = C.INTERACT_NONE
        settings.InteractOnMouseover = C.INTERACT_NONE
        rematch.optionsPanel:UpdateDropDown("InteractOnTarget")
        rematch.optionsPanel:UpdateDropDown("InteractOnMouseover")
    end
    rematch.interact:Update()
end

function rematch.optionsPanel.funcs:InteractOnMouseover(value)
    if value~=C.INTERACT_NONE then
        settings.InteractOnTarget = C.INTERACT_NONE
        settings.InteractOnSoftInteract = C.INTERACT_NONE
        rematch.optionsPanel:UpdateDropDown("InteractOnTarget")
        rematch.optionsPanel:UpdateDropDown("InteractOnSoftInteract")
    end
    rematch.interact:Update()
end

function rematch.optionsPanel.funcs:Anchor(anchor)
    -- changing anchor while in journal mode (or while window is not on screen) messes up anchoring
    if rematch.journal:IsActive() then
        rematch.frame:Toggle() -- hide journal
        rematch.frame:Toggle() -- show standalone window
        if rematch.layout:GetMode()==0 then
            rematch.frame:ToggleMinimized()
        end
    end
    rematch.frame:ChangeAnchor(anchor)
    rematch.optionsPanel:UpdateDropDown("PanelTabAnchor")
end

function rematch.optionsPanel.funcs:PanelTabAnchor(anchor)
    if rematch.frame:IsVisible() and not rematch.journal:IsActive() then
        rematch.frame:Configure(C.CURRENT)
    end
end

-- when checking UseDefaultJournal while in the journal, turn off the journal (like bottombar's rematch checkbutton)
function rematch.optionsPanel.funcs:UseDefaultJournal()
    if settings.UseDefaultJournal and rematch.journal:IsActive() then
        rematch.frame:Hide()
        rematch.frame:SetParent(UIParent)
        PetJournal:Show()
        PetJournal_UpdatePetLoadOut() -- in case journal wasn't keeping up while rematch was doing stuff
    end
end

-- Standalone Window Options: Lower Window Behind UI; toggles the framestrata between LOW and MEDIUM
function rematch.optionsPanel.funcs:LowerStrata()
    if not rematch.journal:IsActive() then
        rematch.frame:SetFrameStrata(settings.LowerStrata and "LOW" or "MEDIUM")
    end
end

function rematch.optionsPanel.funcs:ConfigureToolbar()
    rematch.toolbar:Configure()
end

function rematch.optionsPanel.funcs:CompactPetList()
    rematch.petsPanel.List:SetCompactMode(settings.CompactPetList)
    rematch.petsPanel.List:Update()
end

function rematch.optionsPanel.funcs:CompactTeamList()
    rematch.teamsPanel.List:SetCompactMode(settings.CompactTeamList)
    rematch.teamsPanel.List:Update()
end

function rematch.optionsPanel.funcs:CompactTargetList()
    rematch.targetsPanel.List:SetCompactMode(settings.CompactTargetList)
    rematch.targetsPanel.List:Update()
end

function rematch.optionsPanel.funcs:CompactQueueList()
    rematch.queuePanel.List:SetCompactMode(settings.CompactQueueList)
    rematch.queuePanel.List:Update()
end

-- any option that can change the results of the filtered list (including sort) should run this if the option changes
function rematch.optionsPanel.funcs:UpdateFilters()
    rematch.filters:ForceUpdate() -- sets the dirty flag so the filtered list is rerun in the update
    rematch.petsPanel:Update()
end

-- Pet Filter Options: Allow Hidden Pets; turn off filter it was enabled
function rematch.optionsPanel.funcs:UpdateHiddenPetFilter()
    rematch.filters:Set("Other","Hidden",nil)
    rematch.menus:Hide() -- in case Other filter menu is up (hide the Hidden Pets filter)
    rematch.filters:ForceUpdate()
    rematch.petsPanel:Update()
end

-- any option that can change the pet card
function rematch.optionsPanel.funcs:UpdatePetCard()
    if rematch.petCard:IsVisible() then
        rematch.petCard:Update()
    end
end

-- Pet Card Options: Allow Pet Cards To Be Pinned; unpin it if option unchecked and snap card back to its relativeTo
function rematch.optionsPanel.funcs:UpdatePetCardPin()
    if rematch.petCard:IsVisible() and not rematch.cardManager:IsCardPinned(rematch.petCard) then
        rematch.cardManager:Unpin(rematch.petCard)
    end
end

-- Team Win Record Options: Display Total Wins Instead
function rematch.optionsPanel.funcs:AlternateWinRecord()
    for groupID,group in rematch.savedGroups:AllGroups() do
        if group.sortMode==C.GROUP_SORT_WINS then
            rematch.savedGroups:Sort(groupID)
        end
    end
end

-- Team Options: Always Show Team Tabs
function rematch.optionsPanel.funcs:AlwaysTeamTabs()
    settings.NeverTeamTabs = false
    rematch.teamTabs:Configure()
end

-- Team Options: Never Show Team Tabs
function rematch.optionsPanel.funcs:NeverTeamTabs()
    settings.AlwaysTeamTabs = false
    rematch.teamTabs:Configure()
end

function rematch.optionsPanel.funcs:ShowNewGroupTab()
    rematch.teamTabs:Update()
end

-- for any options that may change queue/behavior
function rematch.optionsPanel.funcs:ProcessQueue()
    rematch.queue:Process()
end

-- for changes to win record options to register/unregister monitoring battles
function rematch.optionsPanel.funcs:AutoWinRecord()
    rematch.winrecord:Update()
end

function rematch.optionsPanel.funcs:UseMinimapButton()
    rematch.minimap:Configure()
end

-- if ExportPetsDialog is open when changing ExportSimplePetList option, then switch to new list
function rematch.optionsPanel.funcs:ExportSimplePetList()
    if rematch.dialog:GetOpenDialog()=="ExportPetsDialog" then
        rematch.dialog.Canvas.CheckButton:SetChecked(settings.ExportSimplePetList)
        rematch.dialog.Canvas.MultiLineEditBox:SetText(rematch.petFilterMenu:GetPetExportData(),true)
    end
end

function rematch.optionsPanel.funcs:HideNotesButtonInBattle()
    rematch.battle.NotesButton:SetShown(not settings.HideNotesButtonInBattle)
end

function rematch.optionsPanel.funcs:NotesFont()
    rematch.notes:UpdateFont()
end

function rematch.optionsPanel.funcs:BreedSource(value)
    if value=="BattlePetBreedID" and settings.BreedFormat==C.BREED_FORMAT_ICONS then
        settings.BreedFormat = C.BREED_FORMAT_LETTERS -- if changing to BattlePetBreedID and format is icons, change format to letters
    end
    rematch.breedInfo:ResetBreedSource()
    rematch.optionsPanel:UpdateDropDown("BreedSource") -- in case ResetBreedSource asserts a different one
    rematch.optionsPanel:UpdateDropDown("BreedFormat")
    rematch.frame:Update()
end

function rematch.optionsPanel.funcs:BreedFormat(value)
    if value==C.BREED_FORMAT_ICONS and settings.BreedSource=="BattlePetBreedID" then
        settings.BreedSource = "PetTracker" -- if changing to Icons and source isn't PetTracker, change source to PetTracker
        rematch.breedInfo:ResetBreedSource()
    end
    rematch.optionsPanel:UpdateDropDown("BreedSource")
    rematch.optionsPanel:UpdateDropDown("BreedFormat")
    rematch.frame:Update()
end

function rematch.optionsPanel.funcs:MousewheelSpeed(speed)
    rematch.optionsPanel.List:SetSpeed(speed)
end

--[[ widget setups ]]


-- Enemy Ability Bar Options: apply changes immediately; no /reload required.
function rematch.optionsPanel.funcs:EnemyAbilityBar(value)
    if rematch.enemyAbilityBar then
        if rematch.enemyAbilityBar.ApplySettings then
            rematch.enemyAbilityBar:ApplySettings()
        else
            if rematch.enemyAbilityBar.ApplyLayout then
                rematch.enemyAbilityBar.ApplyLayout()
            end
            if rematch.enemyAbilityBar.Update then
                rematch.enemyAbilityBar.Update()
            end
        end
    end
end

rematch.optionsPanel.widgetSetup = {}

function rematch.optionsPanel.widgetSetup:UseCustomScaleWidget()
    self.tooltipTitle = L["Use Custom Scale"]
    self.tooltipBody = L["Adjust the relative size of the standalone Rematch window by changing its scale."]
    self.Text:SetText(L["Use Custom Scale"])
    self.ScaleButton.Text:SetFontObject(GameFontHighlight)
end

function rematch.optionsPanel.UseCustomScaleWidget:OnEnter()
    rematch.textureHighlight:Show(self.Check)
    rematch.tooltip:ShowSimpleTooltip(self,self.tooltipTitle,self.tooltipBody)
end

function rematch.optionsPanel.UseCustomScaleWidget:OnLeave()
    rematch.textureHighlight:Hide()
    rematch.tooltip:Hide()
end

function rematch.optionsPanel.UseCustomScaleWidget:OnMouseDown()
    rematch.textureHighlight:Hide()
end

function rematch.optionsPanel.UseCustomScaleWidget:OnMouseUp()
    if self:IsMouseMotionFocus() then
        rematch.textureHighlight:Show(self.Check)
    end
end

function rematch.optionsPanel.UseCustomScaleWidget:OnClick()
    settings.CustomScale = not settings.CustomScale
    rematch.frame:UpdateScale()
    rematch.optionsPanel:Update()
    PlaySound(C.SOUND_CHECKBUTTON)
end

function rematch.optionsPanel.UseCustomScaleWidget.ScaleButton:OnClick()
    rematch.dialog:ShowDialog("CustomScaleDialog")
end

function rematch.optionsPanel.widgetSetup:OptionsManagementWidget()
    self.Label:SetText(L["All Options:"])
    self.ResetButton:SetText(L["Reset"])
    self.ExportButton:SetText(L["Export"])
end

-- exports all non-default options in this format: var=value:var=value:etc=value:
-- settings that are tables are just the count of elements within the table
function rematch.optionsPanel.OptionsManagementWidget.ExportButton:OnClick()
    -- building a table so it can be sorted
    local results = {}
    for k,v in pairs(settings:GetDefaults()) do
        if type(v)=="table" then -- table contents aren't saved, just a count of its contents
            tinsert(results,k.."="..rematch.utils:GetSize(settings[k]))
        elseif v~=settings[k] then
            tinsert(results,k.."="..tostring(settings[k]))
        end
    end
    tinsert(results,"AllTeams="..rematch.utils:GetSize(rematch.savedTeams.AllTeams))
    tinsert(results,"Version="..(C_AddOns.GetAddOnMetadata("Rematch","Version") or ""))
    tinsert(results,"NumPets="..(rematch.roster:GetNumOwned() or ""))
    tinsert(results,"NumTeams="..(rematch.savedTeams:GetNumTeams() or ""))
    table.sort(results)

    rematch.dialog:ShowDialog("ExportOptions",table.concat(results,"\n"))
end

function rematch.optionsPanel.OptionsManagementWidget.ResetButton:OnClick()
    rematch.dialog:ShowDialog("ResetOptions")
end

--[[ widget updates ]]

rematch.optionsPanel.widgetUpdate = {}

function rematch.optionsPanel.widgetUpdate:UseCustomScaleWidget()
    local xoff = settings.CustomScale and 0.25 or 0
    self.Check:SetTexCoord(0+xoff,0.25+xoff,0.5,0.75)
    self.ScaleButton:SetShown(settings.CustomScale)
    self.ScaleButton:SetText(format("%d%%",settings.CustomScaleValue or 0))
end

-- resets all non-table options to default, sets non-table options in import to given values, then reloads the UI
-- this is used for troubleshooting to mimic another user's options that was exported from the Export button in options
function rematch.optionsPanel:ImportOptions(import)
    local defaults = settings:GetDefaults()
    -- wipe all number, boolean or string settings
    for var,value in pairs(defaults) do
        if type(value)=="number" or type(value)=="boolean" or type(value)=="string" then
            settings[var] = value
        end
    end
    for line in ((import or "").."\n"):gmatch("(.-)\n") do
        local var,value = line:match("([A-Za-z0-9_]+)=([A-Za-z0-9_%s]+)")
        if var and value then
            var=var:trim()
            value=value:trim()
            local default = settings[var]
            if default~=nil then
                if type(default)=="number" and tonumber(value) then
                    settings[var] = tonumber(value)
                elseif type(default)=="boolean" and (value=="true" or value=="false") then
                    settings[var] = value=="true"
                elseif type(default)=="string" and tostring(value) then
                    settings[var] = tostring(value)
                end
            end
        end
    end
    ReloadUI()
end
