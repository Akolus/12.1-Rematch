local _,rematch = ...
local L = rematch.localization
local C = rematch.constants

--[[

    All the default layout definitions are defined here. Each layout definition is a table that describes
    its mode, view, width, height, tab text, and panels and their anchors.

    Custom layouts/tabs can be added by following these guidelines.

    Layouts can be one of four modes (required):
        0: minimized
        1: single-panel
        2: dual-panel
        3: triple-panel
    Each mode can be registered for different views (required), generally associated with its tab:
        "pets": Pets panel (this view doesn't exist while in the triple-mode mode because pets are always up)
        "team": Teams panel
        "queue": Queue panel
        "options": Options panel
    Each view can have a subview (optional) for reconfiguring panels without changing the current view:
        "target": for views that display a TargetPanel while a saved target is targeted

    When a layout is registered, a tab is created for the view if one doesn't already exist. The same tab
    will be used for all versions of the same view.

    Other attributes of a layout definition:
        - width (required): width of the frame.Canvas the layout will arrange panels on (this excludes chrome elements)
        - height (required): height of the frame.Canvas the layout will arrange panels on
        - tab (optional): Localized text to display on the tab generated for the layout's view, if it has a tab
        - hasTempTarget (optional): true if this layout has a -target version for temporarily showing saved targets
        - panels (required): an ordered list of sub-lists that list the parentKey (relative to rematch.frame) of
            a panel to place, and then two anchors to position the panel:

                    {panelParentKey,anchorPoint1,relativeTo1,relativePoint1,xoff1,yoff2,
                                    anchorPoint2,relativeTo2,relativePoint2,xoff2,yoff2}

            For instance, placing the PetsPanel to take up the left half of the canvas can be:

                    {"PetsPanel","TOPLEFT","Canvas","TOPLEFT",0,0,"BOTTOMRIGHT","Canvas","BOTTOM",-1,0}

            Note: "Canvas" is resized to the width,height defined in the layout; and panels should anchor
            to this if they're not anchoring to other panels. Note that parentKeys are used for these
            relativeTo's also, and all are a parentKey relative to the main Rematch frame. Any new panels
            must have a parentKey defined and a parent of "RematchFrame".

    After a layout definition is complete, register it with: rematch.layout:Register(definition)

    When a layout is registered, a layoutName is created from the mode-view[-subview]. This is unique and
    registering the same mode-view-subview will overwrite the previous definition. All future references to
    the layout are generally by this layoutName. In addition, a new tab will be created if it's for a view
    not previously seen. This tab will only be visible in the modes defined with the layout. (mode 0 is
    reserved for minimized views and cannot have custom tabs added to it.)

]]

rematch.layout.definitions = {

    --[[ minimized views (0-view) ]]

    {
        mode=0,view="minimized", -- 0-minimized
        width=C.PANEL_MINIMIZED_WIDTH,height=C.PANEL_MINIMIZED_HEIGHT,hasTempTarget=true,
        panels={
            {"LoadedTeamPanel","TOPLEFT","Canvas","TOPLEFT",0,0,"BOTTOMRIGHT","Canvas","TOPRIGHT",0,-C.PANEL_LOADEDTEAM_HEIGHT},
            {"MiniLoadoutPanel","TOPLEFT","LoadedTeamPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","Canvas","BOTTOMRIGHT",0,0}
        }
    },
    {
        mode=0,view="minimized",subview="target", -- 0-minimized-target
        width=C.PANEL_MINIMIZED_WIDTH,height=C.PANEL_MINIMIZED_HEIGHT+2+C.PANEL_SHORT_TARGET_HEIGHT,hasTempTarget=true,
        panels={
            {"LoadedTeamPanel","TOPLEFT","Canvas","TOPLEFT",0,0,"BOTTOMRIGHT","Canvas","TOPRIGHT",0,-C.PANEL_LOADEDTEAM_HEIGHT},
            {"LoadedTargetPanel","TOPLEFT","Canvas","BOTTOMLEFT",0,C.PANEL_SHORT_TARGET_HEIGHT,"BOTTOMRIGHT","Canvas","BOTTOMRIGHT",0,0},
            {"MiniLoadoutPanel","TOPLEFT","LoadedTeamPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","LoadedTargetPanel","TOPRIGHT",0,2}
        }
    },

    --[[ single panel views (1-view) ]]

    {
        mode=1,view="pets", -- 1-pets
        width=C.PANEL_SINGLE_WIDTH,height=C.PANEL_HEIGHT,tab=L["TAB_PETS"],hasTempTarget=true,
        panels={
            {"LoadedTeamPanel","TOPLEFT","Canvas","TOPLEFT",0,0,"BOTTOMRIGHT","Canvas","TOPRIGHT",0,-C.PANEL_LOADEDTEAM_HEIGHT},
            {"MiniLoadoutPanel","TOPLEFT","LoadedTeamPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","LoadedTeamPanel","BOTTOMRIGHT",0,-C.PANEL_MINILOADOUT_HEIGHT-2},
            {"PetsPanel","TOPLEFT","MiniLoadoutPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","Canvas","BOTTOMRIGHT",0,0}
        }
    },
    {
        mode=1,view="pets",subview="target", -- 1-pets-target
        width=C.PANEL_SINGLE_WIDTH,height=C.PANEL_HEIGHT,tab=L["TAB_PETS"],hasTempTarget=true,
        panels={
            {"LoadedTeamPanel","TOPLEFT","Canvas","TOPLEFT",0,0,"BOTTOMRIGHT","Canvas","TOPRIGHT",0,-C.PANEL_LOADEDTEAM_HEIGHT},
            {"MiniLoadoutPanel","TOPLEFT","LoadedTeamPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","LoadedTeamPanel","BOTTOMRIGHT",0,-C.PANEL_MINILOADOUT_HEIGHT-2},
            {"LoadedTargetPanel","TOPLEFT","MiniLoadoutPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","MiniLoadoutPanel","BOTTOMRIGHT",0,-C.PANEL_SHORT_TARGET_HEIGHT-2},
            {"PetsPanel","TOPLEFT","LoadedTargetPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","Canvas","BOTTOMRIGHT",0,0}
        }
    },
    {
        mode=1,view="teams", -- 1-teams
        width=C.PANEL_SINGLE_WIDTH,height=C.PANEL_HEIGHT,tab=L["TAB_TEAMS"],hasTempTarget=true,
        panels={
            {"LoadedTeamPanel","TOPLEFT","Canvas","TOPLEFT",0,0,"BOTTOMRIGHT","Canvas","TOPRIGHT",0,-C.PANEL_LOADEDTEAM_HEIGHT},
            {"MiniLoadoutPanel","TOPLEFT","LoadedTeamPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","LoadedTeamPanel","BOTTOMRIGHT",0,-C.PANEL_MINILOADOUT_HEIGHT-2},
            {"TeamsPanel","TOPLEFT","MiniLoadoutPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","Canvas","BOTTOMRIGHT",0,0}
        }
    },
    {
        mode=1,view="teams",subview="target", -- 1-teams-target
        width=C.PANEL_SINGLE_WIDTH,height=C.PANEL_HEIGHT,tab=L["TAB_TEAMS"],hasTempTarget=true,
        panels={
            {"LoadedTeamPanel","TOPLEFT","Canvas","TOPLEFT",0,0,"BOTTOMRIGHT","Canvas","TOPRIGHT",0,-C.PANEL_LOADEDTEAM_HEIGHT},
            {"MiniLoadoutPanel","TOPLEFT","LoadedTeamPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","LoadedTeamPanel","BOTTOMRIGHT",0,-C.PANEL_MINILOADOUT_HEIGHT-2},
            {"LoadedTargetPanel","TOPLEFT","MiniLoadoutPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","MiniLoadoutPanel","BOTTOMRIGHT",0,-C.PANEL_SHORT_TARGET_HEIGHT-2},
            {"TeamsPanel","TOPLEFT","LoadedTargetPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","Canvas","BOTTOMRIGHT",0,0}
        }
    },
    {
        mode=1,view="targets", -- 1-targets
        width=C.PANEL_SINGLE_WIDTH,height=C.PANEL_HEIGHT,tab=L["TAB_TARGETS"],hasTempTarget=true,
        panels={
            {"LoadedTeamPanel","TOPLEFT","Canvas","TOPLEFT",0,0,"BOTTOMRIGHT","Canvas","TOPRIGHT",0,-C.PANEL_LOADEDTEAM_HEIGHT},
            {"MiniLoadoutPanel","TOPLEFT","LoadedTeamPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","LoadedTeamPanel","BOTTOMRIGHT",0,-C.PANEL_MINILOADOUT_HEIGHT-2},
            {"TargetsPanel","TOPLEFT","MiniLoadoutPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","Canvas","BOTTOMRIGHT",0,0}
        }
    },
    {
        mode=1,view="targets",subview="target", -- 1-targets-target
        width=C.PANEL_SINGLE_WIDTH,height=C.PANEL_HEIGHT,tab=L["TAB_TARGETS"],hasTempTarget=true,
        panels={
            {"LoadedTeamPanel","TOPLEFT","Canvas","TOPLEFT",0,0,"BOTTOMRIGHT","Canvas","TOPRIGHT",0,-C.PANEL_LOADEDTEAM_HEIGHT},
            {"MiniLoadoutPanel","TOPLEFT","LoadedTeamPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","LoadedTeamPanel","BOTTOMRIGHT",0,-C.PANEL_MINILOADOUT_HEIGHT-2},
            {"LoadedTargetPanel","TOPLEFT","MiniLoadoutPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","MiniLoadoutPanel","BOTTOMRIGHT",0,-C.PANEL_SHORT_TARGET_HEIGHT-2},
            {"TargetsPanel","TOPLEFT","LoadedTargetPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","Canvas","BOTTOMRIGHT",0,0}
        }
    },
    {
        mode=1,view="queue", -- 1-queue
        width=C.PANEL_SINGLE_WIDTH,height=C.PANEL_HEIGHT,tab=L["TAB_QUEUE"],hasTempTarget=true,
        panels={
            {"LoadedTeamPanel","TOPLEFT","Canvas","TOPLEFT",0,0,"BOTTOMRIGHT","Canvas","TOPRIGHT",0,-C.PANEL_LOADEDTEAM_HEIGHT},
            {"MiniLoadoutPanel","TOPLEFT","LoadedTeamPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","LoadedTeamPanel","BOTTOMRIGHT",0,-C.PANEL_MINILOADOUT_HEIGHT-2},
            {"QueuePanel","TOPLEFT","MiniLoadoutPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","Canvas","BOTTOMRIGHT",0,0}
        }
    },
    {
        mode=1,view="queue",subview="target", -- 1-queue-target
        width=C.PANEL_SINGLE_WIDTH,height=C.PANEL_HEIGHT,tab=L["TAB_QUEUE"],hasTempTarget=true,
        panels={
            {"LoadedTeamPanel","TOPLEFT","Canvas","TOPLEFT",0,0,"BOTTOMRIGHT","Canvas","TOPRIGHT",0,-C.PANEL_LOADEDTEAM_HEIGHT},
            {"MiniLoadoutPanel","TOPLEFT","LoadedTeamPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","LoadedTeamPanel","BOTTOMRIGHT",0,-C.PANEL_MINILOADOUT_HEIGHT-2},
            {"LoadedTargetPanel","TOPLEFT","MiniLoadoutPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","MiniLoadoutPanel","BOTTOMRIGHT",0,-C.PANEL_SHORT_TARGET_HEIGHT-2},
            {"QueuePanel","TOPLEFT","LoadedTargetPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","Canvas","BOTTOMRIGHT",0,0}
        }
    },
    {
        mode=1,view="options", -- 1-options
        width=C.PANEL_SINGLE_WIDTH,height=C.PANEL_HEIGHT,tab=L["TAB_OPTIONS"],
        panels={
            {"OptionsPanel","TOPLEFT","Canvas","TOPLEFT",0,0,"BOTTOMRIGHT","Canvas","BOTTOMRIGHT",0,0}
        }
    },

    --[[ dual panel views (2-view) ]]

    {
        mode=2,view="pets", -- 2-pets
        width=C.PANEL_WIDTH*2+2,height=C.PANEL_HEIGHT,tab=L["TAB_PETS"],
        panels={
            {"PetsPanel","TOPLEFT","Canvas","TOPLEFT",0,0,"BOTTOMRIGHT","Canvas","BOTTOM",-1,0},
            {"LoadedTargetPanel","TOPLEFT","Canvas","TOP",1,0,"BOTTOMRIGHT","Canvas","TOPRIGHT",0,-C.PANEL_TARGET_HEIGHT},
            {"LoadedTeamPanel","TOPLEFT","LoadedTargetPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","LoadedTargetPanel","BOTTOMRIGHT",0,-C.PANEL_LOADEDTEAM_HEIGHT-2},
            {"LoadoutPanel","TOPLEFT","LoadedTeamPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","Canvas","BOTTOMRIGHT",0,0}
        }
    },
    {
        mode=2,view="teams", -- 2-teams
        width=C.PANEL_WIDTH*2+2,height=C.PANEL_HEIGHT,tab=L["TAB_TEAMS"],
        panels = {
            {"LoadedTargetPanel","TOPLEFT","Canvas","TOPLEFT",0,0,"BOTTOMRIGHT","Canvas","TOP",-1,-C.PANEL_TARGET_HEIGHT},
            {"LoadedTeamPanel","TOPLEFT","LoadedTargetPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","LoadedTargetPanel","BOTTOMRIGHT",0,-C.PANEL_LOADEDTEAM_HEIGHT-2},
            {"LoadoutPanel","TOPLEFT","LoadedTeamPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","Canvas","BOTTOM",-1,0},
            {"TeamsPanel","TOPLEFT","Canvas","TOP",1,0,"BOTTOMRIGHT","Canvas","BOTTOMRIGHT",0,0}
        }
    },
    {
        mode=2,view="targets", -- 2-targets
        width=C.PANEL_WIDTH*2+2,height=C.PANEL_HEIGHT,tab=L["TAB_TARGETS"],
        panels = {
            {"LoadedTargetPanel","TOPLEFT","Canvas","TOPLEFT",0,0,"BOTTOMRIGHT","Canvas","TOP",-1,-C.PANEL_TARGET_HEIGHT},
            {"LoadedTeamPanel","TOPLEFT","LoadedTargetPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","LoadedTargetPanel","BOTTOMRIGHT",0,-C.PANEL_LOADEDTEAM_HEIGHT-2},
            {"LoadoutPanel","TOPLEFT","LoadedTeamPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","Canvas","BOTTOM",-1,0},
            {"TargetsPanel","TOPLEFT","Canvas","TOP",1,0,"BOTTOMRIGHT","Canvas","BOTTOMRIGHT",0,0}
        }
    },
    {
        mode=2,view="queue", -- 2-queue
        width=C.PANEL_WIDTH*2+2,height=C.PANEL_HEIGHT,tab=L["TAB_QUEUE"],hasTempTarget=true,
        panels={
            {"PetsPanel","TOPLEFT","Canvas","TOPLEFT",0,0,"BOTTOMRIGHT","Canvas","BOTTOM",-1,0},
            {"LoadedTeamPanel","TOPLEFT","Canvas","TOP",1,0,"BOTTOMRIGHT","Canvas","TOPRIGHT",0,-C.PANEL_LOADEDTEAM_HEIGHT},
            {"MiniLoadoutPanel","TOPLEFT","LoadedTeamPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","LoadedTeamPanel","BOTTOMRIGHT",0,-C.PANEL_MINILOADOUT_HEIGHT-2},
            {"QueuePanel","TOPLEFT","MiniLoadoutPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","Canvas","BOTTOMRIGHT",0,0}
        }
    },
    {
        mode=2,view="queue",subview="target", -- 2-queue-target
        width=C.PANEL_WIDTH*2+2,height=C.PANEL_HEIGHT,tab=L["TAB_QUEUE"],hasTempTarget=true,
        panels = {
            {"PetsPanel","TOPLEFT","Canvas","TOPLEFT",0,0,"BOTTOMRIGHT","Canvas","BOTTOM",-1,0},
            {"LoadedTeamPanel","TOPLEFT","Canvas","TOP",1,0,"BOTTOMRIGHT","Canvas","TOPRIGHT",0,-C.PANEL_LOADEDTEAM_HEIGHT},
            {"MiniLoadoutPanel","TOPLEFT","LoadedTeamPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","LoadedTeamPanel","BOTTOMRIGHT",0,-C.PANEL_MINILOADOUT_HEIGHT-2},
            {"LoadedTargetPanel","TOPLEFT","MiniLoadoutPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","MiniLoadoutPanel","BOTTOMRIGHT",0,-C.PANEL_SHORT_TARGET_HEIGHT-2},
            {"QueuePanel","TOPLEFT","LoadedTargetPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","Canvas","BOTTOMRIGHT",0,0}
        }
    },
    {
        mode=2,view="options", -- 2-options
        width=C.PANEL_WIDTH*2+2,height=C.PANEL_HEIGHT,tab=L["TAB_OPTIONS"],
        panels = {
            {"LoadedTargetPanel","TOPLEFT","Canvas","TOPLEFT",0,0,"BOTTOMRIGHT","Canvas","TOP",-1,-C.PANEL_TARGET_HEIGHT},
            {"LoadedTeamPanel","TOPLEFT","LoadedTargetPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","LoadedTargetPanel","BOTTOMRIGHT",0,-C.PANEL_LOADEDTEAM_HEIGHT-2},
            {"LoadoutPanel","TOPLEFT","LoadedTeamPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","Canvas","BOTTOM",-1,0},
            {"OptionsPanel","TOPLEFT","Canvas","TOP",1,0,"BOTTOMRIGHT","Canvas","BOTTOMRIGHT",0,0}
        }
    },

    --[[ triple panel views (3-view) ]]

    {
        mode=3,view="teams", -- 3-teams
        width=C.PANEL_WIDTH*3+4,height=C.PANEL_HEIGHT,tab=L["TAB_TEAMS"],
        panels = {
            {"PetsPanel","TOPLEFT","Canvas","TOPLEFT",0,0,"BOTTOMRIGHT","Canvas","BOTTOMLEFT",C.PANEL_WIDTH,0},
            {"TeamsPanel","TOPLEFT","Canvas","TOPRIGHT",-C.PANEL_WIDTH,0,"BOTTOMRIGHT","Canvas","BOTTOMRIGHT",0,0},
            {"LoadedTargetPanel","TOPLEFT","PetsPanel","TOPRIGHT",2,0,"BOTTOMRIGHT","TeamsPanel","TOPLEFT",-2,-C.PANEL_TARGET_HEIGHT},
            {"LoadedTeamPanel","TOPLEFT","LoadedTargetPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","LoadedTargetPanel","BOTTOMRIGHT",0,-C.PANEL_LOADEDTEAM_HEIGHT-2},
            {"LoadoutPanel","TOPLEFT","LoadedTeamPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","TeamsPanel","BOTTOMLEFT",-2,0}
        }
    },
    {
        mode=3,view="targets", -- 3-targets
        width=C.PANEL_WIDTH*3+4,height=C.PANEL_HEIGHT,tab=L["TAB_TARGETS"],
        panels = {
            {"PetsPanel","TOPLEFT","Canvas","TOPLEFT",0,0,"BOTTOMRIGHT","Canvas","BOTTOMLEFT",C.PANEL_WIDTH,0},
            {"TargetsPanel","TOPLEFT","Canvas","TOPRIGHT",-C.PANEL_WIDTH,0,"BOTTOMRIGHT","Canvas","BOTTOMRIGHT",0,0},
            {"LoadedTargetPanel","TOPLEFT","PetsPanel","TOPRIGHT",2,0,"BOTTOMRIGHT","TargetsPanel","TOPLEFT",-2,-C.PANEL_TARGET_HEIGHT},
            {"LoadedTeamPanel","TOPLEFT","LoadedTargetPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","LoadedTargetPanel","BOTTOMRIGHT",0,-C.PANEL_LOADEDTEAM_HEIGHT-2},
            {"LoadoutPanel","TOPLEFT","LoadedTeamPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","TargetsPanel","BOTTOMLEFT",-2,0}
        }
    },
    {
        mode=3,view="queue", -- 3-queue
        width=C.PANEL_WIDTH*3+4,height=C.PANEL_HEIGHT,tab=L["TAB_QUEUE"],
        panels = {
            {"PetsPanel","TOPLEFT","Canvas","TOPLEFT",0,0,"BOTTOMRIGHT","Canvas","BOTTOMLEFT",C.PANEL_WIDTH,0},
            {"QueuePanel","TOPLEFT","Canvas","TOPRIGHT",-C.PANEL_WIDTH,0,"BOTTOMRIGHT","Canvas","BOTTOMRIGHT",0,0},
            {"LoadedTargetPanel","TOPLEFT","PetsPanel","TOPRIGHT",2,0,"BOTTOMRIGHT","QueuePanel","TOPLEFT",-2,-C.PANEL_TARGET_HEIGHT},
            {"LoadedTeamPanel","TOPLEFT","LoadedTargetPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","LoadedTargetPanel","BOTTOMRIGHT",0,-C.PANEL_LOADEDTEAM_HEIGHT-2},
            {"LoadoutPanel","TOPLEFT","LoadedTeamPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","QueuePanel","BOTTOMLEFT",-2,0}
        }
    },
    {
        mode=3,view="options", -- 3-options
        width=C.PANEL_WIDTH*3+4,height=C.PANEL_HEIGHT,tab=L["TAB_OPTIONS"],
        panels = {
            {"PetsPanel","TOPLEFT","Canvas","TOPLEFT",0,0,"BOTTOMRIGHT","Canvas","BOTTOMLEFT",C.PANEL_WIDTH,0},
            {"OptionsPanel","TOPLEFT","Canvas","TOPRIGHT",-C.PANEL_WIDTH,0,"BOTTOMRIGHT","Canvas","BOTTOMRIGHT",0,0},
            {"LoadedTargetPanel","TOPLEFT","PetsPanel","TOPRIGHT",2,0,"BOTTOMRIGHT","OptionsPanel","TOPLEFT",-2,-C.PANEL_TARGET_HEIGHT},
            {"LoadedTeamPanel","TOPLEFT","LoadedTargetPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","LoadedTargetPanel","BOTTOMRIGHT",0,-C.PANEL_LOADEDTEAM_HEIGHT-2},
            {"LoadoutPanel","TOPLEFT","LoadedTeamPanel","BOTTOMLEFT",0,-2,"BOTTOMRIGHT","OptionsPanel","BOTTOMLEFT",-2,0}
        }
    },
}
