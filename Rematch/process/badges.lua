local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.badges = {}

--[[
    Badges are small non-interactive icons placed to the right of list buttons to show if
    the pet is leveling, in a team, etc; or a team has a target, has preferences, etc;
    or any purpose.

    There are four lists:
        "pets"    : pets in the pet list, queue or loadouts
        "teams"   : teams in the team list
        "targets" : targets in the target list (id is npcID)
        "groups"  : team group headers

    To register a badge (within this addon and outside it), use:
    
    Rematch.badges:RegisterBadge(list,name,icon,coords,callback)

        list (string) is one of the above four lists (can be anything but Rematch only adds badges for these)
        name (string) is a unique-per-list identifier for the badge
        icon (string,number,function) is the icon of the badge; if a function it should return a string/number icon
        coords (table,function) is the texcoords of the badge; if a function it should return texcoords
        callback (function) is a function that returns true if the given id's list/name badge should be shown
]]

-- indexed by list ("pets", "teams", "targets"), an ordered list of badge info for the list
local badges = {}

rematch.events:Register(rematch.badges,"PLAYER_LOGIN",function(self)

    --[[ pets: badges for pet lists (queue too) ]]

    -- leveling: whether pet is leveling
    self:RegisterBadge("pets","leveling","Interface\\AddOns\\Rematch\\textures\\badges-borderless",{0.375,0.5,0.125,0.25},
        function(self,petID) -- callback
            return not self.forQueue and (not settings.HideLevelingBadges or rematch.petHerder:GetActionID()=="leveling") and rematch.petInfo:Fetch(petID).isLeveling
        end
    )
    -- team: whether pet is in a team
    self:RegisterBadge("pets","team","Interface\\AddOns\\Rematch\\textures\\badges-borderless",{0.5,0.625,0.125,0.25},
        function(self,petID) -- callback
            return not settings.HideTeamBadges and rematch.petInfo.inTeams
        end
    )
    -- marker: pet tag for the pet
    self:RegisterBadge("pets","marker","Interface\\AddOns\\Rematch\\textures\\badges-borderless",
        function(self,petID) -- coords
            local marker = rematch.petInfo:Fetch(petID).marker
            if marker and marker>=1 and marker<=8 then
                return (marker-1)*0.125,marker*0.125,0.25,0.375
            end
        end,
        function(self,petID) -- callback
            local actionID = rematch.petHerder:GetActionID()
            return (not settings.HideMarkerBadges or (actionID and actionID:match("marker"))) and rematch.petInfo:Fetch(petID).marker
        end
    )
    -- new: whether pet is new/wrapped (sorted to top of list)
    self:RegisterBadge("pets","new","Interface\\AddOns\\Rematch\\textures\\badges-borderless",{0.625,0.75,0.75,0.875},
        function(self,petID) -- callback
            return rematch.petInfo:Fetch(petID).isStickied
        end
    )

    -- cage: whether pet can be caged (only shown while pet harder up with "cage" actionID)
    self:RegisterBadge("pets","cage","Interface\\AddOns\\Rematch\\textures\\badges-borderless",{0.875,1,0.75,0.875},
        function(self,petID) -- callback
            if rematch.petHerder:GetActionID()=="cage" then
                local petInfo = rematch.petInfo:Fetch(petID)
                return petInfo.isTradable and not petInfo.isInjured and not petInfo.isSlotted and (not petInfo.inTeams or rematch.dialog.Canvas.CheckButton:GetChecked())
            end
        end
    )

    --[[ groups: badges for groups (team headers) ]]

    -- preferences: whether group has any preferences
    self:RegisterBadge("groups","preferences","Interface\\AddOns\\Rematch\\textures\\badges-borderless",{0.75,0.875,0.125,0.25},
        function(self,groupID)
            if not settings.HidePreferenceBadges then
                local group = groupID and rematch.savedGroups[groupID]
                return group and group.preferences
            end
        end
    )

    --[[ teams: badges for teams ]]

    -- preferences: whether team has any targets
    self:RegisterBadge("teams","targets","Interface\\AddOns\\Rematch\\textures\\badges-borderless",{0.375,0.5,0.375,0.5},
        function(self,teamID)
            if not settings.HideTargetBadges then
                local team = teamID and rematch.savedTeams[teamID]
                return team and team.targets
            end
        end
    )

    -- preferences: whether team has any preferences
    self:RegisterBadge("teams","preferences","Interface\\AddOns\\Rematch\\textures\\badges-borderless",{0.75,0.875,0.125,0.25},
        function(self,teamID)
            if not settings.HidePreferenceBadges then
                local team = teamID and rematch.savedTeams[teamID]
                return team and team.preferences
            end
        end
    )

    --[[ targets: badges for targets (npcIDs; not using actual targetID) ]]

    -- teams: whether target has any teams
    self:RegisterBadge("targets","teams","Interface\\AddOns\\Rematch\\textures\\badges-borderless",{0.5,0.625,0.125,0.25},
        function(self,npcID)
            return not settings.HideTeamBadges and rematch.savedTargets[npcID]
        end
    )

end)

-- list: generally "pets", "teams" or "targets", used by AddBadges to determine badge set (required)
-- name,icon,coords,callback get added to badges in the order they're registered
function rematch.badges:RegisterBadge(list,name,icon,coords,callback)
    assert(type(list)=="string" and list:len()>0,"Invalid list name: "..(list or "nil"))
    assert(type(name)=="string" and name:len()>0,"Invalid badge name: "..(name or "nil"))
    assert(type(callback)=="function","Invalid callback function for "..name.." badge")

    -- if this list hasn't been started, start one
    if not badges[list] then
        badges[list] = {}
    end

    -- if badge already exists, remove it
    rematch.badges:UnregisterBadge(list,name,true)

    -- add badge to registered badges
    tinsert(badges[list],{
        name = name,
        icon = icon or C.UNKNOWN_ICON,
        coords = coords,
        callback = callback
    })
end

-- removes a registered badge (noUpdate=true to not update the UI)
function rematch.badges:UnregisterBadge(list,name,noUpdate)
    for i=#badges[list],1,-1 do
        if badges[list][i].name==name then
            tremove(badges[list],i)
        end
    end
    if not noUpdate and rematch.frame:IsVisible() then
        rematch.frame:Update()
    end
end

--[[ the following are called by the list updates and should never need to be called outside of one ]]

-- array: parentArray of textures attached to a button (button.Badges)
-- list: generally "pets", "teams" or "targets"; the set of badges registered
-- id: the petID, teamID, groupID, targetID or headerID to add badges for (passed to callbacks)
-- anchorPoint: anchor point of the first badge
-- relativeTo: the frame/region the first badge is anchored to
-- relativePoint: anchor point from the frame/region the first badge is anchored to
-- xoff: x offset for first badge
-- yoff: y offset for first badge
-- xdir: -1 to place badges right to left; 1 to place badges left to right
-- returns: width of the badges
function rematch.badges:AddBadges(array,list,id,anchorPoint,relativeTo,relativePoint,xoff,yoff,xdir)
    -- first clear all badges
    rematch.badges:ClearBadges(array)
    -- go through each registered badge for the list and show it
    local arrayIndex = 1
    local parent = array[1]:GetParent()
    local width = 0
    for _,info in ipairs(badges[list]) do
        -- this badge should show if callback returns true
        if info.callback(parent,id) then
            if not array[arrayIndex] then
                array[arrayIndex] = parent:CreateTexture(nil,"ARTWORK")
                array[arrayIndex]:SetSize(C.BADGE_SIZE,C.BADGE_SIZE)
            end
            local badge = array[arrayIndex]
            badge:SetTexture(type(info.icon)=="function" and info.icon(parent,id) or info.icon)
            local x1,x2,y1,y2
            if type(info.coords)=="function" then
                x1,x2,y1,y2 = info.coords(parent,id)
            elseif type(info.coords)=="table" then
                x1,x2,y1,y2 = info.coords[1],info.coords[2],info.coords[3],info.coords[4]
            end
            if x1 and x2 and y1 and y2 then
                badge:SetTexCoord(x1,x2,y1,y2)
            else
                badge:SetTexCoord(0,1,0,1)
            end
            badge:ClearAllPoints()
            badge:SetPoint(anchorPoint,relativeTo,relativePoint,xoff,yoff)
            badge:Show()
            width = width + C.BADGE_SIZE + 1
            xoff = xoff + (C.BADGE_SIZE + 1)*xdir -- adjust x position of next badge (xdir -1 will go left, 1 right)
            arrayIndex = arrayIndex + 1
        end
    end
    -- badges all placed, return width of badges
    return width
end

-- clears badges in the given parentArray
function rematch.badges:ClearBadges(array)
    for _,badge in ipairs(array) do
        badge:Hide()
    end
end
