# Wasteland Protocol

《机械废土：最后防线》是使用 Godot 4 和 GDScript 制作的低多边形
2.5D俯视角动作 Roguelite

## Development status

- Milestone 1: complete
- Milestone 2: complete
- Milestone 3: complete
- Milestone 4: complete
- Campaign systems: in progress
- Milestones 5-9: pending

The current vertical slice includes a Chinese interface, one-minute industrial
arena, three reward weapons, nine five-level upgrade paths, five normal enemy
archetypes, two elite variants, and a three-phase mechanical boss.

Campaign progress is saved automatically after stage advancement, skill
upgrades, and weapon rewards. `Continue Campaign` restores the current stage,
campaign seed, skill levels, weapon unlocks, and weapon levels. Resuming starts
the current stage from its beginning rather than restoring enemies mid-combat.

Each stage deterministically changes the arena palette, floor grid, and physical
obstacle layout. Enemy health, damage, spawn pressure, and objective quota rise
with the stage. Clearing a stage opens a choice of weapon unlocks or permanent
weapon upgrades before the next arena loads.

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
- `1`, `2`, `3`: switch weapon
- `F3`: toggle Boss debug panel
- `F4`: spawn Boss immediately in debug runs
- `F2`: open an upgrade offer in debug runs

All visuals and sounds are generated from project-owned geometry, SVG, shaders,
and synthesized waveforms. No third-party art assets are included.

See `docs/milestone_04_report.md` for the current verified scope and next risks.
