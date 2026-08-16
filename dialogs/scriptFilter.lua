local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
rematch.scriptFilter = {}
local settings = rematch.settings

rematch.events:Register(rematch.scriptFilter,"PLAYER_LOGIN",function(self)
    self.petInfo = rematch.petInfo:Create() -- creating a separate petInfo for scripting purposes
    self.altInfo = rematch.petInfo:Create() -- create an alternate one too if needed

    if type(settings.ScriptFilters)~="table" then
        settings.ScriptFilters = {}
    end

	-- if no script filters defined, then create some default scripts
	if #settings.ScriptFilters==0 then
        tinsert(settings.ScriptFilters,{L["Unnamed Pets"], L["-- Collected pets that still have their original name.\n\nreturn petInfo.isOwned and not petInfo.customName"]})
        tinsert(settings.ScriptFilters,{L["Partially Leveled"], L["-- Pets that have earned some xp in battle.\n\nreturn petInfo.xp and petInfo.xp>0"]})
        tinsert(settings.ScriptFilters,{L["Pets Without Rares"], L["-- Collected battle pets that have no rare version.\n\nif not rares then\n  rares = {}\n  for petID in AllPetIDs() do\n    if select(5,C_PetJournal.GetPetStats(petID))==4 then\n      rares[C_PetJournal.GetPetInfoByPetID(petID)]=true\n    end\n  end\nend\n\nif petInfo.canBattle and petInfo.isOwned and not rares[speciesID] then\n  return true\nend"]})
        tinsert(settings.ScriptFilters,{L["Polished Pet Charms"], L["-- Pets with Polished Pet Charms in their source.\n\nreturn (petInfo.sourceText or \"\"):match(\"item:163036\") and true"]})
        rematch.menus:UpdateScriptFilters()        
	end

    rematch.dialog:Register("ScriptFilterDialog",{
        title = L["Script Filter"],
        width = 320,
        cancel = CANCEL,
        accept = SAVE,
        other = L["Test"],
        stayOnOther = true,
        layouts = {
            Default={"Text","EditBox","MultiLineEditBox","SmallText"},
            Results={"Text","EditBox","MultiLineEditBox","SmallText","Feedback"},
        },
        refreshFunc = function(self,info,subject,firstRun)
            self.Text:SetText(L["New Script Filter"])
            self.EditBox:SetLabel(L["Script Name:"])
            self.SmallText:SetText(L["Script filters create custom filters with Lua code.\nSee /docs/scriptfilters.txt for more information."])
            if firstRun then
                self.EditBox:SetText(subject and settings.ScriptFilters[subject][1] or "")
                self.MultiLineEditBox:SetText(subject and settings.ScriptFilters[subject][2] or "")
                rematch.dialog.AcceptButton:SetEnabled(subject and true)
                rematch.dialog.OtherButton:SetEnabled(subject and true)
            end
        end,
        -- Test button to run the script; whether it succeeded or not
        otherFunc = function(self,info,subject)
            -- going to assume it ran fine unless it fails
            self.Feedback:Set("success","Script ran without errors!")
            rematch.dialog:ChangeLayout("Results")
            -- run the filter (any failures will end up in HandleError and do a Feedback:Set("failure",message))
            rematch.filters:Set("Script","Code",self.MultiLineEditBox:GetText())
            rematch.petsPanel:Update()
            -- return focus to code editbox
            rematch.dialog.Canvas.MultiLineEditBox:SetFocus(true)
        end,
        changeFunc = function(self,info,subject)
            local hasCode = self.MultiLineEditBox:GetText():trim():len()>0
            rematch.dialog.AcceptButton:SetEnabled(hasCode and self.EditBox:GetText():trim():len()>0)
            rematch.dialog.OtherButton:SetEnabled(hasCode)
        end,
        acceptFunc = function(self,info,subject)
            if not subject then -- if this is a new script filter, add it to settings.ScriptFilters
                tinsert(settings.ScriptFilters,{self.EditBox:GetText():trim(),self.MultiLineEditBox:GetText():trim()})
            elseif settings.ScriptFilters[subject] then -- this is an existing one, update it
                settings.ScriptFilters[subject][1] = self.EditBox:GetText():trim()
                settings.ScriptFilters[subject][2] = self.MultiLineEditBox:GetText():trim()
            end
            rematch.menus:UpdateScriptFilters()
            -- let the dialog close before applying filters so the separate popup appears for errors
            rematch.timer:Start(0,function()
                rematch.filters:Set("Script","Code",settings.ScriptFilters[subject][2])
                rematch.petsPanel:Update()
            end)
        end,
    })

    rematch.dialog:Register("DeleteScriptFilterDialog",{
        title = L["Delete Script Filter"],
        cancel = NO,
        accept = YES,
        layout = {"Text"},
        refreshFunc = function(self,info,subject)
            self.Text:SetText(format(L["\nAre you sure you want to delete the script filter named %s%s\124r?\n\n"],C.HEX_WHITE,settings.ScriptFilters[subject][1]))
        end,
        acceptFunc = function(self,info,subject)
            tremove(settings.ScriptFilters,subject)
            rematch.menus:UpdateScriptFilters()
        end,
    })

    rematch.dialog:Register("ScriptFilterErrorDialog",{
        title = L["Script Filter Error"],
        cancel = OKAY,
        layout = {"Text","Feedback"},
        refreshFunc = function(self,info,subject)
            self.Text:SetText(format(L["%sThe script filter just loaded has the following error and will not be used:"],C.HEX_WHITE))
            self.Feedback:Set("failure",subject)
        end,
    })

end)

-- list of legacy pet variables to assign to the environment (should use petInfo and not these)
local legacyVariables = { "petID", "speciesID", "customName", "level", "xp", "maxXp", "displayID",
	"isFavorite", "name", "icon", "petType", "creatureID", "sourceText", "description", "isWild",
	"canBattle", "abilityList", "levelList" }
-- these legacy variables (key) are now these (value) in petInfo (should use petInfo and not these)
local legacyNewVariables = {owned="isOwned", tradable="IsTradable", unique="isUnique", obtainable="isObtainable"}

-- call before a filter run; sets up a sandboxed namespace/environment for the code to run (if it has no syntax errors)
-- note each RunFilter while script filter enabled will recreate this environment, so old values are wiped clean
-- returns true if environment successfully created; false otherwise
function rematch.scriptFilter:SetupEnvironment()
    -- get the code being filtered
    local code = rematch.filters:Get("Script","Code")
    -- define the scripting environment
    self.environment = {
        -- common lua
        print=print, table=table, string=string, format=format, pairs=pairs, ipairs=ipairs, select=select, tonumber=tonumber, tostring=tostring, random=random, type=type,
        -- Blizzard pet API
        C_PetJournal=C_PetJournal, C_PetBattles=C_PetBattles,
        -- petInfo
        petInfo=self.petInfo, altInfo=self.altInfo,
        -- iterators
        AllSpeciesIDs=rematch.roster.AllSpecies, AllPetIDs=rematch.roster.AllOwnedPets, AllPets=rematch.roster.AllPets,
        AllAbilities=self.AllAbilities, -- keeping for legacy purposes, but petInfo.abilityList should be used
        -- legacy stuff
        GetBreed=self.GetBreed, -- should use petInfo.breedID or petInfo.breedName
        GetSource=self.GetSource, -- should use petInfo.sourceID
        IsPetLeveling=self.IsPetLeveling, -- should use petInfo.isLeveling
    }
    -- it's critical that lua errors triggered by scripts not go through normal channels, or it will be Rematch that's
    -- believed to be bugged and not the user script >:D
    local ok,func = pcall(function() return assert(loadstring(code,"")) end)
    if ok then -- code successfully parsed into a function, set it to environment
        self.scriptFunc = func
        setfenv(self.scriptFunc,self.environment)
        return true
    else -- code couldn't be turned into a function, throw a custom error with its lua error
        self:CleanupEnvironment() -- leave no environment behind
        self:HandleError(func) -- func (second return from pcall) is the lua error instead of the function
        return false
    end    
end

-- call after a filter run (or a failed pcall) to wipe the environment
function rematch.scriptFilter:CleanupEnvironment()
    self.environment = nil
    self.scriptFunc = nil
end

-- handles syntax errors in scripts by display them in the script dialog (if up) or a new one if it wasn't
-- (it's important these don't look like normal errors so there's no confusion whether the error is with the user script)
function rematch.scriptFilter:HandleError(message)
    message = (message or ""):gsub("^.-string \"\"%]%:",L["line "]) -- strip out the error stack before the error
    if rematch.dialog:GetOpenDialog()=="ScriptFilterDialog" then -- script filter dialog up; display error there
        rematch.dialog.Canvas.Feedback:Set("failure",message)
        rematch.dialog:ChangeLayout("Results")
    else -- script filter dialog isn't up, display a separate dialog
        rematch.dialog:ShowDialog("ScriptFilterErrorDialog",message)
    end
    rematch.filters:Clear("Script")
    rematch.petsPanel:Update()

end

-- legacy: iterator function for all abilities of a single pet; self is a speciesID (or petID); use petInfo.abilityList instead
function rematch.scriptFilter:AllAbilities()
    local i = 0
    local petInfo = rematch.petInfo:Fetch(self)
    return function()
        i = i + 1
        if i <= #petInfo.abilityList then
            return petInfo.abilityList[i],petInfo.levelList[i]
        end
    end
end
-- legacy: gets numeric breed of a pet; self is petID passed in GetBreed(petID); use petInfo.breedID instead
function rematch.scriptFilter:GetBreed()
    return rematch.petInfo:Fetch(self).breedID
end
-- legacy: gets numeric source of a pet; self is petID passed in GetSource(petID); use petInfo.sourceID instead
function rematch.scriptFilter:GetSource()
    return rematch.petInfo:Fetch(self).sourceID
end
-- legacy: gets whether pet is leveling; self is petID passed in IsPetLeveling(petID); use petInfo.isLeveling instead
function rematch.scriptFilter:IsPetLeveling()
    return rematch.petInfo:Fetch(self).isLeveling
end

-- called by RunFilters to evaluate whether the petInfo should list
function rematch.scriptFilter:Evaluate(petInfo)
    local env = self.environment
    if not env then -- environment is not set up (script error?), return true to list all the pets
        return true
    end
    -- copy the values of the legacy stuff to the environment
    for _,var in ipairs(legacyVariables) do
        env[var] = petInfo[var]
    end
    for oldVar,newVar in pairs(legacyNewVariables) do
        env[oldVar] = petInfo[newVar]
    end
    -- now assign the script environment's petInfo (don't use the petInfo given above to prevent tampering)
    self.petInfo:Fetch(petInfo.petID)
    if self.scriptFunc then
        local ok,value = pcall(self.scriptFunc)
        if ok then -- code ran okay, return the result of the function
            return value
        else -- code didn't run okay, handle the error and return true so pet lists regardless
            self:HandleError(value)
            return true
        end
    end
end
