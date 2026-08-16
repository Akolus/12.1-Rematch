local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings

--[[

    Rematch refers to pets as a single number or string, depending on their context. This reference,
    called a petID, can be one of nine idTypes:

        idType      example petID value    description
        ----------  ---------------------  -----------------------------------
        "pet"       "Battle-0-0000000etc"  a player-owned pet in the journal
        "species"   42                     speciesID species number
        "leveling"  0                      leveling slot
        "ignored"   "ignored"              ignored slot
        "link"      "battlepet:42:25:etc"  linked pet
        "battle"    "battle:2:1"           pet in battle (battle:owner:index)
        "random"    "random:10"            random mechanical pet (random:0 for any pet type)
        "unnotable" "unnotable:npcID"      pet of a target not in targetData's notableTargets
        "empty"     nil or "blank"         no pet
        "unknown"   (anything else)        indecipherable/undefined pet

    To simplify getting information about these different types of pets, to eliminate the scattered
    code to independently call the various API through C_PetJournal and C_PetBattles, and to reduce
    redundant API calls for information already retrieved (or information not used!), this module
    encapsulates a "front end" for information about pets.

    To use, fetch a petID to make it the pet of interest (which can be any of the above strings or numbers):

        petInfo:Fetch(petID)

    After a pet of interest is fetched, simply index the stat you want:

        print(petInfo.name,"is level",petInfo.level,"and breed",petInfo.breedName)

    The stat can be any of these:

        petID: this is the pet reference Fetched (string, number, link, etc)
        idType: "pet" "species" "leveling" "ignored" "link" "battle" "random" or "unknown" (string)
        speciesID: numeric speciesID of the pet (integer)
        customName: user-renamed pet name (string)
        speciesName: name of the species (string)
        name: customName if defined, speciesName otherwise (string)
        level: whole level 1-25 (integer)
        xp: amount of xp in current level (integer)
        maxXp: total xp to reach next level (integer)
        fullLevel: level+xp/maxXp (float)
        displayID: id of the pet's skin (integer)
        isFavorite: whether pet is favorited (bool)
        icon: fileID of pet's icon or specific filename (integer or string)
        petType: numeric type of pet 1-10 (integer)
        creatureID: npcID of summoned pet (integer)
        sourceText: formatted text about where pet is from (string)
        loreText: "back of the card" lore (string)
        isWild: whether the pet is found in the wild (bool)
        canBattle: whether pet can battle (bool)
        isTradable: whether pet can be caged (bool)
        isUnique: whether only one of pet can be learned (bool)
        isObtainable: whether this pet is in the journal (bool)
        health: current health of the pet (integer)
        maxHealth: maximum health of the pet (integer)
        power: power stat of the pet (integer)
        speed: speed stat of the pet (integer)
        rarity: rarity 1-4 of pet (integer)
        isDead: whether the pet is dead (bool)
        isInjured: whether the pet has less than max health (bool)
        isSummonable: whether the pet can be summoned (bool)
        summonError: the error ID why a pet can't be summoned
        summonErrorText: the error text why a pet can't be summoned
        summonShortError: shortened text of why a pet can't be summoned (for pet card stat)
        isRevoked: whether the pet is revoked (bool)
        abilityList: table of pet's abilities (table)
        levelList: table of pet's ability levels (table)
        valid: whether the petID is valid and petID is not missing (bool)
        owned: whether the petID is a valid pet owned by the player (bool)
        count: number of pet the player owns (integer)
        maxCount: maximum number of this pet the player can own (integer)
        countColor: hex color code for pet count (white for 0, green for count<max, red for count=max)
        hasBreed: whether pet can battle and there's a breed source (bool)
        breedID: 3-12 for known breeds, 0 for unknown breed, nil for n/a (integer)
        breedName: text version of breed like P/P or S/B (string)
        possibleBreedIDs: list of breedIDs possible for the pet's species (table)
        possibleBreedNames: list of breedNames possible for the pet's species (table)
        numPossibleBreeds: number of known breeds for the pet (integer)
        needsFanfare: whether a pet is wrapped (bool)
        battleOwner: whether ally(1) or enemy(2) pet in battle (integer)
        battleIndex: 1-3 index of pet in battle (integer)
        isSlotted: whether pet is slotted (bool)
        inTeams: whether pet is in any teams (pet and species idTypes only) (bool)
        numTeams: number of teams the pet belongs to (pet and species only) (integer)
        sourceID: the source index (1=Drop, 2=Quest, 3=Vendor, etc) of the pet (integer)
        moveset: the exact moveset of the pet ("123,456,etc") (string)
        speciesAt25: whether the pet has a version at level 25 (bool)
        hasNotes: whether the pet has notes (bool)
        notes: the text of the pet's notes (string)
        isLeveling: whether the pet is in the queue (bool)
        isSummoned: whether the pet is currently summoned (bool)
        expansionID: the numeric index of the expansion the pet is from: 0=classic, 1=BC, 2=WotLK, etc. (integer)
        expansionName: the name of the expansion the pet is from (string)
        isSpecialType: whether the petid is a leveling, random or ignored (bool)
        passive: the "racial" or passive text of the pet type (string)
        shortHealthStatus: the numeric health at max health, or percent if injured, or DEAD if dead
        longHealthStatus: a hp/maxHp (percent%) description of pet health
        npcID: the npcID of the target for an unnotable petID
        tint: either "red" for revoked/wrong-faction pets, "grey" for otherwise unsummonable, nil for no tint
        strongVs: a table of [ability]=petType of attacks that do increased damage (table)
        toughVs: the petType of attack that this pet takes reduced damage from (integer)
        vulnerableVs: the petType of attack that this pet takes increased damage from (integeter)
        formattedName: name of pet with color codes for its rarity
        isStickied: whether the pet is temporarily stickied to top of pet list (wrapped) (bool)

    If a separate petInfo is needed (such as doing a comparison of one pet against another), then you can
    create a new petInfo with a :Create() from any other petInfo:

        local myPetInfo = rematch.petInfo:Create()

    At the end of this file, rematch.altInfo is created as an alternative to rematch.petInfo for this purpose.

    How it works:

        petInfo:Fetch(petID) will check if the petID is different from the last-fetched pet. If so,
        it will wipe the existing information and store the petID and idType within the table, ready
        for stats to be queried/indexed.

        The created petInfo table has a __index metamethod to look up indexes that don't exist.

        If a petInfo[stat] has no value, the __index metamethod will call the appropriate API
        (depending on the idType of the pet) and fill in its value. Future references to petInfo[stat]
        will have a value and not invoke a __index.

    Also:

        The script filter system has its own petInfo that's already fetched for each pet. Script filters
        do not need to fetch a the current pet.

        petInfo:Reset() will force a wipe of information.

        When the petID is guaranteed to be from the journal (either a valid, owned petID string or
        speciesID), Fetch(petID,true) will skip the test of its type to improve performance.

        link format: "battlepet:<speciesID>:<level>:<rarity>:<health>:<power>:<speed>"
]]


-- if an alternate petInfo needs made, use: local altInfo = rematch.petInfo:Create()

local GetPetInfoByPetID = C_PetJournal.GetPetInfoByPetID
local GetPetInfoBySpeciesID = C_PetJournal.GetPetInfoBySpeciesID

-- local functions defined here
local fillInfoByPetID, fillInfoBySpeciesID, getIDType, fetch, reset, lookup, create

-- each stat comes from a function. this table says what function populates each stat
local stats = {
    speciesID="General", customName="General", level="General", xp="General", maxXp="General",
    displayID="General", isFavorite="General", speciesName="General", name="General", icon="General",
    petType="General", creatureID="General", sourceText="General", loreText="General", isWild="General",
    canBattle="General", isTradable="General", isUnique="General", isObtainable="General", npcID="General",
    isValid="Valid", isOwned="Valid",
    health="Stats",maxHealth="Stats", power="Stats", speed="Stats", rarity="Stats", color="Stats",
    isDead="Dead", isInjured="Dead",
    shortHealthStatus="Status",longHealthStatus="Status",
    isRevoked="Other", needsFanfare="Other",
    isSummonable="SummonInfo", summonError="SummonInfo", summonErrorText="SummonInfo",
    isSummoned="IsSummoned",
    abilityList="Abilities", levelList="Abilities",
    usableAbilities="UsableAbilities",
    strongVs="StrongVs",
    toughVs="ToughVs", vulnerableVs="ToughVs",
    count="Count", maxCount="Count", countColor="Count",
    fullLevel="FullLevel",
    suffix="Suffix", petTypeName="Suffix",
    battleOwner="Battle", battleIndex="Battle",
    isSlotted="Slotted",
    breedID="Breed", breedName="Breed", hasBreed="Breed",
    possibleBreedIDs="PossibleBreeds", possibleBreedNames="PossibleBreeds", numPossibleBreeds="PossibleBreeds",
    inTeams="Teams", numTeams="Teams",
    sourceID="Source",
    moveset="Moveset",
    isSpeciesAt25="SpeciesAt25",
    isMovesetAt25="MovesetAt25",
    notes="Notes", hasNotes="Notes",
    isLeveling="IsLeveling",
    expansionID="Expansion", expansionName="Expansion",
    isSpecialType="Special",
    passive="Passive",
    marker="PetMarker",
    tint="Tint",
    formattedName="FormattedName",
    isStickied="Stickied",
}
-- and each function is a member of this table, called during a lookup to populate the above stats
local funcs = {}
-- the General func has to deal with 7 idTypes separately, so it has subfuncs broken out into the following table
local generalSubFuncs
-- indexed by petInfo reference, this contains tables like abilityList and fetchedFuncs reused to reduce garbage
local reusedTables = {}

--[[ stat-pulling funcs ]]

-- the majority of information about a pet will come from the General function, which is broken up
-- by idTypes in generalSubFuncs to make lookups a little quicker
function funcs:General()
    local idType = self.idType
    if idType and generalSubFuncs[idType] then
        generalSubFuncs[idType](self)
    else
        self.name = L["Unknown"]
        self.icon = C.UNKNOWN_ICON
    end
end

-- verifies the pet contains information (not a server-reassigned petID or bad speciesID) and if it's owned
function funcs:Valid()
    local idType = self.idType
    if idType=="pet" and self.speciesID then -- if speciesID read ok then "pet" petID is functional
        self.isValid = true
        self.isOwned = true -- owned is only true if regular petID is a "Battle-0-etc" petID
    elseif (idType=="species" and self.name) or (idType=="leveling" or idType=="ignored" or idType=="random" or idType=="unnotable") or (idType=="link" and self.name) or (idType=="battle" and self.name) then
        self.isValid = true
        self.isOwned = false
    else
        self.isValid = false
        self.isOwned = false
    end
end

-- gets rarity, health, power and speed stats if possible
function funcs:Stats()
    local idType = self.idType
    local rarity,health,maxHealth,power,speed
    if idType=="pet" then
        health,maxHealth,power,speed,rarity = C_PetJournal.GetPetStats(self.petID)
    elseif idType=="link" then
        rarity,health,power,speed = self.petID:match("battlepet:%d+:%d+:(%d+):(%d+):(%d+):(%d+)")
        if rarity then
            rarity = tonumber(rarity)+1 -- links are 0-3 rarity intead of 1-4
            health = tonumber(health)
            maxHealth = tonumber(health)
            power = tonumber(power)
            speed = tonumber(speed)
        end
    elseif idType=="battle" then -- pets in a battle fetch live stats (but note values cache!)
        local owner = self.battleOwner
        local index = self.battleIndex
        if C_PetBattles.GetPetSpeciesID(owner,index) then
            rarity = C_PetBattles.GetBreedQuality(owner,index)+1
            health = C_PetBattles.GetHealth(owner,index)
            maxHealth = C_PetBattles.GetMaxHealth(owner,index)
            power = C_PetBattles.GetPower(owner,index)
            speed = C_PetBattles.GetSpeed(owner,index)
        end
    end
    if not self.canBattle then -- for non-battle pets, hide all stats except rarity
        health = nil
        maxHealth = nil
        power = nil
        speed = nil
    end
    self.rarity = rarity
    self.health = health
    self.maxHealth = maxHealth
    self.power = power
    self.speed = speed
    if rarity then
        self.color = rematch.utils:GetRarityColor(rarity-1)
    end
end

-- whether a pet isDead or isInjured
function funcs:Dead()
    if self.maxHealth and self.maxHealth > 0 then
        self.isDead = self.health==0
        self.isInjured = self.health<self.maxHealth
    end
end

-- text versions of pet status (health so far)
function funcs:Status()
    local health,maxHealth = self.health,self.maxHealth
    if self.isDead then -- if pet is dead, use 'Dead' text rather than 0%
        self.shortHealthStatus = DEAD
        self.longHealthStatus = format("%s%d/%d (%s)\124r",C.HEX_RED,health,maxHealth,DEAD)
    elseif self.isInjured then -- if not at full life, display a percent instead of a number
        self.shortHealthStatus = format("%d%%",health*100/maxHealth)
        self.longHealthStatus = format("%s%d/%d (%d%%)\124r",C.HEX_RED,health,maxHealth,health*100/maxHealth)
    else -- at full life, display actual health (same as maxHealth)
        self.shortHealthStatus = tostring(maxHealth)
        self.longHealthStatus = tostring(maxHealth)
    end
end

-- intended for journal listing that probably only happens when updating display
function funcs:Other()
    if self.idType=="pet" then
        local petID = self.petID
        self.isRevoked = C_PetJournal.PetIsRevoked(petID)
        self.needsFanfare = C_PetJournal.PetNeedsFanfare(petID)
    end
end

-- isSummonable moved to this for new GetPetSummonInfo
function funcs:SummonInfo()
    if self.idType=="pet" then
        local isSummonable, error, errorText = C_PetJournal.GetPetSummonInfo(self.petID)
        if not isSummonable and error==Enum.PetJournalError.PetIsDead then
            isSummonable = true -- treating summonable pets that are just dead as summonable
            -- (if there's another reason it's unsummonable, then it's unlikely it could be dead too)
        end
        self.isSummonable = isSummonable
        self.summonError = error
        self.summonErrorText = errorText -- this text is a bit too long for pet card but usable in tooltips
        self.summonShortError = error and C.SUMMON_SHORT_ERRORS[error] or L["Can't Summon"] -- usable for pet card
    end
end

-- whether the pet is currently summoned
function funcs:IsSummoned()
    self.isSummoned = C_PetJournal.GetSummonedPetGUID() == self.petID
end

-- fills petInfo.abilityList and petInfo.levelList tables
function funcs:Abilities()
    if self.speciesID then
        local abilityList = reusedTables[self].abilityList
        local levelList = reusedTables[self].levelList
        C_PetJournal.GetPetAbilityList(self.speciesID,abilityList,levelList)
        self.abilityList = abilityList
        self.levelList = levelList
    end
end

-- fills petInfo.usableAbilities to be a lookup table of abilities the pet can use at their current level
function funcs:UsableAbilities()
    local usableAbilities = reusedTables[self].usableAbilities
    wipe(usableAbilities)
    local level = self.level
    if level and level > 0 then
        local abilityList = self.abilityList
        local levelList = self.levelList
        for i=1,6 do
            local listLevel = levelList[i]
            if listLevel and listLevel <= level then
                usableAbilities[abilityList[i]] = true
            end
        end
    end
    self.usableAbilities = usableAbilities
end

-- fills petInfo.strongVs table indexed by abilityID and the petType the ability is strong against
function funcs:StrongVs()
    local strongVs = reusedTables[self].strongVs
    local abilityList = self.abilityList
    wipe(strongVs)
    if abilityList then
        for _,abilityID in ipairs(abilityList) do
            local _,_,_,_,_,_,abilityType,noHints = C_PetBattles.GetAbilityInfoByID(abilityID)
            if not noHints and abilityType then -- skipping self heals and such that don't attack
                strongVs[abilityID] = C.HINTS_OFFENSE[abilityType][1]
            end
        end
    end
    self.strongVs = strongVs
end

-- sets toughVs to the pet type the pet is tough against ()
function funcs:ToughVs()
    local hint = C.HINTS_DEFENSE[self.petType]
    self.toughVs = hint and hint[2]
    self.vulnerableVs = hint and hint[1]
end

-- gets the current number of collected versions of the pet and the max allowed copies
function funcs:Count()
    if self.speciesID then
        local count,maxCount = C_PetJournal.GetNumCollectedInfo(self.speciesID)
        self.count,self.maxCount = count,maxCount
        if not count or count==0 then
            self.countColor = C.HEX_WHITE
        elseif count==maxCount then
            self.countColor = C.HEX_RED
        elseif count<maxCount then
            self.countColor = C.HEX_GREEN
        end
    end
end

-- gets the pet's level plus their xp/maxXp, so a level 23 pet at 45% towards level 24 is fullLevel 23.45
function funcs:FullLevel()
    local xp = self.xp
    if xp then
        self.fullLevel = self.level + (xp/self.maxXp)
    else
        self.fullLevel = self.level
    end
end

-- suffix is not localized and used for icon names (Water in Pet_Type_Water), petTypeName is the localized name of the pet type (Aquatic)
function funcs:Suffix()
    local petType = self.petType
    if petType then
        self.suffix = PET_TYPE_SUFFIX[petType]
        self.petTypeName = _G["BATTLE_PET_NAME_"..petType]
    end
end

-- pulls battleOwner and battleIndex from the "battle" petID
function funcs:Battle()
    if self.idType=="battle" then
       local owner,index = self.petID:match("battle:(%d):(%d)")
       self.battleOwner = tonumber(owner)
       self.battleIndex = tonumber(index)
    end
end

 -- whether the pet is slotted
function funcs:Slotted()
    local idType = self.idType
    self.isSlotted = (idType=="pet" and C_PetJournal.PetIsSlotted(self.petID)) or (idType=="battle" and self.battleOwner==1)
end

-- the breed of an owned pet in the journal, a link or in battle
function funcs:Breed()
    local source = rematch.breedInfo:GetBreedSource()
    local idType = self.idType
    if source and self.isValid and self.canBattle and (idType=="pet" or idType=="link" or idType=="battle") then
        local breedID,breedName
        if source=="BattlePetBreedID" then
            if idType=="pet" or idType=="link" then
                breedID = BPBID_Internal.CalculateBreedID(self.speciesID,self.rarity,self.level,self.maxHealth,self.power,self.speed,false,false)
            elseif idType=="battle" then
                breedID = BPBID_Internal.breedCache[self.battleIndex + (self.battleOwner==2 and 3 or 0)]
            end
        elseif source=="PetTracker" then
            if idType=="pet" and PetTracker and PetTracker.Pet then
                breedID = PetTracker.Pet(self.petID):GetBreed()
            elseif idType=="link" and PetTracker and PetTracker.Predict then
                breedID = PetTracker.Predict:Breed(self.speciesID,self.level,self.rarity,self.maxHealth,self.power,self.speed)
            elseif idType=="battle" and PetTracker and PetTracker.Battle then
                breedID = PetTracker.Battle(self.battleOwner,self.battleIndex):GetBreed()
            end
        end
        if type(breedID)~="number" then
            breedID = 0
            breedName = self.numPossibleBreeds==0 and "NEW" or "???"
        end
        self.breedID = breedID
        self.breedName = breedName or rematch.breedInfo:GetBreedNameByID(breedID)
        self.hasBreed = true
    else
        self.hasBreed = false
    end
end

-- the possible breeds of the pet's species
function funcs:PossibleBreeds()
    local possibleBreedIDs = reusedTables[self].possibleBreedIDs
    local possibleBreedNames = reusedTables[self].possibleBreedNames
    wipe(possibleBreedIDs)
    wipe(possibleBreedNames)
    local source = rematch.breedInfo:GetBreedSource()
    local speciesID = self.speciesID
    if source and type(speciesID)=="number" and self.canBattle then
        local data -- table to contain possible breeds
        if source=="BattlePetBreedID" then
            if not BPBID_Arrays.BreedsPerSpecies then
                BPBID_Arrays.InitializeArrays()
            end
            data = BPBID_Arrays.BreedsPerSpecies[speciesID]
        elseif source=="PetTracker" then
            data = PetTracker.SpecieBreeds[speciesID]
        end
        -- if there's a table of breeds, copy them to possibleBreeds
        if data and type(data)=="table" then
            for _,breed in ipairs(data) do
                tinsert(possibleBreedIDs,breed)
                tinsert(possibleBreedNames,rematch.breedInfo:GetBreedNameByID(breed))
            end
        end
        self.possibleBreedIDs = possibleBreedIDs
        self.possibleBreedNames = possibleBreedNames
        self.numPossibleBreeds = #possibleBreedIDs
    end
end

-- a moveset is the exact abilities (AND their order) of a pet
function funcs:Moveset()
    if type(self.abilityList)=="table" then
        self.moveset = table.concat(self.abilityList,",")
    else
        self.moveset = nil
    end
end

-- isSpeciesAt25 is true if there's a version of this pet's species at level 25
function funcs:SpeciesAt25()
    self.isSpeciesAt25 = rematch.collectionInfo:IsSpeciesAt25(self.speciesID)
end

-- isMovesetAt25 is true if there's a pet of any species with this moveset at level 25
function funcs:MovesetAt25()
    self.isMovesetAt25 = rematch.collectionInfo:IsMovesetAt25(self.moveset)
end

function funcs:Notes()
    local notes = settings.PetNotes[self.speciesID]
    self.notes = notes
    self.hasNotes = notes and true or false
end

-- sets expansionID and expansionName to describe the expansion the pet is from
function funcs:Expansion()
    local expansionID = rematch.speciesInfo:GetExpansion(self.speciesID)
    if expansionID then
        self.expansionID = expansionID
        self.expansionName = _G["EXPANSION_NAME"..expansionID]
    end
end

-- sourceID is 1=Drop, 2=Quest, 3=Vendor, etc.
function funcs:Source()
    self.sourceID = rematch.speciesInfo:GetSourceID(self.speciesID)
end

-- whether the petID is in a team and how many teams
function funcs:Teams()
    local numTeams = rematch.savedTeams and rematch.savedTeams:GetNumTeamsWithPet(self.petID) or 0
    self.inTeams = numTeams > 0
    self.numTeams = numTeams
end

-- whether the pet is not an actual pet but a special non-pet type
function funcs:Special()
    local idType = self.idType
    self.isSpecialType = idType=="leveling" or idType=="random" or idType=="ignored" or idType=="unnotable"
end

-- the passive or racial text for the pet type
function funcs:Passive()
    local petType = self.petType
    if petType and not self.isSpecialType then
        self.passive = select(5,C_PetBattles.GetAbilityInfoByID(PET_BATTLE_PET_TYPE_PASSIVES[petType])):match("^.-\r\n(.-)\r"):gsub("%[percentage.-%]%%","4%%")
    end
end

-- the numeric 1-8 marker assigned to the speciesID
function funcs:PetMarker()
    local speciesID = self.speciesID
    if speciesID then
        self.marker = settings.PetMarkers[speciesID]
    end
end

-- tint is "red" if the pet is unsummonable and owned (revoked or wrong faction), or "grey" if
-- otherwise unsummonable (uncollected speciesID) or nil if no tint
function funcs:Tint()
    if not self.isSummonable and not self.isSpecialType then
        self.tint = self.isOwned and "red" or "grey"
    end
end

-- true/false if pet is in the leveling queue
-- note: if queue is mid-process, this is unreliable; check the settings.LevelingQueue then
function funcs:IsLeveling()
    self.isLeveling = rematch.queue:IsPetLeveling(self.petID)
end

-- returns the pet name with color codes
function funcs:FormattedName()
    if settings.ColorPetNames then
        local color = self.color
        self.formattedName = format("%s%s\124r",color and color.hex or C.HEX_WHITE,self.name)
    else
        self.formattedName = self.name
    end
end

function funcs:Stickied()
    self.isStickied = rematch.sort:IsPetIDStickied(self.petID)
end

------------------------------------------------------------------------------------------------

--[[ helper funcs (these are declared local at the top here) ]]

-- lookup table of sub-functions to fill General stats depending on the pet's idType
generalSubFuncs = {
    pet =       function(self)
                    fillInfoByPetID(self,self.petID)
                end,
    species =   function(self)
                    fillInfoBySpeciesID(self,self.petID) -- petID here is a number (speciesID)
                end,
    leveling =  function(self)
                    self.name = L["Leveling Pet"]
                    self.icon = C.LEVELING_ICON
                    self.displayID = "Interface\\Buttons\\talktomequestion_ltblue.m2"
                end,
    ignored =   function(self)
                    self.name = L["Ignored Pet"]
                    self.icon = C.IGNORED_ICON
                    self.displayID = "Interface\\Buttons\\talktomered.m2"
                end,
    link =      function(self)
                    local speciesID,level = self.petID:match("battlepet:(%d+):(%d+):")
                    speciesID = tonumber(speciesID)
                    if speciesID then
                        fillInfoBySpeciesID(self,speciesID)
                        self.level = tonumber(level) -- rarity, health, power and speed comes from Stats
                    end
                end,
    battle =    function(self)
                    local owner = self.battleOwner
                    local index = self.battleIndex
                    if owner==1 then -- WoW 12.1: use live battle APIs for ally pets while in battle
                        local speciesID = C_PetBattles.GetPetSpeciesID(owner,index)
                        if speciesID then
                            fillInfoBySpeciesID(self,speciesID)
                            self.name = C_PetBattles.GetName(owner,index) or self.name
                            self.speciesName = self.name or self.speciesName
                            self.level = C_PetBattles.GetLevel(owner,index)
                            self.displayID = C_PetBattles.GetDisplayID(owner,index)
                        end
                    elseif owner==2 then
                        local speciesID = C_PetBattles.GetPetSpeciesID(owner,index)
                        if speciesID then
                            fillInfoBySpeciesID(self,speciesID)
                            self.name = C_PetBattles.GetName(owner,index) or self.name
                            self.speciesName = self.name or self.speciesName
                            self.level = C_PetBattles.GetLevel(owner,index)
                            self.displayID = C_PetBattles.GetDisplayID(owner,index)
                        end
                    end
                end,
    random =    function(self)
                    -- petType always defined as 0-10 for random pets
                    local petType = math.min(10,math.max(0,tonumber(self.petID:match("random:(%d+)")) or 0))
                    self.petType = petType
                    -- name is "Random Pet" or "Random Humanoid", "Random Dragonkin", etc
                    local suffix = PET_TYPE_SUFFIX[petType]
                    self.name = suffix and format(L["Random %s"],_G["BATTLE_PET_NAME_"..petType]) or L["Random Pet"]
                    self.icon = suffix and format("Interface\\Icons\\Icon_PetFamily_%s",suffix) or "Interface\\Icons\\INV_Misc_Dice_02"
                    self.displayID = "Interface\\Buttons\\talktomequestionmark.m2"
                end,
    empty =     function(self)
                    self.name = L["Empty Pet Slot"]
                    self.icon = C.EMPTY_ICON
                end,
    unnotable = function(self)
                    self.name = L["Not Notable"]
                    self.icon = C.UNNOTABLE_ICON
                    self.npcID = tonumber(self.petID:match("unnotable:(%d+)"))
                end,
}

-- used in General functions to gather info by petID (BattlePet-0-000etc)
function fillInfoByPetID(self,petID)
    local speciesID, customName, speciesName -- prevent a __index lookup if petID is invalid or not renamed
    local canBattle, level, xp, maxXp
    speciesID,customName,level,xp,maxXp,self.displayID,
    self.isFavorite,speciesName,self.icon,self.petType,self.creatureID,
    self.sourceText,self.loreText,self.isWild,canBattle,self.isTradable,
    self.isUnique,self.isObtainable = GetPetInfoByPetID(petID)
    self.name = customName or speciesName
    self.speciesID = speciesID
    self.customName = customName
    self.speciesName = speciesName
    -- canBattle can be false for GetPetInfoByPetID when it can be true for GetPetInfoBySpeciesID (/sigh)
    canBattle = rematch.speciesInfo:CanBattle(speciesID)
    if canBattle then -- only define level and xp for pets that can battle
        self.level = level
        self.xp = xp
        self.maxXp = maxXp
    end
    self.canBattle = canBattle
end

-- used in General functions to gather info by speciesID (42)
function fillInfoBySpeciesID(self,speciesID)
    local speciesName,icon -- prevent a __index lookup if speciesID is invalid
    speciesName,icon,self.petType,self.creatureID,self.sourceText,
    self.loreText,self.isWild,self.canBattle,self.isTradable,self.isUnique,
    self.isObtainable,self.displayID = GetPetInfoBySpeciesID(speciesID)
    -- when speciesID is invalid, it returns the GetPetInfoBySpeciesID function now for some reason
    if type(speciesName)=="function" then -- nil everything if
        speciesName = nil
        icon = nil
    end
    self.speciesName = speciesName
    self.name = speciesName
    self.speciesID = speciesID
    self.icon = icon
    if not self.icon then
        self.icon = C.REMATCH_ICON
    end
end

-- used by fetch, getIDType takes a petID and returns what type of id it is. one of:
-- "pet" "species" "leveling" "ignored" "link" "battle" "random" "ignored" or "unknown"
function getIDType(petID,forJournal)
    local idType = type(petID)
    if forJournal then
        if idType=="string" then
            return "pet"
        elseif idType=="number" then
            return "species"
        end
    elseif idType=="string" then
        if petID:match("^BattlePet%-%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") then
            return "pet"
        elseif petID:match("battlepet:%d+:%d+:%d+:%d+:%d+:%d+") then
            return "link"
        elseif petID:match("battle:%d:%d") then
            return "battle"
        elseif petID:match("random:%d+") then
            return "random"
        elseif petID=="ignored" then
            return "ignored"
        elseif petID:match("unnotable:%d+") then
            return "unnotable"
        elseif petID=="empty" then
            return "empty"
        end
    elseif idType=="number" then
        if petID>0 then
            return "species"
        elseif petID==0 then
            return "leveling"
        end
    elseif idType=="nil" then
        return "empty"
    end
    return "unknown" -- if we reached here, no idea what this petID is!
end

-- fetch makes a petID the "pet of interest." it can be a full petID, a speciesID, link, etc.
-- if fromJournal is true, then this petID is trusted to be an owned petID or a speciesID.
-- the same petID can be fetched multiple times and it will not duplicate the work to get info
function fetch(self,petID,fromJournal)
    if petID~=self.petID or not petID then -- nils are okay (they're unknown; need 'not petID' if nil~=nil)
        reset(self)
        self.petID = petID -- note that .petID property is the one used in the fetch and never changes
        self.idType = getIDType(petID,fromJournal)
    end
    return self -- initially, only the given petID and its idType are known
end

-- resets a petInfo, called when a new pet is fetched. it's also a good idea to call this at the start
-- of an update in case any pets changed attributes since the petInfo stat was last fetched. (by design,
-- API calls are not re-run for the same pet, it uses the cached value.)
function reset(self)
    wipe(self)
    for _,tbl in pairs(reusedTables[self]) do
        wipe(tbl) -- wipes the reusable tables
    end
    self.Fetch = fetch -- re-establishing these since we wiped self
    self.Reset = reset
    self.Create = create
end

-- the __index metamethod that returns an already-cached result or fetches the result and returns it
function lookup(self,stat)
    local func = stats[stat]
    local fetchedFuncs = reusedTables[self].fetchedFuncs
    if func and not fetchedFuncs[func] and funcs[func] then -- if function for the stat has not been called
        fetchedFuncs[func] = true -- flag it being used
        funcs[func](self) -- and run the func to populate the stat
    end
    return rawget(self,stat) -- and return the value now, either already cached or just-pulled value
end

-- creates a new petInfo if needed (rematch.petInfo is the primary one. rematch.petInfo (or any
-- petInfo can spawn a new one with petInfo:Create()))
function create()
    local info = {}
    reusedTables[info] = {
        fetchedFuncs = {}, -- lookup of functions that have been run
        abilityList = {}, -- cached result of C_PetJournal.GetPetAbilityList
        levelList = {}, -- cached result of C_PetJouranl.GetPetAbilityList
        usableAbilities = {}, -- list of abilities the pet can use at their current level
        possibleBreedIDs = {}, -- table of breedIDs possible for a speciesID
        possibleBreedNames = {}, -- table of breedNames possible for a speciesID
        strongVs = {}, -- table of abilities and the petTypes they are strong against
    }
    info.Fetch = fetch -- member functions
    info.Reset = reset
    info.Create = create -- any petInfo can spawn new petInfos if needed
    setmetatable(info,{__index=lookup})
    return info
end

-- create the main petInfo used throughout the addon
rematch.petInfo = create()
-- creating an alternate one in case we need to fetch two concurrently (comparing others)
rematch.altInfo = rematch.petInfo:Create()
