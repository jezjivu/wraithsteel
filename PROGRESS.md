# PROGRESS

> **Important:** `WRAITHSTEEL_AGENT_GUIDE.md` was **not in the repository** during the first cloud
> run (only a one-line README existed on `main`). The phase list below is reconstructed from the
> task brief (prologue + 5 chapters, 21 bosses, parry/posture combat, 4-player co-op, world
> bosses, 8-player raid, Spirits/Lanterns/mutations/fusion, expeditions/offline, trading,
> passes/products, compliance). **Next run: add the guide, then reconcile this checklist and
> the contracts in `HANDOFF.md` with guide §8.3 / §11.**

Legend: [x] done in code · [~] code done, needs Studio work/playtest · [ ] not started

## Phase 0 - Foundation (Agent A)
- [x] Rojo project (`default.project.json`), lint/format config, README sync guide
- [x] CLAUDE.md, PROGRESS.md, HANDOFF.md, AssetLog.md
- [x] `Shared/Net` remote creation from `NetSchema` + type checks (`NetValidate`) + per-player rate limits (`RateLimiter`)
- [x] `Shared/Types` (reconstructed §8.3 contracts)
- [x] `Shared/Signal`, `FormatNumber`, `Odds` (luck-aware, sums to exactly 100%), `Time`
- [x] Server `Bootstrap` with ordered Init()/Start(); client `ClientBootstrap` with same pattern
- [x] Modules for every planned service/controller (real or documented stub)
- [x] DataService on vendored ProfileStore (session lock, autosave, BindToClose) + template + `dataVersion` migrations
- [x] PolicyService (cached, restrictive fallback)
- [x] AnalyticsService (onboarding funnel once per profile, economy + custom events)
- [x] ProgressionService (Ember, Jade, XP/levels, Power with chapter caps, multipliers)
- [x] MarketService (idempotent ProcessReceipt, pass cache, gifted passes incl. offline via profile messages, boosts, gift tokens)
- [x] Pure-Luau test harness + specs (`tools/run_tests.py`, 48 tests) and luau-lsp type check (`tools/check.sh`)
- [ ] Create passes/products on the Creator Dashboard and fill ids (MonetizationConfig)

## Phase 1 - Prologue vertical slice
### B - Bladesmith (combat + Spirits)
- [x] CombatConfig, WeaponConfig (Wanderer's Jian: 4-hit combo, heavy, 2 skills, ultimate)
- [x] CombatRules: server validation (seq, rate, stun, busy, dodge-cancel, cooldowns, combo, ultimate charge)
- [x] Parry window / block / dodge i-frames / perilous attacks; posture + posture break
- [x] CombatService: server-side hit detection + damage, parry reflect, spirit passives
- [x] InputController action mapping (KB/M, gamepad, touch) + CombatController requests with input buffer
- [~] Jian animations, VFX, SFX, hit-stop, lock-on camera (Studio)
- [x] SpiritConfig (10 Spirits for Prologue/Ch1, 6 rarities, 6 mutations), LanternConfig (3 lanterns)
- [x] SpiritService, LanternService (server RNG via Odds, pity, policy gating), FusionService (deterministic)
- [x] LanternController odds formatting + "odds shown before open" guard
- [~] Lantern/odds/inventory/fusion UI (Studio)
- [ ] Spirit followers in the world (models + follow AI)
- [ ] SpiritCall action (currently rejected as "Unavailable")
### C - Warden (enemies + bosses)
- [x] Combatant registry (CombatService), batched staggered 10 Hz AI scheduler, attack-token director
- [x] EnemyConfig: Rustbound Bandit, Lantern Ghoul; EnemyService spawning/AI/rewards
- [x] BossConfig + BossStateMachine; Rust Tiger (2 phases, 6 moves, perilous moves, co-op HP scaling)
- [x] BossService encounters (arena prompt, telegraphs, multi-hit, phase transitions, first-clear Jade)
- [~] Rigs + animations for both mobs and Rust Tiger (Studio); spawns/arena placement
### D - Artisan (world/story/UI)
- [x] ChapterConfig (Prologue + 5 chapters, 21 boss ids), ChapterService chapter advance
- [~] Debug HUD + toasts (placeholder) - real HUD, menus, dialogue, cutscenes (Studio)
- [ ] Prologue map, zone gates, story beats (StoryAdvance validation)
### A - Architect
- [x] RewardService (daily streak, playtime gifts, offline earnings)
- [x] QuestService (deterministic daily quests + story quests)
- [x] CodeService (server-only code table)

## Phase 2 - Chapter 1 + depth
- [x] BossConfig entries for the 4 Chapter 1 bosses (Hollow Abbot, Twin Cinder Sisters, Rustwood Matriarch, Gatekeeper of Rust - 3 phases)
- [x] Chapter 1 enemies: Rustwood Stalker, Rust-Eaten Sentinel
- [~] Rigs/animations for the Chapter 1 roster; Twin Cinder Sisters as two bodies (currently one combatant)
- [x] ExpeditionService + ExpeditionConfig (3 routes, 2 slots + 1 with Long Road pass, deterministic Ember + Spirit XP)
- [x] Spirit leveling (Spirit XP from expeditions, `SpiritConfig.XpToNext`, level cap 50); away Spirits locked from equip/fuse/release
- [~] Expedition board UI (Studio)
- [ ] More Spirit passives
- [ ] More weapons (Dao/Spear/Fan classes reserved in WeaponConfig types)

## Phase 3 - Co-op + world bosses + Chapters 2-3
- [ ] PartyService (stub) - 4-player parties, party Ember bonus
- [ ] WorldBossService (stub)
- [ ] ZoneService (stub) zone tracking + gates
- [ ] Chapters 2-3 content

## Phase 4 - Raid + trading + Chapters 4-5
- [ ] RaidService (stub) - 8-player reserved-server raid
- [ ] TradeService (stub, already policy-checked) - two-step confirm, atomic swap
- [ ] Chapters 4-5 content, final boss

## Phase 5 - Launch polish / LiveOps
- [ ] Anti-exploit telemetry from `Net.Rejected` (currently only a signal)
- [ ] Balance pass, economy sinks, events

## Playtesting
- `rojo build playtest.project.json -o Wraithsteel-Playtest.rbxl` -> open in Studio -> Play.
  Test map: bandits, ghouls, Rustwood stalkers, a sentinel, Rust Tiger + Hollow Abbot arenas.
  Studio-only chat commands via DebugService (`/ember`, `/odds`, `/open`, `/spirits`, `/equipall`, `/daily`, `/stats`).

## Next up (for the next run)
1. Add `WRAITHSTEEL_AGENT_GUIDE.md` to the repo and reconcile `Shared/Types`, `NetSchema`,
   service APIs and this checklist with §8.3/§11.
2. Studio session: build EnemySpawns + BossArenas in a test place, playtest combat timings.
3. Feedback from the first Studio playtest (combat timings, enemy movement on placeholder rigs).
4. Phase 3 code: PartyService (4-player parties, party bonus), WorldBossService, ZoneService.

## Known risks
- **Contracts are reconstructed**, not copied from the guide - expect renames when reconciling.
- **Nothing has run inside Roblox yet.** Code is type-checked with luau-lsp against Roblox
  definitions and pure logic is unit-tested, but engine behaviour (Humanoid movement of
  placeholder rigs, ProfileStore in Studio mock mode, remote timing) is unverified.
- Player dodge movement is client-driven; the server only grants i-frames. Add server-side
  position sanity checks before launch.
- Enemy/boss hit timing uses `task.delay(windup)`; once real animations exist, align windups
  with animation events.
- MarketService gift delivery to offline players relies on ProfileStore `MessageAsync`.
- `selene.toml` needs a Roblox std generated (`selene generate-roblox-std`), which could not be
  downloaded in the cloud sandbox; luau-lsp is used instead.
