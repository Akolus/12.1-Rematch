local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.loadTeam = {}


local loadPlan = {} -- ordered list of loadouts to change: {slot,petID,ability1,ability2,ability3}
local timeout = 0 -- timeout counter to stop trying to load
local loadingTeamID -- teamID being loaded

-- local functions to perform the load
local startLoad, runLoad, finishLoad
local getExcludePetIDs

-- indexed by pet slot, an issue with the team being loaded (C.UNPLANNED_PET_MISSING for missing pet, C.UNPLANNED_LOW_LEVEL for random pet under 25)
local unplanned = {}

-- call to load a teamID
function rematch.loadTeam:LoadTeamID(teamID)
    if rematch.loadouts:CantSwapPets() then
        return -- can't swap pets, leave
    end
    if teamID and rematch.savedTeams[teamID] then
        rematch.rebuild:ValidateTeamID(teamID,true)
        loadingTeamID = teamID
        startLoad(teamID)
    end
end

-- loads a team by its case-insensitive name and returns the teamID being loaded if one is going to load
function rematch.loadTeam:LoadTeamByName(teamName)
    local teamID = rematch.savedTeams:GetTeamIDByName(teamName:trim())
    if teamID then
        rematch.loadTeam:LoadTeamID(teamID)
        return teamID
    end
end

function rematch.loadTeam:UnloadTeam()
    settings.currentTeamID = nil
    rematch.queue:Process()
    rematch.events:Fire("REMATCH_TEAM_LOADED")
end

-- returns true if a team is currently loading
function rematch.loadTeam:IsTeamLoading()
    return loadingTeamID and true or false
end

-- returns the healthiest version of the petID (possibly same petID if LoadHealthiest not enabled)
function rematch.loadTeam:FindHealthiestPetID(petID,excludePetIDs,allowPetID)
    local bestPetID = petID
    local petInfo = rematch.altInfo:Fetch(petID)
    -- only looking for a healthier pet if setting enabled, player owns more than 1 of the species and petID injured
    if settings.LoadHealthiest and petInfo.count>1 then
        local bestHealth = petInfo.health
        local speciesID = petInfo.speciesID
        local maxHealth, power, speed = petInfo.maxHealth, petInfo.power, petInfo.speed
        for ownedPetID in rematch.roster:AllSpeciesPetIDs(speciesID) do
            petInfo = rematch.altInfo:Fetch(ownedPetID)
            if petInfo.speciesID==speciesID and petInfo.isOwned and petInfo.health>bestHealth then
                -- if LoadHealthiestAny is true, then don't need to match other stats
                if (settings.LoadHealthiestAny or (petInfo.maxHealth==maxHealth and petInfo.power==power and petInfo.speed==speed)) and (ownedPetID==petID or not (excludePetIDs and excludePetIDs[ownedPetID]) or ownedPetID==allowPetID) then
                    bestPetID = ownedPetID
                    bestHealth = petInfo.health
                end
            end
        end
    end
    if bestPetID and petID~=bestPetID and excludePetIDs then
        excludePetIDs[bestPetID] = true -- add this new petID to excluded pets so it's not loaded into another slot
    end
    return bestPetID
end

-- to be called when we want to make sure the already-loaded team has the healthiest pet (leaving battle, revive/bandages)
-- note to self: if this ever does anything on a delay, make sure to update rematch.main's delayedPetBattleClose too
-- (there's already some potential delay/queue processing for rematch.loadouts:SlotPet(), this is ok)
function rematch.loadTeam:AssertHealthiestPet()
    if settings.LoadHealthiest then
        local teamID = settings.currentTeamID
        local team = teamID and rematch.savedTeams[teamID]
        if team then
            -- for asserting healthiest pets, just exclude loaded petIDs (team's pets may want back in and shouldn't be excluded)
            local excludePetIDs = {}
            for i=1,3 do
                local petID = C_PetJournal.GetPetLoadOutInfo(i)
                if petID then
                    excludePetIDs[petID] = true
                end
            end
            for i=1,3 do
                local loadedPetID,ability1,ability2,ability3 = rematch.loadouts:GetLoadoutInfo(i)
                local petInfo = rematch.petInfo:Fetch(loadedPetID)
                if petInfo.idType=="pet" and petInfo.isOwned and not petInfo.isLeveling then
                    local newPetID = rematch.loadTeam:FindHealthiestPetID(loadedPetID,excludePetIDs)
                    if newPetID and loadedPetID~=newPetID then
                        rematch.loadouts:SlotPet(i,newPetID)
                        C_PetJournal.SetAbility(i,1,ability1)
                        C_PetJournal.SetAbility(i,2,ability2)
                        C_PetJournal.SetAbility(i,3,ability3)
                        excludePetIDs[newPetID] = true
                    end
                end
            end
        end
    end
end


-- sets up the load plan and kicks off loading
function startLoad(teamID)
    wipe(loadPlan)
    local team = teamID and rematch.savedTeams[teamID]
    if team then
        -- if all pets in a team are random, then use lenient rule
        local randomRules = C.RANDOM_RULES_LENIENT
        for i=1,3 do
            if rematch.loadouts:GetSpecialPetIDType(team.pets[slot])~="random" then
                randomRules = settings.RandomPetRules -- a non-random pet in team, used saved random rules
            end
        end

        -- for random teams, build list of pets to exclude including slotted pets and incoming pets
        local excludePetIDs = {}
        for i=1,3 do
            local petID = C_PetJournal.GetPetLoadOutInfo(i)
            if petID then
                excludePetIDs[petID] = true
            end
            local petInfo = rematch.petInfo:Fetch(team.pets[i])
            if petInfo.idType=="pet" then
                excludePetIDs[team.pets[i]] = true
            end
        end

        rematch.queue:Update(teamID) -- update queue to the incoming team's preferences
        local pickIndex = 1 -- 1-3 for leveling pet to load from queue

        wipe(unplanned)

        -- add each pet to the load plan for the team
        for slot=1,3 do
            local petID = team.pets[slot]
            rematch.loadouts:SetSlotPetID(slot,petID) -- set slot's petID regardless if it loads for special slots
            if petID then
                local petInfo = rematch.petInfo:Fetch(petID)
                -- every pet being slotted must be a valid owned pet BattlePet-0-etc
                if petID==0 then -- leveling pet
                    local levelingPetID = rematch.queue:GetTopPick(pickIndex)
                    if levelingPetID then
                        tinsert(loadPlan,{slot,levelingPetID}) -- add leveling pet to load plan
                        excludePetIDs[levelingPetID] = true -- exclude leveling pet from potential randoms
                    elseif settings.QueueRandomWhenEmpty then -- if a leveling pet wasn't found and Random Pet When Queue Empty enabled, pick a random pet
                        local levelingPetID = rematch.randomPets:PickRandomPetID({excludePetIDs=excludePetIDs,levelable=(not settings.QueueRandomMaxLevel)})
                        if levelingPetID then
                            tinsert(loadPlan,{slot,levelingPetID})
                            excludePetIDs[levelingPetID] = true
                        end
                    end
                    pickIndex = pickIndex + 1
                elseif petInfo.idType=="pet" and petInfo.isValid and petInfo.isOwned and petInfo.isSummonable then
                    local ability1,ability2,ability3 = rematch.petTags:GetAbilities(team.tags[slot])
                    local allowPetID = rematch.loadouts:GetLoadoutInfo(slot) -- if pet is replacing one already in the slot, allow keeping this one
                    local healthiestPetID = rematch.loadTeam:FindHealthiestPetID(petID,excludePetIDs,allowPetID) -- returns same petID if option disabled
                    tinsert(loadPlan,{slot,healthiestPetID,ability1,ability2,ability3})
                    excludePetIDs[healthiestPetID] = true
                elseif petInfo.idType=="pet" and not petInfo.isValid then
                    local newPetID = rematch.petTags:FindPetID(team.tags[slot],excludePetIDs)
                    if newPetID then
                        tinsert(loadPlan,{slot,newPetID,ability1,ability2,ability3})
                        excludePetIDs[newPetID] = true
                    end
                elseif petInfo.idType=="random" then
                    local petType = tonumber(petID:match("^random:(%d+)"))
                    local randomPetID = rematch.randomPets:PickRandomPetID({petType=petType,rules=randomRules,excludePetIDs=excludePetIDs})
                    if randomPetID then
                        local petInfo = rematch.petInfo:Fetch(randomPetID)
                        if settings.RandomAbilitiesToo then -- if Random Abilities Too enabled, load random abilities too
                            tinsert(loadPlan,{slot,randomPetID,petInfo.abilityList[1+(random(100)>50 and 3 or 0)],petInfo.abilityList[2+(random(100)>50 and 3 or 0)],petInfo.abilityList[3+(random(100)>50 and 3 or 0)]})
                        else -- otherwise let game choose abilities and only slot petID
                            tinsert(loadPlan,{slot,randomPetID})
                        end
                        if settings.WarnWhenRandomNot25 and (not petInfo.level or petInfo.level<25) then
                            unplanned[slot] = {problem=C.UNPLANNED_LOW_LEVEL,petID=randomPetID}
                        end
                        excludePetIDs[randomPetID] = true -- add this random pet to exclude for other slots
                    end
                elseif not settings.DontWarnMissing then
                    unplanned[slot] = {problem=C.UNPLANNED_PET_MISSING,petID=petID}
                end
            end
        end

    end
    timeout = 0 -- start timeout counter
    runLoad() -- kick off the load
end

-- goes through the load plan and removes anything that no longer needs to be loaded, returning true if something
-- still needs to be loaded; false if all done
function updatePlan()
    local somethingNeedsLoaded = false -- becomes true if something still needs loaded
    -- go through plan and remove anything that's been loaded; if any plan should be entirely removed, change slot to "remove"
    for _,plan in ipairs(loadPlan) do
        local slot,petID,ability1,ability2,ability3 = unpack(plan)
        if type(slot)~="number" and not (slot==1 or slot==2 or slot==3) then
            plan[1] = "remove" -- this slot is not valid, remove from plan
        else
            local loadedPetID,loadedAbility1,loadedAbility2,loadedAbility3,loadedLocked = C_PetJournal.GetPetLoadOutInfo(slot)
            if loadedLocked then
                plan[1] = "remove" -- this slot is locked, remove from plan
            else
                if petID and loadedPetID==petID then
                    plan[2] = nil -- pet doesn't need loaded
                end
                if not ability1 or ability1==0 or (ability1 and loadedAbility1==ability1) then
                    plan[3] = nil -- ability1 doesn't need loaded
                end
                if not ability2 or ability2==0 or (ability2 and loadedAbility2==ability2) then
                    plan[4] = nil -- ability2 doesn't need loaded
                end
                if not ability3 or ability3==0 or (ability3 and loadedAbility3==ability3) then
                    plan[5] = nil -- ability3 doesn't need loaded
                end
                if not plan[2] and not plan[3] and not plan[4] and not plan[5] then
                    plan[1] = "remove" -- petID and all abilities loaded, remove from plan
                end
            end
        end
    end
    -- remove any plans flags for removal
    for i=#loadPlan,1,-1 do
        if loadPlan[i][1]=="remove" then
            tremove(loadPlan,i)
        else
            somethingNeedsLoaded = true
        end
    end
    return somethingNeedsLoaded
end

-- slots the pets planned from startLoad by going through each record and loading it if it's not loaded
function runLoad()
    if timeout<C.TEAM_LOAD_TIMEOUT and updatePlan() then -- if retries remaining and something needs loaded
        timeout = timeout + 1
        for _,plan in ipairs(loadPlan) do
            if plan[2] then -- petID needs loaded into this slot
                rematch.loadouts:SlotPet(plan[1],plan[2])
            end
            if plan[3] then
                C_PetJournal.SetAbility(plan[1],1,plan[3]) -- ability1
            end
            if plan[4] then
                C_PetJournal.SetAbility(plan[1],2,plan[4]) -- ability2
            end
            if plan[5] then
                C_PetJournal.SetAbility(plan[1],3,plan[5]) -- ability3
            end
        end
        -- update plan now that stuff loaded; if something remains to be loaded, come back in a bit to continue loading
        if updatePlan() then
            rematch.timer:Start(C.TEAM_LOAD_WAIT,runLoad)
            return
        end
    end
    -- if reached here, either we hit timeout or team is fully loaded
    finishLoad()
end

-- finishes loading and alerts if any pets missing/replaced and fires REMATCH_TEAM_LOADED
function finishLoad()
    settings.currentTeamID = loadingTeamID
    -- SetSlotPetID to set special slots after team loads
    local team = rematch.savedTeams[loadingTeamID]
    if not team then
        return
    end
    for slot=1,3 do
        local petID = team.pets[slot]
        rematch.loadouts:SetSlotPetID(slot,petID) -- this sets special slots
    end
    -- if we just loaded a team and we have a mini target panel up but panel should not stay up, dismiss it
    if rematch.layout:GetSubview()=="target" and not rematch.loadedTargetPanel:ShouldShowTarget() then
        rematch.frame:Configure()
    end
    if team.notes and settings.ShowNotesOnLoad then
        rematch.cardManager:ShowCard(rematch.notes,loadingTeamID)
    end
    -- if any pets missing or unable to be loaded, show a warning
    rematch.loadTeam:WarnProblemLoads()
    loadingTeamID = nil
    rematch.events:Fire("REMATCH_TEAM_LOADED",settings.currentTeamID)
end

function rematch.loadTeam:WarnProblemLoads()
    local problem
    for slot=1,3 do
        if unplanned[slot] and unplanned[slot].problem==C.UNPLANNED_PET_MISSING then
            problem = C.UNPLANNED_PET_MISSING
        elseif not problem and unplanned[slot] and unplanned[slot].problem==C.UNPLANNED_LOW_LEVEL then
            problem = C.UNPLANNED_LOW_LEVEL -- only care about this if no missing pets
        end
    end
    if not problem then
        return
    end
    rematch.dialog:Register("ProblemLoad",{
        title = problem==C.UNPLANNED_PET_MISSING and L["Pets are missing"] or L["Low level random pet"],
        accept = OKAY,
        layout = {"Text","TeamWarning","CheckButton"},
        refreshFunc = function(self,info,subject,firstRun)
            self.Text:SetText(problem==C.UNPLANNED_PET_MISSING and L["Pets are missing in the team just loaded."] or L["A low level random pet just loaded."])
            self.CheckButton:SetText(problem==C.UNPLANNED_PET_MISSING and L["Don't Warn About Missing Pets"] or L["Warn For Pets Below Max Level"])
            self.CheckButton:SetChecked(problem==C.UNPLANNED_LOW_LEVEL) -- if seeing this dialog, then check is only checked for low level
            for i=1,3 do
                local petID
                if unplanned[i] and unplanned[i].problem==problem then
                    self.TeamWarning.Warnings[i]:Show()
                    petID = unplanned[i].petID
                else
                    self.TeamWarning.Warnings[i]:Hide()
                    petID = rematch.loadouts:GetLoadoutInfo(i)
                end
                self.TeamWarning.Pets[i].petID = petID
                self.TeamWarning.Pets[i]:FillPet(petID)
            end
        end,
        acceptFunc = function(self,info,subject)
            if problem==C.UNPLANNED_LOW_LEVEL and not self.CheckButton:GetChecked() then
                settings.WarnWhenRandomNot25 = false
                rematch.frame:Update()
            elseif problem==C.UNPLANNED_PET_MISSING and self.CheckButton:GetChecked() then
                settings.DontWarnMissing = true
                rematch.frame:Update()
            end
        end
    })
    rematch.dialog:ShowDialog("ProblemLoad")
end