# Wasteland Protocol

《机械废土：最后防线》是使用 Godot 4 和 GDScript 制作的低多边形
2.5D俯视角动作 Roguelite

## Development status

- Milestone 1: complete
- Milestone 2: complete
- Milestones 3-9: pending

The current vertical slice includes a menu, one-minute industrial arena,
top-down movement and mouse aim, rapid fire, dash, one chasing enemy type,
health, spawning pressure, pause/restart, victory/defeat results, synthesized
sound, impact feedback, and camera shake.

Victory requires both surviving the full minute and destroying at least eight
hostiles. Avoiding combat until the timer expires results in `SECTOR OVERRUN`.

## Requirements

- Godot 4.6.3 stable
- Linux or Windows desktop

## Run

```bash
godot4 --path .
```

Headless validation:

```bash
./scripts/validate.sh
```

Release exports:

```bash
godot4 --headless --path . --export-release Linux
godot4 --headless --path . --export-release Windows
```

Outputs are written to `builds/linux/` and `builds/windows/`. Exported builds
are intentionally ignored by Git and must be regenerated locally. Keep each
platform's executable and `WastelandProtocol.pck` together when distributing.

## Controls

- `WASD` or arrow keys: move
- Mouse: aim
- Left mouse: fire
- `Space`: dash
- `Esc`: pause

All visuals and sounds are generated from project-owned geometry, SVG, shaders,
and synthesized waveforms. No third-party art assets are included.

See `docs/milestone_01_02_report.md` for the verified scope and next risks.
