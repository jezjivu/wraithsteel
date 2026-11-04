--!strict
-- SpiritAbilityService: equipped Spirits fight beside you.
--   * Each companion auto-casts its own ability (SpiritConfig.Abilities) while you are in combat:
--     bolts, dives, pounces, chain lightning, bell blasts, heals and shields.
--   * Spirit Burst (T / D-pad up): every companion casts at once, stronger (shared cooldown).
--   * Equipped Spirits earn XP from every enemy you help defeat.
-- All targeting/damage is server-side through CombatService.ApplyHit; clients only get a
-- SpiritCast CombatEvent to animate the companion (SpiritFollowerController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local SpiritStats = require(Shared:WaitForChild("SpiritStats"))
local SpiritConfig = require(Config:WaitForChild("SpiritConfig"))
local EnemyConfig = require(Config:WaitForChild("EnemyConfig"))
local BossConfig = require(Config:WaitForChild("BossConfig"))

local Logic = script.Parent.Parent:WaitForChild("Logic")
local CombatRules = require(Logic:WaitForChild("CombatRules"))
local SpiritLogic = require(Logic:WaitForChild("SpiritLogic"))

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local CombatService = require(script.Parent.CombatService)

type Combatant = CombatService.Combatant

local SpiritAbilityService = { Name = "SpiritAbilityService", Priority = 31 }

type PlayerState = {
	readyAt: { [string]: number }, -- spirit uid -> next cast time
	lastCastAt: number,
	burstReadyAt: number,
	combatAt: number, -- last time the player hit or was hit
}

local states: { [Player]: PlayerState } = {}
local rng = Random.new()

local function stateOf(player: Player): PlayerState
	local s = states[player]
	if s == nil then
		s = { readyAt = {}, lastCastAt = 0, burstReadyAt = 0, combatAt = -math.huge }
		states[player] = s
	end
	return s
end

type Slot = { uid: string, index: number, id: string, rarity: string, mutation: string, level: number }

-- Equipped spirits in the same order as the SpiritParty attribute (companion index).
local function slots(player: Player): { Slot }
	local data = DataService.GetData(player)
	local out = {}
	if data == nil then
		return out
	end
	for _, uid in data.equippedSpirits do
		local s = data.spirits[uid]
		if s then
			table.insert(out, { uid = uid, index = #out + 1, id = s.id, rarity = s.rarity :: string, mutation = s.mutation :: string, level = s.level })
		end
	end
	return out
end

local function enemiesNear(pos: Vector3, range: number): { Combatant }
	local out = {}
	for _, c in CombatService.All() do
		if c.team == "Enemies" and not c.dead and c.humanoid.Health > 0 then
			local d = c.root.Position - pos
			if Vector3.new(d.X, 0, d.Z).Magnitude <= range and math.abs(d.Y) < 20 then
				table.insert(out, c)
			end
		end
	end
	table.sort(out, function(a, b)
		return (a.root.Position - pos).Magnitude < (b.root.Position - pos).Magnitude
	end)
	return out
end

local function accentOf(id: string): { number }
	local def = SpiritConfig.Spirits[id]
	return if def then def.visual.accent else { 255, 255, 255 }
end

-- Casts one spirit's ability. Returns false when there was nothing to do (no target, full HP).
local function cast(player: Player, owner: Combatant, slot: Slot, multiplier: number, burst: boolean): boolean
	local def = SpiritConfig.Spirits[slot.id]
	local ab = def and SpiritConfig.Abilities[def.ability]
	if def == nil or ab == nil then
		return false
	end
	local hum = owner.humanoid
	local hpFrac = hum.Health / math.max(1, hum.MaxHealth)
	local strength = SpiritStats.Strength(slot.id, slot.rarity, slot.mutation, slot.level) * multiplier
	local pos = owner.root.Position
	local color = accentOf(slot.id)
	local event: { [string]: any } = {
		kind = "SpiritCast",
		ownerId = owner.id,
		userId = player.UserId,
		slot = slot.index,
		ability = def.ability,
		abilityKind = ab.kind,
		color = color,
		burst = burst,
	}

	if ab.kind == "Heal" then
		if hpFrac > (ab.threshold or 1) and not burst then
			return false
		end
		event.targetIds = { owner.id }
		Net.Server.FireAll("CombatEvent", event)
		CombatService.Heal(owner, hum.MaxHealth * (ab.heal or 0) * strength)
		return true
	elseif ab.kind == "Shield" then
		if hpFrac > (ab.threshold or 1) and not burst then
			return false
		end
		event.targetIds = { owner.id }
		Net.Server.FireAll("CombatEvent", event)
		CombatService.AddShield(owner, hum.MaxHealth * (ab.shield or 0) * strength, ab.seconds or 5)
		return true
	end

	-- Offensive abilities need an enemy.
	local range = ab.range or ab.radius or 12
	local near = enemiesNear(pos, range)
	if #near == 0 then
		return false
	end
	local main = near[1]
	local victims: { Combatant } = {}
	local center = main.root.Position
	if ab.kind == "Bolt" or ab.kind == "Pounce" then
		victims = { main }
	elseif ab.kind == "Dive" or ab.kind == "Toll" then
		victims = enemiesNear(center, ab.radius or 8)
	elseif ab.kind == "Nova" or ab.kind == "Bloom" then
		center = pos
		victims = enemiesNear(pos, ab.radius or 12)
		if #victims == 0 then
			return false
		end
	elseif ab.kind == "Chain" then
		local hitSet: { [Combatant]: boolean } = {}
		local cur = main
		for _ = 1, ab.chains or 3 do
			table.insert(victims, cur)
			hitSet[cur] = true
			local nextC = nil
			for _, c in enemiesNear(cur.root.Position, 16) do
				if not hitSet[c] then
					nextC = c
					break
				end
			end
			if nextC == nil then
				break
			end
			cur = nextC
		end
	end

	local ids = {}
	for _, v in victims do
		table.insert(ids, v.id)
	end
	event.targetIds = ids
	event.pos = center
	Net.Server.FireAll("CombatEvent", event)

	local power = ProgressionService.GetPower(player)
	local attack = 1 + (CombatService.PlayerStats(player).Attack or 0)
	local delaySeconds = if ab.kind == "Toll" then 0.45 elseif ab.kind == "Nova" or ab.kind == "Bloom" then 0.1 else 0.25
	task.delay(delaySeconds, function()
		for i, v in victims do
			local critMult, crit = CombatService.RollCrit(player)
			-- Chain lightning loses a little on each jump.
			local falloff = if ab.kind == "Chain" then 0.85 ^ (i - 1) else 1
			CombatService.ApplyHit(owner, v, {
				damage = CombatRules.ScaleDamage(ab.damage or 0, power, rng:NextNumber()) * strength * attack * critMult * falloff,
				postureDamage = (ab.posture or 0) * strength * falloff,
				moveId = "spirit_" .. def.ability,
				knockback = ab.knockback,
				crit = crit,
				source = "spirit",
				color = color,
			})
		end
		if ab.kind == "Bloom" and ab.heal then
			CombatService.Heal(owner, hum.MaxHealth * ab.heal * strength)
		end
	end)
	return true
end

local function cooldownOf(player: Player, abilityId: string): number
	local ab = SpiritConfig.Abilities[abilityId]
	local haste = CombatService.PlayerStats(player).Haste or 0
	return (if ab then ab.cooldown else 10) * (1 - haste)
end

local function tick()
	local now = os.clock()
	local cfg = SpiritConfig.AutoCast
	for _, player in Players:GetPlayers() do
		local owner = CombatService.GetByPlayer(player)
		if owner == nil or owner.dead or owner.humanoid.Health <= 0 or owner.duelId ~= nil then
			continue -- (companions sit duels out)
		end
		local st = stateOf(player)
		if now - st.lastCastAt < cfg.gap then
			continue
		end
		local inCombat = now - st.combatAt <= cfg.combatWindow
		if not inCombat and #enemiesNear(owner.root.Position, cfg.engageRange * 0.5) == 0 then
			continue
		end
		for _, slot in slots(player) do
			if now >= (st.readyAt[slot.uid] or 0) then
				local def = SpiritConfig.Spirits[slot.id]
				if def and cast(player, owner, slot, 1, false) then
					st.readyAt[slot.uid] = now + cooldownOf(player, def.ability)
					st.lastCastAt = now
					break -- one companion per gap: casts ripple instead of stacking
				end
			end
		end
	end
end

local function onSpiritCall(player: Player)
	local owner = CombatService.GetByPlayer(player)
	if owner == nil or owner.dead or owner.duelId ~= nil then
		return
	end
	local st = stateOf(player)
	local now = os.clock()
	if now < st.burstReadyAt then
		Net.Server.Fire("CombatEvent", player, { kind = "BurstCooldown", remaining = st.burstReadyAt - now })
		return
	end
	local list = slots(player)
	if #list == 0 then
		Net.Server.Fire("Notify", player, "Info", "Equip Spirits to use Spirit Burst (Spirits menu).")
		return
	end
	local any = false
	for _, slot in list do
		if cast(player, owner, slot, SpiritConfig.Burst.multiplier, true) then
			any = true
			local def = SpiritConfig.Spirits[slot.id]
			if def then
				st.readyAt[slot.uid] = now + cooldownOf(player, def.ability)
			end
		end
	end
	if not any then
		Net.Server.Fire("CombatEvent", player, { kind = "BurstCooldown", remaining = 0, reason = "No enemies nearby" })
		return
	end
	st.combatAt = now
	st.lastCastAt = now
	local cd = SpiritConfig.Burst.cooldown * (1 - (CombatService.PlayerStats(player).Haste or 0))
	st.burstReadyAt = now + cd
	player:SetAttribute("SpiritBurstReadyAt", workspace:GetServerTimeNow() + cd)
	Net.Server.FireAll("CombatEvent", { kind = "SpiritBurst", ownerId = owner.id, userId = player.UserId })
end

-- XP for every equipped spirit when an enemy you damaged dies.
local function onDied(target: Combatant, contributions: { [Player]: number })
	if target.team ~= "Enemies" then
		return
	end
	local xp = 0
	local enemyDef = target.defId and EnemyConfig.Enemies[target.defId]
	local bossDef = target.defId and BossConfig.Bosses[target.defId]
	if enemyDef then
		xp = enemyDef.xpReward
	elseif bossDef then
		xp = bossDef.rewards.xp
	end
	xp = math.floor(xp * SpiritConfig.CombatXpShare)
	if xp <= 0 then
		return
	end
	for player in contributions do
		local data = DataService.GetData(player)
		if data then
			local leveled = false
			for _, uid in data.equippedSpirits do
				local s = data.spirits[uid]
				if s and SpiritLogic.AddXp(s :: any, xp) > 0 then
					leveled = true
				end
			end
			DataService.Changed(player, "spirits")
			if leveled then
				Net.Server.Fire("Notify", player, "Info", "Your Spirits grew stronger!")
				CombatService.ClearStatCache(player)
				ProgressionService.RefreshPower(player)
			end
		end
	end
end

function SpiritAbilityService.Init() end

function SpiritAbilityService.Start()
	CombatService.OnSpiritCall = onSpiritCall
	CombatService.Damaged:Connect(function(target: Combatant, attacker: Combatant?)
		local now = os.clock()
		if target.player then
			stateOf(target.player).combatAt = now
		end
		if attacker and attacker.player then
			stateOf(attacker.player).combatAt = now
		end
	end)
	CombatService.Died:Connect(onDied)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(SpiritConfig.AutoCast.tick)
			local ok, err = pcall(tick :: any)
			if not ok then
				warn("[SpiritAbilityService] tick error:", err)
			end
		end
	end)
end

return SpiritAbilityService
