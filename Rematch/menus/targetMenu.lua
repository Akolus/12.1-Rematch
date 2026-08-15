local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.targetMenu = {}
local tm = rematch.targetMenu

rematch.events:Register(rematch.targetMenu,"PLAYER_LOGIN",function(self)

    -- menu when you right-click a target in the target list
    local targetMenu = {
        {title=tm.GetTargetName},
        {text=L["Edit Target"], func=tm.SetTeams},
        {text=L["Load Random Pets"], func=tm.LoadRandomTeam},
        {text=L["Load Team"], hidden=tm.HasNoTeam, func=tm.LoadSavedTeam, subMenu="TargetLoadTeamMenu", subMenuFunc=tm.BuildLoadTeamSubMenu},
        {text=L["Edit Team"], hidden=tm.HasNoTeam, func=tm.EditSavedTeam, subMenu="TargetEditTeamMenu", subMenuFunc=tm.BuildEditTeamSubMenu},
        {text=CANCEL},
    }
    rematch.menus:Register("TargetMenu",targetMenu)

    -- submenus have just title, subMenuFuncs fill them in
    rematch.menus:Register("TargetEditTeamMenu",{{title=L["Teams"]}})
    rematch.menus:Register("TargetLoadTeamMenu",{{title=L["Teams"]}})

    rematch.dialog:Register("SetTargetTeams",{
        title=L["Edit Target"],
        accept=SAVE,
        cancel=CANCEL,
        width = 290,
        layout={"Text","TeamPicker","Help"},
        refreshFunc = function(self,info,subject,firstRun)
            if firstRun then
                rematch.dialog:SetTitle(rematch.targetInfo:GetNpcName(subject.targetID))
                self.Text:SetText(format(L["These are the teams saved for %s."],rematch.utils:GetFormattedTargetName(subject.targetID)))
                self.Help:SetText(L["The topmost team is the preferred team to load when you interact with this target."])
                self.TeamPicker:SetList(subject.listType,subject.list)
            end
        end,
        acceptFunc = function(self,info,subject)
            local npcID = rematch.targetInfo:GetNpcID(subject.targetID)
            if npcID then
                rematch.savedTargets:Set(npcID,self.TeamPicker:GetList())
                rematch.targetsPanel.List:BlingData(subject.targetID)
            end
        end
    })

end)

function rematch.targetMenu:GetTargetName(npcID)
    return rematch.targetInfo:GetNpcName(npcID)
end

function rematch.targetMenu:SetTeams(targetID)
    local list = {}
    if rematch.savedTargets[targetID] then
        for _,npcID in ipairs(rematch.savedTargets[targetID]) do
            tinsert(list,npcID)
        end
    end
    rematch.dialog:ShowDialog("SetTargetTeams",{targetID=targetID, listType=C.LIST_TYPE_TEAM, list=list})
end

function rematch.targetMenu:LoadRandomTeam(targetID)
    local npcID = rematch.targetInfo:GetNpcID(targetID)
    if npcID then
        rematch.loadedTargetPanel:SetTarget(npcID,true)
    end
    rematch.randomPets:BuildCounterTeam(npcID)
    rematch.loadTeam:LoadTeamID("counter")
end

function rematch.targetMenu:HasNoTeam(targetID)
    return not rematch.savedTargets:GetTeams(targetID)
end

-- BuildLoadTeamSubMenu
-- BuildEditTeamSubMenu

function rematch.targetMenu:BuildTeamSubMenu(targetID,menu,func)
    local def = rematch.menus:GetDefinition(menu)
    -- remove any existing teams
    for i=#def,2,-1 do
        tremove(def,i)
    end
    local teams = rematch.savedTargets:GetTeams(targetID)
    if teams and #teams>0 then
        for _,teamID in ipairs(teams) do
            local name = rematch.utils:GetFormattedTeamName(teamID)
            tinsert(def,{text=name,teamID=teamID,func=func})
        end
    else
        tinsert(def,{text=L["No teams :("]})
    end
    tinsert(def,{text=CANCEL})
    rematch.menus:Register(menu,def)
end

function rematch.targetMenu:BuildLoadTeamSubMenu(targetID)
    rematch.targetMenu:BuildTeamSubMenu(targetID,"TargetLoadTeamMenu",tm.LoadTargetTeam)
end

function rematch.targetMenu:BuildEditTeamSubMenu(targetID)
    rematch.targetMenu:BuildTeamSubMenu(targetID,"TargetEditTeamMenu",tm.EditTargetTeam)
end

function rematch.targetMenu:LoadTargetTeam(targetID)
    rematch.loadTeam:LoadTeamID(self.teamID)
end

function rematch.targetMenu:EditTargetTeam(targetID)
    rematch.teamMenu:EditTeam(self.teamID)
end

-- this loads the preferred teamID for the target (click of Load Team menu button that shows teams submenu)
function rematch.targetMenu:LoadSavedTeam(targetID)
    local teams,index = rematch.savedTargets:GetTeams(targetID)
    if teams and index and teams[index] then
        rematch.loadTeam:LoadTeamID(teams[index])
    end
    rematch.menus:Hide()
end

function rematch.targetMenu:EditSavedTeam(targetID)
    local teams,index = rematch.savedTargets:GetTeams(targetID)
    if teams and index and teams[index] then
        rematch.teamMenu:EditTeam(teams[index])
    end
    rematch.menus:Hide()
end
