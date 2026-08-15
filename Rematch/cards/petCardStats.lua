local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings

--[[
    The following table is an ordered list of stats to display on the pet card: smallish buttons with an icon, text and tooltip, and possibly a function
    to run when clicked. These are stacked along the left side of the front of the pet card, possibly in two columns if the card is minimized.

    To add new stats, add them to this table any time.  Most of these values can be a literal or a function. If it's a function it will use the
    returned value.

    text: text to display for the stat
    icon: path to the icon that will display to the left of the text
    tooltipTitle: title of the tooltip for this stat
    tooltipBody: body of the tooltip for this stat
    isWide: true/false if the stat is wide/can take up two columns
    show: function that returns true if the stat should show for the petID
    click: function to run when the stat is clicked

    Notes:
    - All functions are passed (self,petInfo)
    - Stats that are isWide will list first, otherwise stats appear in the order they're in the following table
    - A stat with a click will have a "push" effect added automatically

]]

local reusedStrongVsWeights = {} -- reusing tables to reduce garbage creation
local reusedStrongVsOrder = {}


rematch.petCardStats = {
    -- Revoked
    {
        icon = "Interface\\Buttons\\UI-GroupLoot-Pass-Down",
        tooltipTitle = L["Revoked"],
        tooltipBody = L["This pet has been revoked, which means Blizzard withdrew your ability to use this pet.\n\nThis commonly happens when a pet no longer meet a condition for ownership, such as the Core Hound Pup requiring an authenticator attached to the account."],
        isWide = true,
        value = L["Revoked"],
        show = function(self,petInfo)
            return petInfo.isOwned and petInfo.isRevoked
        end
    },
    -- Can't Summon
    {
        icon = "Interface\\Buttons\\UI-GroupLoot-Pass-Down",
        tooltipTitle = L["Can't Summon"],
        tooltipBody = function(self,petInfo)
            return petInfo.summonErrorText
        end,
        isWide = true,
        value = function(self,petInfo)
            return petInfo.summonShortError
        end,
        show = function(self,petInfo)
            return petInfo.isOwned and not petInfo.isSummonable and not petInfo.isRevoked and not petInfo.isDead
        end
    },
    -- Expansion
    {
        icon = "Interface\\Store\\category-icon-wow",
        iconCoords = {0.25,0.75,0.25,0.75},
        tooltipTitle = L["Expansion"],
        tooltipBody = L["The World of Warcraft expansion this pet is from."],
        isWide = true,
        value = function(self,petInfo)
            return rematch.utils:GetFormattedExpansionName(petInfo.expansionID)
        end,
        show = function(self,petInfo)
            return petInfo.expansionID and settings.PetCardShowExpansionStat
        end
    },
    -- New Pet
    {
        icon = "Interface\\AddOns\\Rematch\\textures\\badges-borderless",
        iconCoords = {0.625,0.75,0.75,0.875},
        tooltipTitle = L["New Pet"],
        tooltipBody = format(L["This pet was recently added to your collection."]),
        value = C.HEX_GREEN..L["New Pet"],
        show = function(self,petInfo)
            return petInfo.isStickied
        end
    },
    -- Pet Marker
    {
        icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcons",
        iconCoords = function(self,petInfo)
            local coords = petInfo.marker and C.COORDS_4X4[petInfo.marker]
            if coords then
                return coords[1],coords[2],coords[3],coords[4]
            else
                return 0,1,0,1
            end
        end,
        tooltipTitle = function(self,petInfo)
            return rematch.utils:GetFormattedMarkerName(petInfo.marker)
        end,
        tooltipBody = L["This is the pet marker you've chosen for this pet. You can change the marker from the pet's right-click menu."],
        isWide = true,
        value = function(self,petInfo)
            return rematch.utils:GetFormattedMarkerName(petInfo.marker)
        end,
        show = function(self,petInfo)
            return petInfo.marker and true
        end
    },
    -- Slotted
    {
        icon = "Interface\\RaidFrame\\ReadyCheck-Ready",
        tooltipTitle = L["Slotted"],
        tooltipBody = L["This pet is currently slotted in one of the three battle pet slots."],
        value = L["Slotted"],
        show = function(self,petInfo)
            return petInfo.isSlotted
        end
    },
    -- Favorite
    {
        icon = "Interface\\Common\\FavoritesIcon",
        iconCoords = {0.125,0.71875,0.09375,0.6875},
        tooltipTitle = L["Favorite"],
        tooltipBody = L["This pet is marked as a favorite from its right-click menu."],
        value = L["Favorite"],
        show = function(self,petInfo)
            return petInfo.isFavorite
        end
    },
    -- Leveling
    {
        icon = "Interface\\AddOns\\Rematch\\textures\\levelingstat",
        tooltipTile = L["Leveling"],
        tooltipBody = L["This pet is in Rematch's leveling queue."],
        value = L["Leveling"],
        show = function(self,petInfo)
            return petInfo.isLeveling
        end
    },
    -- Health
    {
        icon = "Interface\\PetBattles\\PetBattle-StatIcons",
        iconCoords = {0.5,1,0.5,1},
        tooltipTitle = PET_BATTLE_STAT_HEALTH,
        tooltipBody = PET_BATTLE_TOOLTIP_HEALTH_MAX,
        value = function(self,petInfo)
            return petInfo.health==petInfo.maxHealth and petInfo.maxHealth or format("%s%d/%d",C.HEX_RED,petInfo.health,petInfo.maxHealth)
        end,
        show = function(self,petInfo)
            return petInfo.canBattle and petInfo.health
        end
    },
    -- Power
    {
        icon = "Interface\\PetBattles\\PetBattle-StatIcons",
        iconCoords = {0,0.5,0,0.5},
        tooltipTitle = PET_BATTLE_STAT_POWER,
        tooltipBody = PET_BATTLE_TOOLTIP_POWER,
        value = function(self,petInfo)
            return petInfo.power
        end,
        show = function(self,petInfo)
            return petInfo.canBattle and petInfo.power
        end
    },
    -- Speed
    {
        icon = "Interface\\PetBattles\\PetBattle-StatIcons",
        iconCoords = {0,0.5,0.5,1},
        tooltipTitle = PET_BATTLE_STAT_SPEED,
        tooltipBody = PET_BATTLE_TOOLTIP_SPEED,
        value = function(self,petInfo)
            return petInfo.speed
        end,
        show = function(self,petInfo)
            return petInfo.canBattle and petInfo.speed
        end
    },
    -- Rarity
    {
        icon = "Interface\\PetBattles\\PetBattle-StatIcons",
        iconCoords = {0.5,1,0,0.5},
        tooltipTitle = PET_BATTLE_STAT_QUALITY,
        tooltipBody = PET_BATTLE_TOOLTIP_RARITY,
        value = function(self,petInfo)
            return format("%s%s",petInfo.color.hex,_G["BATTLE_PET_BREED_QUALITY"..(min(6,petInfo.rarity))])
        end,
        show = function(self,petInfo)
            return petInfo.canBattle and petInfo.rarity and not settings.PetCardMinimized
        end
    },
    -- Breed
    {
        altTooltip = "Breed", -- flag that this stat may have an alternate tooltip
        icon = "Interface\\AchievementFrame\\UI-Achievement-Progressive-Shield",
        iconCoords = {0.09375,0.578125,0.140625,0.625},
        tooltipTitle = L["Breed"],
        tooltipBody = function(self,petInfo)
            local breedSource,breedSourceName = rematch.breedInfo:GetBreedSource()
            if breedSource then
                return format(L["Determines how stats are distributed. All breed data is pulled from your installed %s%s\124r addon."],C.HEX_WHITE,breedSourceName)
            end
        end,
        value = function(self,petInfo)
            if rematch.breedInfo:GetBreedSource() then
                return petInfo.breedName or UNKNOWN
            end
        end,
        show = function(self,petInfo)
            return rematch.breedInfo:GetBreedSource() and petInfo.canBattle and petInfo.breedID
        end
    },
    -- Teams
    {
        icon = "Interface\\AddOns\\Rematch\\textures\\badges-borderless",
        iconCoords = {0.5,0.625,0.125,0.25},
        tooltipTitle = L["Teams"],
        tooltipBody = format(L["%s Click to find all teams that include this specific pet."],C.LMB_TEXT_ICON),
        value = function(self,petInfo)
            return format(L["%d Teams"],petInfo.numTeams or 0)
        end,
        show = function(self,petInfo)
            return petInfo.inTeams
        end,
        click = function(self,petInfo)
            if petInfo.isOwned and petInfo.idType=="pet" then
                local petID = petInfo.petID -- about to clobber this if moving to teams view
                rematch.layout:SummonView("teams")
                rematch.teamsPanel:SetSearch(petID)
            elseif petInfo.idType=="species" then
                local name = petInfo.speciesName
                rematch.layout:SummonView("teams")
                rematch.teamsPanel:SetSearch(name)
            end
        end,
    },
    -- Not Tradable
    {
        icon = "Interface\\Common\\icon-noloot",
        tooltipTitle = L["Not Tradable"],
        tooltipBody = L["This pet cannot be caged or given to others."],
        value = L["No Trade"],
        show = function(self,petInfo)
            return petInfo.isObtainable and not petInfo.isTradable
        end
    },
    -- Unique
    {
        icon = "Interface\\AddOns\\Rematch\\textures\\unique",
        tooltipTitle = L["Unique"],
        tooltipBody = L["Only one copy of this pet can be owned at a time."],
        value = L["Unique"],
        show = function(self,petInfo)
            return petInfo.isObtainable and petInfo.isUnique
        end
    },
    -- Collected (stat version displays 3/3 rather than listing all collected versions)
    {
        icon = "Interface\\Icons\\INV_Box_PetCarrier_01",
        iconCoords = {0.075,0.925,0.075,0.925},
        tooltipTitle = COLLECTED,
        tooltipBody = function(self,petInfo)
            return rematch.petCard:GetCollectedList(petInfo)
        end,
        value = function(self,petInfo)
            return format("%s%d/%d",petInfo.countColor,petInfo.count or 0,petInfo.maxCount or 0)
        end,
        show = function(self,petInfo)
            return (settings.PetCardMinimized or settings.PetCardCompactCollected) and petInfo.count
        end
    },
    -- Strong Vs
    {
        icon = "Interface\\PetBattles\\BattleBar-AbilityBadge-Strong",
        iconCoords = {0.1,0.9,0.1,0.9},
        tooltipTitle = L["Strongest Vs"],
        tooltipBody = L["These are the pet types this pet is strongest against. One or more of this pet's attack abilities will deal extra damage to these pet types."],
        value = function(self,petInfo)
            local results = L["vs "]
            for _,petType in pairs(petInfo.strongVs) do -- weigh the strong vs types
                reusedStrongVsWeights[petType] = (reusedStrongVsWeights[petType] or 0)+1
            end
            for k,v in pairs(reusedStrongVsWeights) do -- put the indexes of the weights into an ordered list
                tinsert(reusedStrongVsOrder,k)
            end
            table.sort(reusedStrongVsOrder,function(e1,e2) -- order the list
                return reusedStrongVsWeights[e1] > reusedStrongVsWeights[e2]
            end)
            for i=1,3 do -- and add them to results to return
                if reusedStrongVsOrder[i] then
                    results = results..rematch.utils:PetTypeAsText(reusedStrongVsOrder[i],16,true)
                end
            end
            wipe(reusedStrongVsOrder) -- done with tables, can clean up
            wipe(reusedStrongVsWeights)
            return results
        end,
        show = function(self,petInfo)
            return settings.ShowStrongestVsStat and petInfo.canBattle
        end,
    },
    -- Species ID
    {
        icon = "Interface\\WorldMap\\Gear_64Grey",
        iconCoords = {0.1,0.9,0.1,0.9},
        tooltipTitle = L["Species ID"],
        tooltipBody = L["All versions of this pet share this unique identifying number."],
        value = function(self,petInfo)
            return petInfo.speciesID
        end,
        show = function(self,petInfo)
            return settings.ShowSpeciesID and not petInfo.isSpecialType
        end
    },
    -- Notes
    {
        icon = "Interface\\AddOns\\Rematch\\textures\\notesmicrobutton",
        iconCoords = {0,0.5,0,1},
        value = L["Notes"],
        show = function(self,petInfo)
            return petInfo.hasNotes
        end,
        enter = function(self,petInfo)
            rematch.cardManager:OnEnter(rematch.notes,self,petInfo.petID)
        end,
        leave = function(self,petInfo)
            rematch.cardManager:OnLeave(rematch.notes,self,petInfo.petID)
        end,
        click = function(self,petInfo)
            rematch.cardManager:OnClick(rematch.notes,self,petInfo.petID)
        end
    },
    -- Search
    {
        icon = "Interface\\Minimap\\Tracking\\None",
        tooltipTitle = SEARCH,
        tooltipBody = format(L["%s Click to search for all versions of this pet."],C.LMB_TEXT_ICON),
        value = SEARCH,
        show = function(self,petInfo)
            return petInfo.isObtainable
        end,
        click = function(self,petInfo) -- clicking the search stat will look for an "Exact Species Name" to find all copies of the pet
            local petID = petInfo.petID -- SummonView may potentially clobber the passed petInfo; hold onto the petID just in case
            rematch.layout:SummonView("pets")
            petInfo = rematch.petInfo:Fetch(petID)
            rematch.filters:ClearAll()
            local exactSearch = "\""..petInfo.speciesName.."\""
            rematch.filters:SetSearch(exactSearch)
            rematch.petsPanel.Top.SearchBox:SetText(exactSearch)
            rematch.petsPanel:Update()
            rematch.petCard:Hide()
        end
    },

}