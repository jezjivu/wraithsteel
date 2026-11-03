# AssetLog

Every asset the code references. `0` / `rbxassetid://0` = placeholder; the code skips or uses
a grey block for these. When you upload an asset, replace the id in the listed file and fill in
the row. Only original assets (made by us or licensed for this game) may be used.

| What | File / key | Current id | Needed | Owner | Notes |
|---|---|---|---|---|---|
| Game passes (5) | `src/config/MonetizationConfig.luau` Passes.*.id | 0 | Create on Creator Dashboard | A | Ember Furnace, Ninefold Charm, Spirit Shrine, Lantern Festival, Long Road |
| Dev products (8) | `src/config/MonetizationConfig.luau` Products.*.id | 0 | Create on Creator Dashboard | A | 3 Jade packs, 2 boosts, 3 gift products |
| Weapon models (16) | built from parts by `Shared/WeaponModels` (`WeaponConfig.*.visual`) | n/a (procedural) | Optional sculpted models -> `modelId` | B | Works today without uploads |
| Weapon icons (16) | `assets/weapon_icons/*.png` (rendered by `tools/render_weapons.py`) | not uploaded | Upload as Images if wanted | D | UI currently uses live 3D viewports |
| Class move animations (6 classes, ~45 moves) | `WeaponConfig.Moves.*.animationId` | rbxassetid://0 | Animate + upload | B | Jian, Dao, Spear, Fan, Staff, Greatblade |
| Spirit models + icons (10) | built from parts by `Shared/SpiritModels` (`SpiritConfig.*.visual`); PNGs in `assets/spirit_icons` | procedural | Optional sculpted models -> modelId | B/D | Works today without uploads |
| Enemy/boss rigs | built by `World/RigBuilder` from `look` in EnemyConfig/BossConfig | procedural R15 | Optional Studio rigs in ServerStorage.Enemies/Bosses | C | Studio rigs take priority |
| Lantern models (3) | `src/config/LanternConfig.luau` Lanterns.*.modelId | 0 | Model | D | |
| Rustbound Bandit rig + 2 anims | `ServerStorage.Enemies.rustbound_bandit`, `EnemyConfig` attacks | placeholder block / 0 | Rig + anims | C | |
| Lantern Ghoul rig + 2 anims | `ServerStorage.Enemies.lantern_ghoul`, `EnemyConfig` attacks | placeholder block / 0 | Rig + anims | C | |
| Rust Tiger rig + 6 anims | `ServerStorage.Bosses.rust_tiger`, `BossConfig` moves | placeholder block / 0 | Rig + anims | C | Root-motion pounce/charge |
| Combat SFX / music | `src/config/EffectsConfig.luau` Sounds | built-in rbxasset://sounds/swordslash.wav, swordlunge.wav | Original SFX + music | D | parry clang, posture break, bell toll |
| Hollow Carillon rig + anims | `ServerStorage.Bosses.hollow_carillon`, `BossConfig` moves | placeholder block / 0 | Rig + anims | C | World boss |
| Touch button images | InputController (TODO) | none | Icons | D | |
| Hub town build | `Workspace.Hub` (generated blockout until built) | procedural | Real build with Station attributes | D | See HubConfig |
| Training dummy rig | `ServerStorage.Enemies.training_dummy` | placeholder block | Rig | C | |
| Night Market stall | Part/Model with attribute `Station = "NightMarket"` | none (menu only) | Build in the hub | D | Night 2 |
| Raid arena | `Workspace.RaidArena` (Part; boss spawns on it) | none (spawns ahead of first player) | Build | C/D | Night 2 |
| Kurozuma (raid boss) rig + 9 anims | `ServerStorage.Bosses.kurozuma`, `BossConfig.kurozuma` moves | procedural rig (RigBuilder `look`) / 0 | Sculpted rig + anims | C | Night 3 (config done) |
| Raid gate prop | hub (opens the Raid panel) | none (menu "Raids") | Build | D | Night 2 |
| Tidewater Lantern model | `LanternConfig.tidewater_lantern.modelId` | 0 | Model | D | Night 3 |
| Tidewater Spirits (5) | built from parts (`SpiritConfig.*.visual`); icons in `assets/spirit_icons` | procedural | Optional sculpted models | B/D | Night 3 |
| UI icons | frame-built geometric icons (`Kit.Icon`) | n/a | Optional uploaded icon set | D | Night 3 |
