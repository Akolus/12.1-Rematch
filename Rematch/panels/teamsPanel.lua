local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.teamsPanel = rematch.frame.TeamsPanel
rematch.frame:Register("teamsPanel")

local teamList = {} -- ordered list of all groupIDs and teamIDs to display

rematch.events:Register(rematch.teamsPanel,"PLAYER_LOGIN",function(self)
    self.Top.SearchBox.Instructions:SetText(L["Search Teams"])
    self.Top.TeamsButton:SetText(L["Teams"])

    -- setup autoScrollBox
    self.List:Setup({
        allData = teamList,
        normalTemplate = "RematchNormalTeamListButtonTemplate",
        normalFill = self.FillNormal,
        normalHeight = 44,
        compactTemplate = "RematchCompactTeamListButtonTemplate",
        compactFill = self.FillCompact,
        compactHeight = 26,
        isCompact = settings.CompactTeamList,
        headerTemplate = "RematchHeaderTeamListButtonTemplate",
        headerFill = self.FillHeader,
        headerCriteria = self.IsHeader,
        headerHeight = 26,
        placeholderTemplate = "RematchPlaceholderListButtonTemplate",
        placeholderFill = self.FillPlaceholder,
        placeholderCriteria = self.IsPlaceholder,
        placeholderHeight = 26,
        selects = {
            Loaded = {color={1,0.82,0}, parentKey="Back", padding=0, drawLayer="ARTWORK"},
            Moving = {color={0,0,0,0.65}, tint=true, drawLayer="ARTWORK"}
        },
        expandedHeaders = settings.ExpandedGroups,
        allButton = self.Top.AllButton,
        searchBox = self.Top.SearchBox,
        searchHit = self.SearchHit,
        onScroll = rematch.menus.Hide,
    })

    -- after autoscrollbox setup, hook OnTextChanged to set color if a direct petID being searched
    self.Top.SearchBox:HookScript("OnTextChanged",function(self)
        local text = self:GetText()
        if text and text:match(C.PET_ID_PATTERN) then
            self:SetTextColor(0.5,0.5,0.5) -- searching BattlePet-0-etc; color grey
        else
            self:SetTextColor(1,1,1) -- otherwise set to standard white
        end
    end)

    -- set receive script for autoScrollBox's CaptureButton
    self.List.CaptureButton:SetScript("OnClick",function(self) rematch.dragFrame:HandleReceiveDrag(self) end)

end)

-- wipes and fills the given table with an ordered list of all IDs (used for teamList here and also dialog's TeamPicker)
function rematch.teamsPanel:PopulateTeamList(otable)
    wipe(otable)
    for _,groupID in ipairs(settings.GroupOrder) do
        tinsert(otable,groupID)
        local group = rematch.savedGroups[groupID]
        if group then
            if #group.teams>0 then
                for _,teamID in ipairs(group.teams) do
                    tinsert(otable,teamID)
                end
            else -- if group has no teams, add a placeholder
                tinsert(otable,"placeholder:"..group.groupID)
            end
        end
    end
end

function rematch.teamsPanel:Update()
    rematch.teamsPanel:PopulateTeamList(teamList)
    self.List:Select("Loaded",settings.currentTeamID,true)
    self.List:Update()
end

-- for updating the list visuals (such as loaded team changing) without any data changing
function rematch.teamsPanel:Refresh()
    --self.List:Select("Loaded",C_PetJournal.GetSummonedPetGUID(),true)
    self.List:Refresh()
end

function rematch.teamsPanel:OnShow()
    if self.List.needsRefresh then
        self.List:Refresh()
        self.List.needsRefresh = nil
    end
    rematch.events:Register(self,"REMATCH_TEAM_LOADED",self.SelectLoadedTeam)
end

function rematch.teamsPanel:OnHide()
    rematch.events:Unregister(self,"REMATCH_TEAM_LOADED")
end

function rematch.teamsPanel:SelectLoadedTeam()
    self.List:Select("Loaded",settings.currentTeamID)
end

-- click of the Teams button at top of panel
function rematch.teamsPanel.Top.TeamsButton:OnClick()
    rematch.dialog:HideDialog()
    rematch.menus:Toggle("TeamsButtonMenu",self)
end

--[[ autoscrollbox functions ]]

function rematch.teamsPanel:FillHeader(id)
    self:Fill(id)
end

function rematch.teamsPanel:FillPlaceholder(id)
    if id=="placeholder:group:favorites" then
        self.Text:SetText(L["No favorite teams"])
    elseif id=="placeholder:group:none" then
        self.Text:SetText(L["No ungrouped teams"])
    else
        self.Text:SetText(L["No teams in this group"])
    end
end

function rematch.teamsPanel:FillNormal(id)
    self:Fill(id)
end

function rematch.teamsPanel:FillCompact(id)
    self:Fill(id)
end

function rematch.teamsPanel:IsHeader(id)
    return type(id)=="string" and id:match("^group:") and true or false
end

function rematch.teamsPanel:IsPlaceholder(id)
    return type(id)=="string" and id:match("^placeholder:") and true or false
end

-- returns true if data matches the search mask
function rematch.teamsPanel:SearchHit(mask,data)
    if rematch.savedGroups[data] then
        return rematch.utils:match(mask,rematch.savedGroups[data].name)
    else
        local team = rematch.savedTeams[data]
        if team then
            -- we're searching for a specific petID (BattlePet-0-000000000000)
            if mask:match(C.PET_ID_PATTERN) then
                for i=1,3 do
                    if team.pets[i]==mask then
                        return true
                    end
                end
                return false -- didn't find the pet in this team, leave immediately
            end
            -- check if team name matches
            if rematch.utils:match(mask,team.name) then
                return true
            end
            -- check if any pet name matches
            for i=1,3 do
                local petInfo = rematch.petInfo:Fetch(team.pets[i])
                if petInfo.customName and rematch.utils:match(mask,petInfo.customName) then
                    return true
                end
                if petInfo.speciesName then
                    if rematch.utils:match(mask,petInfo.speciesName) then
                        return true
                    end
                else -- species name wasn't found, this is an invalid pet, possibly caged (if a search it, fill will rebuild it)
                    local speciesID = rematch.petTags:GetSpecies(team.tags[i])
                    petInfo = rematch.petInfo:Fetch(speciesID)
                    if petInfo.speciesName and rematch.utils:match(mask,petInfo.speciesName) then
                        return true
                    end
                end
            end
            -- check if any target name matches
            if team.targets then
                for _,targetID in ipairs(team.targets) do
                    local name = rematch.targetInfo:GetNpcName(targetID,true)
                    if rematch.utils:match(mask,name) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

--[[ listbutton script handlers (called from teamListButton.lua mixins) ]]

-- click of group header
function rematch.teamsPanel.List:HeaderOnClick(button)
    if rematch.dragFrame:HandleReceiveDrag(self,button) then
        return -- something was on cursor and was handled
    elseif button=="RightButton" and not self.noPickup then -- if right-clicking a group, show menu
        rematch.dialog:Hide()
        rematch.menus:Show("GroupMenu",self,self.groupID,"cursor")
    else -- otherwise toggle group
        rematch.teamsPanel.List:ToggleHeader(self.groupID)
        PlaySound(C.SOUND_HEADER_CLICK)
    end
end

-- dragging from a group header
function rematch.teamsPanel.List:HeaderOnDragStart()
    if self.groupID and settings.EnableDrag and not self.noPickup then
        rematch.dragFrame:PickupGroup(self.groupID,true)
    end
end

-- click of team list button
function rematch.teamsPanel.List:TeamOnClick(button)
    if rematch.dragFrame:HandleReceiveDrag(self,button) then
        return -- something was on cursor and handled
    elseif button=="RightButton" and not self.noPickup then -- if right-clicking a team, show menu
        rematch.dialog:Hide()
        rematch.menus:Show("TeamMenu",self,self.teamID,"cursor")
    else -- left-click of team loads it
        rematch.loadTeam:LoadTeamID(self.teamID)
        PlaySound(C.SOUND_TEAM_LOAD)
    end
end

-- dragging from a team list button
function rematch.teamsPanel.List:TeamOnDragStart()
    if self.teamID and settings.EnableDrag and not self.noPickup then
        rematch.dragFrame:PickupTeam(self.teamID,true)
    end
end

-- for programmatically setting search, to handle instructions properly
function rematch.teamsPanel:SetSearch(text)
    text = (text or ""):trim()
    self.Top.SearchBox:SetFocus(true)
    self.Top.SearchBox:SetText(text)
    self.Top.SearchBox:ClearFocus()
end
