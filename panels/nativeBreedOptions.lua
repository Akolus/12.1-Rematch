local _,rematch = ...

-- Replace Rematch's external Breed Source dropdown with a native enable/disable
-- dropdown while preserving BreedSource="BattlePetBreedID" internally so the
-- existing petInfo implementation continues to work unchanged.

local function patchOptions()
    if not rematch.optionsList then return end

    for _,option in ipairs(rematch.optionsList) do
        if option.var=="BreedSource" then
            option.text = "Breed Information"
            option.tooltip = "Use Rematch's built-in breed database and calculator. Battle Pet BreedID or PetTracker are no longer required for breed information."
            option.menu = {
                {text="Rematch Native Breeds", value="BattlePetBreedID", tooltipTitle="Rematch Native Breeds", tooltipBody="Use the breed database and calculator included directly with Rematch."},
                {text="None", value="None", tooltipTitle="None", tooltipBody="Disable breed information."},
            }
            break
        end
    end
end

patchOptions()
C_Timer.After(0,patchOptions)
