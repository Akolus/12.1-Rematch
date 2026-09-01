# Rematch 12.1 Custom Update — Changelog

## [Unreleased]

This update expands pet searching, improves saved-team loading in Battle Pet dungeons, fixes WoW 12.1 compatibility errors, and replaces the standard pet-battle bottom bar with a compact modern interface.

### Added

#### Multi-ability pet search

- Pet searches can now require two or three abilities at the same time.
- Separate ability names with commas or semicolons.
- Every entered term must match a distinct ability from the pet's six possible abilities.
- Existing single-term searches for pet names, abilities, sources, notes, and other text continue to work.
- Example: `Bite, Solar Beam, Sunlight` returns Sunglow Cobra.

#### HP, Power, and Speed search fields

- Added separate HP, Power, and Speed fields directly below the pet search box.
- Each field accepts `<`, `>`, or `=` followed by a number.
- A number without an operator is treated as an exact match.
- Stat fields can be combined with an ability search, such as `Explode` with `HP >1600`.
- Invalid stat expressions are highlighted in red and do not replace the active valid filter.
- Stat searches are preserved in saved favorite filters and cleared alongside the other filters.

#### Unique-pet sorting

- Added `Unique` to the primary, secondary, and tertiary pet sort menus.
- Unique pets—those for which only one copy can be learned, such as Bumbles—sort first by default.
- `Reverse Sort` places non-unique pets first when `Unique` is the active sort.

#### Uncollected-pet breed support

- Stat searches can now return battle pets that have not yet been collected.
- Uncollected species are evaluated using every legal rare-quality level 25 breed.
- HP, Power, and Speed conditions do not need to be satisfied by the same breed. A species is included when each requested stat is possible on at least one of its legal breeds.
- Uncollected species without reliable breed data are not guessed.
- Level-only searches retain the original collected-pet behavior.

#### Modern pet-battle interface

- Added a unified bottom interface containing Battle Data, Pass, Autobattle, the player's abilities, pet switching, capture, forfeit, and pet XP.
- Replaced the wooden Blizzard artwork with a compact dark theme and a single 1 px black outer border.
- Removed the old isolated plaque above the action bar.
- Removed the right-side Blizzard micro menu from the pet-battle interface.
- Restyled the player's action icons to use the same borderless rounded-square appearance as the enemy ability icons.
- Added a 1 px cyan divider 5 px above the player's action icons.
- Added an 8 px full-width themed XP bar at the bottom of the interface.
- The XP bar displays exact `current/max` experience using an 11 px outlined font.
- Added the PvP turn timer as a compact text-only row at the top of the unified interface, using the same typography, spacing, and cyan divider as the utility menu.
- Kept Blizzard's wooden timer plaque hidden instead of embedding its legacy artwork in the modern panel.
- The complete interface is 106 px tall at 100% scale.

#### Ability effectiveness overlays

- Replaced the small green up-arrow and red down-arrow indicators with full-icon gradient overlays.
- Strong abilities glow brightest green at the bottom and fade toward the top.
- Weak abilities glow brightest red at the top and fade toward the bottom.
- The overlays are applied to both the player's abilities and enemy ability icons.
- Neutral abilities and abilities that suppress strong/weak hints remain uncolored.

#### Movable and scalable battle UI

- Shift + left-drag any player action icon or Battle Data/Pass/Autobattle control to move the entire unified bottom interface.
- Ctrl + mouse wheel over the interface scales it up or down in 1% steps.
- Scale is limited to 50–200%.
- Position and scale are saved between sessions.
- Scaling expands and contracts around the center instead of drifting diagonally.

#### Movable and scalable enemy abilities

- Shift + left-drag an enemy ability icon to freely reposition the enemy ability bar.
- Ctrl + mouse wheel over an enemy ability changes its scale in 1% steps.
- Enemy ability position and scale are saved between sessions.
- Center-based anchoring prevents the bar from moving when its scale changes.

#### Autobattle keybinding control

- Removed the dark keybind sub-cell and its divider from the Autobattle control.
- The current binding and `+` now share a separate transparent keybind setter beside Autobattle.
- Clicking `+` opens a compact key-capture prompt.
- The prompt slowly dims and brightens while cycling through `Set keybind.`, `Set keybind..`, and `Set keybind...`.
- The next valid key, modifier combination, or mouse-wheel direction is saved through Pet Battle Scripts.
- Modifier-only presses continue waiting for a complete keybind.
- `Esc` cancels key capture.
- Left- or right-clicking outside the battle UI closes the prompt.
- Existing secondary Autobattle bindings remain visible and are not overwritten.
- Keybind text automatically shrinks when needed to prevent overlap.
- Right-clicking anywhere on the Autobattle control, including its `+` keybind area, toggles continuous script execution.
- While active, Autobattle runs the next scripted move whenever the control becomes enabled for the player's turn and continues until the battle ends or it is toggled off.
- Continuous execution now follows the pet-battle round-playback-complete event directly, with button enable/disable callbacks retained as a fallback for server-specific event behavior.
- The label displays `ON` while continuous execution is active and resets automatically when the battle ends.
- Normal single-step left-click execution and left-clicking `+` to edit the keybind are unchanged.

### Changed

- Battle Data, Pass, and Autobattle now form one continuous row instead of three separately bordered cells.
- Hovering Battle Data, Pass, or Autobattle now turns only its label yellow without adding a background glow.
- Battle Data, Pass, and Autobattle labels now use a 14 px font at 100% interface scale.
- Removed the round pet portrait from the upper-left corner of the journal and reclaimed its toolbar space.
- Tightened the main panel's outer shadow by 2 px so it no longer extends as far beyond the journal edges.
- Hid the underlying Blizzard Collections Journal backdrop while Rematch is active, removing the remaining dark area outside the addon window while preserving and restoring it for the other journal tabs.
- Shifted Rematch 9 px farther left in journal mode and made its journal layout 15 px taller, preserving the corrected top alignment while extending the bottom edge another 5 px downward over Blizzard's window.
- The controls are separated by two light-blue vertical lines.
- Both separators use pixel-aligned sizing so they remain exactly one physical pixel wide at different UI scales.
- The control row was moved closer to the player abilities for a more compact layout.
- The pet search placeholder now reads `Search Pets / Abilities`.
- Pet-search help text now documents multi-ability queries, dedicated stat fields, and uncollected breed handling.

### Fixed

#### Battle Pet dungeon saved-team loading

- Saved teams can now load for gossip-enabled dungeon opponents that do not expose a usable battle-pet species ID when targeted.
- This includes interaction targets such as Gnomeregan's Door Control Console and Blackrock Depths' Horu Cloudwatcher.
- Added a generic fallback from a readable unit name to a uniquely matching notable NPC.
- Added a retry when `GOSSIP_SHOW` fires because some interaction targets reveal their information after `PLAYER_TARGET_CHANGED`.
- The fallback applies to uniquely named notable targets in all supported dungeons rather than a single hard-coded NPC.
- Duplicate NPC names are treated as ambiguous and rejected instead of risking the wrong team.
- Player names are explicitly excluded from the fallback.
- Existing GUID, redirect, and battle-pet species detection remains unchanged.

#### WoW 12.1 mouse API compatibility

- Replaced obsolete global `MouseIsOver(...)` calls with the supported region method `frame:IsMouseOver()`.
- Fixes the repeated `loadoutPanel.lua:388: attempt to call a nil value` error.
- Updated the loadout ability flyout, notes editor, queue drag glow, team/group drag handling, and related mouse-over paths.

#### Battle UI stability and presentation

- Fixed enemy ability positions resetting and overlapping the bottom battle controls.
- Fixed UI scaling moving elements from bottom-left to top-right instead of scaling around their center.
- Fixed Autobattle keybind text overlapping the keybinding control.
- Fixed control dividers occasionally rendering two pixels wide.
- Blizzard's original XP bar is now hidden while continuing to provide the live value and visibility state for the replacement bar.
- Hidden or newly available actions are inserted without leaving layout gaps.
- The unified interface hides correctly when the pet battle ends.

### Controls

| Action | Input |
| --- | --- |
| Move the unified bottom UI | Shift + left-drag a player action or top-row control |
| Resize the unified bottom UI | Ctrl + mouse wheel over the UI |
| Move enemy abilities | Shift + left-drag an enemy ability |
| Resize enemy abilities | Ctrl + mouse wheel over an enemy ability |
| Set the primary Autobattle key | Click `+`, then press the desired key |
| Cancel key capture | `Esc` or left/right-click outside the battle UI |

### Search examples

| Goal | Search |
| --- | --- |
| Require three abilities | `Bite, Solar Beam, Sunlight` |
| Require two abilities | `Bite; Solar Beam` |
| Find high-HP Explode pets | Search: `Explode`; HP: `>1600` |
| Find an exact Power value | Power: `=325` |
| Find slower pets | Speed: `<300` |

### Validation

- Added six standalone Lua regression suites covering:
  - Dungeon target identification and gossip fallbacks.
  - Multi-ability and stat-search parsing.
  - Uncollected species and legal breed evaluation.
  - Enemy ability movement, scaling, and effectiveness overlays.
  - Unified battle controls and Autobattle key capture.
  - Modern action-bar layout, XP mirroring, and visibility.
- All six regression suites pass.
- Lua syntax checks pass for the new battle UI modules.
- The install archive passes a full integrity check.

### Updating

1. Exit World of Warcraft or log out to the character screen.
2. Replace the existing `Rematch` folder in `_retail_/Interface/AddOns/` with the updated folder.
3. Start the game or run `/reload`.

Saved teams and settings do not need to be deleted.
