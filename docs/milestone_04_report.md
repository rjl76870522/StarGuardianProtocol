# Milestone 4 Report

## Completed Scope

- Chinese player-facing menu, HUD, upgrades, weapons, skills, and results
- Five normal enemy archetypes: chaser, shooter, bomber, heavy, and repair unit
- Two behavior-changing elites: teleport-on-hit hunter and radial-hazard heavy
- Shared finite state machine with spawn, idle, search, chase, attack,
  controlled, hurt, and death states
- Staggered decision updates, local physics avoidance, and stuck-direction
  recovery for unreachable or obstructed targets
- Three-phase mechanical Boss driven by phase resources
- Directed fire, charge, summon, radial barrage, ground hazard, laser sweep,
  shockwave, and enrage-speed behavior
- Boss health HUD and F3 debug panel for health, phase, state, cooldowns, reset
- F4 development shortcut for immediate Boss spawning
- Persistent stage progression with a victory-only next-stage action
- Carried skill levels, explicit maximum-level filtering, and clearer upgrade cards
- In-HUD controls for Space dodge and 1/2/3 weapon switching

## Verification

The full suite passes 137 checks. New coverage validates all enemy resources,
five archetypes, two elite behavior flags, finite-state transitions, freeze
control, repair behavior, three Boss phase resources, health thresholds, and
debug controls.

Windowed checks confirmed Chinese glyph rendering, combat HUD layout, distinct
enemy colors, Boss spawning, Boss health display, and the debug panel.

## Known Limits

- Navigation currently uses staggered direct steering, physics collision, and
  stuck recovery rather than a baked navigation mesh
- Enemy and Boss numerical balance needs longer human play sessions
- The fixed arena remains intentionally unchanged until milestone 5

## Next Stage

Milestone 5 will replace the fixed-run structure with deterministic room-graph
generation, room progression, rewards, shops, elite rooms, and a Boss room.
