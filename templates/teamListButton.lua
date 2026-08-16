local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings

--[[
    Teams and Target list buttons are so similar, they're both going to use the same template.
]]

--[[ RematchHeaderTeamListButtonMixin for both group:id and header:id ]]

RematchHeaderTeamListButtonMixin = {}

--[[ these script handlers will also call autoscrollbox:HeaderOnEnter/OnLeave/etc if one is defined ]]

function RematchHeaderTeamListButtonMixin:OnEnter()
    local list = self:GetParent():GetParent():GetParent()
    if not list:IsHeadersLocked() then
        rematch.textureHighlight:Show(self.Back,self.ExpandIcon)
    end
    if list.HeaderOnEnter then
        list.HeaderOnEnter(self)
    end
end

function RematchHeaderTeamListButtonMixin:OnLeave()
    local list = self:GetParent():GetParent():GetParent()
    rematch.textureHighlight:Hide()
    if list.HeaderOnLeave then
        list.HeaderOnLeave(self)
    end
end

function RematchHeaderTeamListButtonMixin:OnMouseDown()
    local list = self:GetParent():GetParent():GetParent()
    rematch.textureHighlight:Hide()
    if list.HeaderOnMouseDown then
        list.HeaderOnMouseDown(self)
    end
end

function RematchHeaderTeamListButtonMixin:OnMouseUp()
    local list = self:GetParent():GetParent():GetParent()
    if self:IsMouseMotionFocus() and not list:IsHeadersLocked() then
        rematch.textureHighlight:Show(self.Back,self.ExpandIcon)
    end
    if list.HeaderOnMouseUp then
        list.HeaderOnMouseUp(self)
    end
end

function RematchHeaderTeamListButtonMixin:OnClick(button)
    local list = self:GetParent():GetParent():GetParent()
    if list.HeaderOnClick then
        list.HeaderOnClick(self,button)
    end
end

function RematchHeaderTeamListButtonMixin:OnDragStart()
    local list = self:GetParent():GetParent():GetParent()
    if list.HeaderOnDragStart then
        list.HeaderOnDragStart(self)
    end
end

-- fill for both group and target headers
function RematchHeaderTeamListButtonMixin:Fill(id)
    local idType = rematch.utils:GetIDType(id)
    if idType=="group" then -- group:id is for group headers
        self:FillGroup(id)
    elseif idType=="header" then -- header:id is for target headers
        self:FillHeader(id)
    end
end

-- fills a team group header
function RematchHeaderTeamListButtonMixin:FillGroup(groupID)
    self.groupID = groupID
    self.headerID = nil
    self:SetBack() -- from RematchHeaderListButtonMixin (normal or wide back depending on mode)

    local group = groupID and rematch.savedGroups[groupID]
    if not group then
        return
    end
    if self.ExpandIcon then --
        local list = self:GetParent():GetParent():GetParent() -- the autoscrollframe this belongs to
        self:SetExpanded(list:IsHeaderExpanded(self.groupID),list:IsSearching() or list:IsHeadersLocked())
    end
    self.Text:SetText(rematch.utils:GetFormattedGroupName(groupID))

    local xoff = -4

    if group.icon then
        self.Icon:SetTexture(group.icon)
        self.Icon:Show()
        self.Border:Show()
        xoff = xoff - 18 - 1
    else
        self.Icon:Hide()
        self.Border:Hide()
    end

    -- place badges (just preferences for now)
    local badgesWidth = rematch.badges:AddBadges(self.Badges,"groups",groupID,"RIGHT",self.Icon,"LEFT",-2,0,-1)
    xoff = xoff - badgesWidth

    self.Text:SetPoint("BOTTOMRIGHT",xoff,2)
end

-- fills a target header
function RematchHeaderTeamListButtonMixin:FillHeader(headerID)
    self.headerID = headerID
    self.groupID = nil
    self:SetBack()
    local list = self:GetParent():GetParent():GetParent() -- the autoscrollframe this belongs to
    self:SetExpanded(list:IsHeaderExpanded(self.headerID),list:IsSearching() or list:IsHeadersLocked())
    self.Text:SetText(rematch.utils:GetFormattedHeaderName(headerID))
    rematch.badges:ClearBadges(self.Badges) -- target headers don't have badges for now
    self.Icon:Hide()
    self.Border:Hide()
end

--[[ RematchCommonTeamListButtonMixin for both Normal and Compact team:id and target:id ]]

RematchCommonTeamListButtonMixin = {}

function RematchCommonTeamListButtonMixin:OnEnter()
    local list = self:GetParent():GetParent():GetParent()
    rematch.textureHighlight:Show(self.Back)
    if list.TeamOnEnter then
        list.TeamOnEnter(self)
    end
    -- if team herder is up, then we're targeting a team to move
    if rematch.dialog:GetOpenLayout()=="Herding" then
        SetCursor("Interface\\Cursor\\Crosshairs")
    end
    if not settings.HideTruncatedTooltips and self.Name:IsTruncated() then
        rematch.tooltip:ShowSimpleTooltip(self,nil,self.Name:GetText() or "","BOTTOM",self.Name,"TOP",0,5,true)
    end
end

function RematchCommonTeamListButtonMixin:OnLeave()
    local list = self:GetParent():GetParent():GetParent()
    rematch.textureHighlight:Hide()
    if list.TeamOnLeave then
        list.TeamOnLeave(self)
    end
    SetCursor(nil)
    rematch.tooltip:Hide()
end

function RematchCommonTeamListButtonMixin:OnMouseDown()
    local list = self:GetParent():GetParent():GetParent()
    rematch.textureHighlight:Hide()
    if list.TeamOnMouseDown then
        list.TeamOnMouseDown(self)
    end
end

function RematchCommonTeamListButtonMixin:OnMouseUp()
    local list = self:GetParent():GetParent():GetParent()
    if self:IsMouseMotionFocus() then
        rematch.textureHighlight:Show(self.Back)
    end
    if list.TeamOnMouseUp then
        list.TeamOnMouseUp(self)
    end
end

function RematchCommonTeamListButtonMixin:OnClick(button)
    -- if team herder is up, then clicking a team will move it
    if rematch.dialog:GetOpenLayout()=="Herding" then
        rematch.dragFrame:ReceiveTeamToGroup(self.teamID,settings.LastSelectedGroup,true)
        return
    end
    local list = self:GetParent():GetParent():GetParent()
    if list.TeamOnClick then
        list.TeamOnClick(self,button)
    end
end

function RematchCommonTeamListButtonMixin:OnDragStart()
    local list = self:GetParent():GetParent():GetParent()
    if list.TeamOnDragStart then
        list.TeamOnDragStart(self)
    end
end

--[[ Normal team list button mixin ]]

RematchNormalTeamListButtonMixin = {}

function RematchNormalTeamListButtonMixin:Fill(id)
    local idType = rematch.utils:GetIDType(id)
    if idType=="team" and rematch.savedTeams[id] then -- team:id is for teams
        self:FillTeam(id)
    elseif idType=="target" then -- target:id is for targets
        self:FillTarget(id)
    end
end

-- fills a team list button with the teamID
function RematchNormalTeamListButtonMixin:FillTeam(teamID)
    local left = 0
    local right = -C.TEAM_LIST_RIGHT_PADDING
    local row1Right = right -- will be extent of notes/badges
    local row2Right = right -- will be extent of wins
    -- assigning teamID to the button
    self.targetID = nil
    local team = rematch.savedTeams[teamID]
    if not team then
        self.teamID = nil
        return -- not a valid team to fill, leave
    else
        self.teamID = teamID
    end
    -- if any pets need fixed, this will rebuild the team and delayed update
    rematch.rebuild:ValidateTeamID(teamID)
    -- teams always have three pets shown on the left
    self.Border:ClearAllPoints()
    self.Border:SetPoint("LEFT")
    local coords = C.PET_BORDER_TEXCOORDS[C.TEAM_SIZE_NORMAL][3]
    self.Border:SetTexCoord(coords[1],coords[2],coords[3],coords[4])
    self.Border:SetWidth(coords[5])
    self.Border:Show()
    for i=1,3 do
        local petInfo = rematch.petInfo:Fetch(team.pets[i])
        self.Pets[i]:ClearAllPoints()
        self.Pets[i]:SetPoint("TOPLEFT",(i-1)*29+2,-2)
        self.Pets[i].petID = team.pets[i]
        self.Pets[i]:SetTexture(petInfo.icon)
        self.Pets[i]:SetDesaturated(petInfo.idType=="species" or not petInfo.isValid)
        self.Pets[i]:Show()
    end
    left = left + coords[5] + 1
    self.Back:SetPoint("TOPLEFT",left,-1)
    self.Back:SetPoint("BOTTOMRIGHT")
    -- favorite never moves nor affects position of other stuff
    self.Favorite:SetShown(team.favorite and true or false)
    -- notes
    if not settings.HideNotesBadges and team.notes then
        self.NotesButton:SetPoint("RIGHT",row1Right,0)
        self.NotesButton:Show()
        row1Right = row1Right - 21
    else
        self.NotesButton:Hide()
    end
    -- badges
    local badgesWidth = rematch.badges:AddBadges(self.Badges,"teams",teamID,"TOPRIGHT",self,"TOPRIGHT",row1Right,-8,-1)
    row1Right = row1Right - badgesWidth
    -- win record never moves but if does it may affect position on right
    if settings.HideWinRecord or not team.winrecord or (team.winrecord.battles or 0)==0 then
        self.Wins:Hide()
    else
        local percent = floor(0.5+(team.winrecord.wins or 0)*100/(team.winrecord.battles or 0.1))
        self.Wins:SetText(settings.AlternateWinRecord and format("%d-%d",(team.winrecord.wins or 0),(team.winrecord.losses or 0)) or format("%d%%",percent))
        if percent >= 60 then
            self.Wins:SetTextColor(0.25,0.75,0.25)
        elseif percent <= 40 then
            self.Wins:SetTextColor(1,0.25,0.25)
        else
            self.Wins:SetTextColor(1,0.82,0)
        end
        self.Wins:Show()
        row2Right = row2Right - self.Wins:GetStringWidth() - 2
    end
    -- at this point, all rightmost matter placed, right is now the min of the two (they're both negative)
    right = min(row1Right,row2Right) - 1 -- minus 1 for text padding on right
    left = left + 4 -- plus 4 for text padding on left
    local name = rematch.utils:GetFormattedTeamName(teamID)
    local subName = team.targets and team.targets[1] and rematch.targetInfo:GetNpcName(team.targets[1])
    if subName and (subName==team.name or subName==C.CACHE_RETRIEVING)then
        subName = nil -- target name is same as team name (or Retrieving data..), can drop target name
    end
    self:FillNames(name,subName,left,right)

end

-- fills a team list button with the targetID
function RematchNormalTeamListButtonMixin:FillTarget(targetID)
    local left = C.TEAM_LIST_LEFT_PADDING
    local right = 0
    local npcID = rematch.targetInfo:GetNpcID(targetID) -- convert targetID to a numeric npcID
    local pets = rematch.targetInfo:GetNpcPets(npcID)
    local numPets = max(1,rematch.targetInfo:GetNumPets(npcID)) -- GetNpcPets will always be 1 for unnotable, here we don't care about actual count
    -- assigning targetID to the button
    self.targetID = targetID
    self.teamID = nil
    -- targets have 0-3 pets and display to the right
    self.Border:ClearAllPoints()
    self.Border:SetPoint("RIGHT")
    local coords = C.PET_BORDER_TEXCOORDS[C.TEAM_SIZE_NORMAL][numPets]
    if coords then
        self.Border:SetTexCoord(coords[1],coords[2],coords[3],coords[4])
        self.Border:SetWidth(coords[5])
        self.Border:Show()
        for i=1,numPets do
            local petInfo = rematch.petInfo:Fetch(pets[i])
            self.Pets[i]:ClearAllPoints()
            self.Pets[i]:SetPoint("TOPRIGHT",-(numPets-i)*29-2,-2) -- numPets-i to place them in 123 order while right-justified
            self.Pets[i].petID = pets[i]
            self.Pets[i]:SetTexture(petInfo.icon)
            if petInfo.idType=="unnotable" then -- use portrait instead of icon for unnotable npcs
                local displayID = rematch.targetInfo:GetNpcDisplayID(npcID)
                if displayID then
                    SetPortraitTextureFromCreatureDisplayID(self.Pets[i],displayID)
                end
            end
            self.Pets[i]:Show()
        end
        for i=numPets+1,3 do
            self.Pets[i]:Hide()
        end
        right = right - coords[5] - 1
    else
        self.Border:Hide()
        for i=1,3 do
            self.Pets[i]:Hide()
        end
    end
    self.Back:SetPoint("TOPLEFT",0,-1)
    self.Back:SetPoint("BOTTOMRIGHT",right,0)
    local badgesWidth = rematch.badges:AddBadges(self.Badges,"targets",npcID,"TOPRIGHT",self,"TOPRIGHT",right,-8,-1)
    right = right - badgesWidth
    local name = rematch.utils:GetFormattedTargetName(targetID)
    local subName = rematch.targetInfo:GetQuestName(npcID)
    if subName and (subName==rematch.targetInfo:GetNpcName(npcID) or subName==C.CACHE_RETRIEVING) then
        subName = nil
    end
    self:FillNames(name,subName,left,right)

    -- this stuff never shown on targets (but may have been shown previously if button was used for a team)
    self.Favorite:Hide()
    self.NotesButton:Hide()
    self.Wins:Hide()
end

-- sets and positions names for both teams and targets
function RematchNormalTeamListButtonMixin:FillNames(name,subName,left,right)
    self.Name:SetHeight(0) -- unbounded height initially
    self.Name:SetPoint("TOPLEFT",left,0) -- need to anchor left/right for wrap height without knowing veritical position yet
    self.Name:SetPoint("TOPRIGHT",right,0)
    self.SubName:Hide()

    self.Name:SetText(name)

    local nameHeight = self.Name:GetStringHeight()
    local subNameHeight = 0

    -- if name is too tall for the button, set name height (not using clipChildren because I prefer the ... to make it clear it's truncated)
    if nameHeight > C.LIST_BUTTON_NORMAL_HEIGHT then
        self.Name:SetHeight(C.LIST_BUTTON_NORMAL_HEIGHT)
    else -- name is not too tall, see if room for subname
        if subName then
            self.SubName:SetHeight(0) -- unbounded to allow to wrap
            self.SubName:SetText(subName)
            subNameHeight = self.SubName:GetStringHeight()
            if nameHeight+subNameHeight+1 <= C.LIST_BUTTON_NORMAL_HEIGHT then -- if there's room to show subname, show it
                self.SubName:Show()
                nameHeight = nameHeight+subNameHeight+1
            elseif nameHeight+12+1 <= C.LIST_BUTTON_NORMAL_HEIGHT then -- otherwise if room to show subname if it's at 12px height, show it
                self.SubName:SetHeight(12)
                self.SubName:Show()
                nameHeight = nameHeight+12+1
            end
        end
        -- center name(s) vertically (if height bounded for normal name, it's already anchored at 0 yoffset)
        self.Name:SetPoint("TOPLEFT",left,-((44-nameHeight)/2))
        self.Name:SetPoint("TOPRIGHT",right,-((44-nameHeight)/2))
    end
end

RematchCompactTeamListButtonMixin = {}

function RematchCompactTeamListButtonMixin:Fill(id)
    local idType = rematch.utils:GetIDType(id)
    if idType=="team" and rematch.savedTeams[id] then -- team:id is for teams
        self:FillTeam(id)
    elseif idType=="target" then -- target:id is for targets
        self:FillTarget(id)
    end
end

function RematchCompactTeamListButtonMixin:FillTeam(teamID)
    local left = 0
    local right = -C.TEAM_LIST_RIGHT_PADDING
    -- assigning teamID to the button
    self.targetID = nil
    local team = rematch.savedTeams[teamID]
    if not team then
        self.teamID = nil
        return -- not a valid team to fill, leave
    else
        self.teamID = teamID
    end
    -- if any pets need fixed, this will rebuild the team and delayed update
    rematch.rebuild:ValidateTeamID(teamID)
    -- teams always have three pets shown on the left
    self.Border:ClearAllPoints()
    self.Border:SetPoint("LEFT")
    local coords = C.PET_BORDER_TEXCOORDS[C.TEAM_SIZE_COMPACT][3]
    self.Border:SetTexCoord(coords[1],coords[2],coords[3],coords[4])
    self.Border:SetWidth(coords[5])
    self.Border:Show()
    for i=1,3 do
        local petInfo = rematch.petInfo:Fetch(team.pets[i])
        self.Pets[i]:ClearAllPoints()
        self.Pets[i]:SetPoint("LEFT",(i-1)*23+2,0)
        self.Pets[i].petID = team.pets[i]
        self.Pets[i]:SetTexture(petInfo.icon)
        self.Pets[i]:SetDesaturated(petInfo.idType=="species" or not petInfo.isValid)
        self.Pets[i]:Show()
    end
    left = left + coords[5] + 1
    self.Back:SetPoint("TOPLEFT",left,-1)
    self.Back:SetPoint("BOTTOMRIGHT")
    -- favorite never moves nor affects position of other stuff
    self.Favorite:SetShown(team.favorite and true or false)
    -- win record never moves if it's shown
    if settings.HideWinRecord or not team.winrecord or (team.winrecord.battles or 0)==0 then
        self.Wins:Hide()
    else
        local percent = floor(0.5+(team.winrecord.wins or 0)*100/(team.winrecord.battles or 0.1))
        self.Wins:SetText(settings.AlternateWinRecord and format("%d-%d",(team.winrecord.wins or 0),(team.winrecord.losses or 0)) or format("%d%%",percent))
        if percent >= 60 then
            self.Wins:SetTextColor(0.25,0.75,0.25)
        elseif percent <= 40 then
            self.Wins:SetTextColor(1,0.25,0.25)
        else
            self.Wins:SetTextColor(1,0.82,0)
        end
        self.Wins:Show()
        right = right - self.Wins:GetStringWidth() - 1
    end
    -- notes
    if not settings.HideNotesBadges and team.notes then
        self.NotesButton:SetPoint("RIGHT",right,0)
        self.NotesButton:Show()
        right = right - 21
    else
        self.NotesButton:Hide()
    end
    -- badges
    local badgesWidth = rematch.badges:AddBadges(self.Badges,"teams",teamID,"RIGHT",self,"RIGHT",right,0,-1)
    right = right - badgesWidth
    -- at this point, all rightmost matter placed, right is now the min of the two (they're both negative)
    left = left + 4 -- plus 4 for text padding on left
    -- name
    self.Name:SetPoint("LEFT",left,0)
    self.Name:SetPoint("RIGHT",right,0)
    self.Name:SetText(rematch.utils:GetFormattedTeamName(teamID))
end

function RematchCompactTeamListButtonMixin:FillTarget(targetID)
    local left = C.TEAM_LIST_LEFT_PADDING
    local right = 0
    local npcID = rematch.targetInfo:GetNpcID(targetID) -- convert targetID to a numeric npcID
    local pets = rematch.targetInfo:GetNpcPets(npcID)
    local numPets = max(1,rematch.targetInfo:GetNumPets(npcID)) -- GetNpcPets will always be 1 for unnotable, here we don't care about actual count
    -- assigning targetID to the button
    self.targetID = targetID
    self.teamID = nil
    -- targets have 0-3 pets and display to the right
    self.Border:ClearAllPoints()
    self.Border:SetPoint("RIGHT")
    local coords = C.PET_BORDER_TEXCOORDS[C.TEAM_SIZE_COMPACT][numPets]
    if coords then
        self.Border:SetTexCoord(coords[1],coords[2],coords[3],coords[4])
        self.Border:SetWidth(coords[5])
        self.Border:Show()
        for i=1,numPets do
            local petInfo = rematch.petInfo:Fetch(pets[i])
            self.Pets[i]:ClearAllPoints()
            self.Pets[i]:SetPoint("RIGHT",-(numPets-i)*23-2,0) -- numPets-i to place them in 123 order while right-justified
            self.Pets[i].petID = pets[i]
            self.Pets[i]:SetTexture(petInfo.icon)
            if petInfo.idType=="unnotable" then -- use portrait instead of icon for unnotable npcs
                local displayID = rematch.targetInfo:GetNpcDisplayID(npcID)
                if displayID then
                    SetPortraitTextureFromCreatureDisplayID(self.Pets[i],displayID)
                end
            end
            self.Pets[i]:Show()
        end
        for i=numPets+1,3 do
            self.Pets[i]:Hide()
        end
        right = right - coords[5] - 1
    else
        self.Border:Hide()
        for i=1,3 do
            self.Pets[i]:Hide()
        end
    end
    self.Back:SetPoint("TOPLEFT",0,-1)
    self.Back:SetPoint("BOTTOMRIGHT",right,0)
    local badgesWidth = rematch.badges:AddBadges(self.Badges,"targets",npcID,"RIGHT",self,"RIGHT",right,0,-1)
    right = right - badgesWidth
    -- name
    self.Name:SetPoint("LEFT",left,0)
    self.Name:SetPoint("RIGHT",right,0)
    self.Name:SetText(rematch.utils:GetFormattedTargetName(targetID))
    -- this stuff never shown on targets (but may have been shown previously if button was used for a team)
    self.Favorite:Hide()
    self.NotesButton:Hide()
    self.Wins:Hide()
end

--[[ RematchTeamListPetButtonMixin ]]

RematchTeamListPetButtonMixin = {}

function RematchTeamListPetButtonMixin:OnEnter()
    rematch.textureHighlight:Show(self,self:GetParent().Back)
    rematch.cardManager:OnEnter(rematch.petCard,self:GetParent(),self.petID) -- anchor to parent
end

function RematchTeamListPetButtonMixin:OnLeave()
    rematch.textureHighlight:Hide()
    rematch.cardManager:OnLeave(rematch.petCard,self:GetParent(),self.petID)
end

function RematchTeamListPetButtonMixin:OnMouseDown()
    rematch.textureHighlight:Hide()
end

function RematchTeamListPetButtonMixin:OnMouseUp()
    if self:IsMouseMotionFocus() then
        rematch.textureHighlight:Show(self,self:GetParent().Back)
        rematch.cardManager:OnClick(rematch.petCard,self:GetParent(),self.petID)
    end
end
