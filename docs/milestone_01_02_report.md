# Milestone 1-2 Report

Date: 2026-07-16

## Delivered

- Standalone Godot 4.6.3 project with GL Compatibility rendering
- Original low-poly industrial-wasteland arena and generated application icon
- Main menu and one-minute combat loop requiring eight kills and survival
- Keyboard movement, mouse aim/fire, dash, health, contact damage, enemy spawning,
  victory, defeat, pause, restart, and return-to-menu flow
- Procedural gun, dash, and hit audio plus impact flashes and camera shake
- Linux and Windows release export presets
- Headless validation covering logic, scenes, lifecycle, and result transitions

## Verification

```bash
./scripts/validate.sh
godot4 --headless --path . --export-release Linux
godot4 --headless --path . --export-release Windows
./builds/linux/WastelandProtocol.x86_64 --headless --quit-after 120
```

The validation suite passes 47 checks. The Linux release starts successfully.
The Windows release is generated as a PE32+ x86-64 GUI executable; execution on
Windows remains a target-machine check.

Windowed verification confirmed actual projectile kills (`SCRAP 003`), physical
debris collision, the death result, and keyboard-focused restart. Victory now
requires surviving 60 seconds with at least eight kills; timer-only avoidance is
explicitly rejected as `SECTOR OVERRUN`.

## Generated files

- `builds/linux/WastelandProtocol.x86_64`
- `builds/linux/WastelandProtocol.pck`
- `builds/windows/WastelandProtocol.exe`
- `builds/windows/WastelandProtocol.pck`
- `tests/latest_report.txt`

Build outputs are local artifacts and are not committed to Git. Each executable
must remain beside its platform's `.pck` file.

## Known limits

- Milestones 3-9 are not implemented
- Only one weapon and one enemy type exist
- The arena is fixed and the run has no upgrade choices or persistence
- Controller bindings exist but controller feel has not been tested on hardware
- Performance and soak tests are not yet measured

## Next risk

Milestone 3 should make weapons, projectiles, enemies, and upgrade choices
data-driven before adding more content. Expanding content first would duplicate
combat logic and make later balancing and automated tests substantially harder.
