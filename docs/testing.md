# Testing

`scripts/validate.sh` performs project import, script/resource parsing, logic
tests, scene smoke tests, and export preset checks. Reports are written to
`tests/latest_report.txt` only after commands have actually run.

Interactive controls and visual presentation still require a windowed smoke run.
Performance claims must include measured Godot monitor output; none are inferred.

## Verified baseline

- Godot 4.6.3 project import and script/resource parsing
- 137 logic and scene checks, including projectile sweep collision, physical
  debris blocking, weapon resources, critical hits, fire-rate limits,
  penetration, status duration, skill stacking, upgrades, enemy states,
  repair behavior, elite definitions, Boss phases, and result transitions
- Three consecutive game-scene create/free cycles
- Main scene headless boot
- Linux release export and exported-binary boot
- Windows x86-64 release export and executable format inspection
- Windowed menu, combat HUD, objective layout, movement, firing, dash, damage,
  enemy death with increasing `SCRAP`, player death, and keyboard restart

Windows execution is not claimed on Ubuntu; only cross-platform export is
verified here. Long-session performance measurements remain a later milestone.
