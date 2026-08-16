local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings

--[[

    Aside from /rematch <team name> to load a team in a macro, slash commands are for "administrative"
    tasks that should not be exposed in the UI.

    /rematch <team name>         : loads a team of the given name
    /rematch targetdata          : generates data for a new target to add to targetData.lua
    /rematch delete all teams    : wipes all teams and groups
    /rematch reset everything    : wipes all settings, teams, groups, etc. and restores addon to initial state
    /rematch reupgrade           : wipes all teams, groups and settings and re-imports everything from Rematch4 savedvars

]]


SLASH_REMATCH1 = "/rematch"
SlashCmdList["REMATCH"] = function(msg)
    msg = (msg or ""):trim():lower()

    -- "/rematch" with no other command will toggle the rematch window
    if msg=="" then
        rematch.frame:Toggle()
        return
    end

    -- "/rematch <team name>" will attempt to load a team (if <team name> found)
    if rematch.loadTeam:LoadTeamByName(msg) then
        return -- if LoadTeamByName found a teamID, then it's loading; leave
    end

    -- "/rematch reset all settings" will wipe and settings with a dialog prompt to confirm
    if msg=="reset everything" then
        rematch.dialog:Register("ResetEverything",{
            title = L["Reset Everything"],
            accept = YES,
            cancel = NO,
            prompt = L["Reset everything?"],
            layout = {"Icon","Text","Feedback"},
            refreshFunc = function(self,info,subject,firstRun)
                self.Icon:SetTexture("Interface\\ICONS\\Ability_Creature_Cursed_02")
                self.Icon:SetTexCoord(0.075,0.925,0.075,0.925)
                self.Text:SetText(L["This will wipe all settings, teams, queue, etc (absolutely everything), and then reload the UI to start Rematch from scratch."])
                self.Feedback:Set("warning",L["Warning: This cannot be undone!"])
            end,
            acceptFunc = function(self,info,subject)
                wipe(Rematch5Settings)
                wipe(Rematch5SavedTeams)
                wipe(Rematch5SavedGroups)
                wipe(Rematch5SavedTargets)
                ReloadUI()
            end
        })
        rematch.dialog:ShowDialog("ResetEverything")
        return
    end

    -- "/rematch delete all teams" will wipe all teams and groups with a dialog prompt to confirm
    if msg=="delete all teams" then
        rematch.dialog:Register("DeleteAllTeams",{
            title = L["Delete All Teams"],
            accept = YES,
            cancel = NO,
            prompt = L["Delete all teams?"],
            layout = {"Icon","Text","Feedback"},
            refreshFunc = function(self,info,subject,firstRun)
                self.Icon:SetTexture("Interface\\ICONS\\Ability_Creature_Cursed_02")
                self.Icon:SetTexCoord(0.075,0.925,0.075,0.925)
                self.Text:SetText(format(L["This will wipe all teams and groups.\n\nAre you sure you want to %sDELETE\124r all teams and groups permanently?"],C.HEX_WHITE))
                self.Feedback:Set("warning",L["Warning: This cannot be undone!"])
            end,
            acceptFunc = function(self,info,subject)
                rematch.savedTeams:Wipe()
                rematch.savedGroups:Wipe()
            end,
        })
        rematch.dialog:ShowDialog("DeleteAllTeams")
        return
    end

    -- "/rematch targetdata" will create a new entry for new targets, to add to targetData.lua.
    -- To use: Target the target and enter battle (it's ok if you lose target, just don't target
    -- anything else) and once you're in battle and see opponent pets, enter /rematch targetdata
    if msg=="targetdata" then
        if not C_PetBattles.IsInBattle() or not rematch.targetInfo.recentTarget then
            rematch.utils:Write(L["Usage: Target an npc to create data for, enter a pet battle, and once in battle with opponent pets displayed, enter:\n\124cffffffff/rematch targetdata"])
            return
        end
        local npcID = rematch.targetInfo.recentTarget
        local npcName = rematch.targetInfo:GetNpcName(npcID)
        local mapID = C_Map.GetBestMapForUnit("player")
        local mapName = C_Map.GetMapInfo(mapID).name
        -- start with map and npcID; 0 is expansion that needs filled in manually, nill is questID
        -- (if the target is in a subzone and a parent mapID should be used, use first mapID for parent)
        local result = format("{%d,%d,%d,0,nil,",mapID,npcID,mapID)
        -- add pets with their stats
        local numPets = C_PetBattles.GetNumPets(Enum.BattlePetOwner.Enemy)
        for i=1,numPets do
            local petInfo = rematch.petInfo:Fetch("battle:2:"..i)
            local speed = petInfo.speed
            if speed and petInfo.petType==3 then -- for flying opponents remember to get stats before it loses racial
                speed = speed/1.5
            end
            if petInfo.speciesID then
                result=result..format("\"battlepet:%d:%d:%d:%d:%d:%d\"%s",petInfo.speciesID,petInfo.level,petInfo.rarity and petInfo.rarity-1 or 0,petInfo.health,petInfo.power,speed or 0,i<numPets and "," or "")
            end
        end
        -- close off line
        result=result..format("}, -- %s, %s",mapName,npcName)
        -- send result to TinyPad if enabled
        if TinyPad then
            TinyPad.Insert(result)
        else -- otherwise print to chat
            rematch.utils:Write(result)
            -- ChatEdit_ActivateChat(DEFAULT_CHAT_FRAME.editBox)
            -- DEFAULT_CHAT_FRAME.editBox:Insert(result)
        end
        return
    end

    -- "/rematch import options" will show a dialog to reset options and update to the ones provided
    if msg=="import options" then
        rematch.dialog:ShowDialog("ImportOptions")
        return
    end

    -- if reached here, the msg didn't resolve to a team or anything meaningful
    rematch.utils:Write(format(L["The team named \"%s\" can't be found."],msg))

end
