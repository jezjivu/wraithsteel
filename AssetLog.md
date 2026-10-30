# AssetLog

Every asset the code references. `0` / `rbxassetid://0` = placeholder; the code skips or uses
a grey block for these. When you upload an asset, replace the id in the listed file and fill in
the row. Only original assets (made by us or licensed for this game) may be used.

| What | File / key | Current id | Needed | Owner | Notes |
|---|---|---|---|---|---|
| Game passes (5) | `src/config/MonetizationConfig.luau` Passes.*.id | 0 | Create on Creator Dashboard | A | Ember Furnace, Ninefold Charm, Spirit Shrine, Lantern Festival, Long Road |
| Dev products (8) | `src/config/MonetizationConfig.luau` Products.*.id | 0 | Create on Creator Dashboard | A | 3 Jade packs, 2 boosts, 3 gift products |
| Jian move animations (8) | `src/config/WeaponConfig.luau` Moves.*.animationId | rbxassetid://0 | Animate + upload | B | Add a "Hit" animation event at start of active frames |
| Wanderer's Jian model | `WeaponConfig.Weapons.jian_wanderer.modelId` | 0 | Model | B | |
| Spirit models + icons (10) | `src/config/SpiritConfig.luau` Spirits.*.modelId / iconId | 0 | Model + icon | B/D | |
| Lantern models (3) | `src/config/LanternConfig.luau` Lanterns.*.modelId | 0 | Model | D | |
| Rustbound Bandit rig + 2 anims | `ServerStorage.Enemies.rustbound_bandit`, `EnemyConfig` attacks | placeholder block / 0 | Rig + anims | C | |
| Lantern Ghoul rig + 2 anims | `ServerStorage.Enemies.lantern_ghoul`, `EnemyConfig` attacks | placeholder block / 0 | Rig + anims | C | |
| Rust Tiger rig + 6 anims | `ServerStorage.Bosses.rust_tiger`, `BossConfig` moves | placeholder block / 0 | Rig + anims | C | Root-motion pounce/charge |
| Combat SFX / music | AudioController (stub) | none | Sounds | D | parry clang, posture break, bell toll |
| Touch button images | InputController (TODO) | none | Icons | D | |
