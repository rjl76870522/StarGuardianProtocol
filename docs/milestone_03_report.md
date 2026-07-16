# Milestone 3 Report

## Completed Scope

- Three data-driven weapons: automatic rifle, scatter cannon, and rail lance
- Weapon switching with keys 1, 2, and 3 plus HUD icon and name feedback
- Critical hits, projectile spread, penetration, ricochet, recoil, range, VFX,
  and synthesized SFX configuration
- Six stackable three-level skills: rapid fire, movement, ricochet,
  penetration, kill healing, and orbit drones
- Three-choice upgrade pause every two kills with max-level exclusion
- Shared burn, freeze, slow, and knockback status-effect controller
- Continuous projectile sweep retained to prevent high-speed tunneling

## Verification

The validation suite passes 99 checks. It covers valid and invalid resource
configuration, deterministic critical damage, fire-rate limiting, physical
penetration through two enemies, status ticking and expiry, skill stacking,
three-choice upgrade flow, cleanup, and round results.

Godot 4.6.3 imports the project and boots the main scene without script errors.
The three weapon slots were also switched during a live debug run.

## Next Risks

- Status effects need stronger enemy-facing visual feedback
- Weapon balance needs longer play sessions and telemetry
- Milestone 4 should add enemy variety before increasing arena complexity
- Controller navigation and broader display-size checks remain future work
