local _,rematch = ...
local C = rematch.constants
local settings = rematch.settings

rematch.breedInfo = {}

-- Native breed source.  We keep the internal source token "BattlePetBreedID"
-- for backwards compatibility with Rematch's existing petInfo.lua.  The data
-- and calculator now live inside Rematch; the standalone addon is not required.
local breedSource
local breedSourceName = "Rematch Native Breeds"
local breedNames = {nil,nil,"B/B","P/P","S/S","H/H","H/P","P/S","H/S","P/B","S/B","H/B"}
local breedTable = {}

local function nativeReady()
    return BPBID_Arrays and BPBID_Internal and type(BPBID_Internal.CalculateBreedID)=="function"
end

function rematch.breedInfo:GetBreedSource()
    if settings.BreedSource=="None" then
        breedSource = false
    elseif nativeReady() then
        breedSource = "BattlePetBreedID" -- compatibility token used by petInfo.lua
        settings.BreedSource = "BattlePetBreedID"
    else
        breedSource = false
    end

    if settings.BreedFormat==C.BREED_FORMAT_ICONS then
        settings.BreedFormat = C.BREED_FORMAT_LETTERS
    end
    return breedSource, breedSource and breedSourceName or nil
end

function rematch.breedInfo:IsAnyBreedAddOnLoaded()
    return nativeReady()
end

function rematch.breedInfo:ResetBreedSource()
    breedSource = nil
end

function rematch.breedInfo:GetBreedFormat()
    if settings.BreedFormat==C.BREED_FORMAT_ICONS then
        settings.BreedFormat = C.BREED_FORMAT_LETTERS
    end
    return settings.BreedFormat
end

function rematch.breedInfo:GetBreedNameByID(breedID)
    if settings.BreedFormat==C.BREED_FORMAT_NUMBERS then
        return breedNames[breedID] and breedID
    end
    return breedNames[breedID]
end

function rematch.breedInfo:GetBreedTable(speciesID)
    wipe(breedTable)
    if not nativeReady() then return breedTable end

    local possible = rematch.nativeBreed:GetPossibleBreeds(speciesID)
    if possible then
        for _,breedID in ipairs(possible) do
            local health,power,speed = rematch.nativeBreed:GetBreedStats25(speciesID,breedID)
            if health then
                breedTable[#breedTable+1] = {breedID,health,power,speed}
            end
        end
    end
    return breedTable
end
