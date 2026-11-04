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

## Hub, weapons and UI (added on request)
- `HubService` builds a blockout hub only when `Workspace.Hub` is missing. A Studio hub just needs
  parts with attribute `Station` (WeaponSmith, LanternShrine (+LanternId), SpiritShrine,
  ExpeditionBoard, QuestBoard, Store, CodeStone); prompts are added automatically.
- Weapons: `WeaponConfig.ClassMoves` gives each class its moveset; weapons add stats/price/look.
  `Shared/WeaponModels` builds models from `visual`; `tools/render_weapons.py` renders icons.
- UI: `src/client/UI/Kit` + `UI/Panels/*` (contract in `UI/PanelTypes`), driven by
  `UIController`. Restyle freely; keep the Lantern panel's "odds before Open" order.
- Open question: Jade-priced weapons (Ninth-Bell Jian, Skypiercer) are fixed-price, not random,
  but are slightly stronger than Ember weapons of the same chapter (Power is still capped per
  chapter). Confirm this is acceptable or make them cosmetic-equal.

## Playability systems (part 3)
- Rig priority for enemies/bosses: `ServerStorage.Enemies|Bosses/<id>` > RigBuilder (config `look`) > block placeholder.
- AnimationController owns NPC joints (absolute) and layers onto player joints; uploaded
  animationIds on moves replace procedural poses for players.
- Companions: `SpiritParty` player attribute -> SpiritFollowerController (client-only parts).
- Guide: objective chain in GuideController/GuideConfig; extend when chapters grow.

## World generation (part 4)
- Service order: Ambience(5) -> Map(27) -> Hub(29) -> Enemy(30) -> Boss(31). MapService builds
  terrain/props/spawns first, HubService raycasts the ground and builds on it.
- Replace generated content by adding `Workspace.World` / `Workspace.Hub` in Studio (then the
  generators skip) and keep `EnemySpawns`, `BossArenas`, `Station` attributes.
- Enemy behaviour knobs live in EnemyConfig (combos, comboChance, lunge, flinch, guardChance).

## Spirits & Qi arts (part 7)
- `Shared/SpiritStats` is the single source for Spirit stat numbers (UI + server). Totals are capped per stat (`SpiritConfig.StatInfo`).
- `SpiritAbilityService` (priority 31) auto-casts companion abilities every 0.25 s while the owner is in combat and handles SpiritCall (T) via `CombatService.OnSpiritCall`. Events: `CombatEvent` kinds `SpiritCast`, `SpiritBurst`, `BurstCooldown`.
- `SpellService` (priority 32) + `Logic/SpellLogic` (tested). Remotes `CastSpell(spellId, aim?, point?)`, `SetSpellSlot(slot, spellId)`. Qi lives server-side, mirrored as character attributes `Qi`/`QiMax`. Events: `Spell`, `SpellRejected`.
- `CombatService.Hit` gained `crit`, `source`, `color`; combatants gained `shield`/`shieldUntil` (attribute `Shield` = fraction of max HP). New helpers: `PlayerStats`, `RollCrit`, `Heal`, `AddShield`, `ClearStatCache`.
- Profile v3: `spellLoadout` (migration 3). Spirit `passive`/`Passives` were replaced by `stats` + `ability` (SpiritConfig is config, not a frozen type).
- AnimationController now poses joints through `Motor6D.C0 = baseC0 * offset` (base saved in attribute `BaseC0` on each motor).
- `ServerScriptService.EditTools`: BuildWorld()/ClearWorld() for edit mode; Map/Hub/Ambience services expose `Build()`/`Apply()`; generated containers carry attribute `Generated = true`.

## Posture combat (part 8)
- CombatRules: `GuardRelease` action, hold-to-guard (`GuardMaxHold`), `ResolveIncoming(state, hit, now, ctx?)` with outcomes `Countered` / `Jumped` / `Deflected`; `IsGuarding`.
- CombatService: Hit gains `perilousKind`, `severing`; combatants gain `dodgeAt/dodgeDir` (from the Dodge request's `move` vector), `deflectChance`, `canDeflect`; signal `Deflected(enemy, attacker)`; model attribute `Broken`.
- EnemyConfig/BossConfig: `perilousKind`, `deflectChance` (`BossConfig.DefaultDeflect`).
- AnimationController poses joint anchors (`Motor6D.C0` or `AnimationConstraint.Attachment0.CFrame`, base saved as attribute `BaseAnchor`). If arms still do not move in Studio, check Output for `[AnimationController] no posable joints`.

## Animation tracks (part 9)
- `UI/AnimBuilder` builds KeyframeSequences from AnimationConfig poses and registers them with `KeyframeSequenceProvider:RegisterKeyframeSequence` (temporary ids, client-side). If registration fails it warns once and AnimationController falls back to joint-anchor posing.
- Known risk: temporary ids are meant for local testing; if they do not work in a published game, upload the generated sequences (or real animations) and set `animationId`s.

## Realms, story, waystones (part 10)
- RealmConfig (local coords per realm; Japan portal relative to the hub), RealmService (priority 29.5: after Hub, before Enemy/Boss so spawns + shrine pads exist when they start), builders in World/ (BuildKit, NeonBuilder, AeloriaBuilder). Player attribute `Realm`; client RealmAmbienceController applies LightingConfig.Realms.
- WaystoneService + WaystoneConfig; ReplicatedStorage.WaystoneDirectory lists waystones for the Travel panel (far models aren't streamed). Profile v4: `waystones`, `respawnWaystone`, `saga`.
- SagaConfig/SagaLogic (tested in tests/saga.spec.luau)/SagaService; ReplicatedStorage.NpcDirectory holds NPC positions; StoryEvent kinds `Dialogue`, `QuestStarted`, `QuestComplete`, `RealmEntered`.
- Stealth: EnemyConfig.Stealth; combatant `unaware` + model attribute `Unaware`; Hit `shadow`.
- Preview realms offline: `python3 tools/render_map.py <luau> build/neon.png neon` (or `greek`).

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

## Part 15 (this run): wide valley, outfits, skill tree, UI look, exploration
- **Valley layout** is now `MapConfig.Roads` (several polylines) instead of one `Route`
  (`MapConfig.Route` = `Roads[1]` kept for compatibility). A road segment whose two points have
  different `y` is a stone stair (ValleyBuilder.buildStair). Plateau zones (`y = 50`) are filled
  solid down to the valley floor.
- **Outfits** (`World/Outfits`): RigLook gained `outfit`, `mask`, `face` (all optional). Pieces are
  welded to limbs so they animate. Preview: `python3 tools/render_rigs.py <luau> build/rigs.png`.
- **Skill tree**: profile `skills` (v8). Points = `SkillLogic.PointsEarned(level)` + relics found.
  Skill stats are merged into `CombatService.PlayerStats` (same keys as spirit stats + new ones,
  listed in SkillConfig). `CombatService.RefreshStats(player)` re-applies max HP / flask.
  Arts tied to a skill (`SkillConfig.ArtSkill`) are checked in SpellLogic.CanCast/SetLoadout.
- **Exploration** (`ExplorationService` / `ExplorationController`, profile `shortcuts` + `relics`, v9):
  gates are server parts; opening is per player, so the client swings its own copy open and turns
  off collision (character physics is client-owned). Models use `ModelStreamingMode.Atomic`.
- **Grappling hook**: `GrappleController` (client only) pulls to parts tagged `GrapplePoint`
  (attribute `LandAt`). No server-side movement check (same risk as dashes).
- Open questions: gate leaf swing direction and grapple landing spots need a Studio look;
  Skills panel is laid out for >= 720 px wide windows (scrolls on small screens).

## Part 16
- **No bosses in the Ashen Valley.** BossConfig keeps only kagura_9 (Neon) and archon_helion
  (Aeloria). MapConfig.BossArenas = {}, WorldBossConfig.Rotation = {}. BossService destroys any
  shrine whose BossId no longer exists (older saved Studio worlds); WorldBossService removes
  Workspace.WorldBossSpawns when the rotation is empty. Migration v11 drops the old ids.
- Shadow Kunai: KunaiService / KunaiController, remote ThrowKunai(Vector3), character attribute
  `Kunai`, CombatService.Rested signal refills it.
- Sentries: EnemySpawns entries with `lookout = n` stand on that lookout platform (`Sentry` spawn
  attribute; EnemyService never walks them).
- Day/night: LightingConfig.DayNight, client-only, from workspace:GetServerTimeNow().

## Part 17
- Elites have `lives = 2` (EnemyConfig): CombatService.ApplyHit turns the first lethal blow into a
  "LifeLost" event (full heal, posture reset, short invulnerability). Model attribute `Lives`.
- Enemy alerts: spotting a player fires CombatEvent "Alert" and makes unaware allies within
  EnemyConfig.Alert.radius aware for a few seconds.
- Secrets: waterfall cave (MapConfig.WaterfallCave, relic with `absY`), rooftop hooks on intact
  village houses. Map panel (M) draws MapConfig; K opens Skills.

## Night 2 (cloud run, branch `claude/dreamy-fermi-wfrtop`, built on night 1's PR branch)
The guide is **still not in the repo**; this run followed the task brief + night 1 contracts.
- **Compliance fix (decide):** MonetizationConfig sells Ember (EmberSmall/EmberLarge/
  StarterBundle), which makes Ember lanterns *paid random items* under Roblox rules. Now
  `Shared/LanternOdds.IsPaid(lanternId)` = `paid` flag OR currency is Robux-purchasable (derived
  from the product list). LanternService refuses paid opens where PolicyService restricts paid
  random items (free opens still work); the client hides those lanterns unless the player has
  free opens. Alternative: remove the Ember products, then Ember lanterns are unpaid again
  automatically.
- **Spirit `paid` flag** (new optional `SpiritInstance.paid`): set when a Spirit is bought with
  currency from a paid lantern or the Night Market; fusion keeps it; trades carry it.
- **Trades:** `TradeLogic.New(a, b, allowPaid)`; `Validate` split from `Execute`. TradeService
  commits via `Logic/TradeLedger` (DataStore `TradeConfig.LedgerStoreName`, in-memory in Studio
  without API access). Keys: `t_<tradeId>` record, `u_<userId>` index. Profile `tradesApplied` /
  `tradeOrder` (v12, private). `DataService.AddLoadHook` runs recovery before the snapshot.
  `Logic/TradeLock` freezes Spirit-changing requests (Spirit/Fusion/Expedition services check it).
- **Night Market:** `NightMarketConfig` (items, weights, limits), `Shared/NightMarketLogic`
  (Stock(window), CanBuy), `Shared/SeededRandom` (mulberry32; never for paid rolls). Remotes
  `GetNightMarket()`, `BuyNightMarket(slot, window)`. Profile `nightMarket` (v13). Station kind
  `NightMarket` maps to the panel (stall itself is a Studio TODO); menu button "Market".
- **Raids:** `RaidConfig`, `Logic/RaidLogic`, `RaidService` (priority 54), remotes
  `RaidRequest(op, arg?)` / `RaidEvent`. Raid server = `PrivateServerId ~= ""` and
  `PrivateServerOwnerId == 0`; manifest from MemoryStore `RaidConfig.ManifestStore` keyed by
  PrivateServerId. Profile `raidClears` (v14). `BossService.StartEncounter(..., healthMultiplier?)`,
  `BossService.Fail(id)`, `BossService.EncounterEnded(id, bossId, victory, participants)`.
  Placeholder: the raid fights `archon_helion` until a raid boss exists.
- **Security:** `SecurityService` (priority 7), `Logic/ExploitScore`, server-only
  `ServerConfig/SecurityConfig`. Analytics custom events `SecurityFlag`, `SecurityKick`.
- Tooling used: luau 0.700 + luau-lsp 1.53.0 with the matching `globalTypes.None.d.luau` from
  the luau-lsp 1.53.0 tag (the defs on luau-lsp `main` need a newer luau-lsp).
- Not done from the brief: a separate GiftService - gifting already lives in MarketService
  (gift products, gift tokens, offline delivery via profile messages).

## Night 3 (UI pass + content, same branch)
- **Design tokens live only in `src/client/UI/Kit.luau`** (`Kit.Colors`, fonts, `Kit.Radius`).
  Button style follows the color passed: `C.Accent` = vermilion primary (use once per screen),
  `C.Row`/`C.Steel` = quiet, anything else = tinted. New components: `Seal`, `GateLine`,
  `Icon(kind)`, `Section`, `Chip`, `Progress`, `BarLine`, `KeyValue`, `Currency` (returns pill +
  value label), `Wallet`, `Toggle`, `Empty`, `Strip`, `AutoScale`, `ScaleFor`.
  `Kit.Window(parent, title, { tabs, activeTab, onTab, glyph?, subtitle? })`.
- **Dock** (`UIController`): groups table `GROUPS`; add a panel to a group's `tabs` to give it a
  tab. Station prompts still open panels directly (with `atStation`).
- **HUD**: bottom meters live in the `Vitals` frame (scaled as one block). Arts bar, objective,
  controls card, toasts and dock each carry `Kit.AutoScale`.
- **Preview tool**: `python3 tools/render_ui.py <luau> [scene ...] [--size WxH] [--out dir]`
  runs real client code with `tests/engine_mock.luau` + `tools/ui_mock.luau` +
  `tools/ui_fixture.luau` and draws PNGs. It approximates Roblox (stand-in fonts, no images or
  3D in viewports). New scene = a file in `tools/ui_scenes/` returning a builder function
  (`__client()`, `__openPanel(name)`). `tools/ui_sheet.py` tiles PNGs.
- **Content**: `BossConfig.kurozuma` (Raid), Tidewater Spirits + abilities in `SpiritConfig`,
  `LanternConfig.tidewater_lantern` (added to `HubConfig.ShrineLanterns`, so the generated hub
  now has 4 pedestals), Night Market `crab_ashen` / `kite_gilded`.

## Night 4 (same branch)
- **Bell Dice** (`Shared/DiceLogic`, `DiceConfig`, `DiceService` priority 25, `DiceController`,
  panel `BellDice` in the Market dock group). Remotes `DiceState()`, `DiceBet(betId, amount)`,
  `DiceExchange(amount)`, `DiceEvent` (broadcast). Profile v15: `chips`, `chipsDay`,
  `chipsExchangedDay`, `chipsExchanged`. **Compliance:** chips must never get a Robux, Ember or
  Jade path in, never be tradeable, never be a code/bundle reward (tests/dice.spec.luau checks
  products and codes). It is refused where PolicyService restricts paid random items. Real-
  money/Robux gambling is not allowed on Roblox; this is simulated gambling with free chips and
  must be declared in the experience questionnaire.
- **Enemy AI**: `Logic/EnemyMovement` (ring slots, separation, step back, pack offsets,
  anti-guard weight), knobs in `EnemyConfig.Movement`. EnemyService brains gained
  `attackedAt`, `attackHandled`, `retreatUntil`, `driftSign`.
- **World**: `MapConfig.Clutter` (gate counts), `MapConfig.MinSpawnGap` / `MinSentryGap`
  (enforced by tests/world.spec.luau). The map itself was not scaled: Saga NPCs, waystones,
  the river and the waterfall cave are hand-placed and would need moving together.
- **Party frames**: `PartyFramesController` (reads PartyController.State + characters).
  The dock now sits at 60% height so the frames fit above it.

## Night 5 (same branch)
- **Ironcrow Keep**: `RealmConfig.Realms.keep` (origin {0, 0, -5000}, half 420, unlocked by
  `archon_helion`), `World/KeepBuilder` (blockout), portals greek <-> keep, `LightingConfig.Realms.keep`,
  `RealmConfig.FallRespawnDepth` (RealmService sends fallen players to the realm's nearest waystone).
  Map preview: `python3 tools/render_map.py <luau> out.png keep` (assets/keep_top_preview.png).
- **Bosses** `tessai` (ArenaConfig layout "Castle") and `ashrei` (layout "Throne"); enemies
  `keep_footman`, `crow_knight`, `ember_archer`, elite `castellan`.
- **Story**: NPC `hanabusa` (keep), quests `iron_gate`, `crows_over_ash`, `ember_throne`.
- **Smoke test**: `python3 tools/smoke_server.py <luau> [ticks]` with `tools/server_mock.luau`
  (DataStores fail with 403 so ProfileStore uses its mock; task.wait parks threads until the
  next tick; os.clock does not advance, so timed loops and rate limits are only roughly
  exercised). Add actions to its SPEC to cover new remotes.

## Night 6 (same branch)
- **Styles**: `StyleConfig.Styles.*.mechanic` + `Shared/StyleLogic` (pure). CombatService keeps
  `styleId`, `styleState`, `armorUntil` per player combatant; stacks published as character
  attribute `StyleStacks`. `CombatRules.Validate` takes `opts.dashWindow`. Hit field `guardCrush`.
- **Animations**: `AnimationConfig.StyleStances` (additive on the class stance; stance keys
  look like "OneHanded:mountain"), `AnimationConfig.StyleFlavor`, `DefaultFlavor`.
  Preview: `python3 tools/render_poses.py <luau> out.png`.
- **Duels**: `PvpConfig`, `Logic/DuelLogic`, `DuelService` (priority 55), remotes
  `DuelRequest(op, userId?)` / `DuelEvent`, `DuelController`, panel `Duels` (Bonds tab).
  `Combatant.duelId` marks fighters (TargetsInArc lets duel opponents hit each other;
  SpellService/KunaiService/SpiritAbilityService refuse during duels; RefreshStats skips).
  `CombatService.OnDuelLethal` is called instead of a kill. Player attributes `InDuel`, `InArena`.
  Profile v16: `pvpWins`, `pvpLosses`, `pvpStreak`.
- **Smoke test** gained `__giveCharacter` / `__advance` (tools/server_mock.luau) and a scripted
  duel + style checks.
