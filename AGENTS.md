# Agent guide

## Environment

- Engine: Godot 4.6.3 stable
- Language: typed GDScript only; do not introduce C#
- Run: `godot4 --path .`
- Tests: `./scripts/validate.sh`
- Linux export: `godot4 --headless --path . --export-release Linux`
- Windows export: `godot4 --headless --path . --export-release Windows`

## Structure

- `scenes/`: composition roots
- `src/core/`: game flow and persistent state
- `src/player/`, `src/enemies/`, `src/combat/`: runtime actors
- `src/world/`: arena and future generation
- `src/ui/`: menus and HUD
- `src/effects/`: disposable feedback effects and audio synthesis
- `tests/`: headless logic and smoke tests
- `assets/generated/`: original generated assets only

## Rules

- Prefer small scenes, typed scripts, signals, Resources, and composition
- Damage rules must not depend on visual effects
- Never scan the entire scene tree every frame
- Runtime entities must have bounded lifetimes
- Do not add networking before milestone 9 is complete
- Do not commit `.godot/`, exported builds, credentials, or absolute host paths
- Keep the GL Compatibility renderer unless a measured requirement changes it
- After every change run project import, headless smoke, logic tests, and export checks

