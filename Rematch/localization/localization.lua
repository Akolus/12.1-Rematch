-- this sets up localization; and also a place to put constant strings for different purposes

local _,rematch = ...
rematch.localization = setmetatable({},{__index=function(self,key) return key end})

-- for localization: local L=rematch.localization, then L["Text"]
local L = rematch.localization

-- for enUS clients these words are short enough to fit on tabs; but other language may need alternate short names/abbreviations
L["TAB_PETS"] = "Pets"
L["TAB_TEAMS"] = "Teams"
L["TAB_TARGETS"] = "Targets"
L["TAB_QUEUE"] = "Queue"
L["TAB_OPTIONS"] = "Options"
-- the Total Pets text in the topleft corner button
L["TOTAL_PETS"] = "Total Pets"
L["UNIQUE_PETS"] = "Unique Pets"
-- grey panel buttons have text defined here so localized text doesn't run off the edges of the buttons
L["FILTER"] = "Filter"
-- typebar tab in the pet panel
L["TYPEBAR_TAB_TYPE"] = "Pet Type"
L["TYPEBAR_TAB_STRONG_VS"] = "Strong Vs"
L["TYPEBAR_TAB_TOUGH_VS"] = "Tough Vs"