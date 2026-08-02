# Mobile Build Notes

Star Guardian Protocol uses a landscape 1280x720 base viewport and Godot's
Compatibility renderer. The battle scene includes touch controls only for
mobile exports:

- Left-side buttons move the guardian.
- Right-side buttons fire, dodge, pulse, interact, and open upgrades.
- Dragging on the right half of the screen controls aim. If no target is
  selected, the guardian automatically faces the nearest enemy.
- Weapon slots, gadgets, and active skills remain available from the lower
  right control area.

## Android

Use the `Android` export preset. It targets 64-bit ARM phones and tablets,
requires Android 7.0 or later, and exports a signed debug APK for testing.
For a store release, replace the debug keystore with a dedicated release
keystore before publishing.

## iPhone and iPad

iOS packaging must be done on macOS with Xcode and an Apple signing team.
Open the project in Godot on the Mac, add an `iOS` export preset, export the
Xcode project, set the signing team and bundle identifier in Xcode, then run
on a real iPhone or iPad. The game does not depend on Android-specific plugins,
and its mobile input is implemented in shared GDScript, so the same touch
controls are used on iPad.

Before release, test a current iPad in landscape: main menu layout, pause and
reward panels, five weapon buttons, and two-finger system gestures near the
screen edges.
