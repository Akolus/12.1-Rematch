local _,rematch = ...
local L = rematch.localization
local C = rematch.constants

--[[ Option format:

	[1] = type of option: "check" "radio" "header" "widget" or "spacer"

	"check"
	[2] = the settings[var] of the optn ("FastPetCard", "ClickPetCard", etc)
	[3] = the name of the option as displayed ("Faster pet cards", "Click for pet cards", etc)
	[4] = the tooltip text of the option
	[5] = the settings[var] that the option is dependant upon ("AutoLoadTargetOnly" would have "AutoLoad" here)
	[6] = name of optionFunc to run when clicked, or true if it's named after the setting
	[7] = boolean whether this setting's optionFunc should run on login

	"radio"
	[2] = the shared settings[var] of the option
	[3] = the name of the option as displayed ("Minimized Standalone" "Maximized Standalone")
	[4] = the tooltip text of the option
	[5] = the value (number) to assign to the shared settings[var]

	"header"
	[2] = text to display in header
	[3] = header index (number, see below)

	"widget"
	[2] = name of widget (parentKey of childframe to RematchOptionPanel)

	Header indexes: These numbers are "keys" to the header (expanded in settings.ExpandedOptHeaders).
	If changing headers, make sure not to reuse an index. It's ok if they're missing or if
	they're out of order. The index is merely for a permanent expanded handle.
		0 = All Options
		1 = Targeting Options
		2 = Standalone Window Options
		3 = Appearance Options
		4 = Pet Card & Notes Options
		5 = Leveling Queue Options
		6 = Miscellaneous Options
		7 = Preferred Window Mode
		8 = Pet Filters
		9 = Toolbar Options
		10 = Team Options
		11 = Confirmation Options
		12 = Debugging Options
		13 = Team Win Record Options
		14 = List Behavior Options
		15 = Help Options
		16 = Ability Tooltip Options
		17 = Notes Options
		18 = Breed Options
		19 = Leveling Queue Options
		20 = About
		21 = Random Pet Options
		22 = Icon Legend
		23 = Badge Options
]]

rematch.optionsList = {
	-- All Options
	--{type="header", group=0, text=L["All Options"]},
	-- Targeting Options
	{type="header", group=1, text=L["Interaction Options"]},
	{type="dropdown", group=1, text=L["On Target"], var="InteractOnTarget", func="InteractOnTarget", tooltip=L["Choose the action to take when you target an NPC with a saved team that's not already loaded."],
		menu = {{text=L["Do Nothing"], value=C.INTERACT_NONE, tooltipTitle=L["Do Nothing"], tooltipBody=L["When targeting an NPC with a saved team not already loaded, do nothing."]},
				{text=L["Prompt To Load"], value=C.INTERACT_PROMPT, tooltipTitle=L["Prompt To Load"], tooltipBody=L["When targeting an NPC with a saved team not already loaded, show a prompt to load the save team."]},
				{text=L["Show Window"], value=C.INTERACT_WINDOW, tooltipTitle=L["Show Window"], tooltipBody=L["When targeting an NPC with a saved team not already loaded, show the standalone Rematch window."]},
				{text=L["Auto Load"], value=C.INTERACT_AUTOLOAD, tooltipTitle=L["Auto Load"], tooltipBody=format(L["When targeting an NPC with a saved team not already loaded, automatically load the saved team.\n\n%sWarning\124r: If you target with right click and immediately enter battle, it may be too late to load a team. %sAuto Load is not recommended for On Target.\124r Use On Mouseover for Auto Load instead."],C.HEX_RED,C.HEX_WHITE)}}
	},
	{type="dropdown", group=1, text=L["On Mouseover"], var="InteractOnMouseover", func="InteractOnMouseover", tooltip=L["Choose the action to take when the mouse moves over an NPC with a saved team that's not already loaded."],
		menu = {{text=L["Do Nothing"], value=C.INTERACT_NONE, tooltipTitle=L["Do Nothing"], tooltipBody=L["When the mouse moves over an NPC with a saved team not already loaded, do nothing."]},
				{text=L["Prompt To Load"], value=C.INTERACT_PROMPT, tooltipTitle=L["Prompt To Load"], tooltipBody=L["When the mouse moves over an NPC with a saved team not already loaded, show a prompt to load the save team."]},
				{text=L["Show Window"], value=C.INTERACT_WINDOW, tooltipTitle=L["Show Window"], tooltipBody=L["When the mouse moves over an NPC with a saved team not already loaded, show the standalone Rematch window."]},
				{text=L["Auto Load"], value=C.INTERACT_AUTOLOAD, tooltipTitle=L["Auto Load"], tooltipBody=L["When the mouse moves over an NPC with a saved team not already loaded, automatically load the saved team."]}}
	},
	{type="dropdown", group=1, text=L["On Soft Interact"], var="InteractOnSoftInteract", func="InteractOnSoftInteract", tooltip=format(L["Choose the action to take when you soft interact with an NPC with a saved team that's not already loaded.\n\n%sNote\124r: This option is only available if SoftTargetInteract cvar is fully enabled (3). It will be hidden otherwise."],C.HEX_WHITE),
		menu = {{text=L["Do Nothing"], value=C.INTERACT_NONE, tooltipTitle=L["Do Nothing"], tooltipBody=L["When soft interactiong with an NPC with a saved team not already loaded, do nothing."]},
				{text=L["Prompt To Load"], value=C.INTERACT_PROMPT, tooltipTitle=L["Prompt To Load"], tooltipBody=L["When soft interacting with an NPC with a saved team not already loaded, show a prompt to load the save team."]},
				{text=L["Show Window"], value=C.INTERACT_WINDOW, tooltipTitle=L["Show Window"], tooltipBody=L["When soft interacting with an NPC with a saved team not already loaded, show the standalone Rematch window."]},
				{text=L["Auto Load"], value=C.INTERACT_AUTOLOAD, tooltipTitle=L["Auto Load"], tooltipBody=format(L["When soft interacting with an NPC with a saved team not already loaded, automatically load the saved team."],C.HEX_RED,C.HEX_WHITE)}}
	},
	{type="check", group=1, text=L["Always Interact"], var="InteractAlways", tooltip=L["The default behavior is to perform the target or mouseover interaction once until you interact with another NPC with a saved team. Check this to always interact with NPCs that have a saved team not already loaded."]},
	{type="check", group=1, text=L["Even If Team Already Loaded"], var="InteractAlwaysEvenLoaded", dependency="InteractAlways", tooltip=L["Always interact with a saved target even if a team is already loaded for that target."]},
	{type="check", group=1, text=L["Prefer Uninjured Teams"], var="InteractPreferUninjured", tooltip=L["When you interact with an NPC that has more than one team saved to it, choose the team with no injured pets instead of the topmost team for the target. On Prompt To Load and Show Window options where you can choose which team to load before loading, start with the healthiest team."]},
	{type="check", group=1, text=L["Show Window After Loading"], var="InteractShowAfterLoad", tooltip=L["When a team is loaded from an interaction (target or mouseover) and the Rematch window is not on screen, summon the standalone Rematch window."]},
	{type="check", group=1, text=L["Only When Any Pets Injured"], var="InteractOnlyWhenInjured", dependency="InteractShowAfterLoad", tooltip=L["If a team is loaded but no pets are injured, don't summon the Rematch window."]},

	-- Standalone Window Options
	{type="header", group=2, text=L["Standalone Window Options"]},
	{type="dropdown", group=2, text=L["Anchor To"], var="Anchor", func="Anchor", tooltip=L["When the standalone window is minimized or maximized, use the chosen corner/edge as the anchor."],
		menu = {{text="Bottom Left", value="BOTTOMLEFT", icon="Interface\\AddOns\\Rematch\\textures\\arrows", iconCoords={0,0.25,0.5,0.75}},
				{text="Bottom Center", value="BOTTOM", icon="Interface\\AddOns\\Rematch\\textures\\arrows", iconCoords={0.25,0.5,0.5,0.75}},
				{text="Bottom Right", value="BOTTOMRIGHT", icon="Interface\\AddOns\\Rematch\\textures\\arrows", iconCoords={0.5,0.75,0.5,0.75}},
				{text="Top Right", value="TOPRIGHT", icon="Interface\\AddOns\\Rematch\\textures\\arrows", iconCoords={0.5,0.75,0,0.25}},
				{text="Top Center", value="TOP", icon="Interface\\AddOns\\Rematch\\textures\\arrows", iconCoords={0.25,0.5,0,0.25}},
				{text="Top Left", value="TOPLEFT", icon="Interface\\AddOns\\Rematch\\textures\\arrows", iconCoords={0,0.25,0,0.25}}}
	},
	{type="dropdown", group=2, text=L["Panel Tabs"], var="PanelTabAnchor", func="PanelTabAnchor", tooltip=L["Choose which corner of the standalone Rematch window to anchor panel tabs such as Pets, Teams, Targets, etc.\n\nNote: Choosing a new anchor for the whole window will change the tabs anchor to match. You can change this tabs anchor again anytime."],
		menu = {{text="Bottom Left", value="BOTTOMLEFT", icon="Interface\\AddOns\\Rematch\\textures\\arrows", iconCoords={0,0.25,0.5,0.75}},
				{text="Bottom Center", value="BOTTOM", icon="Interface\\AddOns\\Rematch\\textures\\arrows", iconCoords={0.25,0.5,0.5,0.75}},
				{text="Bottom Right", value="BOTTOMRIGHT", icon="Interface\\AddOns\\Rematch\\textures\\arrows", iconCoords={0.5,0.75,0.5,0.75}},
				{text="Top Right", value="TOPRIGHT", icon="Interface\\AddOns\\Rematch\\textures\\arrows", iconCoords={0.5,0.75,0,0.25}},
				{text="Top Center", value="TOP", icon="Interface\\AddOns\\Rematch\\textures\\arrows", iconCoords={0.25,0.5,0,0.25}},
				{text="Top Left", value="TOPLEFT", icon="Interface\\AddOns\\Rematch\\textures\\arrows", iconCoords={0,0.25,0,0.25}}}
	},
	{type="check", group=2, text=L["Prefer Minimized Window"], var="PreferMinimized", tooltip=L["When the window is automatically summoned such as from an Interact Option or Safari Hat Reminder, summon the window in minimized mode."]},
	{type="widget", group=2, text=L["Use Custom Scale"], parentKey="UseCustomScaleWidget"},
	{type="check", group=2, text=L["Keep Window On Screen"], var="LockWindow", tooltip=L["Don't hide the standalone window when the ESCape key is pressed or most other times it would hide, such as going to the game menu."]},
	{type="check", group=2, text=L["Even For Pet Battles"], var="StayForBattle", dependency="LockWindow", tooltip=L["Keep the standalone window on the screen even when you enter pet battles."]},
	{type="check", group=2, text=L["Even Across Sessions"], var="StayOnLogout", dependency="LockWindow", tooltip=L["If the standalone window was on screen when logging out, automatically summon it on next login."]},
	{type="check", group=2, text=L["Don't Minimize With ESC Key"], var="LockDrawer", tooltip=L["Don't minimize the standalone window when the ESCape key (or game menu key) is pressed."]},
	{type="check", group=2, text=L["Don't Minimize With Panel Tabs"], var="DontMinTabToggle", tooltip=L["Don't let the Pets, Teams, Queue or Options tabs minimize the standalone window."]},
	{type="check", group=2, text=L["Lower Window Behind UI"], var="LowerStrata", func="LowerStrata", tooltip=L["Push the standalone window back behind other parts of the UI so other parts of the UI can appear ontop."]},
	{type="check", group=2, text=L["Show Pets Tab While Minimized"], var="PreferPetsTab", tooltip=L["When the window has a Pets tab and is minimized, drop the Targets tab and keep the Pets tab visible."] },
	{type="check", group=2, text=L["Show Window After Battle"], var="ShowAfterBattle", tooltip=L["Show the standalone Rematch window after leaving a pet battle."]},
	{type="check", group=2, text=L["But Not After PVP Battle"], var="ShowAfterPVEOnly", dependency="ShowAfterBattle", tooltip=L["Since pets don't remain injured in PVP battles, don't show the window when leaving a PVP battle."]},

	-- Appearance Options
	{type="header", group=3, text=L["Appearance Options"]},
    {type="check", group=3, text=L["Use Custom Battle UI (Requires Reload)"], var="UseCustomBattleUI", func="CustomBattleUI", tooltip=L["Enable Rematch's custom pet battle menu, action bar and PvP timer. Unchecked uses Blizzard's default battle UI. After changing this option, type /reload to apply it."]},
	{type="check", group=3, text=L["Compact Pet List"], var="CompactPetList", func="CompactPetList", tooltip=L["Display more pets in the pet list by using a more compact view of each pet."]},
    {type="check", group=3, text=L["Compact Team List"], var="CompactTeamList", func="CompactTeamList", tooltip=L["Display more teams in the team list by using a more compact view of each team."]},
	{type="check", group=3, text=L["Compact Target List"], var="CompactTargetList", func="CompactTargetList", tooltip=L["Display more targets in the target list by using a more compact view of each target."]},
	{type="check", group=3, text=L["Compact Queue List"], var="CompactQueueList", func="CompactQueueList", tooltip=L["Display more pets in the queue by using a more compact view of each pet."]},
	{type="check", group=3, text=L["Hide Level At Max Level"], var="HideLevelBubbles", update=true, tooltip=L["If a pet is level 25, don't show its level on the pet icon."]},
	{type="check", group=3, text=L["Hide Rarity Borders"], var="HideRarityBorders", update=true, tooltip=L["Don't color the icon border for pets you own in the same color as its rarity."]},
	{type="check", group=3, text=L["Show Ability Numbers"], var="ShowAbilityNumbers", update=true, tooltip=L["In the ability flyout, show the numbers 1 and 2 to help with the common notation such as \"Pet Name 122\" to know which abilities to use."]},
	{type="check", group=3, text=L["On Loaded Abilities Too"], var="ShowAbilityNumbersLoaded", dependency="ShowAbilityNumbers", update=true, tooltip=L["In addition to the flyouts, show the numbers 1 and 2 on loaded abilities."]},
	{type="check", group=3, text=L["Color Pet Names By Rarity"], var="ColorPetNames", update=true, tooltip=L["Make the names of pets you own the same color as its rarity. Blue for rare, green for uncommon, etc."]},
	{type="check", group=3, text=L["Color Team Names By Group"], var="ColorTeamNames", update=true, tooltip=L["Make team names colored the same as the colors you've chosen for the groups they belong to."]},
	{type="check", group=3, text=L["Color Targets By Expansion"], var="ColorTargetNames", update=true, tooltip=L["Make notable target names colored after the expansion the target is from."]},

	-- Badge Options
	{type="header", group=23, text=L["Badge Options"]},
	--{type="check", group=23, text=L["Only Show Badges On Mouseover"], var="ShowBadgesOnMouseover", update=true, tooltip=L["Hide all badges unless the mouse is over the pet, team or target.\n\nA badge is a non-interactive icon to the right of a list item to indicate some property such as whether it's leveling.\n\nWith this option enabled, the notes button, breed and win record are also hidden unless the mouse is over the list item."]},
	{type="check", group=23, text=format(L["Hide Team Badges %s"],rematch.utils:GetBadgeAsText(12,14,true)), var="HideTeamBadges", update=true, tooltip=format(L["Hide the %s badge on pets and targets that indicate the pet or target is saved in a team."],rematch.utils:GetBadgeAsText(12,14,true))},
	{type="check", group=23, text=format(L["Hide Leveling Badges %s"],rematch.utils:GetBadgeAsText(11,14,true)), var="HideLevelingBadges", update=true, tooltip=format(L["Hide the %s badge on pets that indicate the pet is in the leveling queue."],rematch.utils:GetBadgeAsText(11,14,true))},
	{type="check", group=23, text=format(L["Hide Pet Tag Badges %s"],rematch.utils:GetBadgeAsText(16,14,true)), var="HideMarkerBadges", update=true, tooltip=format(L["Hide the pet tag badges (such as %s %s %s etc) on pets to indicate what pet tag has been given to the pet."],rematch.utils:GetBadgeAsText(16,14,true),rematch.utils:GetBadgeAsText(17,14,true),rematch.utils:GetBadgeAsText(18,14,true))},
	{type="check", group=23, text=format(L["Hide Target Badges %s"],rematch.utils:GetBadgeAsText(27,14,true)), var="HideTargetBadges", update=true, tooltip=format(L["Hide the %s badge on teams that indicate the team contains a target."],rematch.utils:GetBadgeAsText(27,14,true))},
	{type="check", group=23, text=format(L["Hide Preference Badges %s"],rematch.utils:GetBadgeAsText(14,14,true)), var="HidePreferenceBadges", update=true, tooltip=format(L["Hide the %s badge on teams that indicate the team contains leveling preferences."],rematch.utils:GetBadgeAsText(14,14,true))},
	{type="check", group=23, text=format(L["Hide Notes Badges %s"],rematch.utils:GetBadgeAsText(13,16,false)), var="HideNotesBadges", update=true, tooltip=format(L["Hide the %s badge/button on pets and teams that indicate the pet or team has saved notes."],rematch.utils:GetBadgeAsText(13,16,false))},
	-- {type="check", group=23, text=format(L["Hide External Badges %s"],rematch.utils:GetBadgeAsText(33,16,true)), var="HideExternalBadges", update=true, tooltip=L["Try to hide any badges added to lists from an external source like a third-party addon. (Rematch has no control over what outside addons do, so some addon's badges may not hide with this option.)"]},

	-- Behavior Options
	{type="header", group=14, text=L["Behavior Options"]},
	{type="dropdown", group=14, text=L["Card Speed"], var="CardBehavior", tooltip=L["Choose how quickly you prefer the pet card and notes to be shown when you mouseover a pet or notes button."],
		menu = {{text=L["Slow"], value=C.MOUSE_SPEED_SLOW, tooltipTitle=L["Slow Mouseover"], tooltipBody=L["Wait three quarters of a second for the pet card or notes to appear when you mouseover a pet or notes button."]},
				{text=L["Normal"], value=C.MOUSE_SPEED_NORMAL, tooltipTitle=L["Normal Mouseover"], tooltipBody=L["Wait a quarter of a second for the pet card or notes to appear when you mouseover a pet or notes button."]},
				{text=L["Fast"], value=C.MOUSE_SPEED_FAST, tooltipTitle=L["Fast Mouseover"], tooltipBody=L["Immediately show the pet card or notes when you mouseover a pet or notes button."]},
				{text=L["On Click"], value=C.MOUSE_SPEED_CLICK, tooltipTitle=L["On Click"], tooltipBody=L["Only show the pet card or notes when you click a pet or notes button."]}}
	},
	{type="dropdown", group=14, text=L["Tooltip Speed"], var="TooltipBehavior", tooltip=L["Choose how quickly you prefer the tooltips (including pet ability tooltips) to be shown."],
		menu = {{text=L["Slow"], value=C.MOUSE_SPEED_SLOW, tooltipTitle=L["Slow Mouseover"], tooltipBody=L["Wait three quarters of a second for the tooltip to appear when you mouseover a button with a tooltip."]},
				{text=L["Normal"], value=C.MOUSE_SPEED_NORMAL, tooltipTitle=L["Normal Mouseover"], tooltipBody=L["Wait a quarter of a second for the tooltip to appear when you mouseover a button with a tooltip."]},
				{text=L["Fast"], value=C.MOUSE_SPEED_FAST, tooltipTitle=L["Fast Mouseover"], tooltipBody=L["Immediately show the tooltip when you mouseover a button with a tooltip."]}}
	},
	{type="dropdown", group=14, text=L["Mousewheel Speed"], var="MousewheelSpeed", func="MousewheelSpeed", tooltip=L["Choose how quickly you prefer lists to scroll when you mousewheel up or down over a list."],
		menu = {{text=L["Slow"], value=C.MOUSE_SPEED_SLOW, tooltipTitle=L["Slow Mousewheel"], tooltipBody=L["Scroll one line at a time."]},
				{text=L["Normal"], value=C.MOUSE_SPEED_NORMAL, tooltipTitle=L["Normal Mousewheel"], tooltipBody=L["Scroll two lines at a time."]},
				{text=L["Medium"], value=C.MOUSE_SPEED_MEDIUM, tooltipTitle=L["Medium Mousewheel"], tooltipBody=L["Scroll roughly half a page at a time."]},
				{text=L["Fast"], value=C.MOUSE_SPEED_FAST, tooltipTitle=L["Fast Mousewheel"], tooltipBody=L["Scroll nearly a whole page at a time."]}}
	},
	{type="check", group=14, text=L["Collapse Lists With ESC Key"], var="CollapseOnEsc", tooltip=L["When the ESCape key (or game menu key) is pressed, collapse any expanded list--such as this options list, teams or targets."]},

	-- Toolbar Options
	{type="header", group=9, text=L["Toolbar Options"]},
	{type="check", group=9, text=L["Reverse Toolbar Buttons"], var="ReverseToolbar", func="ConfigureToolbar", tooltip=L["Reverse the order of the toolbar buttons (Revive Battle Pets, Battle Pet Bandages, Safari Hat, etc)."]},
	{type="check", group=9, text=L["Hide On Toolbar Right Click"], var="ToolbarDismiss", tooltip=L["When a toolbar button is used with a right click, dismiss the Rematch window after performing its action."]},
	{type="check", group=9, text=L["Safari Hat Reminder"], var="SafariHatShine", update=true, tooltip=L["When a pet is laoded below max level, draw attention to the Safari Hat button, including summoning the window if it's not on screen."]},
	{type="check", group=9, text=L["Display Unique Pets Total"], var="DisplayUniqueTotal", update=true, tooltip=L["Instead of Total Pets in the collections button at the topleft, display a total of Unique Pets."]},
	{type="check", group=9, text=L["Always Use Pet Satchel"], var="AlwaysUsePetSatchel", func="ConfigureToolbar", tooltip=L["Rather than displaying all toolbar buttons in larger views of the addon, always use the Pet Satchel button to cycle through infrequently used toolbar buttons."]},

	-- Pet Filter Options
	{type="header", group=8, text=L["Pet Filter Options"]},
	{type="check", group=8, text=L["Use Level In Strong Vs Filter"], var="StrongVsLevel", func="UpdateFilters", tooltip=L["When doing a Strong Vs filter, take the level of the pet into account. If a pet is not high enough level to use a Strong Vs ability, do not list the pet.\n\n\124cffffffffNote:\124r A Strong Vs filter is sometimes useful for identifying pets you want to level or capture. This option will hide those pets while the Strong Vs filter is active."]},
	{type="check", group=8, text=L["Reset Filters On Login"], var="ResetFilters", tooltip=L["When logging in, start with all pets listed and no filters active."]},
	{type="check", group=8, text=L["Reset Sort With Filters"], var="ResetSortWithFilters", update=true, tooltip=L["When clearing filters, also reset the sort back to the default: Sort by Name, Favorites First."]},
	{type="check", group=8, text=L["Don't Reset Search With Filters"], var="ResetExceptSearch", update=true, tooltip=L["When manually clearing filters, don't clear the search box too.\n\nSome actions, such as logging in or Find Similar, will always clear search regardless of this setting."]},
	{type="check", group=8, text=L["Sort By Chosen Name"], var="SortByNickname", func="UpdateFilters", tooltip=L["When pets are sorted by name, sort them by the name given with the Rename option instead of their original name."]},
	{type="check", group=8, text=L["Sort New Pets To Top"], var="StickyNewPets", func="UpdateFilters", tooltip=L["When you learn new pets, temporarily sort them to the top of the pet list until you next close Rematch or choose Reset All from the filter menu."]},
	{type="check", group=8, text=L["Hide Non-Battle Pets"], var="HideNonBattlePets", func="UpdateFilters", tooltip=L["Only list pets that can battle. Do not list pets like balloons, squires and other companion pets that cannot battle."]},
	{type="check", group=8, text=L["Allow Hidden Pets"], var="AllowHiddenPets", func="UpdateHiddenPetFilter", tooltip=L["Allow the ability to hide specific pet species in the pet list with a 'Hide Pet' in the list's right-click menu.\n\nYou can view pets you've hidden from the Other -> Hidden Pets filter."]},
	{type="check", group=8, text=L["Export Simple Pet List"], var="ExportSimplePetList", func="ExportSimplePetList", tooltip=L["When exporting pets from the Export Pets filter menu item, only export a list of pets without details."]},
	{type="check", group=8, text=L["Don't Sort By Relevance"], var="DontSortByRelevance", func="UpdateFilters", tooltip=L["When searching for pets by name, don't sort the results by relevance.\n\nWhen sorted by relevance, pets with the search term in their name are listed first, followed by term in notes, then abilities."]},

	-- Breed Options
	{type="header", group=18, text=L["Breed Options"]},
	{type="dropdown", group=18, text=L["Breed Source"], var="BreedSource", func="BreedSource", tooltip=L["Which enabled addon you want to use to supply breed data."],
		menu = {{text=L["None"], value="None", tooltipTitle=L["None"], tooltipBody=L["No breed information will be shown if this is selected. Rematch does not maintain its own breed data."]},
				{text=L["Battle Pet Breed ID"], value="BattlePetBreedID", hidden=function() return not C_AddOns.IsAddOnLoaded("BattlePetBreedID") end},
				{text=L["PetTracker"], value="PetTracker", hidden=function() return not C_AddOns.IsAddOnLoaded("PetTracker") end}}
	},
	{type="dropdown", group=18, text=L["Breed Format"], var="BreedFormat", func="BreedFormat", tooltip=L["How breeds should display."],
		menu = {{text=L["Letters"], value=C.BREED_FORMAT_LETTERS},
				{text=L["Numbers"], value=C.BREED_FORMAT_NUMBERS},
				{text=L["Icons"], value=C.BREED_FORMAT_ICONS, hidden=function() return not C_AddOns.IsAddOnLoaded("PetTracker") end}}
	},
	{type="check", group=18, text=L["Hide Breed In Lists"], var="HideBreedsLists", update=true, tooltip=L["Hide the breeds displayed in lists. Breeds will still be visible in pet cards."]},
	{type="check", group=18, text=L["Hide Breed In Pet Slots"], var="HideBreedsLoadouts", update=true, tooltip=L["Hide the breeds displayed on pet slots. Breeds will still be visible in pet cards."]},
	{type="check", group=18, text=L["Larger Breed Text"], var="LargerBreedText", update=true, tooltip=L["Increase the size of breed text (such as B/B or H/P) on pet list buttons and pet slots."]},

	-- Pet Card Options
	{type="header", group=4, text=L["Pet Card Options"]},
	{type="dropdown", group=4, text=L["Card Background"], var="PetCardBackground", func="UpdatePetCard", tooltip=L["The artwork displayed in the background on the front of pet cards."],
		menu = {{text=L["Expansion Art"], value="Expansion"},{text=L["Portrait Art"], value="Portrait"},{text=L["Icon Art"], value="Icon"},{text=L["Type Art"], value="Type"},{text=L["None"], value="None"}}
	},
	{type="dropdown", group=4, text=L["Flip Modifier Key"], var="PetCardFlipKey", func="UpdatePetCard", tooltip=L["The modifier key that will flip the pet card over. Regardless of this setting, you can flip the pet card over by mouseover of the pet's icon at the top of the card."],
		menu = {{text="Alt Key", value="Alt"},{text="Shift Key", value="Shift"},{text="Ctrl Key", value="Ctrl"},{text="None", value="None"}}
	},
	{type="check", group=4, text=L["Don't Flip On Mouseover"], var="PetCardNoMouseoverFlip", tooltip=L["When you mouseover the pet icon or type icon at the top of the pet card, don't flip to the back of the card. Instead, flip the card only by clicking the pet or type icon at the top of the pet card; or by the flip modifier key if defined."]},
	{type="check", group=4, text=L["Allow Pet Cards To Be Pinned"], var="PetCardCanPin", func="UpdatePetCardPin", tooltip=L["When dragging a pet card to another part of the screen, pin the card so all future pet cards display in the same spot, until the pet card is moved again or the unpin button is clicked."]},
	{type="check", group=4, text=L["Always Show Health Bar"], var="PetCardAlwaysShowHPBar", func="UpdatePetCard", tooltip=L["On the pet card, always display the health bar if a pet can battle and has health. While unchecked, the health bar is only displayed for injured pets."]},
	{type="check", group=4, text=L["Always Show HP/XP Bar Text"], var="PetCardAlwaysShowHPXPText", func="UpdatePetCard", tooltip=L["On the pet card health and experience bars, keep the status text always visible instead of requiring a mouseover to view."]},
	{type="check", group=4, text=L["Always Hide Possible Breeds"], var="PetCardHidePossibleBreeds", func="UpdatePetCard", tooltip=L["When the pet card is not minimized, rather than list possible breeds across the bottom of the pet card, always put the list of possible breeds in the tooltip of the pet's breed stat button.\n\nNote: For uncollected pets that don't have a breed, this means possible breeds will not be visible."]},
	{type="check", group=4, text=L["Always Use Collected Stat"], var="PetCardCompactCollected", func="UpdatePetCard", tooltip=L["When the pet card is not minimized, rather than list collected versions of a pet across the bottom of the pet card, use a collected button alongside other stats to display collected totals. Mouseover of the button will display the list of collected versions of the pet."]},
	{type="check", group=4, text=L["Show Expansion On Front"], var="PetCardShowExpansionStat", func="UpdatePetCard", tooltip=L["Instead of displaying the expansion the pet is from on the back of the pet card, display it on the front alongside other stats."]},
	--{type="check", group=4, text=L["Show Strongest Vs Stat"], var="ShowStrongestVsStat", func="UpdatePetCard", tooltip=L["On the pet card display the top three pet types the pet is strongest against, based on its abilities."]},
	{type="check", group=4, text=L["Show Species IDs Stat"], var="ShowSpeciesID", func="UpdatePetCard", tooltip=L["Display the numerical speciesID as a stat on pet cards."]},
	{type="check", group=4, text=L["Alternate Lore Font"], var="BoringLoreFont", func="UpdatePetCard", tooltip=L["Use a more modern-looking font for lore text on the back of the pet card."]},
	{type="check", group=4, text=L["Use Pet Cards In Battle"], var="PetCardInBattle", tooltip=L["Use the pet card on the unit frames during a pet battle instead of the default tooltip."]},
	{type="check", group=4, text=L["Use Pet Cards For Links"], var="PetCardForLinks", tooltip=L["Use the pet card when viewing a link of a pet someone else sent you instead of the default link."]},

	-- Notes Options
	{type="header", group=17, text=L["Notes Options"]},
	{type="check", group=17, text=L["Keep Notes On Screen"], var="KeepNotesOnScreen", tooltip=L["Don't hide notes when changing tabs or closing Rematch."]},
	{type="check", group=17, text=L["Even When Escape Pressed"], var="NotesNoEsc", dependency="KeepNotesOnScreen", tooltip=L["Also don't hide notes when ESCape key is pressed."]},
	{type="check", group=17, text=L["Show Notes When Teams Load"], var="ShowNotesOnLoad", tooltip=L["When a team with notes is loaded, display the notes for the team."]},
	{type="check", group=17, text=L["Show Notes In Battle"], var="ShowNotesInBattle", tooltip=L["If the loaded team has notes, display and lock the notes when you enter a pet battle."]},
	{type="check", group=17, text=L["Only Once Per Team"], var="ShowNotesOnce", dependency="ShowNotesInBattle", tooltip=L["Only display notes automatically the first time entering battle, until another team is loaded."]},
	{type="dropdown", group=17, text=L["Notes Size"], var="NotesFont", func="NotesFont", tooltip=L["Choose the size of the text in the pet and team notes."],
		menu = {{text=L["Small"], value="GameFontHighlightSmall"},{text=L["Medium"], value="GameFontHighlight"},{text=L["Large"], value="GameFontHighlightLarge"}}
	},
	{type="check", group=17, text=L["Hide Notes Button In Battle"], var="HideNotesButtonInBattle", func="HideNotesButtonInBattle", tooltip=L["In the Battle UI, hide the notes \"micro\" button to show notes for the currently-loaded team. Enable this option if another addon wants to use the same space."]},

	-- Ability Tooltip Options
	{type="header", group=16, text=L["Ability Tooltip Options"]},
	{type="dropdown", group=16, text=L["Ability Background"], var="AbilityBackground", tooltip=L["The artwork displayed in the background of ability tooltips."],
		menu = {{text=L["Icon Art"], value="Icon"},{text=L["Type Art"], value="Type"},{text=L["None"], value="None"}}
	},
	{type="check", group=16, text=L["Show Ability IDs"], var="ShowAbilityID", tooltip=L["Show the ability ID for the ability being viewed in the ability tooltip."]},

	-- Team Options
	{type="header", group=10, text=L["Team Options"]},
	{type="check", group=10, text=L["Load Healthiest Pets"], var="LoadHealthiest", tooltip=L["When a team loads, if any pet is injured or dead and there's another version with more health \124cffffffffand identical stats\124r, load the healthier version.\n\nPets in the leveling queue are exempt from this option.\n\n\124cffffffffNote:\124r This is only when a team loads. It will not automatically swap in healthier pets when you leave battle."] },
	{type="check", group=10, text=L["Allow Any Version"], var="LoadHealthiestAny", dependency="LoadHealthiest", tooltip=L["Instead of choosing only the healthiest pet with identical stats, choose the healthiest version of the pet regardless of stats."], "LoadHealthiest" },
	{type="check", group=10, text=L["After Battles Or Heals Too"], var="LoadHealthiestAfterBattle", dependency="LoadHealthiest", tooltip=L["Also load healthiest pets after leaving a pet battle or using Revive Battle Pets or Battle Pet Bandage."], "LoadHealthiest"},
	{type="check", group=10, text=L["Show Create New Group Tab"], var="ShowNewGroupTab", func="ShowNewGroupTab", tooltip=L["When space permits, add a button at the bottom of team tabs to create a new group."]},
	{type="check", group=10, text=L["Always Show Team Tabs"], var="AlwaysTeamTabs", func="AlwaysTeamTabs", tooltip=L["Show team tabs along the right side of the window even if you're not on the teams panel."]},
	{type="check", group=10, text=L["Never Show Team Tabs"], var="NeverTeamTabs", func="NeverTeamTabs", tooltip=L["Never show team tabs along the right side of the window even if you're on the teams panel."]},
	{type="check", group=10, text=L["Display Where Teams Dragged"], var="EchoTeamDrag", tooltip=L["When a team is dragged to another group, print in the chat window where the team was moved to."]},
	{type="check", group=10, text=L["Enable Dragging To Move Teams"], var="EnableDrag", tooltip=L["Allow moving teams or groups by dragging them. When this is unchecked you can still move a team or group from its right-click menu."]},
	{type="check", group=10, text=L["Require Click To Drag Teams"], var="ClickToDrag", dependency="EnableDrag", tooltip=L["When dragging teams or groups to move them, release of the mouse button at the end of the drag will not move the team or group. A separate click is needed."]},
	{type="dropdown", group=10, text=L["Combine Group Key"], var="CombineGroupKey", tooltip=L["While dragging a team group in the team list, holding this modifier key when you click another group will combine the two groups by moving all teams in the group on the cursor into the clicked group."],
		menu = {{text="Alt Key", value="Alt"},{text="Shift Key", value="Shift"},{text="Ctrl Key", value="Ctrl"},{text=L["None"], value="None"}}
	},
	{type="check", group=10, text=L["Prioritize Breed On Import"], var="PrioritizeBreedOnImport", tooltip=L["When importing or receiving teams, fill the team with the best matched breed as the first priority instead of the highest level."]},
	{type="check", group=10, text=L["Remember Import Override"], var="ImportRememberOverride", tooltip=L["Rather than resetting to 'Create a new copy' everytime a team is imported and another team shares the same name, remember the last-chosen option without resetting."]},

	-- Random Pet Options
	{type="header", group=21, text=L["Random Pet Options"]},
	{type="dropdown", group=21, text=L["Random Pet Rules"], var="RandomPetRules", tooltip=L["Rules to apply when loading a random pet. The more strict rules will limit the pool of random pets to choose from.\n\nNote: When a team loads with random pets in all three slots, 'Lenient' rules are used regardless of this setting."],
		menu = {{text=L["Strict"], value=C.RANDOM_RULES_STRICT, tooltipTitle=L["Scrict Rules"], tooltipBody=L["When a random pet is chosen, never pick pets saved in a team and never pick injured pets."]},
				{text=L["Normal"], value=C.RANDOM_RULES_NORMAL, tooltipTitle=L["Normal Rules"], tooltipBody=L["When a random pet is chosen, prefer pets not saved in a team and prefer uninjured pets."]},
				{text=L["Lenient"], value=C.RANDOM_RULES_LENIENT, tooltipTitle=L["Lenient Rules"], tooltipBody=L["When a random pet is chosen, allow pets saved in a team and prefer uninjured pets."]}}
	},
	{type="check", group=21, text=L["Pick Aggressive Counters"], var="PickAggressiveCounters", tooltip=L["When using a Load Random Pets button for random pets to counter a target, prefer pets with more Strong attacks over pets that are Tough vs opponent attacks."]},
	{type="check", group=21, text=L["Random Abilities Too"], var="RandomAbilitiesToo", tooltip=L["For random pets, choose random abilities too."] },
	{type="check", group=21, text=L["Warn For Pets Below Max Level"], var="WarnWhenRandomNot25", tooltip=L["Show a warning dialog when a random pet is chosen below level 25. (This is recommended if you're doing Family Familiar achievements with random pets.)\n\nWhen possible, random pets will be from a pool of your max-level pets. However, depending on your collected pets and the other random pet options you've chosen, the random pool may include pets not at max level."]},

    -- Team Win Record Options
    {type="header", group=13, text=L["Team Win Record Options"]},
    {type="check", group=13, text=L["Hide Win Record Text"], var="HideWinRecord", update=true, tooltip=L["Hide the win record displayed to the right of each team.\n\nYou can still manually edit a team's win record from its right-click menu and automatic tracking (if enabled) will continue if win records are hidden."]},
	{type="check", group=13, text=L["Auto Track Win Record"], var="AutoWinRecord", func="AutoWinRecord", tooltip=L["At the end of each battle, automatically record whether the loaded team won or lost.\n\nForfeits always count as a loss.\n\nYou can still manually update a team's win record at any time from its right-click menu."]},
    {type="check", group=13, text=L["For PVP Battles Only"], var="AutoWinRecordPVPOnly", dependency="AutoWinRecord", tooltip=L["Automatically track whether the loaded team won or lost only in a PVP battle and never for a PVE battle."]},
    {type="check", group=13, text=L["Display Win-Loss Instead"], var="AlternateWinRecord", func="AlternateWinRecord", tooltip=L["Instead of displaying the win percentage of a team to the right of the team list, display the total number of wins and losses in the format win-loss.\n\nTeam tabs that are sorted by win record will sort by total wins also."]},

	-- Leveling Queue Options
	{type="header", group=19, text=L["Leveling Queue Options"]},
	{type="check", group=19, text=L["Show Extra Preferences Button"], var="ShowLoadedTeamPreferences", update=true, tooltip=L["When a leveling slot is loaded, show a preferences button above the loadout panel where pets are slotted, in addition to the one always shown at the top of the queue panel."]},
	{type="check", group=19, text=L["Sort Queue By Pet Name Too"], var="QueueSortByNameToo", tooltip=L["When the queue is sorted, sort pets by name also. Otherwise, pets will try to stay in the order they were added to the queue or moved."]},
	{type="check", group=19, text=L["Hide Leveling Pet Toast"], var="HidePetToast", tooltip=L["Don't display the popup 'toast' when a new pet is automatically loaded from the leveling queue."]},
	{type="check", group=19, text=L["Add Fill Queue More Option"], var="ShowFillQueueMore", tooltip=L["In addition to a 'More' button added to the Fill Queue dialog, add a Fill Queue More option to the Queue menu."]},
	{type="check", group=19, text=L["Prefer Living Pets"], var="QueueSkipDead", func="ProcessQueue", tooltip=L["When loading pets from the queue, skip dead pets and load living ones first."]},
	{type="check", group=19, text=L["And At Full Health"], var="QueuePreferFullHP", func="ProcessQueue", dependency="QueueSkipDead", tooltip=L["Also prefer uninjured pets when loading pets from the queue."]},
	{type="check", group=19, text=L["Double Click To Send To Top"], var="QueueDoubleClick", tooltip=L["When a pet in the queue panel is double clicked, send it to the top of the queue instead of summoning it."]},
	{type="check", group=19, text=L["Add Imported Pets To Queue"], var="QueueAutoImport", tooltip=L["When importing a team, automatically add any chosen pets to the leveling queue if they're below level 25."]},
	{type="check", group=19, text=L["Automatically Level New Pets"], var="QueueAutoLearn", tooltip=L["When you capture or learn a pet that can level, automatically add it to the leveling queue."]},
	{type="check", group=19, text=L["Only Pets Without One At 25"], var="QueueAutoLearnOnly", dependency="QueueAutoLearn", tooltip=L["Only automatically add pets to the queue when you don't have a version already at 25 or in the queue."]},
	{type="check", group=19, text=L["Only Rare Pets"], var="QueueAutoLearnRare", dependency="QueueAutoLearn", tooltip=L["Only automatically add rare pets to the leveling queue."]},
	{type="check", group=19, text=L["Random Pet When Queue Empty"], var="QueueRandomWhenEmpty", tooltip=L["When the queue is empty and a team loads with leveling slots, put random pets that are not max level into the leveling slots."]},
	{type="check", group=19, text=L["Pick Random Max Level"], var="QueueRandomMaxLevel", dependency="QueueRandomWhenEmpty", tooltip=L["When the queue is empty and a team loads with leveling slots, put random max-level pets in the leveling slots."]},

	-- Confirmation Options
	{type="header", group=11, text=L["Confirmation Options"]},
	{type="check", group=11, text=L["Don't Ask When Hiding Pets"], var="DontConfirmHidePets", tooltip=L["Don't ask for confirmation when hiding a pet.\n\nYou can view hidden pets in the 'Other' pet filter."]},
	{type="check", group=11, text=L["Don't Ask When Caging Pets"], var="DontConfirmCaging", tooltip=L["If the pet doesn't belong to any teams, don't ask for confirmation when putting a pet in a cage."]},
	{type="check", group=11, text=L["Don't Ask When Deleting Teams"], var="DontConfirmDeleteTeams", tooltip=L["Don't ask for confirmation when deleting a team."]},
	{type="check", group=11, text=L["Don't Ask When Deleting Notes"], var="DontConfirmDeleteNotes", tooltip=L["Don't ask for confirmation when deleting notes from a pet or team."]},
	{type="check", group=11, text=L["Don't Ask When Filling Queue"], var="DontConfirmFillQueue", tooltip=L["Don't ask for confirmation when filling the queue from the Queue menu."]},
	{type="check", group=11, text=L["Don't Ask To Stop Active Sort"], var="DontConfirmActiveSort", tooltip=L["Don't ask to stop the Active Sort in the queue when moving a pet within the queue while it's enabled. Always turn off active sort."]},
	{type="check", group=11, text=L["Don't Ask To Remove From Queue"], var="DontConfirmRemoveQueue", tooltip=L["Don't ask for confirmation when removing a pet from the leveling queue."]},
	{type="check", group=11, text=L["Don't Warn About Missing Pets"], var="DontWarnMissing", tooltip=L["Don't display a popup when a team loads and a pet within the team can't be found."]},
	{type="check", group=11, text=L["Don't Remind About Backups"], var="NoBackupReminder", tooltip=L["Don't show a popup offering to backup teams every once in a while. Generally, the popup appears sometime after the number of teams increases by 50."]},

	-- Miscellaneous Options
	{type="header", group=6, text=L["Miscellaneous Options"]},
	{type="check", group=6, text=L["Use Default Journal"], var="UseDefaultJournal", func="UseDefaultJournal", tooltip=L["Turn off Rematch integration with the default pet journal.\n\nYou can still use Rematch in its standalone window, accessed via key binding, /rematch command or from the Minimap button if enabled in options."]},
	{type="check", group=6, text=L["Keep Companion"], var="KeepCompanion", tooltip=L["After a team is loaded, summon back the companion that was at your side before the load; or dismiss the pet if you had none summoned."]},
	{type="check", group=6, text=L["Use Minimap Button"], var="UseMinimapButton", func="UseMinimapButton", tooltip=L["Place a button on the minimap to toggle Rematch and load favorite teams."]},
	{type="check", group=6, text=L["No Summon On Double Click"], var="NoSummonOnDblClick", tooltip=L["Do nothing when pets within Rematch are double-clicked. The normal behavior of double click throughout Rematch is to summon or dismiss the pet."]},
	{type="check", group=6, text=L["Disable Sharing"], var="DisableShare", tooltip=L["Disable the Send button and also block any incoming pets sent by others. Import and Export still work."]},


    -- Enemy Ability Bar Options
    {type="header", group=24, text="Enemy Ability Bar Options"},
    {type="dropdown", group=24, text="Icon Size", var="EnemyAbilityIconSize", func="EnemyAbilityBar",
        tooltip="Size of each enemy ability icon in pixels.",
        menu={{text="30", value=30},{text="31", value=31},{text="32", value=32},{text="33", value=33},{text="34", value=34},{text="35", value=35},{text="36", value=36},{text="37", value=37},{text="38", value=38},{text="39", value=39},{text="40", value=40},{text="41", value=41},{text="42", value=42},{text="43", value=43},{text="44", value=44},{text="45", value=45},{text="46", value=46},{text="47", value=47},{text="48", value=48},{text="49", value=49},{text="50", value=50},{text="51", value=51},{text="52", value=52},{text="53", value=53},{text="54", value=54},{text="55", value=55},{text="56", value=56},{text="57", value=57},{text="58", value=58},{text="59", value=59},{text="60", value=60}}},
    {type="dropdown", group=24, text="Space Between Icons", var="EnemyAbilitySpacing", func="EnemyAbilityBar",
        tooltip="Horizontal spacing between enemy ability icons in pixels.",
        menu={{text="0", value=0},{text="1", value=1},{text="2", value=2},{text="3", value=3},{text="4", value=4},{text="5", value=5},{text="6", value=6},{text="7", value=7},{text="8", value=8},{text="9", value=9},{text="10", value=10},{text="11", value=11},{text="12", value=12},{text="13", value=13},{text="14", value=14},{text="15", value=15},{text="16", value=16}}},
    {type="dropdown", group=24, text="Cooldown Font", var="EnemyAbilityCooldownFont", func="EnemyAbilityBar",
        tooltip="Font used for the small cooldown value in the top-right corner.",
        menu={{text="Friz Quadrata", value="GameFontNormalSmall"},{text="Friz Quadrata Large", value="GameFontNormalLarge"},{text="Number Font", value="NumberFontNormal"},{text="Number Font Large", value="NumberFontNormalLarge"}}},
    {type="dropdown", group=24, text="Cooldown Font Size", var="EnemyAbilityCooldownFontSize", func="EnemyAbilityBar",
        tooltip="Size of the cooldown font.",
        menu={{text="8", value=8},{text="9", value=9},{text="10", value=10},{text="11", value=11},{text="12", value=12},{text="13", value=13},{text="14", value=14},{text="15", value=15},{text="16", value=16},{text="17", value=17},{text="18", value=18},{text="19", value=19},{text="20", value=20},{text="21", value=21},{text="22", value=22},{text="23", value=23},{text="24", value=24}}},
    {type="dropdown", group=24, text="Cooldown X Position", var="EnemyAbilityCooldownX", func="EnemyAbilityBar",
        tooltip="Horizontal offset of the cooldown number. Negative moves left; positive moves right.",
        menu={{text="-12", value=-12},{text="-11", value=-11},{text="-10", value=-10},{text="-9", value=-9},{text="-8", value=-8},{text="-7", value=-7},{text="-6", value=-6},{text="-5", value=-5},{text="-4", value=-4},{text="-3", value=-3},{text="-2", value=-2},{text="-1", value=-1},{text="0", value=0},{text="1", value=1},{text="2", value=2},{text="3", value=3},{text="4", value=4},{text="5", value=5},{text="6", value=6},{text="7", value=7},{text="8", value=8},{text="9", value=9},{text="10", value=10},{text="11", value=11},{text="12", value=12}}},
    {type="dropdown", group=24, text="Cooldown Y Position", var="EnemyAbilityCooldownY", func="EnemyAbilityBar",
        tooltip="Vertical offset of the cooldown number. Negative moves down; positive moves up.",
        menu={{text="-12", value=-12},{text="-11", value=-11},{text="-10", value=-10},{text="-9", value=-9},{text="-8", value=-8},{text="-7", value=-7},{text="-6", value=-6},{text="-5", value=-5},{text="-4", value=-4},{text="-3", value=-3},{text="-2", value=-2},{text="-1", value=-1},{text="0", value=0},{text="1", value=1},{text="2", value=2},{text="3", value=3},{text="4", value=4},{text="5", value=5},{text="6", value=6},{text="7", value=7},{text="8", value=8},{text="9", value=9},{text="10", value=10},{text="11", value=11},{text="12", value=12}}},
    {type="dropdown", group=24, text="Remaining Cooldown Font Size", var="EnemyAbilityRemainingFontSize", func="EnemyAbilityBar",
        tooltip="Size of the large remaining-rounds number shown over an ability while it is on cooldown.",
        menu={{text="10", value=10},{text="11", value=11},{text="12", value=12},{text="13", value=13},{text="14", value=14},{text="15", value=15},{text="16", value=16},{text="17", value=17},{text="18", value=18},{text="19", value=19},{text="20", value=20},{text="21", value=21},{text="22", value=22},{text="23", value=23},{text="24", value=24},{text="25", value=25},{text="26", value=26},{text="27", value=27},{text="28", value=28}}},

	-- Help Options
	{type="header", group=15, text=L["Help Options"]},
	{type="check", group=15, text=L["Hide Extra Help"], var="HideMenuHelp", func="UpdatePetCard", tooltip=L["Hide the informational \"Help\" items found in menus, pet cards, dialogs and elsewhere."]},
	{type="check", group=15, text=L["Hide Descriptive Tooltips"], var="HideTooltips", tooltip=L["Hide tooltips that describe what a button does."]},
	{type="check", group=15, text=L["Hide Toolbar Tooltips"], var="HideToolbarTooltips", tooltip=L["Hide tooltips for the toolbar buttons."]},
	{type="check", group=15, text=L["Hide Option Tooltips"], var="HideOptionTooltips", tooltip=L["Hide tooltips for options like the one you're reading now."]},
	{type="check", group=15, text=L["Hide Truncated Tooltips"], var="HideTruncatedTooltips", tooltip=L["Hide tooltips for team or target names when they're truncated (such as Sully \"The Pickle\" McL... instead of Sully \"The Pickle\" McLeary)."]},

	-- About Rematch
	{type="header", group=20, text=L["About Rematch"]},
	{type="widget", group=20, text=L["All Options Troubleshoot Export Reset"], parentKey="OptionsManagementWidget"},
	{type="text", group=20, text=L["Version "]..(C_AddOns.GetAddOnMetadata("Rematch","Version") or "")},
	{type="text", group=20, isHelp=true, text=rematch.utils:GetBadgeAsText(12,16,true).."\124cffb0b0b0 "..L["Target or pet is in a team"]},
	{type="text", group=20, isHelp=true, text=rematch.utils:GetBadgeAsText(11,16,true).."\124cffb0b0b0 "..L["Pet is in the leveling queue"]},
	{type="text", group=20, isHelp=true, text=rematch.utils:GetBadgeAsText(27,16,true).."\124cffb0b0b0 "..L["Team has at least one target"]},
	{type="text", group=20, isHelp=true, text=rematch.utils:GetBadgeAsText(14,16,true).."\124cffb0b0b0 "..L["Team or group has preferences"]},
	{type="text", group=20, isHelp=true, text=rematch.utils:GetBadgeAsText(13,16,true).."\124cffb0b0b0 "..L["Team or pet has notes"]},

}

