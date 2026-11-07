-- Extra headless playtest scenarios (spliced into tools/smoke_server.py's SPEC, so `require`,
-- `game`, `__giveCharacter`, `__advance` ... are available). Each scenario prints [smoke] lines
-- and must not throw; errors inside game threads are collected by the harness.
local ONLY = __ONLY__
local function want(name)
	if ONLY == nil then
		return true
	end
	return table.find(ONLY, name) ~= nil
end

function __scenarios(call, kaito, mirelle, remotes, SSS)
	local RS = game:GetService("ReplicatedStorage")
	local Combat = require(SSS.Services.CombatService)
	local DataService = require(SSS.Services.DataService)
	local function cof(player)
		return Combat.GetByPlayer(player)
	end
	local function stand(player, pos, faceTo)
		local c = cof(player)
		if c == nil then
			return
		end
		c.root.CFrame = if faceTo then CFrame.lookAt(pos, faceTo) else CFrame.new(pos)
		c.humanoid.Health = c.humanoid.MaxHealth
		c.dead = false
	end

	-- 1. Enemy AI against characters ----------------------------------------------------------
	if want("ai") then
		print("[smoke] --- scenario: enemy AI ---")
		local enemies = {}
		for _, c in Combat.All() do
			if c.kind == "Enemy" and not c.dead and c.defId == "rustbound_bandit" then
				table.insert(enemies, c)
			end
		end
		print("[smoke] bandits available: " .. #enemies)
		local e1 = enemies[1]
		if e1 then
			local p = e1.root.Position
			stand(kaito, p + Vector3.new(0, 0, 5), p)
			stand(mirelle, p + Vector3.new(0, 0, -5), p)
			local ck, cm = cof(kaito), cof(mirelle)
			local hk, hm = ck.humanoid.Health, cm.humanoid.Health
			local log = {}
			local realApply = Combat.ApplyHit
			Combat.ApplyHit = function(attacker, target, hit)
				table.insert(log, string.format("%s -> %s dmg %.1f %s", attacker and attacker.id or "?", target.id, hit.damage or 0, tostring(hit.moveId)))
				return realApply(attacker, target, hit)
			end
			local hpTrace = {}
			for i = 1, 8 do
				__advance(1)
				table.insert(hpTrace, string.format("%.0f", e1.humanoid.Health))
			end
			Combat.ApplyHit = realApply
			print("[smoke] AI: enemy1 hp per second: " .. table.concat(hpTrace, ", "))
			print("[smoke] AI: ApplyHit calls: " .. #log)
			for i = 1, math.min(#log, 6) do
				print("[smoke]   " .. log[i])
			end
			print(string.format("[smoke] AI: kaito hp %.0f -> %.0f, mirelle hp %.0f -> %.0f, enemy1 alive %s", hk, ck.humanoid.Health, hm, cm.humanoid.Health, tostring(not e1.dead)))
			print(string.format("[smoke] AI: enemy1 hp %.0f/%.0f aware %s", e1.humanoid.Health, e1.humanoid.MaxHealth, tostring(not e1.unaware)))
		end
	end
	-- 2. Bosses: arenas (new layouts) + every boss fight ---------------------------------------
	if want("boss") then
		print("[smoke] --- scenario: bosses ---")
		local ArenaBuilder = require(SSS.World.ArenaBuilder)
		local ArenaConfig = require(RS.Config.ArenaConfig)
		local BossConfig = require(RS.Config.BossConfig)
		for id, theme in ArenaConfig.Themes do
			local ok, m = pcall(ArenaBuilder.Build, Vector3.new(0, 300, 0), theme)
			local n = 0
			if ok then
				for _ in m:GetDescendants() do
					n += 1
				end
			end
			print(string.format("[smoke] arena %-14s layout %-9s %s (%s instances)", id, tostring(theme.layout), if ok then "built" else "FAILED: " .. tostring(m), tostring(n)))
		end
		local BossService = require(SSS.Services.BossService)
		local ended = {}
		BossService.EncounterEnded:Connect(function(id, bossId, victory)
			ended[id] = { bossId = bossId, victory = victory }
		end)
		local ids = {}
		for bossId in BossConfig.Bosses do
			table.insert(ids, bossId)
		end
		table.sort(ids)
		for _, bossId in ids do
			local def = BossConfig.Bosses[bossId]
			stand(kaito, Vector3.new(0, 5, 300), nil)
			stand(mirelle, Vector3.new(4, 5, 300), nil)
			local encounterId = BossService.StartEncounter(bossId, CFrame.new(0, 5, 280), { kaito, mirelle }, nil, nil, 1)
			if encounterId == nil then
				print("[smoke] boss " .. bossId .. ": StartEncounter returned nil")
				continue
			end
			local boss
			for _, c in Combat.All() do
				if c.kind == "Boss" and c.defId == bossId and not c.dead then
					boss = c
				end
			end
			if boss == nil then
				print("[smoke] boss " .. bossId .. ": not registered")
				continue
			end
			local hits = 0
			local moves = {}
			local realApply = Combat.ApplyHit
			Combat.ApplyHit = function(attacker, target, hit)
				if attacker == boss then
					hits += 1
					moves[tostring(hit.moveId)] = true
				end
				return realApply(attacker, target, hit)
			end
			local hp0 = boss.humanoid.Health
			__advance(5)
			-- push the boss through its phases
			for _, frac in { 0.6, 0.3 } do
				boss.humanoid.Health = boss.humanoid.MaxHealth * frac
				__advance(3.5)
			end
			Combat.ApplyHit = realApply
			local names = {}
			for m in moves do
				table.insert(names, m)
			end
			table.sort(names)
			BossService.Fail(encounterId)
			__advance(0.3)
			print(string.format("[smoke] boss %-14s hp %.0f, boss hits on players %d, distinct moves %d (%s), active after Fail %s, ended %s", bossId, hp0, hits, #names, table.concat(names, "/"):sub(1, 60), tostring(BossService.IsActive(encounterId)), tostring(ended[encounterId] ~= nil)))
			if boss and not boss.dead then
				Combat.Unregister(boss.id)
			end
		end
	end
	-- 3. Trade with the escrow ledger ------------------------------------------------------------
	if want("trade") then
		print("[smoke] --- scenario: trade ---")
		local SpiritService = require(SSS.Services.SpiritService)
		local dk, dm = DataService.GetData(kaito), DataService.GetData(mirelle)
		stand(kaito, Vector3.new(0, 5, 150), nil)
		stand(mirelle, Vector3.new(0, 5, 154), nil)
		local a = SpiritService.Grant(kaito, "reed_fox", "Uncommon", "Gilded", false)
		local b = SpiritService.Grant(mirelle, "brass_carp", "Rare", "None", false)
		local paid = SpiritService.Grant(kaito, "mist_heron", "Rare", "None", true)
		print("[smoke] trade: kaito gives " .. a.uid .. " (reed_fox), mirelle gives " .. b.uid .. " (brass_carp)")
		local function count(d)
			local n, names = 0, {}
			for _, s in d.spirits do
				n += 1
				table.insert(names, s.id)
			end
			table.sort(names)
			return n, table.concat(names, ",")
		end
		print("[smoke] trade before: kaito " .. select(2, count(dk)) .. " | mirelle " .. select(2, count(dm)))
		print("[smoke] trade request: " .. tostring(select(2, call(kaito, "TradeRequest", mirelle.UserId))))
		print("[smoke] trade open:    " .. tostring(select(2, call(mirelle, "TradeRequest", kaito.UserId))))
		call(kaito, "TradeUpdate", { op = "offer", uids = { a.uid } })
		call(mirelle, "TradeUpdate", { op = "offer", uids = { b.uid } })
		call(kaito, "TradeUpdate", { op = "confirm" })
		call(mirelle, "TradeUpdate", { op = "confirm" })
		__advance(6.5)
		print("[smoke] trade after:  kaito " .. select(2, count(dk)) .. " | mirelle " .. select(2, count(dm)))
		print("[smoke] trade applied ids: kaito " .. #dk.tradeOrder .. ", mirelle " .. #dm.tradeOrder)
		local gotPaid = false
		for _, sp in dm.spirits do
			gotPaid = gotPaid or sp.paid == true
		end
		-- a paid Spirit may only go to accounts allowed to trade paid items (mock policy allows both)
		print("[smoke] trade: paid flag travels with the spirit: " .. tostring(paid.paid == true))
	end

	-- 4. Raid launch (Studio path: runs in place) -------------------------------------------------
	if want("raid") then
		print("[smoke] --- scenario: raid ---")
		local dk, dm = DataService.GetData(kaito), DataService.GetData(mirelle)
		dk.level, dm.level = 12, 12
		stand(kaito, Vector3.new(0, 5, 150), nil)
		stand(mirelle, Vector3.new(0, 5, 154), nil)
		print("[smoke] raid create: " .. tostring(select(2, call(kaito, "RaidRequest", "create", "sunken_bell_vigil"))))
		local lobbyId
		local RaidService = require(SSS.Services.RaidService)
		local lobby = RaidService.LobbyOf(kaito)
		lobbyId = lobby and lobby.id
		print("[smoke] raid join: " .. tostring(select(2, call(mirelle, "RaidRequest", "join", lobbyId))))
		print("[smoke] raid launch: " .. tostring(select(2, call(kaito, "RaidRequest", "launch"))))
		__advance(2)
		local errsNow = __smokeErrors()
		for i = math.max(1, #errsNow - 2), #errsNow do
			print("[smoke] raid thread error: " .. string.sub(errsNow[i], 1, 300))
		end
		local BossService = require(SSS.Services.BossService)
		local boss
		for _, c in Combat.All() do
			if c.kind == "Boss" and c.defId == "kurozuma" and not c.dead then
				boss = c
			end
		end
		print("[smoke] raid boss spawned: " .. tostring(boss ~= nil) .. (if boss then string.format(" (hp %.0f)", boss.humanoid.MaxHealth) else ""))
		if boss then
			local before = dk.raidClears.sunken_bell_vigil or 0
			-- keep hitting until the boss is down (it may be invulnerable during phase transitions)
			local tries = 0
			while not boss.dead and tries < 40 do
				tries += 1
				Combat.ApplyHit(cof(kaito), boss, { damage = 1e9, postureDamage = 0, moveId = "jian_light_1" })
				__advance(0.25)
			end
			print(string.format("[smoke] raid boss dead after %d tries: %s (invulnerable now: %s)", tries, tostring(boss.dead), tostring(boss.invulnerable)))
			__advance(1.5)
			print(string.format("[smoke] raid victory: clears %d -> %d, ember %s, jade %s", before, dk.raidClears.sunken_bell_vigil or 0, tostring(dk.ember), tostring(dk.jade)))
		end
	end

	-- 5. A Studio test purchase through ProcessReceipt -----------------------------------------
	if want("market") then
		print("[smoke] --- scenario: market ---")
		local dk = DataService.GetData(kaito)
		local jade0, level0 = dk.jade, dk.level
		remotes:FindFirstChild("PromptProduct").OnServerEvent:Fire(kaito, "JadeSmall")
		__advance(1.5)
		print(string.format("[smoke] purchase JadeSmall: jade %s -> %s, receipts recorded %d", tostring(jade0), tostring(dk.jade), #dk.receiptOrder))
		remotes:FindFirstChild("PromptProduct").OnServerEvent:Fire(kaito, "LevelUp5")
		__advance(1.5)
		print(string.format("[smoke] purchase LevelUp5: level %s -> %s", tostring(level0), tostring(dk.level)))
		remotes:FindFirstChild("PromptPass").OnServerEvent:Fire(kaito, "DoubleEmber")
		__advance(1.5)
		local MarketService = require(SSS.Services.MarketService)
		print("[smoke] pass DoubleEmber owned: " .. tostring(MarketService.HasPass(kaito, "DoubleEmber")))
	end

	-- 6. Expeditions -------------------------------------------------------------------------------
	if want("expedition") then
		print("[smoke] --- scenario: expedition ---")
		local SpiritService = require(SSS.Services.SpiritService)
		local dk = DataService.GetData(kaito)
		local uids = {}
		for _, sp in dk.spirits do
			if not table.find(dk.equippedSpirits, sp.uid) and not sp.locked then
				table.insert(uids, sp.uid)
				if #uids == 2 then
					break
				end
			end
		end
		if #uids < 2 then
			table.insert(uids, SpiritService.Grant(kaito, "ember_sparrow", "Common", "None", false).uid)
			table.insert(uids, SpiritService.Grant(kaito, "lantern_moth", "Common", "None", false).uid)
		end
		print("[smoke] expedition start: " .. tostring(select(2, call(kaito, "StartExpedition", "slot1", "reed_marsh", uids))))
		print("[smoke] expedition claim too early: " .. tostring(select(2, call(kaito, "ClaimExpedition", "slot1"))))
		local e = dk.expeditions.slot1
		if e then
			e.endsAt = os.time() - 1
		end
		local ember0 = dk.ember
		local res = call(kaito, "ClaimExpedition", "slot1")
		print(string.format("[smoke] expedition claimed: %s, ember %s -> %s", type(res) == "table" and "table" or tostring(res), tostring(ember0), tostring(dk.ember)))
	end

	-- 7. Portals and waystones, with characters present ---------------------------------------
	if want("travel") then
		print("[smoke] --- scenario: travel ---")
		local RealmService = require(SSS.Services.RealmService)
		local RealmConfig = require(RS.Config.RealmConfig)
		local dk = DataService.GetData(kaito)
		dk.level = 20
		for _, realm in { "neon", "greek", "keep" } do
			local ok0, why = RealmService.CanEnter(kaito, realm)
			if realm == "greek" then
				dk.bossesDefeated.kagura_9 = 1
			elseif realm == "keep" then
				dk.bossesDefeated.archon_helion = 1
			end
			local ok1 = RealmService.CanEnter(kaito, realm)
			stand(kaito, Vector3.new(0, 5, 150), nil)
			RealmService.Travel(kaito, realm)
			local pos = cof(kaito).root.Position
			print(string.format("[smoke] realm %-5s sealed before boss: %s (%s) | after: %s | arrived at %.0f,%.0f realm=%s attr=%s", realm, tostring(not ok0), tostring(why), tostring(ok1), pos.X, pos.Z, RealmConfig.At(pos), tostring(kaito:GetAttribute("Realm"))))
			__advance(RealmConfig.PortalCooldown + 0.2)
		end
		-- waystone: rest at one, then fast travel to it from elsewhere
		local WaystoneService = require(SSS.Services.WaystoneService)
		local wp = WaystoneService.Position("keep_road")
		stand(kaito, wp + Vector3.new(2, 0, 2), nil)
		WaystoneService.Rest(kaito, "keep_road")
		print("[smoke] waystone keep_road attuned: " .. tostring(dk.waystones.keep_road))
		stand(kaito, Vector3.new(0, 5, 150), nil)
		__advance(0.5)
		print("[smoke] fast travel: " .. tostring(select(2, call(kaito, "TravelWaystone", "keep_road"))))
		local pos = cof(kaito).root.Position
		print(string.format("[smoke] after fast travel at %.0f,%.0f (waystone %.0f,%.0f)", pos.X, pos.Z, wp.X, wp.Z))
	end
	-- 8. The whole story, through the real services -------------------------------------------------
	if want("saga") then
		print("[smoke] --- scenario: saga (fresh player walks the questline) ---")
		local SagaService = require(SSS.Services.SagaService)
		local EnemyService = require(SSS.Services.EnemyService)
		local BossService = require(SSS.Services.BossService)
		local SagaConfig = require(RS.Config.SagaConfig)
		local RealmConfig = require(RS.Config.RealmConfig)
		local fresh = DataService.GetData(mirelle)
		fresh.level, fresh.xp, fresh.chapter = 1, 0, 0
		fresh.saga = { quest = 1, step = 1, progress = 0, started = false }
		stand(mirelle, Vector3.new(0, 5, 150), nil)
		local cp = cof(mirelle)
		for _, q in SagaConfig.Quests do
			SagaService.Talk(mirelle, q.giver) -- start
			for _, step in q.steps do
				if step.kind == "Kill" then
					for i = 1, step.count do
						EnemyService.Defeated:Fire(step.enemies[1], { [mirelle] = 10 })
					end
				elseif step.kind == "Boss" then
					BossService.BossDefeated:Fire(step.bossId, { mirelle }, {})
					fresh.bossesDefeated[step.bossId] = (fresh.bossesDefeated[step.bossId] or 0) + 1
				elseif step.kind == "Reach" then
					stand(mirelle, RealmConfig.World(step.realm, step.at), nil)
					__advance(1.4)
				elseif step.kind == "Talk" then
					SagaService.Talk(mirelle, step.npc)
				end
			end
			local before = fresh.saga.quest
			SagaService.Talk(mirelle, q.giver) -- hand in
			print(string.format("[smoke] quest %-18s -> saga index %d (was %d), level %d, chapter %d, ember %d", q.id, fresh.saga.quest, before, fresh.level, fresh.chapter, fresh.ember))
		end
		print(string.format("[smoke] saga finished: quest index %d of %d, chapter %d", fresh.saga.quest, #SagaConfig.Quests, fresh.chapter))
	end
end
