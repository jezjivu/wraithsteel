# WRAITHSTEEL: Bell of Nine Gates

An original Roblox story action RPG: wuxia parry/posture sword combat, a Prologue and five
chapters (21 bosses), 4-player co-op, world bosses, an 8-player raid, and collectible Spirits
hatched from Spirit Lanterns. Design spec: `WRAITHSTEEL_AGENT_GUIDE.md` (see note in HANDOFF.md).

All game code lives in this repo as Luau files and is synced into Roblox Studio with **Rojo**.

## Getting the code into Roblox Studio

You do this once per computer, then every time you want the latest code.

1. **Install Rojo**
   - Install the Rojo CLI: download `rojo` from https://github.com/rojo-rbx/rojo/releases
     (or `aftman add rojo-rbx/rojo` / `rokit add rojo-rbx/rojo` if you use a toolchain manager).
   - In Roblox Studio, install the **Rojo** plugin (Plugins tab -> search "Rojo" by
     rojo-rbx, or `rojo plugin install`).
2. **Get the code**: clone this repository (or download it as a ZIP and unzip it).
3. **Start the Rojo server** in the repo folder:
   ```bash
   rojo serve
   ```
   Leave this window open. It prints `Rojo server listening on port 34872`.
4. **Connect from Studio**: open your place, Plugins tab -> **Rojo** -> **Connect**.
   The code appears in:
   - `ReplicatedStorage.Shared` (from `src/shared`) and `ReplicatedStorage.Config` (`src/config`)
   - `ServerScriptService` (`src/server`: `Bootstrap`, `Services`, `Logic`, `Packages`, `ServerConfig`)
   - `StarterPlayer.StarterPlayerScripts` (`src/client`: `ClientBootstrap`, `Controllers`)
5. **Enable data saving in Studio** (optional): Game Settings -> Security ->
   "Enable Studio Access to API Services". Without it, saves use a temporary mock store.
6. Press **Play**. The output should show `[Bootstrap] N services started`.

Rojo only manages the folders above. Maps, models, UI and anything else you build in Studio are
not touched by Rojo - save the place file as usual.

### What you need to build in Studio for a first playtest

- `Workspace.EnemySpawns` folder with Parts; give each Part attributes `EnemyId`
  (`rustbound_bandit` or `lantern_ghoul`), `Count` (number) and `RespawnSeconds` (number).
- `Workspace.BossArenas` folder with a Part that has attribute `BossId = "rust_tiger"`.
  Walk up to it and hold the "Challenge" prompt.
- Without rigs, enemies and the boss appear as plain blocks. Put real rigs in
  `ServerStorage.Enemies/<enemyId>` and `ServerStorage.Bosses/<bossId>`.

Controls: Left click = strike, R = heavy, F = parry, Q = dodge, 1/2 = skills, G = ultimate.
E = use a hub station, H = controls card. Attacks auto-aim at the nearest enemy in front of you. Menu buttons (bottom-left): Spirits, Weapons, Quests, Expeditions, Store, Party, Trade, Codes.

The hub town (Ninefold Crossing) is generated automatically if `Workspace.Hub` does not exist.

## Quick playtest without Rojo

`rojo build playtest.project.json -o Wraithsteel-Playtest.rbxl` makes a place file with all code
and nothing else: on Play the server generates the Japanese-inspired world (MapService), the hub
town (HubService), enemy spawns and boss shrines. To use your own map instead, create
`Workspace.World` (or set Workspace attribute `UseStudioMap = true`) plus `EnemySpawns`/`BossArenas`. Open it in Studio and press Play.
Studio-only chat commands: `/ember 1000`, `/odds paper_lantern`, `/open paper_lantern`,
`/spirits`, `/equipall`, `/daily`, `/stats`, `/worldboss`, `/chapter 1` (DebugService; disabled in live servers).
Preview tools (no Studio): `python3 tools/render_weapons.py <luau>`, `python3 tools/render_spirits.py <luau>`, `python3 tools/render_hub.py <luau>`, `python3 tools/render_map.py <luau>`.

## For developers / agents

- Read `CLAUDE.md` (standing rules) and `PROGRESS.md` (what is done / next).
- Type-check + unit tests (no Studio needed):
  ```bash
  TOOLS=/path/to/tools ./tools/check.sh
  ```
  needs `luau-lsp`, the `luau` CLI and luau-lsp's Roblox `globalTypes.d.luau` in `$TOOLS`.
  Tests only: `python3 tools/run_tests.py path/to/luau`.
- Third-party code: `src/server/Packages/ProfileStore.luau` (MadStudio, Apache-2.0,
  license in `vendor-licenses/`).
