local _,rematch = ...
local L = rematch.localization

Rematch = rematch -- global variable for outside/xml access

-- key bindings
BINDING_HEADER_REMATCH = L["Rematch"]
BINDING_NAME_REMATCH_WINDOW = L["Toggle Rematch"]
BINDING_NAME_REMATCH_NOTES = L["Rematch Team Notes"]

-- backdrop color/style
REMATCH_BORDER_BACKGROUND_COLOR = CreateColor(0.5,0.5,0.5)
REMATCH_BORDER_RED_COLOR = CreateColor(1.0,0,0)
REMATCH_SOLID_DARK_BACKDROP_COLOR = CreateColor(0.05,0.05,0.05)
REMATCH_SOLID_LIGHT_BACKDROP_COLOR = CreateColor(0.2,0.2,0.2)
REMATCH_SOLID_BACKDROP_STYLE = {
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileEdge = true,
	tileSize = 16,
	edgeSize = 16,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

rematch.constants = {
    -- color codes for text
    HEX_WHITE = "\124cffffffff",
    HEX_GOLD = "\124cffffd200",
    HEX_GREY = "\124cffc0c0c0",
    HEX_RED = "\124cffff4848",
    HEX_GREEN = "\124cff20ff20",
    HEX_BLUE = "\124cff88bbff",
    -- text icons for inline textures
    LMB_TEXT_ICON = "\124TInterface\\TutorialFrame\\UI-Tutorial-Frame:12:12:0:0:512:512:10:65:228:283\124t", -- left mouse button
    RMB_TEXT_ICON = "\124TInterface\\TutorialFrame\\UI-Tutorial-Frame:12:12:0:0:512:512:10:65:330:385\124t", -- right mouse button
    NMB_TEXT_ICON = "\124TInterface\\TutorialFrame\\UI-Tutorial-Frame:12:12:0:0:512:512:89:144:228:283\124t", -- no mouse button
    WARN_TEXT_ICON = "\124TInterface\\DialogFrame\\UI-Dialog-Icon-AlertNew:0\124t",
    ADD_TEXT_ICON = "\124TInterface\\AddOns\\Rematch\\textures\\texticons:16:16:0:0:256:256:0:32:0:32\124t",
    DELETE_TEXT_ICON = "\124TInterface\\AddOns\\Rematch\\textures\\texticons:16:16:0:0:256:256:32:64:0:32\124t",
    DELETE_DISABLED_TEXT_ICON = "\124TInterface\\AddOns\\Rematch\\textures\\texticons:16:16:0:0:256:256:192:224:0:32\124t",
    UP_TEXT_ICON = "\124TInterface\\AddOns\\Rematch\\textures\\texticons:16:16:0:0:256:256:64:96:0:32\124t",
    UP_DISABLED_TEXT_ICON = "\124TInterface\\AddOns\\Rematch\\textures\\texticons:16:16:0:0:256:256:128:160:0:32\124t",
    DOWN_TEXT_ICON = "\124TInterface\\AddOns\\Rematch\\textures\\texticons:16:16:0:0:256:256:96:128:0:32\124t",
    DOWN_DISABLED_TEXT_ICON = "\124TInterface\\AddOns\\Rematch\\textures\\texticons:16:16:0:0:256:256:160:192:0:32\124t",
    LEFT_TEXT_ICON = "\124TInterface\\AddOns\\Rematch\\textures\\texticons:16:16:0:0:256:256:0:32:32:64\124t",
    --BLANK_TEXT_ICON = "\124TInterface\\AddOns\\Rematch\\textures\\texticons:16:16:0:0:256:256:224:256:0:32\124t",
    EMPTY_TEXT_ICON = "\124TInterface\\PaperDoll\\UI-Backpack-EmptySlot:16:16:0:0:64:64:5:59:5:59\124t",
    MAGIC_TEXT_ICON = "\124TInterface\\AddOns\\Rematch\\textures\\texticons:18:18:0:0:256:256:32:64:32:64\124t",
    MAGIC_DISABLED_TEXT_ICON = "\124TInterface\\AddOns\\Rematch\\textures\\texticons:18:18:0:0:256:256:64:96:32:64\124t",
    MECHANICAL_TEXT_ICON = "\124TInterface\\AddOns\\Rematch\\textures\\texticons:18:18:0:0:256:256:96:128:32:64\124t",
    MECHANICAL_DISABLED_TEXT_ICON = "\124TInterface\\AddOns\\Rematch\\textures\\texticons:18:18:0:0:256:256:128:160:32:64\124t",
    LOAD_TEXT_ICON = "\124TInterface\\AddOns\\Rematch\\textures\\texticons:14:14:0:0:256:256:0:32:64:96\124t",
    LOAD_DISABLED_TEXT_ICON = "\124TInterface\\AddOns\\Rematch\\textures\\texticons:14:14:0:0:256:256:32:64:64:96\124t",
    SAVE_TEXT_ICON = "\124TInterface\\AddOns\\Rematch\\textures\\texticons:14:14:0:0:256:256:224:256:0:32\124t",
    EDIT_TEXT_ICON = "\124TInterface\\AddOns\\Rematch\\textures\\texticons:14:14:0:0:256:256:160:192:32:64\124t",
    -- icons
    LEVELING_ICON = "Interface\\AddOns\\Rematch\\Textures\\levelingicon",
    IGNORED_ICON = "Interface\\AddOns\\Rematch\\Textures\\ignoredicon",
    REMATCH_ICON = "Interface\\Icons\\INV_Pet_BattlePetTraining",
    UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark",
    EMPTY_ICON = "Interface\\AddOns\\Rematch\\Textures\\blank", -- "Interface\\PaperDoll\\UI-Backpack-EmptySlot",
    FANFARE_ICON = "Interface\\Icons\\Item_Shop_GiftBox01",
    UNNOTABLE_ICON = "Interface\\AddOns\\Rematch\\Textures\\unnotable",
    NEW_TAB_ICON = "Interface\\GuildBankFrame\\UI-GuildBankFrame-NewTab",
    SUMMON_RANDOM_ICON = 652131,
    -- colors
    HP_BAR_COLOR = {r=0.1, g=0.9, b=0.1},
    XP_BAR_COLOR = {r=0.18, g=0.54, b=0.9},
    -- texCoords into Interface\GLUES\AccountUpgrade\AccountUpgradeBanners for each expansionID
    EXPANSION_BG_TEXCOORDS = {
        [0]={0.198242, 0.393555, 0.798828, 0.994141}, -- classic
        [1]={0.395508, 0.588867, 0.234375, 0.427734}, -- burning crusade
        [2]={0.000976562, 0.196289, 0.279297, 0.552734}, -- wrath of the lich king
        [3]={0.000976562, 0.196289, 0.00195312, 0.275391}, -- catclysm
        [4]={0.592773, 0.788086, 0.00195312, 0.230469}, -- mists of pandaria
        [5]={0.790039, 0.985352, 0.00195312, 0.230469}, -- warlords of draenor
        [6]={0.395508, 0.59082, 0.00195312, 0.230469}, -- legion
        [7]={0.000976562, 0.196289, 0.556641, 0.818359}, -- battle for azeroth
        [8]={0.198242, 0.393555, 0.267578, 0.529297}, -- shadowlands
        [9]={0.198242, 0.393555, 0.00195312, 0.263672}, -- dragonflight
        [10]={0.198242, 0.393555, 0.533203, 0.794922}, -- the war within
    },
    EXPANSION_COLORS = {
        [0] = "D6AB7D", -- classic
        [1] = "E43E5A", -- burning crusade
        [2] = "3FC7EB", -- wrath of the lich king
        [3] = "FF7C0A", -- cataclysm
        [4] = "00EF88", -- mists of pandaria
        [5] = "F48CBA", -- warlords of draenor
        [6] = "AAD372", -- legion
        [7] = "FFF468", -- battle for azeroth
        [8] = "9798FE", -- shadowlands
        [9] = "53B39F", -- dragonflight
        [10] = "90CCDD", -- the war within (was 309BD6)
    },
    -- color picker adds these to EXPANSION_COLORS to build color swatches
    COLOR_PICKER_COLORS = {
        "E6E6E6", -- white
        "AAAAAA", -- grey
        "FFD200", -- gold
        "80BFFF", -- blue
        "BF80FF", -- purple
    },
    -- in a BasicFrameTemplate, offsets for content to start
    FRAME_LEFT_MARGIN = 5,
    FRAME_RIGHT_MARGIN = 5,
    FRAME_TOP_MARGIN = 24,
    FRAME_BOTTOM_MARGIN = 4,
    -- sizes for panel layouts
    PANEL_MINIMIZED_WIDTH = 260,
    PANEL_MINIMIZED_HEIGHT = 120,
    PANEL_SINGLE_WIDTH = 340,
    PANEL_WIDTH = 280,
    PANEL_HEIGHT = 520,
    -- specific panel heights
    PANEL_LOADEDTEAM_HEIGHT = 26,
    PANEL_MINILOADOUT_HEIGHT = 92,
    PANEL_TARGET_HEIGHT = 75, --87,
    PANEL_SHORT_TARGET_HEIGHT = 51, --60,
    -- list button widths
    LIST_BUTTON_NORMAL_WIDTH = 246,
    LIST_BUTTON_WIDE_WIDTH = 306,
    LIST_BUTTON_NORMAL_HEIGHT = 44,
    LIST_BUTTON_COMPACT_HEIGHT = 26,
    -- chrome dimensions
    TOOLBAR_HEIGHT = 32,
    TOOLBAR_BUTTON_SIZE = 32,
    BOTTOMBAR_HEIGHT = 22,
    -- constants for dealing with layouts
    CURRENT = 1,
    STANDALONE = 2,
    JOURNAL = 3,
    MAXIMIZED = 4,
    -- panel tabs
    PANEL_TAB_SPACING = 64,
    -- default layouts
    DEFAULT_STANDALONE_LAYOUT = "3-teams",
    DEFAULT_JOURNAL_LAYOUT = "3-teams",
    -- for textureHighlight (used by composite and thin buttons)
    HIGHLIGHT_VERTEX = 0.65,
    HIGHLIGHT_ALPHA = 0.85,
    HIGHLIGHT_DESATURATE = true, -- I can't decide whether to desaturate highlight or not; so making it a constant
    -- tooltip constants
    TOOLTIP_MAX_WIDTH = 220,
    TOOLTIP_PADDING = 10,
    TOOLTIP_LINE_SPACING = 3,
    TOOLTIP_FADE_WAIT = 3, -- seconds before cursor tooltip starts to fade
    TOOLTIP_FADE_ALPHA = 1, -- time for tooltip to fade after its wait is done
    -- delay for cards to show in Normal and Slow mode
    CARD_MANAGER_DELAY_NORMAL = 0.25,
    CARD_MANAGER_DELAY_SLOW = 0.75,
    -- menu variables
    MENU_OPEN_TIMER = 1.5,
    MENU_TITLE_HEIGHT = 20,
    MENU_BUTTON_HEIGHT = 20,
    MENU_SPACER_HEIGHT = 8,
    MENU_FRAME_PADDING = 8,
    MENU_INDENT_SIZE = 8,
    -- colors used for pet marker text
    MARKER_COLORS = {"FFEB00","FA9100","D438E6","0AF200","B3D1DF","00B5FF","FF3D2B","FAFAFA"},
    -- texcoords into a square texture that's divided into a 4x4 grid, with the topleft being index 1, topright being index 4, etc.
    COORDS_4X4 = {
    	{0,0.25,0,0.25},{0.25,0.5,0,0.25},{0.5,0.75,0,0.25},{0.75,1.0,0,0.25},
    	{0,0.25,0.25,0.5},{0.25,0.5,0.25,0.5},{0.5,0.75,0.25,0.5},{0.75,1.0,0.25,0.5},
    	{0,0.25,0.5,0.75},{0.25,0.5,0.5,0.75},{0.5,0.75,0.5,0.75},{0.75,1.0,0.5,0.75},
        {0,0.25,0.75,1.0},{0.25,0.5,0.75,1.0},{0.5,0.75,0.75,1.0},{0.75,1.0,0.75,1.0}
    },
    -- texcoords into greybuttons for various sized buttons
    GREY_BUTTON_COORDS = {
            ["200x24"] = {Up={0,0.78125,0.46875,0.5625}, Down={0,0.78125,0.578125,0.671875}},
            ["68x24"] = {Up={0,0.265625,0.6875,0.78125}, Down={0,0.265625,0.796875,0.890625}},
            ["80x24"] = {Up={0,0.3125,0.25,0.34375}, Down={0,0.3125,0.359375,0.453125}},
            ["108x28"] = {Up={0,0.421875,0,0.109375}, Down={0,0.421875,0.125,0.234375}},
            ["68x34"] = {Up={0.5,0.765625,0,0.1328125}, Down={0.5,0.765625,0.15625,0.2890625}},
            ["76x24"] = {Up={0.3125,0.609375,0.6875,0.78125}, Down={0.3125,0.609375,0.796875,0.890625}},
            ["24x24"] = {Up={0.375,0.46875,0.25,0.34375}, Down={0.375,0.46875,0.359375,0.453125}},
    },
    -- time before an On-Demand table expires
    ODTABLE_EXPIRE_TIME = 0.25,
    -- spellIDs and itemIDs
    GCD_SPELL_ID = 61304, -- "Global Cooldown", a spell specifically for monitoring GCD
    SUMMON_RANDOM_SPELL_ID = 243819,
    PET_ACHIEVEMENT_CATEGORY = 15117,
    REVIVE_SPELL_ID = 125439,
    SAFARI_HAT_ITEM_ID = 92738,
    BANDAGE_ITEM_ID = 86143,
    BANDAGE_SPELL_ID = 133994, -- this is the spellID case when bandages used
    PET_TREAT_ITEM_ID = 98114,
    LESSER_PET_TREAT_ITEM_ID = 98112,
    DEFAULT_LEVELING_STONE_ITEM_ID = 116429,
    DEFAULT_RARITY_STONE_ITEM_ID = 98715,
    -- the leveling and rarity stones prioritize petType-specific stones first (the first ten in list) and then
    -- general next, and hard-to-get ones last. (92741 is a tradable rarity stone; may drop so user doesn't accidentally use)
    RARITY_STONES = {92682, 92683, 92677, 92681, 92676, 92678, 92665, 92675, 92679, 92680, 98715, 92741},
    LEVELING_STONES = {116416, 116419, 116421, 116423, 116418, 116422, 116420, 116374, 116424, 116417, 116429, 127755, 122457},
    -- reasons why a pet can't be summoned
    SUMMON_SHORT_ERRORS = {
        [Enum.PetJournalError.JournalIsLocked] = L["Journal Is Locked"],
        [Enum.PetJournalError.InvalidFaction] = L["Wrong Faction"],
        [Enum.PetJournalError.PetIsDead] = L["Pet Is Dead"]
    },
    -- enum for colors to tints for rematch.utils:TintTexture()
    TINT_NONE = 1,
    TINT_RED = 2,
    TINT_GREY = 3,
    -- badge constants
    BADGE_SIZE = 14,
    -- this table describes how an attack will be received by the indexed pet type (incoming modifier)
    -- {[petType]={increasedVs,decreasedVs},[petType]={increasedVs,decreasedVs},etc}
    -- ie dragonkin pets {1,3} take increased damage from humanoid attacks (1) and less damage from flying attacks (3)
    HINTS_DEFENSE = {{4,5},{1,3},{6,8},{5,2},{8,7},{2,9},{9,10},{10,1},{3,4},{7,6}},
    -- this table describes how an attack of the indexed pet type will be applied (outgoing modifier)
    -- {[attackType]={increasedVs,decreasedVs},[attackType]={increasedVs,decreasedVs},etc}
    -- ie dragonkin attacks {6,4) deal increased damage to magic pets (6) and less damage to undead pets (4)
    HINTS_OFFENSE = {{2,8},{6,4},{9,2},{1,9},{4,1},{3,10},{10,5},{5,3},{7,6},{8,7}},
    -- filter constants
    SIMILIAR_FILTER_THRESHHOLD = 3, -- number of shared abilities to count as a similar pet
    -- sort categories
    SORT_NAME = 1,
    SORT_LEVEL = 2,
    SORT_RARITY = 3,
    SORT_TYPE = 4,
    SORT_HEALTH = 5,
    SORT_POWER = 6,
    SORT_SPEED = 7,
    SORT_TEAMS = 8,
    -- default sorts for the 3 sortLevels
    SORT_DEFAULT_LEVEL_1 = 1, -- SORT_NAME
    SORT_DEFAULT_LEVEL_2 = 2, -- SORT_LEVEL
    SORT_DEFAULT_LEVEL_3 = 3, -- SORT_RARITY
    -- toggleable top of petpanel heights
    PETPANEL_TOP_COLLAPSED_HEIGHT = 29,
    PETPANEL_TOP_EXPANDED_HEIGHT = 88,
    -- toggleable top of petpanel heights
    PETPANEL_TOP_COLLAPSED_HEIGHT = 29,
    PETPANEL_TOP_EXPANDED_HEIGHT = 88,
    -- typebar constants
    TYPEBAR_TAB_TYPE = 1,
    TYPEBAR_TAB_STRONG_VS = 2,
    TYPEBAR_TAB_TOUGH_VS = 3,
    -- dialog constants
    DIALOG_LEFT_MARGIN = 9,
    DIALOG_RIGHT_MARGIN = 11,
    DIALOG_TOP_MARGIN = 30,
    DIALOG_BOTTOM_MARGIN = 32,
    DIALOG_PROMPT_HEIGHT = 29,
    DIALOG_OUTER_PADDING = 6, -- left,right,top,bottom space before edge of canvas
    DIALOG_INNER_PADDING = 6, -- space between controls
    DIALOG_DEFAULT_WIDTH = 280, -- these are canvas width/height
    DIALOG_DEFAULT_HEIGHT = 100,
    DIALOG_MIN_WIDTH = 120, -- still canvas width/height
    DIALOG_MIN_HEIGHT = 16,
    DIALOG_MULTILINE_EDITBOX_HEIGHT = 166, -- default height of multiline editbox
    EXPORT_CHUNK_FAST = 20,
    EXPORT_CHUNK_MEDIUM = 10,
    EXPORT_CHUNK_SLOW = 5,
    -- pet card constants
    PET_CARD_TOP_NORMAL_HEIGHT = 47,
    PET_CARD_TOP_MINIMIZED_HEIGHT = 38,
    PET_CARD_ABILITIES_NORMAL_HEIGHT = 111,
    PET_CARD_ABILITIES_MINIMIZED_HEIGHT = 99,
    PET_CARD_TOP_ICON_NORMAL_SIZE = 40,
    PET_CARD_TOP_ICON_MINIMIZED_SIZE = 32,
    PET_CARD_STAT_LEFT_MARGIN = 6,
    PET_CARD_STAT_TOP_MARGIN = 6,
    PET_CARD_STAT_BOTTOM_MARGIN = 4,
    PET_CARD_STAT_HEIGHT = 16,
    PET_CARD_STAT_PADDING = 1,
    PET_CARD_STAT_WIDTH_SMALL = 56,
    PET_CARD_STAT_WIDTH_MEDIUM = 90, -- 76,
    PET_CARD_STAT_WIDTH_WIDE = 120,
    PET_CARD_STAT_WIDTH_FULL = 232,
    PET_CARD_STATUS_BAR_WIDTH = 226,
    PET_CARD_MIN_MODEL_HEIGHT = 150,
    PET_CARD_MIN_MODEL_WIDTH = 172,
    PET_CARD_RACIAL_MINIMIZED_HEIGHT = 67,
    PET_CARD_RACIAL_NORMAL_HEIGHT = 105, -- height of racial ability added to this
    PET_CARD_CHROME_HEIGHT = 33, -- height of the extra frame matter outside content on a pet card
    -- ability tooltip constants
    ABILITY_TOOLTIP_OUTER_PADDING = 8,
    ABILITY_TOOLTIP_INNER_PADDING = 6,
    -- time for flyouts to remain open before closing
    FLYOUT_OPEN_TIMER = 1.5,
    -- loadout panels
    MINILOADOUT_STATUSBAR_WIDTH = 38,
    LOADOUT_XPBAR_WIDTH = 250, -- for main loadout
    LOADOUT_HPBAR_WIDTH = 58,
    LOADOUT_COLOR_LEVELING = {0.5,0.75,1},
    LOADOUT_COLOR_RANDOM = {0.5,1,0.5},
    LOADOUT_COLOR_IGNORED = {1,0.5,0.5},
    LOADOUT_COLOR_NORMAL = {1,1,1},
    -- team group/tabs
    GROUP_SORT_ALPHA = 1,
    GROUP_SORT_WINS = 2,
    GROUP_SORT_CUSTOM = 3,
    MAX_TEAM_TABS = 16, -- maximum number of team tabs allowed at a time
    -- targeting
    TARGET_HISTORY_SIZE = 3, -- going back to 3 targets for recent targets
    ALLY_TEAM = 1,
    ENEMY_TEAM = 2,
    CACHE_RETRIEVING = L["\124cffff2020Retrieving data..."], -- name for an npc/other data that hasn't cached yet
    CACHE_ATTEMPTS = 10, -- number of times to attempt to cache an npc name
    CACHE_TIMEOUT = 3, -- time to wait (in seconds) before giving up caching npc name
    CACHE_WAIT = 0.333, -- time between cache attempts
    -- dragging
    CURSOR_TYPE_GROUP = 1,
    CURSOR_TYPE_TEAM = 2,
    CURSOR_TYPE_TARGET = 3,
    CURSOR_TYPE_PET = 4,
    DRAG_DIRECTION_PREV = -1,
    DRAG_DIRECTION_NEXT = 1,
    DRAG_DIRECTION_END = 0,
    -- the texcoords for the border around pets in the team and target lists
    TEAM_SIZE_NORMAL = 1,
    TEAM_SIZE_COMPACT = 2,
    TEAM_SIZE_WIDE = 3,
    PET_BORDER_TEXCOORDS = {
        { -- Normal (C.TEAM_SIZE_NORMAL) left,right,top,bottom,width,height
            {0.6328125,0.7578125,0,0.171875,32,44}, -- 1 pet (32x44)
            {0.375,0.61328125,0,0.171875,61,44}, -- 2 pets (61x44)
            {0,0.3515625,0,0.171875,90,44}  -- 3 pets (90x44)
        },
        { -- Compact (C.TEAM_SIZE_COMPACT)
            {0.53125,0.6328125,0.1875,0.2890625,26,26}, -- 1 pet (26x26)
            {0.3125,0.50390625,0.1875,0.2890625,49,26}, -- 2 pets (49x26)
            {0,0.28125,0.1875,0.2890625,72,26}  -- 3 pets (72x26)
        },
        { -- Wide (C.TEAM_SIZE_WIDE)
            {0.25,0.421875,0.3125,0.484375,44,44}, -- 1 pet (44x44)
            {0.46875,0.80078125,0.3125,0.484375,85,44}, -- 2 pets (85x44)
            {0.25,0.7421875,0.5,0.671875,125,44}, -- 3 pets (126x44)
        }
    },
    TEAM_LIST_LEFT_PADDING = 4, -- px from left of teamlistbuttons where content begins
    TEAM_LIST_RIGHT_PADDING = 4, -- px from right of teamlist buttons where content ends
    -- team loading constants
    TEAM_LOAD_TIMEOUT = 5, -- times before giving up trying to load a team
    TEAM_LOAD_WAIT = 0.25, -- wait before next run of loading team
    -- target panel constants
    BUTTON_MODE_LOAD = 1,
    BUTTON_MODE_SAVE = 2,
    -- random pet rules
    RANDOM_RULES_STRICT = 1,
    RANDOM_RULES_NORMAL = 2,
    RANDOM_RULES_LENIENT = 3,
    COUNTER_TEAM_NAME = L["Random Team"], -- default name for a random team
    -- notes constants
    NOTES_CONTROLS_HEIGHT = 26,
    -- save dialog constants
    LIST_TYPE_GROUP = 1,
    LIST_TYPE_TEAM = 2,
    LIST_TYPE_TARGET = 3,
    SAVE_MODE_EDIT = 1,
    SAVE_MODE_SAVEAS = 2,
    SAVE_MODE_RECEIVE = 3,
    -- breed constants
    BREED_FORMAT_LETTERS = 1,
    BREED_FORMAT_NUMBERS = 2,
    BREED_FORMAT_ICONS = 3,
    -- leveling queue constants
    QUEUE_SORT_ALL = 0,
    QUEUE_SORT_ASC = 1,
    QUEUE_SORT_DESC = 2,
    QUEUE_SORT_MID = 3,
    QUEUE_SORT_TEAMS = 4,
    QUEUE_SORT_FAVORITES = 5,
    QUEUE_SORT_RARITY = 6,
    QUEUE_PROCESS_WAIT = 1.25,
    QUEUE_PROCESS_TIMEOUT = 10,
    -- interaction constants
    INTERACT_NONE = 0,
    INTERACT_PROMPT = 1,
    INTERACT_WINDOW = 2,
    INTERACT_AUTOLOAD = 3,
    -- pattern for petIDs (for string.match to confirm it's an owned battle pet)
    PET_ID_PATTERN = "^BattlePet%-%x%-%x%x%x%x%x%x%x%x%x%x%x%x$",
    -- unplanned categories for problems loading a team
    UNPLANNED_PET_MISSING = 1,
    UNPLANNED_LOW_LEVEL = 2,
    -- collection summary/statistics constants
    BARCHART_TYPES = 1, -- index into collectionInfo:GetSpeciesStats() species info for pet types
    BARCHART_SOURCES = 2, -- index into collectionInfo:GetSpeciesStats() species info for pet sources
    BARCHART_IN_JOURNAL = 1, -- Unique Pets In the Journal barchart category
    BARCHART_TOTAL_COLLECTED = 2, -- Total Collected Pets barchart category
    BARCHART_UNIQUE_COLLECTED = 3, -- Unique Collected Pets barchart category
    BARCHART_NOT_COLLECTED = 4, -- Pets Not Collected barchart category
    BARCHART_PERCENT_COLLECTED = 5, -- Percent Collected barchart category
    BARCHART_MAX_LEVEL = 6, -- Max Level Pets barchart category
    BARCHART_AVG_LEVEL = 7, -- Average Pet Level barchart category
    BARCHART_RARE_QUALITY = 8, -- Rare Quality Pets barchart category
    BARCHART_IN_TEAMS = 9, -- Pets In Teams barchart category
    -- this needs to be sufficiently long for journal to update after battle closes
    POST_BATTLE_TIMER = 3, -- number of seconds after battle to watch for pet health changing
    -- send constants
    SEND_TIMEOUT = 5, -- number of seconds to wait for a response from a team being sent
    BACKUP_INTERVAL = 50, -- number of teams before asking if user wants to backup their teams
    -- sounds
    SOUND_DRAG_START = 688,
    SOUND_DRAG_STOP = 689,
    SOUND_REMATCH_OPEN = SOUNDKIT.IG_CHARACTER_INFO_OPEN,
    SOUND_REMATCH_CLOSE = SOUNDKIT.IG_CHARACTER_INFO_CLOSE,
    SOUND_PET_CARD = SOUNDKIT.IG_QUEST_LIST_SELECT,
    SOUND_CHECKBUTTON = SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF,
    SOUND_FLYOUT_OPEN = SOUNDKIT.UI_JOURNEYS_OPEN_LORE_BOOK,
    SOUND_FLYOUT_CLOSE = SOUNDKIT.UI_JOURNEYS_CLOSE_LORE_BOOK,
    SOUND_HEADER_CLICK = SOUNDKIT.UI_PROFESSION_SPEC_PATH_SELECT,
    SOUND_DIALOG_OPEN = SOUNDKIT.UI_CLASS_TALENT_OPEN_WINDOW,
    SOUND_DIALOG_CLOSE = SOUNDKIT.UI_CLASS_TALENT_CLOSE_WINDOW,
    SOUND_PANEL_TAB = SOUNDKIT.UI_TOYBOX_TABS,
    SOUND_TEAM_LOAD = SOUNDKIT.IG_QUEST_LIST_SELECT,
    SOUND_SATCHEL = SOUNDKIT.IG_BACKPACK_OPEN,
    SOUND_GENERIC_OPEN = SOUNDKIT.UI_JOURNEYS_OPEN_LORE_BOOK,
    SOUND_GENERIC_CLOSE = SOUNDKIT.UI_JOURNEYS_CLOSE_LORE_BOOK,
    -- help text
    HELP_TEXT_PET_FILTER = L["In addition to the filters in this menu, you can further refine the pet list with the search box. Some search examples:\n\nPets: %sBlack Tabby\124r\nZones: %sSilithus\124r\nAbilities: %sSandstorm\124r\nText in abilities: %sBleed\124r\nLevels: %slevel=21-23\124r\nStats: %sspeed>300\124r\n\nSearches in \"quotes\" will limit results to only complete matches.\n\nSearch results will be sorted by relevance unless the option %sDon't Sort By Relevance\124r is checked in the Options tab."],
    HELP_TEXT_MULTI_CHECK = L["In filter menus, checkbox groups assume if nothing is checked you want to view all choices.\n\nYou can also:\n\n%s[Shift]+Click\124r to check all except the box clicked.\n\n%s[Alt]+Click\124r to uncheck all except the box clicked."],
    HELP_TEXT_PET_TAGS = L["Pet Tags are a way to categorize pets for any meaning you choose. You can then filter by specific tags.\n\nTo tag a pet, right-click a pet in the pet list and choose a tag from the Pet Tags menu.\n\nTo easily tag multiple pets, choose the %sPet Herder\124r option in the main Filters menu.\n\nYou can rename a tag by moving the mouse over a tag in a Pet Tags menu and clicking the %s that appears to the right of the tag's name.\n\nFor instance you can rename %s to Wild Pets To Get, tag pets you'd like to capture with a %s, and the pet card and other places will use the new name for the tag."],
    -- for mouse behavior speed (mouseover/mousewheel)
    MOUSE_SPEED_SLOW = "Slow",
    MOUSE_SPEED_NORMAL = "Normal",
    MOUSE_SPEED_MEDIUM = "Medium",
    MOUSE_SPEED_FAST = "Fast",
    MOUSE_SPEED_CLICK = "Click",
}
