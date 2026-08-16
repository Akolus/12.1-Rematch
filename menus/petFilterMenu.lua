local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.petFilterMenu = {}
local pfm = rematch.petFilterMenu

--[[
    The menu and its submenus from the Filter button in PetsPanel
]]

rematch.events:Register(rematch.petFilterMenu,"PLAYER_LOGIN",function(self)

	-- parent filter menu with all the submenus
    local mainMenu = {
        {text=COLLECTED, check=true, group="Collected", key="Owned", isChecked=pfm.GetNotChecked, func=pfm.ToggleChecked},
		{text=L["Only Favorites"], check=true, indent=true, group="Favorite", key=1, isChecked=pfm.GetChecked, func=pfm.ToggleChecked},
		{text=NOT_COLLECTED, check=true, group="Collected", key="Missing", isChecked=pfm.GetNotChecked, func=pfm.ToggleChecked},
		{text=PET_FAMILIES, subMenu="PetTypes", group="Types", highlight=pfm.GroupUsed},
		{text=L["Strong Vs"], subMenu="PetStrong", group="Strong", highlight=pfm.GroupUsed},
		{text=L["Tough Vs"], subMenu="PetTough", group="Tough", highlight=pfm.GroupUsed},
		{text=SOURCES, subMenu="PetSources", group="Sources", highlight=pfm.GroupUsed},
		{text=EXPANSION_FILTER_TEXT, subMenu="PetExpansion", group="Expansion", highlight=pfm.GroupUsed},
		{text=RARITY, subMenu="PetRarity", group="Rarity", highlight=pfm.GroupUsed},
		{text=LEVEL, subMenu="PetLevel", group="Level", highlight=pfm.GroupUsed},
		{text=L["Breed"], hidden=pfm.NoBreedAddon, subMenu="PetBreed", group="Breed", highlight=pfm.GroupUsed},
		{text=L["Pet Tags"], subMenu="PetMarker", group="Marker", highlight=pfm.GroupUsed},
		{text=OTHER, subMenu="PetOther", group="Other", highlight=pfm.GroupUsed},
		{text=L["Script"], subMenu="ScriptFilters", group="Script", highlight=pfm.GroupUsed},
		{text=RAID_FRAME_SORT_LABEL, subMenu="PetSort", group="Sort", highlight=pfm.GroupUsed},
		{text=L["Favorite Filters"], subMenu="FavoriteFilters"},
		{spacer=true},
		{text=L["Export Pets"], func=pfm.ExportPets},
		{text=L["Pet Herder"], func=pfm.PetHerder},
		{spacer=true},
		{text=L["Help"], stay=true, isHelp=true, hidden=pfm.HideMenuHelp, icon="Interface\\Common\\help-i", iconCoords={0.15,0.85,0.15,0.85}, tooltipTitle=L["Pet Filter"], tooltipBody=format(C.HELP_TEXT_PET_FILTER,C.HEX_WHITE,C.HEX_WHITE,C.HEX_WHITE,C.HEX_WHITE,C.HEX_WHITE,C.HEX_WHITE,C.HEX_WHITE)},
		{text=L["Reset All"], func=pfm.ResetAll, stay=true},
		{text=OKAY, noPostFunc=true},
    }
	rematch.menus:Register("PetFilterMenu",mainMenu)

	-- Pet Families, Strong Vs and Tough Vs submenus all built together since they're so similar
	for _,info in ipairs({{"PetTypes","Types",PET_FAMILIES},{"PetStrong","Strong",L["Strong Vs"]},{"PetTough","Tough",L["Tough Vs"]}}) do
		local menu = { {title=info[3]} }
		for i=1,10 do
			tinsert(menu,{text=_G["BATTLE_PET_NAME_"..i], check=true, group=info[2], key=i, icon=pfm.GetIcon, isChecked=pfm.GetChecked, func=pfm.ToggleChecked, multiCheck=10})
		end
		tinsert(menu,{text=L["Help"], stay=true, isHelp=true, hidden=pfm.HideMenuHelp, icon="Interface\\Common\\help-i", iconCoords={0.15,0.85,0.15,0.85}, tooltipTitle=L["Checkbox Groups"], tooltipBody=format(C.HELP_TEXT_MULTI_CHECK,C.HEX_WHITE,C.HEX_WHITE)})
		tinsert(menu,{text=RESET, group=info[2], stay=true, func=pfm.ResetGroup})
		rematch.menus:Register(info[1],menu)
	end

	-- Sources
	local sourcesMenu = { {title=SOURCES} }
	for i=1,12 do
		tinsert(sourcesMenu,{text=_G["BATTLE_PET_SOURCE_"..i], check=true, group="Sources", key=i, icon=pfm.GetIcon, iconCoords=pfm.GetIconCoords, isChecked=pfm.GetChecked, func=pfm.ToggleChecked, multiCheck=12})
	end
	tinsert(sourcesMenu,{text=L["Help"], stay=true, isHelp=true, hidden=pfm.HideMenuHelp, icon="Interface\\Common\\help-i", iconCoords={0.15,0.85,0.15,0.85}, tooltipTitle=L["Checkbox Groups"], tooltipBody=format(C.HELP_TEXT_MULTI_CHECK,C.HEX_WHITE,C.HEX_WHITE)})
	tinsert(sourcesMenu,{text=RESET, group="Sources", stay=true, func=pfm.ResetGroup})
	rematch.menus:Register("PetSources",sourcesMenu)

	-- Expansion
	local expansionMenu = { {title=EXPANSION_FILTER_TEXT} }
	for i=10,0,-1 do
		tinsert(expansionMenu,{text=rematch.utils:GetFormattedExpansionName(i), check=true, group="Expansion", key=i, icon=pfm.GetIcon, isChecked=pfm.GetChecked, func=pfm.ToggleChecked, multiCheck=10, multiCheckStart=0})
	end
	tinsert(expansionMenu,{text=L["Help"], stay=true, isHelp=true, hidden=pfm.HideMenuHelp, icon="Interface\\Common\\help-i", iconCoords={0.15,0.85,0.15,0.85}, tooltipTitle=L["Checkbox Groups"], tooltipBody=format(C.HELP_TEXT_MULTI_CHECK,C.HEX_WHITE,C.HEX_WHITE)})
	tinsert(expansionMenu,{text=RESET, group="Expansion", stay=true, func=pfm.ResetGroup})
	rematch.menus:Register("PetExpansion",expansionMenu)

	-- Rarity
	local rarityMenu = { {title=RARITY} }
	for i=1,4 do
		tinsert(rarityMenu,{text=pfm.GetRarityText, check=true, group="Rarity", key=i, isChecked=pfm.GetChecked, func=pfm.ToggleChecked, multiCheck=4})
	end
	tinsert(rarityMenu,{text=L["Help"], stay=true, isHelp=true, hidden=pfm.HideMenuHelp, icon="Interface\\Common\\help-i", iconCoords={0.15,0.85,0.15,0.85}, tooltipTitle=L["Checkbox Groups"], tooltipBody=format(C.HELP_TEXT_MULTI_CHECK,C.HEX_WHITE,C.HEX_WHITE)})
	tinsert(rarityMenu,{text=RESET, group="Rarity", stay=true, func=pfm.ResetGroup})
	rematch.menus:Register("PetRarity",rarityMenu)

	-- Level
	local levelMenu = {
		{title=LEVEL},
		{text=L["Low Level (1-7)"], check=true, group="Level", multiCheck=4, key=1, isChecked=pfm.GetChecked, func=pfm.ToggleChecked},
		{text=L["Mid Level (8-14)"], check=true, group="Level", multiCheck=4, key=2, isChecked=pfm.GetChecked, func=pfm.ToggleChecked},
		{text=L["High Level (15-24)"], check=true, group="Level", multiCheck=4, key=3, isChecked=pfm.GetChecked, func=pfm.ToggleChecked},
		{text=L["Max Level (25)"], check=true, group="Level", multiCheck=4, key=4, isChecked=pfm.GetChecked, func=pfm.ToggleChecked},
		{spacer=true},
		{text=L["Without Any 25s"], check=true, group="Level", key="Without25s", isChecked=pfm.GetChecked, func=pfm.ToggleChecked},
		{text=L["Moveset Not At 25"], check=true, group="Level", key="MovesetNot25", isChecked=pfm.GetChecked, func=pfm.ToggleChecked},
		{spacer=true},
		{text=L["Help"], stay=true, isHelp=true, hidden=pfm.HideMenuHelp, icon="Interface\\Common\\help-i", iconCoords={0.15,0.85,0.15,0.85}, tooltipTitle=L["Checkbox Groups"], tooltipBody=format(C.HELP_TEXT_MULTI_CHECK,C.HEX_WHITE,C.HEX_WHITE)},
		{text=RESET, group="Level", stay=true, func=pfm.ResetGroup}
	}
	rematch.menus:Register("PetLevel",levelMenu)

	-- Breed
	if rematch.breedInfo:GetBreedSource() then
		local breedMenu = { {title=L["Breed"]} }
		for i=3,12 do
			tinsert(breedMenu,{text=pfm.GetBreedName, check=true, group="Breed", multiCheck=11, multiCheckStart=3, key=i, isChecked=pfm.GetChecked, func=pfm.ToggleChecked})
		end
		tinsert(breedMenu,{text=NEW, check=true, group="Breed", multiCheck=11, multiCheckStart=3, key=13, isChecked=pfm.GetChecked, func=pfm.ToggleChecked})
		tinsert(breedMenu,{text=L["Help"], stay=true, isHelp=true, hidden=pfm.HideMenuHelp, icon="Interface\\Common\\help-i", iconCoords={0.15,0.85,0.15,0.85}, tooltipTitle=L["Breed"], tooltipBody=format(L["All breed data is pulled from your installed %s%s\124r addon.\n\nThe breed \"New\" means the pet has no breed data. Keep your breed addon up to date to ensure it has the most recent breed data."],C.HEX_WHITE,C_AddOns.GetAddOnMetadata(rematch.breedInfo:GetBreedSource(),"Title") or rematch.breedInfo:GetBreedSource())})
		tinsert(breedMenu,{text=RESET, group="Breed", stay=true, func=pfm.ResetGroup})
		rematch.menus:Register("PetBreed",breedMenu)
	end

	-- Pet Marker
	local markerMenu = { {title=L["Pet Tags"]} }
	for i=8,1,-1 do
		tinsert(markerMenu,{text=pfm.GetMarkerName, icon="Interface\\TargetingFrame\\UI-RaidTargetingIcons", iconCoords=pfm.GetIconCoords, check=true, group="Marker", multiCheck=9, key=i, isChecked=pfm.GetChecked, editButton=true, editFunc=pfm.RenameMarker, func=pfm.ToggleChecked})
	end
	tinsert(markerMenu,{text=NONE, icon="", check=true, group="Marker", multiCheck=9, key=9, isChecked=pfm.GetChecked, func=pfm.ToggleChecked})
	tinsert(markerMenu,{text=L["Help"], stay=true, isHelp=true, hidden=pfm.HideMenuHelp, icon="Interface\\Common\\help-i", iconCoords={0.15,0.85,0.15,0.85}, tooltipTitle=L["Pet Tags"], tooltipBody=format(C.HELP_TEXT_PET_TAGS,C.HEX_WHITE,rematch.utils:IconAsText("Interface\\WorldMap\\Gear_64Grey"), rematch.utils:GetBadgeAsText(21,16,true), rematch.utils:GetBadgeAsText(21,16,true))})
	tinsert(markerMenu,{text=RESET, group="Marker", stay=true, func=pfm.ResetGroup})
	rematch.menus:Register("PetMarker",markerMenu)

	-- Other
	local otherMenu = {
		{title=OTHER},
		{text=L["Leveling"], radio=true, group="Other", radioGroup="Leveling", key="Leveling", isChecked=pfm.GetRadioChecked, func=pfm.ToggleRadio},
		{text=L["Not Leveling"], radio=true, group="Other", radioGroup="Leveling", key="NotLeveling", isChecked=pfm.GetRadioChecked, func=pfm.ToggleRadio},
		{spacer=true},
		{text=L["Tradable"], radio=true, group="Other", radioGroup="Tradable", key="Tradable", isChecked=pfm.GetRadioChecked, func=pfm.ToggleRadio},
		{text=L["Not Tradable"], radio=true, group="Other", radioGroup="Tradable", key="NotTradable", isChecked=pfm.GetRadioChecked, func=pfm.ToggleRadio},
		{spacer=true},
		{text=L["Can Battle"], hidden=pfm.NonBattlePetsHidden, radio=true, group="Other", radioGroup="Battle", key="Battle", isChecked=pfm.GetRadioChecked, func=pfm.ToggleRadio},
		{text=L["Can't Battle"], hidden=pfm.NonBattlePetsHidden, radio=true, group="Other", radioGroup="Battle", key="NotBattle", isChecked=pfm.GetRadioChecked, func=pfm.ToggleRadio},
		{spacer=true, hidden=pfm.NonBattlePetsHidden},
		{text=L["One Copy"], radio=true, group="Other", radioGroup="Quantity", key="Qty1", isChecked=pfm.GetRadioChecked, func=pfm.ToggleRadio},
		{text=L["Two+ Copies"], radio=true, group="Other", radioGroup="Quantity", key="Qty2", isChecked=pfm.GetRadioChecked, func=pfm.ToggleRadio},
		{text=L["Three+ Copies"], radio=true, group="Other", radioGroup="Quantity", key="Qty3", isChecked=pfm.GetRadioChecked, func=pfm.ToggleRadio},
		{spacer=true},
		{text=L["In A Team"], radio=true, group="Other", radioGroup="Team", key="InTeam", isChecked=pfm.GetRadioChecked, func=pfm.ToggleRadio},
		{text=L["Not In A Team"], radio=true, group="Other", radioGroup="Team", key="NotInTeam", isChecked=pfm.GetRadioChecked, func=pfm.ToggleRadio},
		{spacer=true},
      	{text=L["Unique Moveset"], radio=true, group="Other", radioGroup="Moveset", key="UniqueMoveset", isChecked=pfm.GetRadioChecked, func=pfm.ToggleRadio},
      	{text=L["Shared Moveset"], radio=true, group="Other", radioGroup="Moveset", key="SharedMoveset", isChecked=pfm.GetRadioChecked, func=pfm.ToggleRadio},
		{spacer=true},
		{text=L["Current Zone"], check=true, group="Other", radioGroup="Zone", key="CurrentZone", isChecked=pfm.GetChecked, func=pfm.ToggleChecked},
		{text=L["Hidden Pets"], hidden=function() return not settings.AllowHiddenPets end, check=true, group="Other", key="Hidden", isChecked=pfm.GetChecked, func=pfm.ToggleChecked},
		{text=L["Has Notes"], check=true, group="Other", radioGroup="Notes", key="HasNotes", isChecked=pfm.GetChecked, func=pfm.ToggleChecked},
		{spacer=true},
		{text=RESET, group="Other", stay=true, func=pfm.ResetGroup},
	}
	rematch.menus:Register("PetOther",otherMenu)

	local firstSortMenu = {
		{title=RAID_FRAME_SORT_LABEL},
		{text=NAME, radio=true, group="Sort", sortLevel=1, key=C.SORT_NAME, isChecked=pfm.GetSortRadio, func=pfm.SetSortRadio},
		{text=LEVEL, radio=true, group="Sort", sortLevel=1, key=C.SORT_LEVEL, isChecked=pfm.GetSortRadio, func=pfm.SetSortRadio},
		{text=RARITY, radio=true, group="Sort", sortLevel=1, key=C.SORT_RARITY, isChecked=pfm.GetSortRadio, func=pfm.SetSortRadio},
		{text=TYPE, radio=true, group="Sort", sortLevel=1, key=C.SORT_TYPE, isChecked=pfm.GetSortRadio, func=pfm.SetSortRadio},
		{text=PET_BATTLE_STAT_HEALTH, radio=true, group="Sort", sortLevel=1, key=C.SORT_HEALTH, isChecked=pfm.GetSortRadio, func=pfm.SetSortRadio},
		{text=PET_BATTLE_STAT_POWER, radio=true, group="Sort", sortLevel=1, key=C.SORT_POWER, isChecked=pfm.GetSortRadio, func=pfm.SetSortRadio},
		{text=PET_BATTLE_STAT_SPEED, radio=true, group="Sort", sortLevel=1, key=C.SORT_SPEED, isChecked=pfm.GetSortRadio, func=pfm.SetSortRadio},
		{text=L["Teams"], radio=true, group="Sort", sortLevel=1, key=C.SORT_TEAMS, isChecked=pfm.GetSortRadio, func=pfm.SetSortRadio},
		{text=L["Then Sort By"], subMenu="PetSecondSort"},
		{spacer=true},
		{text=L["Reverse Sort"], check=true, group="Sort", key=-1, isChecked=pfm.GetChecked, func=pfm.ToggleChecked},
		{text=L["Favorites First"], check=true, group="Sort", key="FavoritesNotFirst", isChecked=pfm.GetNotChecked, func=pfm.ToggleChecked},
		{spacer=true},
		{text=L["Help"], stay=true, isHelp=true, hidden=pfm.HideMenuHelp, icon="Interface\\Common\\help-i", iconCoords={0.15,0.85,0.15,0.85}, tooltipTitle=L["Checkbox Groups"], tooltipTitle=RAID_FRAME_SORT_LABEL, tooltipBody=format(L["You can filter to a specific range of stats too. For example, search for:\n\n%shealth>500\124r\nor\n%sspeed=200-300\124r\n\nThe sort order is not ordinarily reset when filters are reset. The option %sReset Sort With Filters\124r in the Options tab will reset the sort when you reset the filters."],C.HEX_WHITE,C.HEX_WHITE,C.HEX_WHITE)},
		{text=RESET, group="Sort", stay=true, func=pfm.ResetGroup},
	}
	rematch.menus:Register("PetSort",firstSortMenu)

	local secondSortMenu = {
		{title=L["Then Sort By"]},
		{text=NAME, radio=true, group="Sort", sortLevel=2, key=C.SORT_NAME, hidden=pfm.HideSortRadio, isChecked=pfm.GetSortRadio, func=pfm.SetSortRadio},
		{text=LEVEL, radio=true, group="Sort", sortLevel=2, key=C.SORT_LEVEL, hidden=pfm.HideSortRadio, isChecked=pfm.GetSortRadio, func=pfm.SetSortRadio},
		{text=RARITY, radio=true, group="Sort", sortLevel=2, key=C.SORT_RARITY, hidden=pfm.HideSortRadio, isChecked=pfm.GetSortRadio, func=pfm.SetSortRadio},
		{text=TYPE, radio=true, group="Sort", sortLevel=2, key=C.SORT_TYPE, hidden=pfm.HideSortRadio, isChecked=pfm.GetSortRadio, func=pfm.SetSortRadio},
		{text=PET_BATTLE_STAT_HEALTH, radio=true, group="Sort", sortLevel=2, key=C.SORT_HEALTH, hidden=pfm.HideSortRadio, isChecked=pfm.GetSortRadio, func=pfm.SetSortRadio},
		{text=PET_BATTLE_STAT_POWER, radio=true, group="Sort", sortLevel=2, key=C.SORT_POWER, hidden=pfm.HideSortRadio, isChecked=pfm.GetSortRadio, func=pfm.SetSortRadio},
		{text=PET_BATTLE_STAT_SPEED, radio=true, group="Sort", sortLevel=2, key=C.SORT_SPEED, hidden=pfm.HideSortRadio, isChecked=pfm.GetSortRadio, func=pfm.SetSortRadio},
		{text=L["Teams"], radio=true, group="Sort", sortLevel=2, key=C.SORT_TEAMS, hidden=pfm.HideSortRadio, isChecked=pfm.GetSortRadio, func=pfm.SetSortRadio},
		{text=L["Finally Sort By"], subMenu="PetThirdSort"},
		{spacer=true},
		{text=L["Reverse Sort"], check=true, group="Sort", key=-2, isChecked=pfm.GetChecked, func=pfm.ToggleChecked},
	}
	rematch.menus:Register("PetSecondSort",secondSortMenu)

	local thirdSortMenu = {
		{title=L["Finally Sort By"]},
		{text=NAME, radio=true, group="Sort", sortLevel=3, key=C.SORT_NAME, hidden=pfm.HideSortRadio, isChecked=pfm.GetSortRadio, func=pfm.SetSortRadio},
		{text=LEVEL, radio=true, group="Sort", sortLevel=3, key=C.SORT_LEVEL, hidden=pfm.HideSortRadio, isChecked=pfm.GetSortRadio, func=pfm.SetSortRadio},
		{text=RARITY, radio=true, group="Sort", sortLevel=3, key=C.SORT_RARITY, hidden=pfm.HideSortRadio, isChecked=pfm.GetSortRadio, func=pfm.SetSortRadio},
		{text=TYPE, radio=true, group="Sort", sortLevel=3, key=C.SORT_TYPE, hidden=pfm.HideSortRadio, isChecked=pfm.GetSortRadio, func=pfm.SetSortRadio},
		{text=PET_BATTLE_STAT_HEALTH, radio=true, group="Sort", sortLevel=3, key=C.SORT_HEALTH, hidden=pfm.HideSortRadio, isChecked=pfm.GetSortRadio, func=pfm.SetSortRadio},
		{text=PET_BATTLE_STAT_POWER, radio=true, group="Sort", sortLevel=3, key=C.SORT_POWER, hidden=pfm.HideSortRadio, isChecked=pfm.GetSortRadio, func=pfm.SetSortRadio},
		{text=PET_BATTLE_STAT_SPEED, radio=true, group="Sort", sortLevel=3, key=C.SORT_SPEED, hidden=pfm.HideSortRadio, isChecked=pfm.GetSortRadio, func=pfm.SetSortRadio},
		{text=L["Teams"], radio=true, group="Sort", sortLevel=3, key=C.SORT_TEAMS, hidden=pfm.HideSortRadio, isChecked=pfm.GetSortRadio, func=pfm.SetSortRadio},
		{spacer=true},
		{text=L["Reverse Sort"], check=true, group="Sort", key=-3, isChecked=pfm.GetChecked, func=pfm.ToggleChecked},
	}
	rematch.menus:Register("PetThirdSort",thirdSortMenu)

	rematch.menus:Register("ScriptFilters",{})
	rematch.menus:UpdateScriptFilters()
	-- dialogs for script filters are defined in /dialogs/scriptFilter.lua

	rematch.menus:Register("FavoriteFilters",{})
	rematch.menus:UpdateFavoriteFilters() -- this populates the FavoriteFilters menu (menu can change as filters add/remove)

	rematch.dialog:Register("FavoriteFilterDialog",{
		title = L["Save Favorite Filter"],
        accept = SAVE,
        cancel = CANCEL,
        prompt = L["Save this Favorite Filter?"],
        layout = {"Text","EditBox"},
		refreshFunc = function(self,info,subject,firstRun)
			if subject then -- if editing a filter
				self.Text:SetText(format(L["Filters: %s%s\124r\n\nEnter a new name for this Favorite Filter:"],C.HEX_WHITE,rematch.filters:GetFilterList(settings.FavoriteFilters[subject][2])))
				self.EditBox:SetText(settings.FavoriteFilters[subject][1],true)
				rematch.dialog.AcceptButton:Enable()
			else
				self.Text:SetText(format(L["Filters: %s%s\124r\n\nEnter a name for this new Favorite Filter:"],C.HEX_WHITE,rematch.filters:GetFilterList(settings.Filters)))
				self.EditBox:SetText("")
				rematch.dialog.AcceptButton:Disable()
			end

		end,
		changeFunc = function(self,info,subject)
			local text = self.EditBox:GetText()
			rematch.dialog.AcceptButton:SetEnabled(text and text:len()>0)
		end,
		acceptFunc = function(self,info,subject)
			if subject then -- if we're editing the name of an existing favorite filter
				settings.FavoriteFilters[subject][1] = self.EditBox:GetText():trim()
			else -- this is a new favorite filter being saved
				local filters = CopyTable(settings.Filters)
				if not next(filters.Search) then
					filters.RawSearchText=nil -- special case, nil out the raw search term if search empty
				end
				tinsert(settings.FavoriteFilters,{self.EditBox:GetText():trim(),filters})
			end
			rematch.menus:UpdateFavoriteFilters() -- update the favorite filter menu to add new one
		end,
	})

	rematch.dialog:Register("DeleteFavoriteFilterDialog",{
		title = L["Delete Favorite Filter"],
		accept = YES,
		cancel = NO,
		layout = {"Text"},
		refreshFunc = function(self,info,subject,firstRun)
			self.Text:SetText(format(L["\nAre you sure you want to delete the filter named %s%s\124r?\n\nFilters: %s%s\n\n"],C.HEX_WHITE,settings.FavoriteFilters[subject][1],C.HEX_WHITE,rematch.filters:GetFilterList(settings.FavoriteFilters[subject][2])))
			rematch.dialog.AcceptButton:Enable()
		end,
		acceptFunc = function(self,info,subject)
			tremove(settings.FavoriteFilters,subject)
			rematch.menus:UpdateFavoriteFilters()
		end,
	})

	rematch.dialog:Register("ExportPetsDialog",{
		title = L["Export Pets"],
		cancel = OKAY,
		layout = {"Text","MultiLineEditBox","CheckButton"},
		refreshFunc = function(self,info,subject,firstRun)
			self.Text:SetText(format(L["Press Ctrl+C to copy to clipboard\n\n%sThese are pets currently listed. Adjust the filters to limit which to include."],C.HEX_GREY))
			self.CheckButton:SetText(L["Export Simple Pet List"])
			self.CheckButton:SetChecked(settings.ExportSimplePetList)
			self.MultiLineEditBox:SetText(pfm:GetPetExportData(),true)
		end,
		changeFunc = function(self,info,subject)
			local oldSetting = settings.ExportSimplePetList
			local newSetting = self.CheckButton:GetChecked()
			if oldSetting ~= newSetting then
				settings.ExportSimplePetList = newSetting
				self.MultiLineEditBox:SetText(pfm:GetPetExportData(),true)
				if rematch.optionsPanel:IsVisible() then
					rematch.optionsPanel:Update()
				end
			end
		end,
	})

	rematch.dialog:Register("RenamePetMarkerDialog",{
		title = L["Rename Pet Marker"],
        accept = ACCEPT,
        cancel = CANCEL,
        other = PET_RENAME_DEFAULT_LABEL,
        prompt = L["Enter a new name"],
		layout = {"Icon","EditBox"},
		refreshFunc = function(self,info,subject,firstRun)
            if firstRun then
				self.Icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
				self.Icon:SetTexCoord(unpack(C.COORDS_4X4[subject]))
                self.EditBox:SetText(settings.PetMarkerNames[subject] or _G["RAID_TARGET_"..subject],true)
            end
        end,
		changeFunc = function(self,info,subject)
			rematch.dialog.AcceptButton:SetEnabled(self.EditBox:GetText():trim():len()>0)
		end,
		acceptFunc = function(self,info,subject)
			settings.PetMarkerNames[subject] = self.EditBox:GetText():trim()
		end,
		otherFunc = function(self,info,subject)
			settings.PetMarkerNames[subject] = nil
		end,
	})

end)

-- returns value of info.group/info.key
function pfm:GetChecked()
    return rematch.filters:Get(self.group,self.key)
end
-- for variables where false should be checked (collected/not collected)
function pfm:GetNotChecked()
    return not rematch.filters:Get(self.group,self.key)
end
-- returns whether radio is checked (specifically, if settings.Filters[group][radioGroup]==key)
function pfm:GetRadioChecked()
	return rematch.filters:Get(self.group,self.radioGroup)==self.key
end
-- returns whether radio is default (this radioGroup value is nil and not a key)
function pfm:GetRadioDefaultChecked()
	return not rematch.filters:Get(self.group,self.radioGroup)
end
-- toggles the value of a check
function pfm:ToggleChecked()
	local start = self.multiCheckStart or 1
	if self.multiCheck and IsShiftKeyDown() then -- on multiCheck, check all but current if Shift down
		for i=start,start+self.multiCheck-1 do
			rematch.filters:Set(self.group,i,i~=self.key)
		end
	elseif self.multiCheck and IsAltKeyDown() then -- on multiCheck, uncheck all but current if Alt down
		for i=start,start+self.multiCheck-1 do
			rematch.filters:Set(self.group,i,i==self.key)
		end
	else -- for all other cases, toggle the current check
		rematch.filters:Set(self.group,self.key,not rematch.filters:Get(self.group,self.key))
	end
	-- if this is a multicheck menu and all are checked, then clear all checks
	if self.multiCheck then
		local somethingUnchecked = false
		for i=start,start+self.multiCheck-1 do
			if not rematch.filters:Get(self.group,i) then
				somethingUnchecked = true
			end
		end
		-- if everything is checked then clear all checks
		if not somethingUnchecked then
			rematch.filters:Clear(self.group)
		end
	end
	rematch.petsPanel:Update()
end
-- either clears radio value or sets it to current key
function pfm:ToggleRadio()
	if pfm.GetRadioChecked(self) or (self.radioGroup=="Sort" and self.key=="Name") then
		rematch.filters:Set(self.group,self.radioGroup,nil)
	else
		rematch.filters:Set(self.group,self.radioGroup,self.key)
	end
	rematch.petsPanel:Update()
end
-- gets an icon for the given group and key
function pfm:GetIcon()
	if self.group=="Types" or self.group=="Strong" or self.group=="Tough" then
		return "Interface\\Icons\\Pet_Type_"..PET_TYPE_SUFFIX[self.key]
	elseif self.group=="Sources" then
		return "Interface\\AddOns\\Rematch\\textures\\sources"
	end
end
-- returns texcoords for an icon
function pfm:GetIconCoords()
	if (self.group=="Sources" or self.group=="Marker") and C.COORDS_4X4[self.key] then
		return C.COORDS_4X4[self.key]
	end
end
-- resets all filter groups
function pfm:ResetAll()
	rematch.sort:ClearStickiedPetIDs()
	rematch.filters:ClearAll()
	rematch.petsPanel:Update()
end
-- resets the group of the current subMenu
function pfm:ResetGroup()
	rematch.filters:Clear(self.group)
	rematch.petsPanel:Update()
end
-- returns true if the HideMenuHelp option is enabled
function pfm:HideMenuHelp()
	return settings.HideMenuHelp
end
-- returns true if the filterGroup is currently used
function pfm:GroupUsed()
	return not rematch.filters:IsClear(self.group)
end
-- returns colored text for rarity number
function pfm:GetRarityText()
	return rematch.utils:GetRarityColor(self.key-1).hex.._G["BATTLE_PET_BREED_QUALITY"..self.key]
end
-- returns true if the user doesn't have a supported breed addon enabled
function pfm:NoBreedAddon()
	return not rematch.breedInfo:GetBreedSource()
end
-- returns the name of the breed
function pfm:GetBreedName()
	return rematch.breedInfo:GetBreedNameByID(self.key,true)
end
-- returns the color-coded name for a pet marker
function pfm:GetMarkerName()
	return rematch.utils:GetFormattedMarkerName(self.key)
end
-- returns true if the option 'Hide Non-Battle Pets' is checked
function pfm:NonBattlePetsHidden()
	return settings.HideNonBattlePets
end
-- for sort radio buttons, it should return true if default is nil
function pfm:GetSortRadio()
	return rematch.filters:GetSort(self.sortLevel)==self.key
end
-- for sort radio buttons, setting the default should make it nil (and all subsorts should be adjusted so there's no repeats)
function pfm:SetSortRadio()
	rematch.filters:SetSort(self.sortLevel,self.key)
	rematch.petsPanel:Update()
end
-- for sort radio buttons, hide sorts that are already defined for a parent sort
function pfm:HideSortRadio()
	return not rematch.filters:IsSortKeyAvailable(self.sortLevel,self.key)
end

--[[ Script Filters ]]

-- from settings.ScriptFilters, populate the Script filter menu
function rematch.menus:UpdateScriptFilters()
	local menu = rematch.menus:GetDefinition("ScriptFilters")
	wipe(menu)
	tinsert(menu,{title=L["Script Filters"]})
	for index,saved in ipairs(settings.ScriptFilters) do
		tinsert(menu,{text=saved[1], index=index, radio=true, isChecked=pfm.IsCurrentScript, tooltipTitle=pfm.SavedScriptFilterTooltipTitle, deleteButton=true, deleteFunc=pfm.DeleteScriptFilter, editButton=true, editFunc=pfm.EditScriptFilter, tooltipBody=pfm.SavedScriptFilterTooltipBody, func=pfm.LoadSavedScriptFilter})
	end
	if #menu>1 then
		tinsert(menu,{spacer=true})
	end
	tinsert(menu,{text=L["New Script"], icon="Interface\\GuildBankFrame\\UI-GuildBankFrame-NewTab", func=pfm.EditScriptFilter})
	tinsert(menu,{text=L["Help"], stay=true, isHelp=true, hidden=pfm.HideMenuHelp, icon="Interface\\Common\\help-i", iconCoords={0.15,0.85,0.15,0.85}, tooltipTitle=L["Script Filters"], tooltipBody=L["Script filters are a way to create new pet filters with Lua code.\n\nSome knowledge of Lua is helpful to create them. See docs/scriptfilters.txt for more information."]})
	tinsert(menu,{text=RESET, group="Script", stay=true, func=pfm.ResetGroup})

	rematch.menus:Register("ScriptFilters",menu)
end

-- returns true if self.index into settings.ScriptFilters is the currently-loaded script
function pfm:IsCurrentScript()
	return self.index and settings.ScriptFilters[self.index] and settings.ScriptFilters[self.index][2]==rematch.filters:Get("Script","Code")
end

-- runs the saved script filter at self.index
function pfm:LoadSavedScriptFilter()
	local code = settings.ScriptFilters[self.index] and settings.ScriptFilters[self.index][2]
	if code then
		if code==rematch.filters:Get("Script","Code") then
			rematch.filters:Clear("Script")
		else
			rematch.filters:Set("Script","Code",code)
		end
		rematch.petsPanel:Update()
	end
end

-- if self.index is nil, it's a new script filter; otherwise it's an existing one at index settings.ScriptFilters
function pfm:EditScriptFilter()
	rematch.dialog:ShowDialog("ScriptFilterDialog",self.index)
end

-- only return a title if the script filter has a comment on the first line
function pfm:SavedScriptFilterTooltipTitle()
	local code = settings.ScriptFilters[self.index][2]
	if code and code:match("^%-%-") then
		return settings.ScriptFilters[self.index][1]
	end
end

-- only return a tooltip body if the script filter has a comment on the first line
function pfm:SavedScriptFilterTooltipBody()
	local code = settings.ScriptFilters[self.index][2]
	if code and code:match("^%-%-") then
		return code:match("^%-%-(.-)\n"):trim()
	end
end

function pfm:DeleteScriptFilter()
	rematch.dialog:ShowDialog("DeleteScriptFilterDialog",self.index)
end

--[[ Favorite Filters ]]

-- from settings.FavoriteFilters, populate the Favorite Filters menu
function rematch.menus:UpdateFavoriteFilters()
	local menu = rematch.menus:GetDefinition("FavoriteFilters")
	wipe(menu)
	tinsert(menu,{title=L["Favorite Filters"]})
	for index,saved in ipairs(settings.FavoriteFilters) do
		tinsert(menu,{text=saved[1], index=index, tooltipTitle=saved[1], deleteButton=true, deleteFunc=pfm.DeleteFavoriteFilter, editButton=true, editFunc=pfm.SaveFavoriteFilter, tooltipBody=pfm.SavedFavoriteFilterTooltip, func=pfm.LoadSavedFavoriteFilter})
	end
	if #settings.FavoriteFilters>0 then
		tinsert(menu,{spacer=true})
	end
	tinsert(menu,{text=L["Save Filter"], icon="Interface\\AddOns\\Rematch\\textures\\save", isDisabled=rematch.filters.IsAllClear, disabledTooltip=L["A filter must be active before it can be saved."], func=pfm.SaveFavoriteFilter})
	rematch.menus:Register("FavoriteFilters",menu)
end

-- if self.index is nil, it's a new favorite filter; otherwise it's an existing one at index settings.FavoriteFilters
function pfm:SaveFavoriteFilter()
	rematch.dialog:ShowDialog("FavoriteFilterDialog",self.index)
end

function pfm:SavedFavoriteFilterTooltip()
	local filters = self.index and settings.FavoriteFilters[self.index]
	if filters and filters[2] then
		return rematch.filters:GetFilterList(filters[2])
	end
end

function pfm:LoadSavedFavoriteFilter()
	local filters = self.index and settings.FavoriteFilters[self.index]
	if filters and filters[2] then
		rematch.filters:LoadFavoriteFilter(filters[2])
		rematch.petsPanel:Update()
		local rawSearch = (not rematch.filters:IsClear("Search") or not rematch.filters:IsClear("Stats")) and filters[2].RawSearchText or ""
		rematch.petsPanel.Top.SearchBox:SetText(rawSearch)
		settings.Filters.RawSearchText = rawSearch
	end
end

function pfm:DeleteFavoriteFilter()
	rematch.dialog:ShowDialog("DeleteFavoriteFilterDialog",self.index)
end

--[[ Export Pets ]]

-- returns the currently filtered pets as an ordered table where each element is a line of text
function pfm:GetPetExportData()
	local results = {}
	local list = rematch.filters:RunFilters() -- get list of petIDs
	if settings.ExportSimplePetList then
		-- for a simple list, only listing (in alphabetical order) pets by their species name with a count if more than one
		local speciesCount = {}
		local total,unique = 0,0
		for _,petID in ipairs(list) do
			local speciesName = rematch.petInfo:Fetch(petID).speciesName
			if speciesCount[speciesName] then
				speciesCount[speciesName] = speciesCount[speciesName] + 1
			else
				speciesCount[speciesName] = 1
				unique = unique + 1
			end
			total = total + 1
		end
		for speciesName,count in pairs(speciesCount) do
			tinsert(results,count>1 and format("%s x%d",speciesName,count) or speciesName)
		end
		table.sort(results)
		tinsert(results,format(L["Total Pets: %d"],total))
		tinsert(results,format(L["Distinct Pets: %d"],unique))
	else -- for detailed list, generate a csv of pet details
		local header = L["Species Name,Custom Name,Type,Collected,Favorite,Level,Rarity"]
		if rematch.breedInfo:GetBreedSource() then
			header = header..L[",Breed"]
		end
		tinsert(results,header)
		for _,petID in ipairs(list) do
			local petInfo = rematch.petInfo:Fetch(petID)
			local speciesName = (petInfo.speciesName:match(",") and '"'..petInfo.speciesName..'"' or petInfo.speciesName)
			local line = speciesName..","..(petInfo.customName or "")..","..(petInfo.petTypeName or "")..","..
					(petInfo.isOwned and "Y" or "N")..","..(petInfo.isFavorite and "Y" or "N")..","..(petInfo.level or "")..","..
					(petInfo.rarity and _G["BATTLE_PET_BREED_QUALITY"..(min(6,petInfo.rarity))] or "")
			-- if a breed addon enabled, add breed to end (P/P letter breed, not icon breed)
			-- with special handling for PetTracker. another reason not to use icons as breeds: you can't put icons in a csv!
			if rematch.breedInfo:GetBreedSource() then
				local breedName = petInfo.breedName and rematch.breedInfo:GetBreedNameByID(petInfo.breedID,nil,true)
				if not breedName then -- a new breed for pettracker won't have a lettered value here, determine if new or breed n/a
					if petInfo.isOwned and petInfo.canBattle then
						breedName = "NEW"
					else
						breedName = ""
					end
				end
				line = line..","..breedName
			end
			tinsert(results,line)
		end
	end
	return results
end

function pfm:ExportPets()
	rematch.dialog:ShowDialog("ExportPetsDialog")
end

function pfm:RenameMarker()
	rematch.dialog:ShowDialog("RenamePetMarkerDialog",self.key)
end

function pfm:PetHerder()
	rematch.dialog:ShowDialog("PetHerder")
end
