local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.convert = {}

--[[
    For converting Rematch 4.x data to Rematch 5.x

    In main.lua's PLAYER_LOGIN, ConversionCheck() is the first thing done to convert Rematch 4
    teams/settings to Rematch 5, if needed. This has to happen before all other initialization.

    Note for other addons that need to know about the conversion:

    The Rematch event REMATCH_TEAMS_CONVERTED will fire when this conversion happens (and have
    a table of converted key/teamID values in its payload):

        Rematch.events:Register(yourframe,"REMATCH_TEAMS_CONVERTED",function(self,convertedTeams)
            for key,teamID in pairs(convertedTeams) do
                print(key,"is now",teamID)
            end
        end)

    But chances are this will fire too soon for other addons to register/be aware of it.

    Instead, anytime after Rematch's PLAYER_LOGIN (if Rematch is a dependency then your PLAYER_LOGIN
    should be sufficient), call Rematch.convert:GetConvertedTeams() to get a table of old Rematch 4
    keys to their Rematch 5 teamID equivalents, with a second return of whether the conversion
    happened in this session. (The key/teamID values are saved in a savedvar and will persist but it
    may disappear when the Rematch 4 saved data is dropped in the future.)

        local convertedTeams,convertedJustNow = Rematch.convert:GetConvertedTeams()
        if convertedJustNow then
            for key,teamID in pairs(convertedTeams) do
                print(key,"is now",teamID)
            end
        end

    NOTE: When Rematch 4 settings are removed, all the settings that end in Fix should be removed too:
    - NotesNoEscFix
    - ShowNewGroupTabFix
    - KeepCompanionFix
]]

local conversionHappened -- true if an import/conversion of Rematch 4 to 5 teams happened this session

function rematch.convert:ConversionCheck()
    -- if there are Rematch4 savedvars then copy them to Rematch4Saved/Settings and nil old versions
    if RematchSaved and RematchSettings then
        Rematch4Saved = CopyTable(RematchSaved)
        Rematch4Settings = CopyTable(RematchSettings)
        RematchSaved = nil
        RematchSettings = nil
    end
    -- if new settings are empty and there are Rematch4Settings, then import stuff after pets loaded
    -- (settings.WasShownOnLogout will have a value on a reload, so checking if 1 or less settings exists)
    if rematch.utils:GetSize(Rematch5Settings)<=1 and Rematch4Settings then
        rematch.convert:ImportSettings() -- import settings without waiting for pets to load (some modules need it on login)
        -- and after pets load, import teams and queue
        rematch.events:Register(self,"REMATCH_PETS_LOADED",function()
            rematch.convert:ImportTeams()
            rematch.convert:ImportQueue()
        end)
    end

    -- team option Show Create New Group Tab is default enabled for Rematch 4 users (new installs default disable)
    if Rematch4Settings and not settings.ShowNewGroupTabFix then
        settings.ShowNewGroupTab = true
        settings.ShowNewGroupTabFix = true
    end

    if Rematch4Settings and Rematch4Settings.FavoriteFilters and not next(settings.FavoriteFilters) then
        settings.FavoriteFilters = CopyTable(Rematch4Settings.FavoriteFilters)
    end
    if Rematch4Settings and Rematch4Settings.KeepSummoned and not settings.KeepCompanionFix then
        settings.KeepCompanion = true
        settings.KeepCompanionFix = true
        settings.KeepSummoned = nil
    end
    if Rematch4Settings and Rematch4Settings.NotesNoESC and not settings.NotesNoEscFix then
        settings.KeepNotesOnScreen = true
        settings.NotesNoEsc = true
        settings.NotesNoEscFix = true
        settings.NotesNoESC = nil
    end
    -- 5.0.5: moving QueueRandomWhenEmpty QueueRandomMaxLevel
    if settings.QueueRandomWhenEmpty and Rematch5Settings.QueueRandomMaxLevel==nil then
        settings.QueueRandomMaxLevel = true
    end
end

-- copies various settings from Rematch 4.x
-- note: THIS SHOULD BE IMPORTED FIRST (LevelingQueue and GroupOrder (among other things) are in settings)
function rematch.convert:ImportSettings()
    if not Rematch4Settings then
        return
    end
    -- bring over boolean settings that are default false but true in 4.x (let default true stay true)
    for k,v in pairs(Rematch4Settings) do
        -- HideMenuHelp/HideOptionTooltips will always remain cleared
        if type(v)=="boolean" and type(settings[k])=="boolean" and v and k~="HideMenuHelp" and k~="HideOptionTooltips" then
            settings[k] = v
        end
    end
    -- bring over pet notes
    settings.PetNotes = CopyTable(Rematch4Settings.PetNotes)
    -- bring over script filters
    if type(Rematch4Settings.ScriptFilters)=="table" and #Rematch4Settings.ScriptFilters>0 then
        settings.ScriptFilters = CopyTable(Rematch4Settings.ScriptFilters)
    end
    -- bring over favorite filters
    settings.FavoriteFilters = CopyTable(Rematch4Settings.FavoriteFilters)
    -- the Other favorite filters require a little more remapping from 4.x to 5.x
    for i,favfilter in ipairs(settings.FavoriteFilters) do
        local filters = type(favfilter)=="table" and type(favfilter[2])=="table" and favfilter[2].Other
        if filters then
            local otherFilters = CopyTable(filters)
            wipe(filters)
            for old,new in pairs({
                Tradable = "Tradable", NotTradable = "Tradable", InTeam = "Team", NotInTeam = "Team",
                Qty1 = "Quantity", Qty2 = "Quantity", Qty3 = "Quantity", Leveling = "Leveling",
                NotLeveling = "Leveling", UniqueMoveset = "Moveset", SharedMoveset = "Moveset",
                Battle = "Battle", NotBattle = "Battle", CurrentZone = true, Hidden = true,
                HasNotes = true
            }) do
                if otherFilters[old] and type(new)=="string" then
                    filters[new] = old
                elseif otherFilters[old] and type(new)=="boolean" then
                    filters[old] = true
                end
            end
        end
    end
    -- convert Auto Load settings to their new version, if any set
    if Rematch4Settings.AutoLoad then
        if Rematch4Settings.AutoLoadTargetOnly then
            settings.InteractOnTarget = C.INTERACT_AUTOLOAD
        else
            settings.InteractOnMouseover = C.INTERACT_AUTOLOAD
        end
        if Rematch4Settings.AutoLoadShow then
            settings.InteractShowAfterLoad = true
        end
    elseif Rematch4Settings.PromptToLoad then
        if Rematch4Settings.PromptWithMinimized then
            settings.InteractOnTarget = C.INTERACT_WINDOW
        else
            settings.InteractOnTarget = C.INTERACT_PROMPT
        end
        if Rematch4Settings.PromptAlways then
            settings.InteractAlways = true
        end
    end
end

-- converts a single Rematch4.x team to Rematch 5.x
local teamUpgradeMap = {} -- unordered table of [oldkey] = teamID only populated for upgraded teams
local function upgradeTeam(key,team)
    local sideline = rematch.savedTeams.sideline
    rematch.savedTeams:Reset("sideline")
    if type(key)=="number" then -- team with target
        sideline.targets = {key}
        sideline.name = rematch.savedTeams:GetUniqueName(team.teamName)
    else
        sideline.name = rematch.savedTeams:GetUniqueName(key)
    end
    -- copy pets and create tags
    for i=1,3 do
        local petID,ability1,ability2,ability3 = unpack(team[i])
        local petInfo = rematch.petInfo:Fetch(petID)
        if not petInfo.isValid then
            petID = team[i][5] -- if petID isn't valid, use its speciesID instead
        end
        sideline.pets[i] = petID
        local tag = rematch.petTags:Create(petID,ability1,ability2,ability3)
        sideline.tags[i] = tag
    end
    -- if team has preferences, create a table for them
    if team.minHP or team.maxHP or team.minXP or team.maxXP then
        sideline.preferences = {
            minHP = team.minHP,
            maxHP = team.maxHP,
            minXP = team.minXP,
            maxXP = team.maxXP,
            allowMM = team.allowMM,
            expectedDD = team.expectedDD
        }
    end
    -- win record
    if team.wins or team.losses or team.draws then
        sideline.winrecord = {
            wins = team.wins,
            losses = team.losses,
            draws = team.draws,
            battles = (team.wins or 0)+(team.losses or 0)+(team.draws or 0)
        }
    end
    -- "General" (index 1) tab from older Rematch is now Ungrouped Teams ("group:none")
    sideline.groupID = (team.tab and team.tab>1) and "group:"..(team.tab-1) or "group:none"
    -- favorited teams are actually in the Favorite Teams groupID, but with a homeID of original group
    if team.favorite then
        sideline.favorite = true
        sideline.homeID = sideline.groupID
        sideline.groupID = "group:favorites"
    end
    sideline.notes = team.notes
    local newTeam = rematch.savedTeams:Create(sideline)  -- create the team
    teamUpgradeMap[key] = newTeam.teamID
    -- save key->teamID mapping and fire event that an old team was converted to a new one
    settings.ConvertedTeams[key] = newTeam.teamID
end

-- imports teams (and groups) from Rematch4Saved
-- note: this should only run on login; teamIDsByName needs to be empty (if this is needed after
-- login then expose teamIDsByName from savedTeams and wipe it here)
function rematch.convert:ImportTeams()
    if not Rematch4Saved then
        return
    end

    wipe(Rematch5SavedGroups)
    wipe(Rematch5SavedTeams)
    wipe(Rematch5SavedTargets)
    wipe(settings.GroupOrder)
    wipe(settings.ExpandedGroups)
    rematch.savedGroups:Validate() -- rebuild group structure

    settings.ConvertedTeams = {} -- lookup table, indexed by Rematch 4 key of the Rematch 5 teamID

    -- first upgrade teams with targets (so they get first dibs on unique names)
    for key,team in pairs(Rematch4Saved) do
        if type(key)=="number" then
            upgradeTeam(key,team)
        end
    end

    -- next upgrade teams without targets
    for key,team in pairs(Rematch4Saved) do
        if type(key)~="number" then
            upgradeTeam(key,team)
        end
    end

    rematch.savedGroups["group:favorites"].showTab = true

    -- next upgrade tabs to groups
    for index,oldGroup in ipairs(Rematch4Settings.TeamGroups) do
        local group = rematch.savedGroups["group:none"]
        if index>1 then -- team tab 1 is now "group:none"
            group = rematch.savedGroups:Create(oldGroup[1]) -- create a new group with the old group name
        end
        group.icon = oldGroup[2]
        group.sortMode = oldGroup[5] and C.GROUP_SORT_WINS or oldGroup[3] and C.GROUP_SORT_CUSTOM or C.GROUP_SORT_ALPHA
        -- if sort order is a list of keys, we want a list of teamIDs
        if oldGroup[3] then
            for _,key in ipairs(oldGroup[3]) do
                if teamUpgradeMap[key] then
                    tinsert(group.teams,teamUpgradeMap[key])
                end
            end
        end
        -- copy preferences
        if oldGroup[4] then
            group.preferences = CopyTable(oldGroup[4])
        end
        -- if room for a tab, make one
        if rematch.savedGroups:GetNumTeamTabs() < C.MAX_TEAM_TABS then
            group.showTab = true
        end
    end

    wipe(teamUpgradeMap) -- no longer need this but keep table in case it needs re-run
    rematch.savedTeams:TeamsChanged(true)

    -- fire an event that teams were converted, with a copy of the old key->new teamID mapping
    rematch.events:Fire("REMATCH_TEAMS_CONVERTED",CopyTable(settings.ConvertedTeams))
    conversionHappened = true

    settings.BackupCount = rematch.utils:GetSize(Rematch5SavedTeams) -- not using rematch.savedTeams:GetNumTeams() since afterTeamsChanged hasn't run yet

end

-- copies queue from Rematch 4.x
function rematch.convert:ImportQueue()
    if not Rematch4Settings then
        return
    end
    wipe(settings.LevelingQueue)
    for i,petID in ipairs(Rematch4Settings.LevelingQueue) do
        local petInfo = rematch.petInfo:Fetch(petID)
        if petInfo.isValid then
            tinsert(settings.LevelingQueue,{petID=petID,petTag=rematch.petTags:Create(petID,"Q"),added=rematch.utils:GetDateTime()})
        end
    end
    rematch.queue:Process()
end

-- returns a lookup table of Rematch4 keys to Rematch5 teamIDs, and whether conversion happened this session
function rematch.convert:GetConvertedTeams()
    return CopyTable(settings.ConvertedTeams),conversionHappened or false
end