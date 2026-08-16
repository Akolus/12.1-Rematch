local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.targetsPanel = rematch.frame.TargetsPanel
rematch.frame:Register("targetsPanel")

local targetList = {} -- ordered list of all headerIDs and teamIDs to display

rematch.events:Register(rematch.targetsPanel,"PLAYER_LOGIN",function(self)
    self.Top.SearchBox.Instructions:SetText(L["Search Targets"])
    -- setup autoScrollBox
    self.List:Setup({
        allData = targetList,
        normalTemplate = "RematchNormalTeamListButtonTemplate",
        normalFill = self.FillNormal,
        normalHeight = 44,
        compactTemplate = "RematchCompactTeamListButtonTemplate",
        compactFill = self.FillCompact,
        compactHeight = 26,
        isCompact = settings.CompactTargetList,
        headerTemplate = "RematchHeaderTeamListButtonTemplate",
        headerFill = self.FillHeader,
        headerCriteria = self.IsHeader,
        headerHeight = 26,
        placeholderTemplate = "RematchPlaceholderListButtonTemplate",
        placeholderFill = self.FillPlaceholder,
        placeholderCriteria = self.IsPlaceholder,
        placeholderHeight = 26,
        expandedHeaders = settings.ExpandedTargets,
        allButton = self.Top.AllButton,
        searchBox = self.Top.SearchBox,
        searchHit = self.SearchHit,
        onScroll = rematch.menus.Hide,
    })
end)

-- fills otable with recent targets and notable npcs, used for targetList here and dialog's TeamPicker)
function rematch.targetsPanel:PopulateTargetList(otable)
    -- if this list isn't populated yet, then fill it with headers and notable npcIDs (only recent targets ever change)
    local headerID
    if #otable==0 then
        tinsert(otable,"header:Recent Targets")
        tinsert(otable,"placeholder:0") -- only one placeholder ever in otable: "No recent targets"
        for _,info in ipairs(rematch.targetData.notableTargets) do
            if headerID~=info[1] then -- new header found
                tinsert(otable,"header:"..info[1])
                headerID = info[1]
            end
            tinsert(otable,"target:"..info[2])
        end
    end
    -- update recent targets without recreating whole list
    -- first remove previous recent targets
    local index = 2
    while not self:IsHeader(otable[index]) do
        index = index + 1 -- find the index of the header after recent targets
    end
    for i=index-1,2,-1 do
        tremove(otable,i) -- remove everything before the second header and after recent targets header
    end
    -- then add current recent targets
    local history = rematch.targetInfo:GetTargetHistory()
    if #history==0 then
        tinsert(otable,2,"placeholder:0")
    else
        for _,npcID in ipairs(history) do
            tinsert(otable,2,"target:"..npcID)
        end
    end
end

function rematch.targetsPanel:Update()
    self:PopulateTargetList(targetList)
    self.List:Update()
end

function rematch.targetsPanel:OnShow()
    rematch.events:Register(self,"REMATCH_TARGET_CHANGED",self.REMATCH_TARGET_CHANGED)
end

function rematch.targetsPanel:OnHide()
    rematch.events:Unregister(self,"REMATCH_TARGET_CHANGED")
end

function rematch.targetsPanel:REMATCH_TARGET_CHANGED()
    if UnitExists("target") then
        self:Update() -- recent targets has changed
    end
end

--[[ autoscrollbox functions ]]

function rematch.targetsPanel:FillNormal(targetID)
    self:Fill(targetID)
end

function rematch.targetsPanel:FillCompact(targetID)
    self:Fill(targetID)
end

function rematch.targetsPanel:FillHeader(headerID)
    self:Fill(headerID)
end

function rematch.targetsPanel:FillPlaceholder(placeholderID)
    self.Text:SetText(L["No recent targets"])
end

function rematch.targetsPanel:IsHeader(id)
    return type(id)=="string" and id:match("^header:") and true or false
end

function rematch.targetsPanel:IsPlaceholder(id)
    return type(id)=="string" and id:match("^placeholder:") and true or false
end

-- target search skips recent targets because if the player has less than 3 recents, selecting targets shifts stuff down
-- (if there's demand this can be an option to enable recent search hits)
local skipRecent = true
function rematch.targetsPanel:SearchHit(mask,data)
    if data=="header:Recent Targets" then
        skipRecent = true
    elseif rematch.targetsPanel:IsHeader(data) then
        skipRecent = false
        if rematch.utils:match(mask,rematch.targetInfo:GetHeaderName(data)) then -- only searching name if a header
            return true
        end
    elseif skipRecent then
        -- do nothing if skipping
    elseif not rematch.targetsPanel:IsPlaceholder(data) then
        local npcID = rematch.targetInfo:GetNpcID(data)
        if rematch.utils:match(mask,rematch.targetInfo:GetNpcName(npcID)) then
            return true
        elseif rematch.utils:match(mask,rematch.targetInfo:GetQuestName(npcID)) then
            return true
        end
        -- search for pets that contain the name
        local pets = rematch.targetInfo:GetNpcPets(npcID)
        for _,petID in ipairs(pets) do
            local petInfo = rematch.petInfo:Fetch(petID)
            if rematch.utils:match(mask,petInfo.name) then
                return true
            end
        end
        -- search for team names
        if rematch.savedTargets[npcID] then
            for _,teamID in ipairs(rematch.savedTargets[npcID]) do
                local team = rematch.savedTeams[teamID]
                if rematch.utils:match(mask,team.name) then
                    return true
                end
            end
        end
    end
    return false -- if reached here, not a search hit
end

--[[ list button script handlers ]]

function rematch.targetsPanel.List:HeaderOnClick(button)
    if button~="RightButton" then
        rematch.targetsPanel.List:ToggleHeader(self.headerID)
        PlaySound(C.SOUND_HEADER_CLICK)
    end
end

-- click of target list button
function rematch.targetsPanel.List:TeamOnClick(button)
    if button=="RightButton" and not self.noPickup then -- if right-clicking a target, show menu
        rematch.dialog:Hide()
        rematch.menus:Show("TargetMenu",self,self.targetID,"cursor")
    else
        local npcID = rematch.targetInfo:GetNpcID(self.targetID)
        if npcID then
            rematch.loadedTargetPanel:SetTarget(npcID,true)
            PlaySound(C.SOUND_TEAM_LOAD)
        end
    end
end