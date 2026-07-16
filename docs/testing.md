# Testing

`scripts/validate.sh` performs project import, script/resource parsing, logic
tests, scene smoke tests, and export preset checks. Reports are written to
`tests/latest_report.txt` only after commands have actually run.

Interactive controls and visual presentation still require a windowed smoke run.
Performance claims must include measured Godot monitor output; none are inferred.

## Verified baseline

- Godot 4.6.3 project import and script/resource parsing
- 28 logic and scene checks, including victory and defeat transitions
- Three consecutive game-scene create/free cycles
- Main scene headless boot
- Linux release export and exported-binary boot
- Windows x86-64 release export and executable format inspection
- Windowed menu, combat HUD, pause/result layout, movement, firing, dash, damage,
  enemy death, player death, keyboard restart, and a full 60-second victory run

Windows execution is not claimed on Ubuntu; only cross-platform export is
verified here. Long-session performance measurements remain a later milestone.
