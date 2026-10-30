# HANDOFF

Run: first cloud run ("night 1"). Code only, no Studio.

## The design guide was missing
`WRAITHSTEEL_AGENT_GUIDE.md` is not in the repository (checked `main` and all branches). This
run built from the task brief. Everything that the brief said was "exact §8.3" or "§8.2 rule N"
is a **best reconstruction** - please add the guide and reconcile:
- `src/shared/Types.luau` (ProfileData, SpiritInstance, OddsEntry/Result, Combat types)
- `src/shared/NetSchema.luau` (remote names + argument types)
- Service/controller list and APIs (each module's header comment lists its API)
- Phase list in `PROGRESS.md`

## Architecture as built
```
ReplicatedStorage
  Shared/   Net, NetSchema, NetValidate, RateLimiter, Types, Signal, FormatNumber, Odds,
            LanternOdds, ProgressionMath, Time
  Config/   Economy, Monetization, Spirit, Lantern, Combat, Weapon, Enemy, Boss, Chapter,
            Reward, Input
ServerScriptService
  Bootstrap (Script)       loads Services by Priority: Init all, then Start all
  Services/                Data(0) Policy(1) Analytics(2) Market(3) Progression(4) Quest(10)
                           Reward(11) Code(12) Spirit(20) Lantern(21) Fusion(22) Combat(23)
                           Enemy(30) Boss(31) Chapter(40) Party/Trade/Expedition/WorldBoss/
                           Raid/Zone (50+, stubs)
  Logic/                   pure, unit-tested rules: ProfileTemplate, Migrations, ReceiptLedger,
                           SpiritLogic, LanternRoll, RewardLogic, CombatRules, Posture,
                           AttackDirector, AIScheduler, BossStateMachine
  ServerConfig/CodeConfig  server-only (codes)
  Packages/ProfileStore    vendored, Apache-2.0
StarterPlayer.StarterPlayerScripts
  ClientBootstrap (LocalScript)
  Controllers/             Data(0) Input(10) Combat(20) Lantern(30) Notification(40) HUD(41)
                           + UI stubs (Spirit, Shop, Quest, Dialogue, Camera, Audio)
```
Dependency direction (no cycles): Data -> Analytics -> Market -> Progression -> Quest ->
Reward/Code/Spirit -> Lantern/Fusion/Combat -> Enemy/Boss -> Chapter.

## Rules implemented the way I read them
- **ProcessReceipt (rule 6):** see `Logic/ReceiptLedger.luau` header. Unknown product/player
  not present/profile not loaded/grant failed/save not confirmed -> `NotProcessedYet`.
  Already-recorded PurchaseId -> no re-grant. `PurchaseGranted` only after a save containing
  the PurchaseId (`DataService.SaveAndWait`).
- **Server validation (rule 3):** clients send `{action, seq}` only. `Logic/CombatRules`
  validates; `CombatService` does hit detection from server positions.
- **Odds:** `Shared/Odds.Compute` is used by `LanternOdds.Sheet` (UI) and `Odds.Roll` (server).
  Luck changes weights (`luckAffinity` per rarity/mutation) and is included in the displayed
  odds. Mutation odds and pity rules are displayed too.
- **Policy:** paid lanterns (`paid = true`, Jade) refused server-side when
  `ArePaidRandomItemsRestricted`; client hides them. Trading checks `IsPaidItemTradingAllowed`.
  Policy load failure = restrictive.

## Things for Studio agents
- See README "What you need to build in Studio" and `AssetLog.md`.
- Enemy spawns: `Workspace.EnemySpawns/<Part>` (attrs `EnemyId`, `Count`, `RespawnSeconds`).
- Boss arenas: `Workspace.BossArenas/<Part>` (attr `BossId`).
- Rigs: `ServerStorage.Enemies/<id>`, `ServerStorage.Bosses/<id>` (Humanoid + HumanoidRootPart).
- HUD/Toasts are code-built placeholders (`HUDController`, `NotificationController`).
- Lantern UI must call `LanternController.FetchOdds` -> render `FormatOdds` ->
  `MarkOddsShown` before enabling the Open button.

## Open questions for the designer
- Is Ember purchasable? (Assumed **no**; only Jade is sold, so only Jade lanterns are "paid".)
- Exact chapter/boss names: ChapterConfig uses original placeholders for 20 of 21 bosses.
- Should equipped Spirits be fusable (auto-unequip)? Currently must unequip first.
