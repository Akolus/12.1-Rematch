local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.layout = {}

local allLayouts = {} -- contains all registered layouts, indexed by their layoutName ("1-pets", "2-teams-target", etc.)
local knownPanels = {} -- lookup table of all encountered panels; keyed by panel's frame reference
local defaultLayouts = {} -- indexed by mode, the first layout registered is the default layout for the mode

--[[
    definitions.lua has more information on layout definitions

    For referencing a layout, there's four constants that should always be used as a reference:

        C.CURRENT    -- the current layout regardless of standalone vs journal or minimized state
        C.STANDALONE -- the last standalone layout used (can be minimized or maximized)
        C.MAXIMIZED  -- the last maximized standalone layout used (never minimized)
        C.JOURNAL    -- the last journal layout used (never minimized)

    The following return information about one of the four layouts above:

        rematch.layout:GetLayout(C.CURRENT) -- returns the name of the layout used for one of the four layouts above (*)
        rematch.layout:GetLayout(layoutName) -- returns the layoutName if valid and adjusts it to suit the current mode if not
        rematch.layout:GetDefinition(C.CURRENT) -- returns the full layout definition in table form
        rematch.layout:GetMode(C.CURRENT) -- returns the mode (0=minimized, 1=single panel, 2=dual panel, 3=triple panel)
        rematch.layout:GetView(C.CURRENT) -- returns the view ("pets", "teams", "queue", "options")

        (*) GetLayout(layoutName) can also be used to validate the layoutName and return an adjusted name if it's not valid

    The following can be used to alter the layout:

        rematch.layout:ChangeMode(mode) -- changes the mode of the current layout to the given mode and calls a Configure
        rematch.layout:ChangeView(view) -- changes the view of the current layout to the given view and calls a Configure
]]

-- on login, set up layout definitions
rematch.events:Register(rematch.layout,"PLAYER_LOGIN",function(self)
    -- register the layouts defined in definitions.lua
    for _,layout in ipairs(rematch.layout.definitions) do
        rematch.layout:Register(layout)
    end
    -- done with definitions, safe to delete
    rematch.layout.definitions = nil
end)

-- registers a layout in allLayouts and returns the layout's name
function rematch.layout:Register(layout)
    -- asserting the layout is defined properly
    assert(type(layout)=="table","Layout format: {mode=[number], view=[string], panels=[table]}")
    assert(layout.mode and layout.mode>=0 and layout.mode<=3,"A layout mode must be 0-3.")
    assert(type(layout.view)=="string","A layout must have a named view, like 'pets'.")
    assert(type(layout.width)=="number" and type(layout.height)=="number","A layout must have a width and height.")
    assert(type(layout.panels)=="table" and #layout.panels>0,"A layout must have at least one panel defined.")

    -- build a name for the layout, this will be used as a reference for this layout
    local layoutName = layout.mode.."-"..layout.view..(layout.subview and "-"..layout.subview or "")

    -- some more assertions that panels are defined properly
    for _,info in ipairs(layout.panels) do
        for i=1,11 do
            assert(info[i] and true,"Layout panel format: {parentKey, anchorPoint1, relativeTo1, relativePoint1, xoff1, yoff1, anchorPoint2, relativeTo2, relativePoint2, xoff2, yoff2}")
        end
        assert(info[1] and rematch.frame[info[1]],"Layout panel nil parentKey in "..layoutName)
        assert(info[3] and rematch.frame[info[3]],"Layout panel nil relativeTo1 in "..layoutName)
        assert(info[8] and rematch.frame[info[8]],"Layout panel nil relativeTo2 in "..layoutName)
    end

    -- add the layout to allLayouts (making a copy instead of referencing original)
    allLayouts[layoutName] = CopyTable(layout)
    allLayouts[layoutName].layoutName = layoutName
    -- create a lookup table for panels used in this layout
    allLayouts[layoutName].panelsUsed = {}

    -- add its panels to knownPanels
    for _,info in ipairs(layout.panels) do
        knownPanels[rematch.frame[info[1]]] = true
        allLayouts[layoutName].panelsUsed[rematch.frame[info[1]]] = true
    end

    -- register the layout to its tab (if any)
    rematch.panelTabs:Register(layoutName)

    -- if this is first time seeing this mode, set this layout as the default (in case moving to a mode where
    -- a view doesnt exist, such as moving from 2-pets to 3-pets (doesn't exist) will move to 3-teams
    if not defaultLayouts[layout.mode] then
        defaultLayouts[layout.mode] = layoutName
    end

    return layoutName
end

-- returns the name of the CURRENT, STANDALONE, MAXIMIZED or JOURNAL layout; or validates the name of the given
-- layout. if the layout doesn't exist for the layout's mode, it will return the default layout that does exist
-- (for example going from 1-pets to 3-pets for the journal will switch to 3-teams since 3-pets doesn't exist.)
function rematch.layout:GetLayout(layout)
    local layoutName = layout -- can be one of the CURRENT/STANDALONE/JOURNAL constants or a layout name
    if not layout or layout==C.CURRENT then
        layoutName = settings.CurrentLayout
    elseif layout==C.STANDALONE then
        layoutName = settings.StandaloneLayout
    elseif layout==C.MAXIMIZED then
        layoutName = settings.MaximizedLayout
    elseif layout==C.JOURNAL then
        layoutName = settings.JournalLayout
        -- if in journal mode and somehow ended up with a non-3 layout, revert back
        if not layoutName or (layoutName and layoutName:sub(1,1)~="3") then
            layoutName = C.DEFAULT_JOURNAL_LAYOUT
        end
    else
        layoutName = layout
    end
    -- verifies the layout exists before returning it
    if type(layoutName)=="string" then
        if allLayouts[layoutName] then -- if given layout was a named layout that exists, return same layout name
            return layoutName
        else -- layout name doesn't exist, see if it has a mode to grab the mode's default layout
            local mode = tonumber(layoutName:sub(1,1))
            if mode then
                return defaultLayouts[mode]
            end
        end
    end
    -- if reached here, no layout or an invalid layout was given
    assert(false,"Layout "..(layoutName or "nil").." doesn't exist.")
end

-- returns the definition for the CURRENT, STANDALONE, MAXIMIZED, JOURNAL or named layout
function rematch.layout:GetDefinition(layout)
    return allLayouts[rematch.layout:GetLayout(layout)]
end

-- returns the mode for the CURRENT, STANDALONE, MAXIMIZED, JOURNAL or named layout
function rematch.layout:GetMode(layout)
    return rematch.layout:GetDefinition(layout).mode
end

-- returns the view for the CURRENT, STANDALONE, MAXIMIZED, JOURNAL or named layout
function rematch.layout:GetView(layout)
    return rematch.layout:GetDefinition(layout).view
end

-- returns the subview for the CURRENT, STANDALONE, MAXIMIZED, JOURNAL or named layout
function rematch.layout:GetSubview(layout)
    return rematch.layout:GetDefinition(layout).subview
end

-- changes the current mode to a different mode with the same view (changes view if view doesn't exist in the mode)
-- returns true if already in the mode or successfully changed into it
function rematch.layout:ChangeMode(mode)
    local def = rematch.layout:GetDefinition(C.CURRENT)
    -- if already in the intended mode, just leave
    if def.mode==mode then
        return true
    end
    -- if view and mode exists then apply
    if def.view and mode then
        rematch.frame:Configure(rematch.layout:GetLayout(mode.."-"..def.view))
    end
end

-- changes the current layout to a different view of the same mode
function rematch.layout:ChangeView(view)
    local def = rematch.layout:GetDefinition(C.CURRENT)
    -- if already in intended view, just leave
    if def.view==view then
        return
    end
    -- if mode and view exist then apply
    if def.mode and view then
        rematch.frame:Configure(rematch.layout:GetLayout(def.mode.."-"..view))
    end
end

-- intended to turn a subview on and off of the current layout; subview is nil to turn it off
function rematch.layout:ChangeSubview(subview)
    local def = rematch.layout:GetDefinition(C.CURRENT)
    if def.subview==subview then
        return
    end
    if not subview then
        rematch.frame:Configure(rematch.layout:GetLayout(def.mode.."-"..def.view))
    else
        rematch.frame:Configure(rematch.layout:GetLayout(def.mode.."-"..def.view.."-"..subview))
    end
end

-- hides all panels that don't belong to the given definition
function rematch.layout:HidePanels(def)
    for panel in pairs(knownPanels) do
        if not def.panelsUsed[panel] then
            panel:Hide()
        end
    end
end

-- a more forceful version of ChangeView, it summons the Rematch window (in preferred mode if not already up) and
-- goes to the given view, one of: "pets", "teams", "targets", "queue" or "options".
-- for any new panels created, this would use the ___Panel name. eg otherPanel would be OpenView("other")
function rematch.layout:SummonView(view)
    -- summon window if it's not already visible
    if not rematch.frame:IsVisible() then
        if settings.LastOpenJournal then
            ToggleCollectionsJournal(COLLECTIONS_JOURNAL_TAB_INDEX_PETS)
        else
            rematch.frame:Toggle()
        end
    end
    -- append Panel to the view to tell if it's already visible (eg petsPanel)
    local panel = view.."Panel"
    -- only go to the view if the panel isn't visible
    if rematch[panel] and not rematch[panel]:IsVisible() then
        if rematch.layout:GetMode()==0 then -- in minimized mode, switch to a maximized mode with the view
            local mode = rematch.layout:GetMode(C.MAXIMIZED)
            rematch.frame:Configure(mode.."-"..view)
        else -- not minimized, simpler switch to the view
            rematch.layout:ChangeView(view)
        end
    end
end
