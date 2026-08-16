local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.breedInfo = {}

--[[
    Helper function for breed data sources. In order of priority, breed data is pulled from:
        1. Battle Pet BreedID
        2. PetTracker

        (LibPetBreedInfo-1.0 was dropped in 5.0; at this time the last update was in 2017)

    For individual pets, all breed data should be pulled from petInfo, where pet breeds are determined.
]]

-- for Breed stat group
local breedSource -- addon that's providing breed data: "BattlePetBreedID", "PetTracker" or "LibPetBreedInfo-1.0"
local breedSourceName -- name of the addon from its metadata (## Title): "Battle Pet BreedID" or "PetTracker"
local breedLib -- for LibPetBreedInfo-1.0 only
local breedNames = {nil,nil,"B/B","P/P","S/S","H/H","H/P","P/S","H/S","P/B","S/B","H/B"}

-- the first time this runs it looks for a breed addon enabled and returns it
-- future runs will just return the saved source (so this only looks for a breed addon once)
-- addons are used in this priority: BattlePetBreedID, PetTracker_Breeds then LibPetBreedInfo-1.0
function rematch.breedInfo:GetBreedSource()
    if breedSource==nil then -- can be false if a prior search for a source didn't find any
        if settings.BreedSource=="BattlePetBreedID" and C_AddOns.IsAddOnLoaded("BattlePetBreedID") then
            breedSource = "BattlePetBreedID"
        elseif settings.BreedSource=="PetTracker" and C_AddOns.IsAddOnLoaded("PetTracker") and C_AddOns.GetAddOnMetadata("PetTracker","Version")~="10.2.7" then
            breedSource = "PetTracker"
        elseif settings.BreedSource=="None" then
            breedSource = false
        elseif C_AddOns.IsAddOnLoaded("BattlePetBreedID") then
            breedSource = "BattlePetBreedID"
            settings.BreedSource = breedSource
        elseif C_AddOns.IsAddOnLoaded("PetTracker") and PetTracker and PetTracker.Pet and PetTracker.Pet.GetBreed and C_AddOns.GetAddOnMetadata("PetTracker","Version")~="10.2.7" then
            breedSource = "PetTracker"
            settings.BreedSource = breedSource
        end
        if breedSource then
            breedSourceName = C_AddOns.GetAddOnMetadata(breedSource,"Title")
        else
            breedSource = false -- none found, only attempt to find a source once
        end
    end
    if breedSource~="PetTracker" and settings.BreedFormat==C.BREED_FORMAT_ICONS then
        settings.BreedFormat = C.BREED_FORMAT_LETTERS
    end
    return breedSource,breedSourceName
end

-- returns true if any breed addon is loaded
function rematch.breedInfo:IsAnyBreedAddOnLoaded(addon)
    return C_AddOns.IsAddOnLoaded("BattlePetBreedID") or C_AddOns.IsAddOnLoaded("PetTracker")
end

function rematch.breedInfo:ResetBreedSource()
    breedSource = nil
end

-- returns either "text" or "icon", the format of breed to display
function rematch.breedInfo:GetBreedFormat()
    if breedSource~="PetTracker" and settings.BreedFormat==C.BREED_FORMAT_ICONS then
        settings.BreedFormat = C.BREED_FORMAT_LETTERS
    end
    return settings.BreedFormat
end

-- returns the name of a breed by its ID; full is true if the icon+name should be used if PetTracker enabled
function rematch.breedInfo:GetBreedNameByID(breedID,full)
    if breedSource~="PetTracker" and settings.BreedFormat==C.BREED_FORMAT_ICONS then
        settings.BreedFormat = C.BREED_FORMAT_LETTERS
    end
    if settings.BreedFormat==C.BREED_FORMAT_NUMBERS then
        return breedNames[breedID] and breedID
    elseif settings.BreedFormat==C.BREED_FORMAT_LETTERS then
        return breedNames[breedID]
    elseif breedSource=="PetTracker" and PetTracker.Breeds.Names[breedID] then
        if full then
            return PetTracker.Breeds:Icon(breedID,.85) .. " " .. PetTracker.Breeds.Names[breedID]
        else
            return PetTracker.Breeds:Icon(breedID,.85)
        end
    end
end

-- returns an ordered table of all possible breeds as {breedID,health,power,speed} as a 25 rare
local breedTable = {}
function rematch.breedInfo:GetBreedTable(speciesID)
    wipe(breedTable)
    local petInfo = rematch.altInfo:Fetch(speciesID) -- to get possible breeds
    if petInfo.numPossibleBreeds then
        if breedSource=="BattlePetBreedID" then
            local data = BPBID_Arrays
            for _,breed in ipairs(petInfo.possibleBreedIDs) do
                local health = ceil((data.BasePetStats[speciesID][1] + data.BreedStats[breed][1]) * 25 * ((data.RealRarityValues[4] - 0.5) * 2 + 1) * 5 + 100 - 0.5)
                local power = ceil((data.BasePetStats[speciesID][2] + data.BreedStats[breed][2]) * 25 * ((data.RealRarityValues[4] - 0.5) * 2 + 1) - 0.5)
                local speed = ceil((data.BasePetStats[speciesID][3] + data.BreedStats[breed][3]) * 25 * ((data.RealRarityValues[4] - 0.5) * 2 + 1) - 0.5)
                tinsert(breedTable,{breed,health,power,speed})
            end
        elseif breedSource=="PetTracker" then
            local breedsTable = PetTracker.SpecieBreeds
            local statsTable = PetTracker.Predict.BreedStats
            if breedsTable[speciesID] then
                for _,breed in pairs(breedsTable[speciesID]) do
                    local health, power, speed = unpack(statsTable[breed])
                    health = health*50
                    power = power*50
                    speed = speed*50
                    tinsert(breedTable,{breed,health>0 and format("%d%%",health) or "-",power>0 and format("%d%%",power) or "-",speed>0 and format("%d%%",speed) or "-"})
                end
            end
        end
    end
    return breedTable
end