Rematch – WoW 12.1 Pet Battle Enhancements

A collection of compatibility fixes and quality-of-life improvements for the Rematch World of Warcraft addon, updated for WoW 12.1.

This project started as an attempt to restore Rematch functionality affected by WoW 12.1's new protected/secret-value behavior and gradually evolved into a more complete enhancement for pet battle encounters.

What it does
WoW 12.1 Target Detection Fix

WoW 12.1 can return protected/secret values for NPC information in certain pet battle encounters and instances. This caused Rematch to lose its ability to properly identify some pet battle targets, resulting in entries such as:

Unknown (npc ID XXXXX)

and preventing Rematch's saved-team popup from appearing automatically.

The compatibility patch introduces an alternative target-identification method for battle-pet encounters, allowing Rematch to once again:

Identify supported pet battle targets before combat
Display their proper names
Match targets with saved Rematch teams
Automatically display the appropriate saved-team popup
Work in encounters where the normal NPC GUID/name information is restricted

Ambiguous matches are deliberately rejected rather than guessing the wrong target.

Enemy Ability Bar

The project also adds an integrated Enemy Ability Bar directly to Rematch.

During a pet battle, the three abilities of the currently active enemy pet are displayed as compact ability icons.

Features
Displays all three abilities of the active enemy pet
Automatically updates when the enemy switches pets
Native Blizzard pet-battle ability tooltips
Correct calculated damage and hit chance in tooltips
Strong/weak pet-family information
Rounded action-bar-style ability icons
No Blizzard quickslot borders
Configurable icon size
Configurable spacing between icons
Configurable cooldown font
Configurable cooldown font size
Configurable cooldown X/Y position
Large remaining-cooldown indicator
Settings integrated directly into the Rematch Options panel
Configuration changes apply immediately without /reload
WoW 12.1 Enemy Cooldown Tracking

WoW 12.1 introduced another complication.

For enemy PvE battle pets, Blizzard's:

C_PetBattles.GetAbilityState()

can report an ability as:

usable = true
cooldown = 0

even immediately after the enemy has used an ability that has a cooldown.

Because of this, simply querying Blizzard's current ability state is not sufficient to reliably display enemy cooldowns.

The Enemy Ability Bar therefore maintains its own battle-state tracking. Enemy ability casts are detected during combat and their remaining cooldowns are calculated round-by-round.

Cooldown history is maintained independently for each enemy pet, including when the opponent switches pets and later switches back.

Native Rematch Integration

This is intentionally not a separate addon.

The functionality is integrated into Rematch itself and uses Rematch's existing settings system and interface.

The goal was to avoid installing a full additional pet-battle addon just to obtain enemy ability and cooldown information.

Once installed, the new options are available directly through:

Rematch → Options → Enemy Ability Bar Options

Requirements
World of Warcraft Retail 12.1
Rematch 5.3.1
Pet Battles enabled

The patches were developed and tested against these versions. Compatibility with older or future versions is not guaranteed.

Important

This project modifies files belonging to Rematch.

Updating Rematch through CurseForge, WoWUp, or another addon manager may overwrite these modifications. Back up the modified files or reapply the patch after updating Rematch.

This project is an unofficial modification and is not affiliated with or maintained by the original Rematch author.

Rematch itself remains the work of its original author, Gello.
