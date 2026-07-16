# Architecture

The game uses a small scene composition root and typed actor scripts. `GameState`
is the only initial Autoload and stores cross-scene run statistics. Combat rules
are static, deterministic functions separated from meshes, particles, audio, and
camera feedback.

Milestones 1-3 use a fixed arena. Later procedural rooms will replace only the
world provider while preserving player, enemy, combat, and UI interfaces.

Combat content is data-driven through `WeaponData`, `SkillData`, and
`StatusEffectData` resources. Runtime systems consume these resources without
weapon-specific damage branches, keeping damage and status behavior shared.
