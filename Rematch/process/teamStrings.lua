local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.teamStrings = {}

--[[

    For exporting, importing (and send/receiving), groups and teams are converted to strings here.

    Teams always take up one line, with \n in notes escaped when turned into a string:

    With no preferences and no notes:
        Team Name:<npcID>,<npcID>,<etc>:petTag1:petTag2:petTag3:

    With preferences and no notes:
        Team Name:<npcID>,<npcID>,<etc>:petTag1:petTag2:petTag3:P:<minHP>:<allowMM>:<expectedDD>:<minXP>:<maxXP>:

    With no preferences and notes:
        Team Name:<npcID>,<npcID>,<etc>:petTag1:petTag2:petTag3:N:<notes>

    With preferences and notes:
        Team Name:<npcID>,<npcID>,<etc>:petTag1:petTag2:petTag3:P:<minHP>:<allowMM>:<expectedDD>:<minXP>:<maxXP>:N:<notes>

    * The name field is the only required field, but the colons (:) to fill out the other fields is required,
      with the exception of P:<preferences> and N:<notes> they can be completely dropped.
    * See utils\petTags.lua for format of petTags.
    * npcIDs are converted to base 32, but preference values are not (and minXP and maxXP can be floats like 23.5)

    When multiple teams are exported, their group headers are in one of three formats:

    Legacy format (still supported):
        __ Group Name __

    With no preferences:
        __ Group Name:<sort>:<icon>:<color>: __

    With preferences:
        __ Group Name:<sort>:<icon>:<color>:P:minHP:allowMM:expectedDD:maxHP:minXP:maxXP: __

    * If the icon is a path like "Interface\Icons\INV_Misc_QuestionMark" it's converted to a fileID on export.
    * The fileID is converted to base 32.

    An export of a whole group of teams will then be:

        __ Group Name:etc: __

        Team Name:etc:
        Team Name:etc:
        Team Name:etc:

    * With teams are exported they're in their current order defined by settings.GroupOrder.
    * When all groups are exported (backup), it will export all groups in their order. On an import, it
      will add them to the existing groups even if names match existing groups.
    * When teams are imported, if any team shares a name with an existing team, an option will be given to
      overwrite the existing teams or make new copies (append a number like (2) to make the name unique)
]]

-- returns the preference substring: P:minHP:allowMM:expectedDD:maxHP:minXP:maxXP:
-- note: none of these values are converted to base32 and minXP and maxXP can be floats (23.5)
function rematch.teamStrings:ExportPreferences(preferences)
    if type(preferences)=="table" and settings.ExportIncludePreferences then
        return format("P:%s:%s:%s:%s:%s:%s:",preferences.minHP or "",preferences.allowMM and "1" or "",preferences.expectedDD or "",preferences.maxHP or "",preferences.minXP or "",preferences.maxXP or "")
    else
        return ""
    end
end

-- returns a team string for a single given teamID
function rematch.teamStrings:ExportTeam(teamID)
    local team = teamID and rematch.savedTeams[teamID]
    if not team then
        return
    end

    -- a team can have multiple targets separated by commas: Team Name:123,987,456:ABCD:EFGH:IJKL:
    local npcIDs = ""
    if team.targets then
        local targets = {}
        for _,npcID in ipairs(team.targets) do
            tinsert(targets,rematch.utils:ToBase32(npcID))
        end
        npcIDs = table.concat(targets,",")
    end

    -- base always exists name:npcID:petTag1:petTag2:petTag3:
    local result = format("%s:%s:%s:%s:%s:",team.name,npcIDs,team.tags[1] or "",team.tags[2] or "",team.tags[3] or "")

    -- add preferences P:minHP:allowMM:expectedDD:maxHP:minXP:maxXP
    result = result..rematch.teamStrings:ExportPreferences(rematch.preferences:GetTeamPreferences(teamID))

    -- notes always at end
    if team.notes and team.notes:trim():len()>0 and settings.ExportIncludeNotes then
        result = result..format("N:%s",team.notes:trim():gsub("\n","\\n"))
    end

    return result
end

-- returns a multi-line string of the given teamID in a "plain text" format meant to be human readable
-- (plain text exports are never meant to be imported)
function rematch.teamStrings:ExportPlainTextTeam(teamID)
    local team = teamID and rematch.savedTeams[teamID]
    if not team then
        return
    end

    -- team name is always first line by itself
    local result = team.name.."\n"
    -- second line if any targets (named differently than team) list them as "(Target Name, Other Target, etc.)"
    if team.targets then
        local targets = {}
        for _,npcID in ipairs(team.targets) do
            local name = rematch.targetInfo:GetNpcName(npcID)
            if name and name~=team.name and name~=C.CACHE_RETRIEVING then -- only include target names if they aren't team name
                tinsert(targets,name)
            end
        end
        if #targets>0 then
            result = result.."("..table.concat(targets,", ")..")\n"
        end
    end
    -- line after team name (and possible target)
    result = result..string.rep("-",team.name:len()).."\n"
    -- next three lines are each pet in the team and their abilities (if applicable)
    for i=1,3 do
        local petID = team.pets[i]
        local petTag = team.tags[i]
        local petInfo = rematch.petInfo:Fetch(petID)
        local name = petInfo.speciesName or petInfo.name or UNKNOWN
        -- if abilities are in the tag (and not 000 for any abilities in any slot)
        local abilities = petTag and petTag:match("^([012][012][012])")
        if abilities and abilities~="000" then -- if all are 0, don't show abilities; but if 1 or 2 are 0, show as "any"; eg 1/1/any
            name = name.." ("
            for j=1,3 do
                local ability = string.sub(abilities,j,j)
                name = name..(ability=="0" and L["any"] or ability)..(j<3 and "," or "")
            end
            name = name..")"
        end
        result = result..name.."\n"
    end

    local preferences = type(team.preferences)=="table" and team.preferences
    if settings.ExportIncludePreferences and preferences and rematch.utils:GetSize(preferences)>0 then
        result = result..string.rep("-",team.name:len()).."\n".."Leveling preferences: "
        local list = {}
        if preferences.minHP then
            tinsert(list,format(L["at least %d health"],preferences.minHP))
        end
        if preferences.allowMM then
            tinsert(list,L["allow low-level Magic or Mechanical pets"])
        end
        if preferences.expectedDD then
            tinsert(list,format(L["expect %s damage"],_G["BATTLE_PET_NAME_"..preferences.expectedDD] or UNKNOWN))
        end
        if preferences.maxHP then
            tinsert(list,format(L["at most %d health"],preferences.maxHP))
        end
        if preferences.minXP then
            tinsert(list,format(L["at least level %.f"],preferences.minXP))
        end
        if preferences.maxXP then
            tinsert(list,format(L["at most level %.f"],preferences.maxXP))
        end
        if #list>0 then
            result = result..table.concat(list,", ").."\n"
        end
    end

    if settings.ExportIncludeNotes and team.notes then
        result = result..string.rep("-",team.name:len()).."\n"..team.notes
    end

    return result:trim()
end

-- returns a string for a group header in format "__ name:sort:icon:color:showTab:[preferences] __"
-- all except name are optional, and preferences field only exists if group has preferences
function rematch.teamStrings:ExportHeader(groupID)
    local group = groupID and rematch.savedGroups[groupID]
    if group and group.name then
        return format("__ %s:%s:%s:%s:%s:%s __",
            group.name:trim(),
            group.sortMode or "",
            rematch.utils:ToBase32(type(group.icon)=="number" and group.icon or GetFileIDFromPath(group.icon or "")) or "",
            group.color or "",
            group.showTab and "1" or "",
            rematch.teamStrings:ExportPreferences(group.preferences)
        )
    end
end

-- returns an ordered table of strings for a group and all teams in the group (in table form
-- so it can spool to the multilineeditbox)
function rematch.teamStrings:ExportGroup(groupID)
    local results = {}

    local header = rematch.teamStrings:ExportHeader(groupID)
    if header then
        tinsert(results,header)
        tinsert(results,"")

        for _,teamID in ipairs(rematch.savedGroups[groupID].teams) do
            local team = rematch.teamStrings:ExportTeam(teamID)
            if team then
                tinsert(results,team)
            end
        end
    end

    return results
end

-- returns an ordered table of all groups and teams
function rematch.teamStrings:ExportAll()
    local results = {}

    for _,groupID in ipairs(settings.GroupOrder) do
        for _,teamString in pairs(rematch.teamStrings:ExportGroup(groupID)) do
            tinsert(results,teamString)
        end
        tinsert(results,"")
    end
    -- remove trailing blank line
    if #results>1 then
        tremove(results,#results)
    end

    return results
end

-- analyzes the import string for groups and teams and returns numGroups, numTeams, numConflicts, numBad
function rematch.teamStrings:AnalyzeImport(import)
    local numGroups = 0 -- number of group headers in the import
    local numTeams = 0 -- number of teams in the import
    local numConflicts = 0 -- number of teams/groups that share the name of an existing team in the import
    local numBad = 0 -- number of unrecognized non-empty lines in the import
    local foundFirst -- becomes "group" or "team"; if "team" found first then all groups ignored

    -- read each line of the import
    for line in ((import or "").."\n"):gmatch("(.-)\n") do
        local test = line:trim()
        local groupName = test:match("^__ (.-):*.* __$")
        if groupName then -- this matches a group format, increment numGroups
            numGroups = numGroups + 1
            local existingGroupID = rematch.savedGroups:GetGroupIDByName(groupName)
            -- if this group already exists (and it's not favorites or ungrouped which never conflict), increment numConflicts
            if existingGroupID and existingGroupID~="group:favorites" and existingGroupID~="group:none" then
                numConflicts = numConflicts + 1
            end
            if not foundFirst then
                foundFirst = "group"
            end
        else
            local teamName = test:match("^([^\n]-):[%w,]*:%w*:%w*:%w*:")
            if teamName then -- this line matches a team format, increment numTeams
                numTeams = numTeams + 1
                if rematch.savedTeams:GetTeamIDByName(teamName) then
                    numConflicts = numConflicts + 1 -- an existing team has this name, increment numConflicts
                end
                if not foundFirst then
                    foundFirst = "team"
                end
            elseif test:len()>0 then -- don't know what this is, increment numBad
                numBad = numBad + 1
            end
        end
    end

    -- if teams found before groups, ignore all groups and treat this as a multi-team import without groups
    -- (so user is offered which group to put teams; otherwise these teams would have no place to go)
    if foundFirst=="team" then
        numGroups = 0
    end

    return numGroups,numTeams,numConflicts,numBad
end

-- imports a single team to the loadonly meta team and loads the team
function rematch.teamStrings:LoadOnly(import)
    if type(import)~="string" then
        return -- if import is not a string, do nothing and leave
    end

    -- confirm that only one team is being imported
    local numGroups,numTeams = self:AnalyzeImport(import)
    if not numGroups or (numGroups>0 and numTeams~=1) then
        return -- this is not a single team import, leave
    end

    self:ImportTeam(import:trim(),"group:none",true)

    rematch.loadTeam:LoadTeamID("loadonly")
end

-- imports the teams (possibly groups too) from the given import string
function rematch.teamStrings:Import(import)

    if type(import)~="string" then
        return -- if import is not a string, do nothing and leave
    end

    -- first analyze to figure out if groups are going to be made (first valid string is a group)
    -- remember: if a team lists first, all groups are ignored. groups can ONLY be imported if the first
    -- valid string is a group.
    local numGroups,numTeams = self:AnalyzeImport(import)

    -- for single team or multi team (not group) imports, the group to put teams is settings.LastSelectedGroup
    -- here confirm setting is group:none if not defined or a no-longer-existing group
    if not settings.LastSelectedGroup or not rematch.savedGroups[settings.LastSelectedGroup] then
        settings.LastSelectedGroup = "group:none"
    end

    -- if ImportConflictOverwrite is true and any teams with same name are found, then overwrite existing team
    local overwrite = settings.ImportConflictOverwrite

    local groupID = settings.LastSelectedGroup
    local firstGroupID

    -- read each line of the import
    for line in ((import or "").."\n"):gmatch("(.-)\n") do
        local test = line:trim()
        local groupLine = test:match("^(__ .+ __)$")
        local teamLine = test:match("^([^\n]-:[%w,]*:%w*:%w*:%w*:.*)$")
        -- if groups can be picked up, look for groups to add (and teams will be added to these new groups)
        if numGroups>0 then
            if groupLine then
                groupID = self:ImportGroup(groupLine:trim())
                if not firstGroupID then
                    firstGroupID = groupID
                end
                settings.ExpandedGroups[groupID] = true
            elseif teamLine then
                self:ImportTeam(teamLine:trim(),groupID)
            end
        end
        -- if no groups, then only look for teams and use the settings.LastSelectedGroup for where to put these
        if numGroups==0 then
            if teamLine then
                local teamID = self:ImportTeam(teamLine:trim(),groupID)
                rematch.savedTeams:TeamsChanged(true)
                if numTeams==1 then -- if only importing one team, bling it
                    rematch.layout:SummonView("teams")
                    rematch.saveDialog:LoadAndBlingTeamID({teamID=teamID})
                end
            end
        end
    end
    -- if more than one team imported, scroll the group they were imported to top (first group if multi group)
    if numTeams>1 or numGroups>0 then
        rematch.layout:SummonView("teams")
        rematch.saveDialog:BlingTeamIDOrGroupID(firstGroupID or groupID)
    end
end

-- for the given tag (and excludePetIDs lookup table), return a petID and add to lookup if one found
local function findPetID(tag,excludePetIDs)
    local petID = rematch.petTags:FindPetID(tag,excludePetIDs)
    if type(petID)=="string" and petID:match("^BattlePet") then -- if an actual pet
        excludePetIDs[petID] = true
    end
    return petID
end

-- takes the "extras" part of a string (preferences and notes) and returns preferences,notes as a table and string;
-- either or both can be nil
local function parseExtras(extras)
    local preferences
    local minHP,allowMM,expectedDD,maxHP,minXP,maxXP,notes = extras:match("^P:(%d*):(%d*):(%d*):(%d*):([%d%.]*):([%d%.]*):N:(.+)$")
    if not minHP then
        minHP,allowMM,expectedDD,maxHP,minXP,maxXP = extras:match("^P:(%d*):(%d*):(%d*):(%d*):([%d%.]*):([%d%.]*):$")
    end
    if not minHP then
        notes = extras:match("^N:(.+)$")
    end
    if minHP then
        preferences = {}
        preferences.minHP = tonumber(minHP)
        preferences.allowMM = tonumber(allowMM)==1 and true or nil
        preferences.expectedDD = tonumber(expectedDD)
        preferences.maxHP = tonumber(maxHP)
        preferences.minXP = tonumber(minXP)
        preferences.maxXP = tonumber(maxXP)
    end
    return preferences,notes
end

-- sets the sideline to the team in the import string
function rematch.teamStrings:SidelineTeamString(import,groupID)
    -- test for extras (preferences/notes) first
    local teamString,extras = import:match("^([^\n]-:[%w,]*:%w*:%w*:%w*:)(.+)$")
    if not teamString then -- no extras, test for just team
        teamString = import:match("^([^\n]-:[%w,]*:%w*:%w*:%w*:)$")
    end
    if not teamString then
        return -- just team not found; not valid
    end

    -- at this point teamString is name:npcIDs:pet1:pet2:pet3: (and extras is any remainder)

    local name,npcIDs,pet1,pet2,pet3 = teamString:match("([^\n]-):([%w,]*):(%w*):(%w*):(%w*):$")
    name=name:trim()

    -- build sideline
    rematch.savedTeams:Reset("sideline")
    rematch.savedTeams.sideline.name = name
    rematch.savedTeams.sideline.tags[1] = pet1
    rematch.savedTeams.sideline.tags[2] = pet2
    rematch.savedTeams.sideline.tags[3] = pet3

    -- set groupID
    rematch.savedTeams.sideline.groupID = groupID or "group:none"
    if groupID=="group:favorites" then
        rematch.savedTeams.sideline.homeID = "group:none"
        rematch.savedTeams.sideline.favorite = true
    end

    -- find petIDs for each tag
    local excludePetIDs = {}
    rematch.savedTeams.sideline.pets[1] = findPetID(pet1,excludePetIDs)
    rematch.savedTeams.sideline.pets[2] = findPetID(pet2,excludePetIDs)
    rematch.savedTeams.sideline.pets[3] = findPetID(pet3,excludePetIDs)

    -- set targets (comma-separated list)
    if npcIDs:len()>0 then
        rematch.savedTeams.sideline.targets = {}
        for npcID in npcIDs:gmatch("[^,]+") do
            local target = tonumber(npcID,32)
            if target then
                tinsert(rematch.savedTeams.sideline.targets,target)
            end
        end
    end

    -- parse extras (preferences and notes) if any
    if extras then
        local preferences,notes = parseExtras(extras)
        if preferences then
            rematch.savedTeams.sideline.preferences = CopyTable(preferences)
        end
        if notes then
            rematch.savedTeams.sideline.notes = notes:gsub("\\n","\n")
        else
            rematch.savedTeams.sideline.notes = nil
        end
    end

end

-- imports a single team to the given groupID
-- if loadOnly is true, then the team is imported into the "loadonly" meta team and not saved
function rematch.teamStrings:ImportTeam(import,groupID,loadOnly)

    rematch.teamStrings:SidelineTeamString(import,groupID)

    -- if team name already used, we're either making a copy (make name unique) or overwriting
    -- (savedTeams:Create() call a TeamsChanged)
    local existingTeamID = rematch.savedTeams:GetTeamIDByName(rematch.savedTeams.sideline.name)
    local newTeamID
    if loadOnly then -- if only loading team, copy sideline to loadonly meta team
        --rematch.savedTeams.sideline.name = rematch.savedTeams:GetUniqueName(rematch.savedTeams.sideline.name)
        rematch.savedTeams.loadonly = rematch.savedTeams.sideline
        newTeamID = "loadonly"
    elseif existingTeamID then
        if settings.ImportConflictOverwrite then -- when overwriting, reuse old teamID
            rematch.events:Fire("REMATCH_TEAM_OVERWRITTEN",existingTeamID)
            rematch.savedTeams[existingTeamID] = rematch.savedTeams.sideline
            newTeamID = existingTeamID
            rematch.savedTeams:TeamsChanged()
        else
            rematch.savedTeams.sideline.name = rematch.savedTeams:GetUniqueName(rematch.savedTeams.sideline.name)
            newTeamID = rematch.savedTeams:Create().teamID
        end
    else -- this is a new team with no conflict, create a new team
        newTeamID = rematch.savedTeams:Create().teamID
    end

    -- if any of the chosen pets are below 25 (and QueueAutoImport enabled), then add them to queue
    if settings.QueueAutoImport then
        for i=1,3 do
            local petID = rematch.savedTeams.sideline.pets[i]
            local petInfo = rematch.petInfo:Fetch(petID)
            if rematch.queue:PetIDCanLevel(petID) then
                -- since queue won't have time to process/sort, making a manual check for each pass
                local inQueue
                for _,info in ipairs(settings.LevelingQueue) do
                    if info.petID==petID then
                        inQueue = true
                        break
                    end
                end
                if not inQueue then
                    rematch.queue:AddPetID(petID)
                    rematch.utils:WriteSystem(format(L["%s has been added to your leveling queue!"],petInfo.formattedName))
                end
            end
        end
    end

    -- returning teamID of team either created or overwritten
    return newTeamID
end

-- creates a new group from the given __ name:sort:icon:color:[preferences] __ and returns the groupID that was created
function rematch.teamStrings:ImportGroup(import)
    -- test for new group definition with preferences (extras) first
    local groupName,sort,icon,color,showTab,extras = import:match("^__ ([^\n]-):(%d*):(%w*):(%w*):(%w*):(.+) __$")
    -- no match yet, try without preferences next
    if not groupName then
        groupName,sort,icon,color,showTab = import:match("^__ ([^\n]-):(%d*):(%w*):(%w*):(%w*): __$")
    end
    -- still no match, try legacy with just group (was tab) name __
    if not groupName then
        groupName = import:match("^__ (.+) __$")
    end
    if not groupName then
        return -- no group found in import string, leave
    end

    groupName = groupName:trim()

    -- if group has a valid name
    if groupName:len()>0 then
        local group
        local existingGroupID = rematch.savedGroups:GetGroupIDByName(groupName)
        if existingGroupID=="group:favorites" or existingGroupID=="group:none" then
            group = rematch.savedGroups[existingGroupID] -- favorites and ungrouped always import into existing group
        elseif existingGroupID and settings.ImportConflictOverwrite then
            group = rematch.savedGroups[existingGroupID] -- other groups that share a name use existing one if overwrite chosen
        else
            group = rematch.savedGroups:Create(groupName) -- in all other cases create a new group (can be same name)
        end
        group.sortMode = tonumber(sort) or C.GROUP_SORT_ALPHA
        group.icon = tonumber((icon or ""),32) or C.REMATCH_ICON
        group.color = tonumber((color or ""),16) and color:trim() or nil
        group.showTab = showTab~="" and true or nil

        if extras then
            group.preferences = parseExtras(extras:trim()) -- no notes support yet; but if so it'd be second return here
        end

        rematch.savedTeams:TeamsChanged()
        return group.groupID
    end

end

-- this creates and returns an ordered table with the teamID's string potentially split across multiple lines.
-- if a teamString is less than 254 characters, it only has one line.
-- when a line is incomplete (more are incoming) then it ends with \003.
-- when a line is a continuation (not the first line) then it begins with \002.
-- when an incoming team begins without \002 it should start a new team.
-- when an incoming line ends with \003 it should wait for the next line.
function rematch.teamStrings:SplitTeamStrings(teamID)
    local teamString = self:ExportTeam(teamID) 
    if not teamString then
        return -- teamID invalid
    end
    local results = {}
    -- sending a team should always include preferences and notes
    local oldIncludePreferences = settings.ExportIncludePreferences
    local oldIncludeNotes = settings.ExportIncludeNotes 
    repeat
        tinsert(results,teamString:sub(1,253))
        teamString = teamString:sub(254)
    until teamString:len()==0
    if #results>1 then
        for i=1,#results-1 do
            results[i] = results[i].."\003"
        end
        for i=2,#results do
            results[i] = "\002"..results[i]
        end
    end
    return results
end

-- checks if it's time to prompt about backups and displays the dialog if so
function rematch.teamStrings:CheckForBackup()
    if not settings.NoBackupReminder and not C_PetBattles.IsInBattle() and not InCombatLockdown() and not C_PetBattles.GetPVPMatchmakingInfo() then
        local numTeams = rematch.savedTeams:GetNumTeams()
        if type(settings.BackupCount)~="number" or settings.BackupCount==0 then
            settings.BackupCount = numTeams
        elseif numTeams > (settings.BackupCount+C.BACKUP_INTERVAL) then
            settings.BackupCount = numTeams
            rematch.dialog:Register("BackupTeams",{
                title = L["Backup Teams"],
                accept = YES,
                cancel = NO,
                layout = {"Text","SmallText","CheckButton"},
                refreshFunc = function(self,info,subject,firstRun)
                    self.Text:SetText(format(L["You have %s%d\124r Rematch teams.\n\nWould you like to back them up now?"],C.HEX_WHITE,numTeams))
                    self.SmallText:SetText(L["Choosing Yes will export all teams to copy and paste in an email to yourself or someplace safe.\n\nYou can also do this at any time from the Teams button at the top of the Teams panel of Rematch."])
                    self.CheckButton:SetText(L["Don't Remind About Backups"])
                    self.CheckButton:SetChecked(settings.NoBackupReminder)
                end,
                changeFunc = function(self,info,subject,firstRun)
                    settings.NoBackupReminder = self.CheckButton:GetChecked()
                end,
                acceptFunc = function(self,info,subject)
                    rematch.timer:Start(0.1,function() 
                        rematch.dialog:ShowDialog("ExportMultipleTeams")
                    end)
                end,
            })
            rematch.dialog:Hide()
            rematch.dialog:ShowDialog("BackupTeams")
        end
    end
end