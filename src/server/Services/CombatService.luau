--!strict
-- CombatService: server-authoritative combat (guide §8.2 rule 3).
-- Clients send CombatAction requests ({action, seq, aim?}); this service validates them with
-- Logic/CombatRules, runs the move on the server timeline, does its own hit detection from the
-- server-side character position/facing, and applies damage. Clients never report hits.
--
-- Also owns the combatant registry used by EnemyService/BossService.
--
-- API:
--   CombatService.Register(c: Combatant) / Unregister(id) / Get(id) / GetByPlayer(player)
--   CombatService.All() -> { Combatant }
--   CombatService.ApplyHit(attacker: Combatant?, target: Combatant, hit) -> Resolution?
--   CombatService.Damaged: Signal(target, attacker?, resolution)
--   CombatService.PostureBroken: Signal(target)
--   CombatService.Died: Signal(target, contributions: { [Player]: number })
--   CombatService.PlayerStats(player) -> spirit stat totals (Shared/SpiritStats, cached)
--   CombatService.RollCrit(player) -> (multiplier, crit: boolean)
--   CombatService.Heal(c, amount) / AddShield(c, amount, seconds)
--   CombatService.OnSpiritCall: ((player) -> ())?  -- set by SpiritAbilityService (T key)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local CombatConfig = require(Config:WaitForChild("CombatConfig"))
local WeaponConfig = require(Config:WaitForChild("WeaponConfig"))
local EnemyConfig = require(Config:WaitForChild("EnemyConfig"))
local BossConfig = require(Config:WaitForChild("BossConfig"))
local StyleConfig = require(Config:WaitForChild("StyleConfig"))
local MapConfig = require(Config:WaitForChild("MapConfig"))

local Logic = script.Parent.Parent:WaitForChild("Logic")
local CombatRules = require(Logic:WaitForChild("CombatRules"))
local Posture = require(Logic:WaitForChild("Posture"))
local SpiritLogic = require(Logic:WaitForChild("SpiritLogic"))

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local QuestService = require(script.Parent.QuestService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local SpiritService = require(script.Parent.SpiritService)

export type Combatant = {
	id: string,
	kind: "Player" | "Enemy" | "Boss",
	team: "Players" | "Enemies",
	defId: string?, -- EnemyConfig/BossConfig key
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	player: Player?,
	posture: Posture.Posture,
	brokenSeconds: number,
	power: number,
	rules: CombatRules.State?, -- players only
	invulnerable: boolean,
	dead: boolean,
	contributions: { [Player]: number },
	guardUntil: number?, -- enemies: guard raised until this time (blocks until posture breaks)
	shield: number?, -- absorbs health damage until shieldUntil (spirit wards, Jade Barrier)
	shieldUntil: number?,
	dodgeAt: number?, -- players: last dash (for Needle Counters against Pierce attacks)
	dodgeDir: Vector3?,
	flask: number?, -- players: Spring Flask charges left
	breath: boolean?, -- players: Second Breath still available this life
	unaware: boolean?, -- enemies: hasn't noticed any player yet (Shadow Strike possible)
	deflectChance: number?, -- enemies/bosses: chance to deflect a strike while canDeflect()
	canDeflect: (() -> boolean)?,
}

export type Hit = {
	damage: number,
	postureDamage: number,
	perilous: boolean?,
	moveId: string,
	knockback: number?, -- studs/s away from the attacker
	launch: number?, -- studs/s upward
	riposte: boolean?, -- empowered counter after a perfect parry (for effects)
	crit: boolean?, -- critical hit (for effects)
	source: string?, -- "spirit" | "spell" (for effects; also no lifesteal from spirits)
	color: { number }?, -- damage number tint
	perilousKind: string?, -- "Pierce" | "Sweep" | "Grasp" (see CombatConfig)
	severing: boolean?, -- Severing Blow on a posture-broken enemy
	ranged: boolean?, -- projectile / wave / eruption: a parry does not stagger the attacker
	shadow: boolean?, -- Severing Blow on an enemy that never saw you coming
}

local MAX_TARGETS_PER_SWING = 4
local COMBATANT_TAG = "Combatant"
local VALID_ACTIONS = {
	LightAttack = true,
	HeavyAttack = true,
	Parry = true,
	Dodge = true,
	Skill1 = true,
	Skill2 = true,
	Ultimate = true,
	SpiritCall = true,
	GuardRelease = true,
	Flask = true,
}

local CombatService = {
	Name = "CombatService",
	Priority = 23,
	Damaged = Signal.new(),
	PostureBroken = Signal.new(),
	Died = Signal.new(),
	Staggered = Signal.new(), -- (combatant, seconds): its attack was parried
	Deflected = Signal.new(), -- (enemy, attacker): an enemy deflected a player's strike (counter now)
	OnSpiritCall = nil :: ((player: Player) -> ())?,
}

local combatants: { [string]: Combatant } = {}

-- Healing areas from MapConfig (center, radius, fraction per second).
local healAreas: { { center: Vector3, radius: number, rate: number } } = {}
for _, a in MapConfig.Areas do
	local rate = (MapConfig.HealAreas :: any)[a.id]
	if rate then
		table.insert(healAreas, { center = Vector3.new(a.center[1], 0, a.center[2]), radius = a.radius, rate = rate })
	end
end
local lastHurtAt: { [Combatant]: number } = {} -- players only: for out-of-combat regen
local statCache: { [Player]: { [string]: number } } = {}
local byPlayer: { [Player]: Combatant } = {}
local rng = Random.new()

function CombatService.Register(c: Combatant)
	combatants[c.id] = c
	if c.player then
		byPlayer[c.player] = c
	end
	c.model:SetAttribute("CombatantId", c.id)
	c.model:SetAttribute("CombatantKind", c.kind)
	-- Clients find combatants by tag (health/posture bars, damage numbers, animations).
	CollectionService:AddTag(c.model, COMBATANT_TAG)
end

function CombatService.Unregister(id: string)
	local c = combatants[id]
	if c then
		combatants[id] = nil
		lastHurtAt[c] = nil
		if c.player and byPlayer[c.player] == c then
			byPlayer[c.player] = nil
		end
	end
end

function CombatService.Get(id: string): Combatant?
	return combatants[id]
end

function CombatService.GetByPlayer(player: Player): Combatant?
	return byPlayer[player]
end

function CombatService.All(): { Combatant }
	local out = {}
	for _, c in combatants do
		table.insert(out, c)
	end
	return out
end

local EMPTY_STATS: { [string]: number } = {}

-- Spirit stat totals for a player (cached; cleared when their spirit party changes).
function CombatService.PlayerStats(player: Player): { [string]: number }
	local cached = statCache[player]
	if cached then
		return cached
	end
	local data = DataService.GetData(player)
	if data == nil then
		return EMPTY_STATS
	end
	local totals = SpiritLogic.StatTotals(data :: any)
	statCache[player] = totals
	return totals
end

function CombatService.ClearStatCache(player: Player)
	statCache[player] = nil
end

function CombatService.RollCrit(player: Player): (number, boolean)
	local stats = CombatService.PlayerStats(player)
	local chance = CombatConfig.Crit.baseChance + (stats.CritChance or 0)
	if rng:NextNumber() < chance then
		return 1 + CombatConfig.Crit.baseDamage + (stats.CritDamage or 0), true
	end
	return 1, false
end

local function maxHealthFor(player: Player, level: number): number
	local base = CombatConfig.PlayerMaxHealth + (level - 1) * CombatConfig.PlayerHealthPerLevel
	return math.floor(base * (1 + (CombatService.PlayerStats(player).Health or 0)))
end

local function syncShield(c: Combatant)
	local frac = if c.shield and c.shield > 0 then c.shield / math.max(1, c.humanoid.MaxHealth) else 0
	c.model:SetAttribute("Shield", frac)
end

local function broadcast(payload: { [string]: any })
	Net.Server.FireAll("CombatEvent", payload)
end

function CombatService.Heal(c: Combatant, amount: number)
	if c.dead or amount <= 0 then
		return
	end
	local hum = c.humanoid
	local before = hum.Health
	hum.Health = math.min(hum.MaxHealth, hum.Health + amount)
	local healed = hum.Health - before
	if healed >= 1 then
		broadcast({ kind = "Heal", targetId = c.id, amount = healed })
	end
end

-- Seconds since this player last took damage (math.huge if never).
function CombatService.SinceHurt(c: Combatant): number
	local t = lastHurtAt[c]
	return if t then os.clock() - t else math.huge
end

-- Resting at a waystone: full heal, Spring Flask + Second Breath refilled.
function CombatService.Rest(c: Combatant)
	if c.dead then
		return
	end
	CombatService.Heal(c, c.humanoid.MaxHealth)
	c.flask = CombatConfig.Flask.charges
	c.model:SetAttribute("Flask", c.flask)
	c.breath = true
	c.model:SetAttribute("Breath", true)
	c.posture.value = 0
	c.model:SetAttribute("Posture", 0)
end

function CombatService.AddShield(c: Combatant, amount: number, seconds: number)
	if c.dead or amount <= 0 then
		return
	end
	local now = os.clock()
	local current = if c.shieldUntil and now < c.shieldUntil then c.shield or 0 else 0
	c.shield = math.max(current, amount)
	c.shieldUntil = now + seconds
	syncShield(c)
end

-- Mirrors ultimate charge (0..1) to the character for the HUD.
local function syncUltimate(c: Combatant)
	if c.rules then
		c.model:SetAttribute("Ultimate", c.rules.ultimateCharge / WeaponConfig.UltimateChargeMax)
	end
end

-- Applies a hit to `target`. Players resolve parry/block/dodge; enemies/bosses take it directly.
function CombatService.ApplyHit(attacker: Combatant?, target: Combatant, hit: Hit): CombatRules.Resolution?
	if target.dead or target.invulnerable or target.humanoid.Health <= 0 then
		return nil
	end
	local now = os.clock()
	-- Challenge scaling: enemies and bosses hit players harder than their listed numbers.
	if target.player and attacker and attacker.kind ~= "Player" then
		local dm = if attacker.kind == "Boss" then BossConfig.DamageMultiplier else EnemyConfig.DamageMultiplier
		local pm = if attacker.kind == "Boss" then BossConfig.PostureMultiplier else EnemyConfig.PostureMultiplier
		hit = table.clone(hit)
		hit.damage *= dm
		hit.postureDamage *= pm
	end
	local res: CombatRules.Resolution
	if target.rules then
		local ctx: CombatRules.Context = {}
		if hit.perilous and attacker then
			local hum = target.humanoid
			local state = hum:GetState()
			ctx.airborne = hum.FloorMaterial == Enum.Material.Air
				or state == Enum.HumanoidStateType.Freefall
				or state == Enum.HumanoidStateType.Jumping
				or target.root.Position.Y > attacker.root.Position.Y + 3
			local dir = target.dodgeDir
			if target.dodgeAt and dir and now - target.dodgeAt <= CombatConfig.Counter.window then
				local toward = attacker.root.Position - target.root.Position
				local flat = Vector3.new(toward.X, 0, toward.Z)
				ctx.dashedToward = flat.Magnitude < 0.5 or flat.Unit:Dot(dir) >= CombatConfig.Counter.towardDot
			end
		end
		res = CombatRules.ResolveIncoming(target.rules, hit, now, ctx)
	elseif attacker and attacker.player and hit.source == nil and not hit.severing and target.deflectChance
		and not Posture.IsBroken(target.posture, now)
		and (if target.canDeflect then target.canDeflect() else (target.guardUntil ~= nil and now < target.guardUntil))
		and rng:NextNumber() < target.deflectChance then
		-- The enemy deflects your strike: no damage, both postures take a little, it counters.
		res = { outcome = "Deflected", damage = 0, postureDamage = hit.postureDamage * CombatConfig.Deflect.targetPosture, reflectPosture = hit.postureDamage * CombatConfig.Deflect.attackerPosture }
	elseif target.guardUntil and now < target.guardUntil and not hit.perilous and not hit.severing then
		-- Enemy guard: little health damage, extra posture damage. Break the guard to punish.
		res = {
			outcome = "Blocked",
			damage = hit.damage * EnemyConfig.GuardDamageMultiplier,
			postureDamage = hit.postureDamage * EnemyConfig.GuardPostureMultiplier,
			reflectPosture = 0,
		}
	else
		res = { outcome = "Hit", damage = hit.damage, postureDamage = hit.postureDamage, reflectPosture = 0 }
	end

	local damage = res.damage
	if Posture.IsBroken(target.posture, now) and not hit.severing then
		damage *= CombatConfig.PostureBrokenDamageMultiplier
	end
	local postureDamage = res.postureDamage
	if target.player then
		postureDamage *= 1 - (CombatService.PlayerStats(target.player).Guard or 0)
	end
	if attacker and attacker.player then
		local stats = CombatService.PlayerStats(attacker.player)
		postureDamage *= 1 + (stats.Posture or 0)
		local lifesteal = stats.Lifesteal or 0
		if lifesteal > 0 and damage > 0 and hit.source ~= "spirit" and (res.outcome == "Hit" or res.outcome == "Blocked") then
			local hum = attacker.humanoid
			hum.Health = math.min(hum.MaxHealth, hum.Health + damage * lifesteal)
		end
		target.contributions[attacker.player] = (target.contributions[attacker.player] or 0) + damage
		if attacker.rules then
			attacker.rules.ultimateCharge = math.min(
				WeaponConfig.UltimateChargeMax,
				attacker.rules.ultimateCharge + postureDamage * WeaponConfig.UltimateChargePerPostureDamage
			)
		end
	end

	-- Second Breath: the killing blow leaves a player at 1 HP, then they rise again.
	if target.player and target.breath and damage >= target.humanoid.Health and damage > 0 then
		target.breath = false
		target.model:SetAttribute("Breath", false)
		damage = math.max(0, target.humanoid.Health - 1)
		target.invulnerable = true
		if target.rules then
			target.rules.stunnedUntil = now + CombatConfig.SecondBreath.seconds
		end
		broadcast({ kind = "SecondBreath", targetId = target.id, seconds = CombatConfig.SecondBreath.seconds })
		task.delay(CombatConfig.SecondBreath.seconds, function()
			if not target.dead then
				target.invulnerable = false
				CombatService.Heal(target, target.humanoid.MaxHealth * CombatConfig.SecondBreath.heal)
				broadcast({ kind = "Revived", targetId = target.id })
			end
		end)
	end
	-- Shields soak health damage first.
	if damage > 0 and target.shield and target.shield > 0 then
		if target.shieldUntil and now < target.shieldUntil then
			local absorbed = math.min(target.shield, damage)
			target.shield -= absorbed
			damage -= absorbed
		else
			target.shield = 0
		end
		syncShield(target)
	end
	if damage > 0 then
		target.humanoid.Health = math.max(0, target.humanoid.Health - damage)
		if target.player then
			lastHurtAt[target] = now
		end
	end
	local broke = Posture.Add(target.posture, postureDamage, now, target.brokenSeconds)
	if broke then
		if target.rules then
			target.rules.stunnedUntil = now + target.brokenSeconds
		end
		CombatService.PostureBroken:Fire(target)
		target.model:SetAttribute("Broken", true)
		if attacker and attacker.player then
			QuestService.Increment(attacker.player, "PostureBreaks", 1)
		end
	end

	-- Knockback / launch away from the attacker (halved through a block, none on parry/dodge).
	if attacker and (hit.knockback or hit.launch) and (res.outcome == "Hit" or res.outcome == "Blocked") then
		local away = target.root.Position - attacker.root.Position
		local flat = Vector3.new(away.X, 0, away.Z)
		local dir = if flat.Magnitude > 0.1 then flat.Unit else attacker.root.CFrame.LookVector
		local scale = if res.outcome == "Blocked" then 0.5 else 1
		CombatService.Knockback(target, (dir * (hit.knockback or 0) + Vector3.new(0, hit.launch or 0, 0)) * scale)
	end

	-- Enemy deflect: your posture takes the rebound, the enemy counters.
	if res.outcome == "Deflected" and attacker then
		if Posture.Add(attacker.posture, res.reflectPosture, now, attacker.brokenSeconds) then
			if attacker.rules then
				attacker.rules.stunnedUntil = now + attacker.brokenSeconds
			end
			CombatService.PostureBroken:Fire(attacker)
		end
		attacker.model:SetAttribute("Posture", Posture.Fraction(attacker.posture))
		CombatService.Deflected:Fire(target, attacker)
	end

	-- Parry / Needle Counter reflect posture damage back to the attacker, and stagger it.
	if (res.outcome == "Parried" or res.outcome == "Countered") and attacker and not hit.ranged then
		CombatService.Staggered:Fire(attacker, if res.outcome == "Countered" then CombatConfig.Counter.stagger else CombatConfig.ParriedStaggerSeconds)
		if Posture.Add(attacker.posture, res.reflectPosture, now, attacker.brokenSeconds) then
			if attacker.rules then
				attacker.rules.stunnedUntil = now + attacker.brokenSeconds
			end
			CombatService.PostureBroken:Fire(attacker)
		end
		attacker.model:SetAttribute("Posture", Posture.Fraction(attacker.posture))
		if target.player then
			QuestService.Increment(target.player, "PerfectParries", 1)
			AnalyticsService.Onboarding(target.player, "FirstParry")
		end
	end

	broadcast({
		kind = "Damage",
		sourceId = attacker and attacker.id,
		targetId = target.id,
		damage = damage,
		postureDamage = postureDamage,
		outcome = res.outcome,
		moveId = hit.moveId,
		postureFrac = Posture.Fraction(target.posture),
		broken = broke,
		riposte = hit.riposte,
		severing = hit.severing,
		shadow = hit.shadow,
		crit = hit.crit,
		source = hit.source,
		color = hit.color,
	})
	target.model:SetAttribute("Posture", Posture.Fraction(target.posture))
	syncUltimate(target)
	if attacker then
		syncUltimate(attacker)
	end
	CombatService.Damaged:Fire(target, attacker, res)

	if target.humanoid.Health <= 0 and not target.dead then
		target.dead = true
		CombatService.Died:Fire(target, target.contributions)
	end
	return res
end

-- Finds enemies of `attacker` inside the move's arc, using server positions only.
-- aim (optional): horizontal unit direction to swing toward; defaults to the root's facing.
function CombatService.TargetsInArc(attacker: Combatant, range: number, arcDegrees: number, aim: Vector3?): { Combatant }
	local out = {}
	local pos = attacker.root.Position
	local look = aim or attacker.root.CFrame.LookVector
	for _, c in combatants do
		if c.team ~= attacker.team and not c.dead and c.humanoid.Health > 0 then
			local tp = c.root.Position
			if math.abs(tp.Y - pos.Y) < 12 and CombatRules.InArc(pos.X, pos.Z, look.X, look.Z, tp.X, tp.Z, range, arcDegrees) then
				table.insert(out, c)
			end
		end
	end
	table.sort(out, function(a, b)
		return (a.root.Position - pos).Magnitude < (b.root.Position - pos).Magnitude
	end)
	while #out > MAX_TARGETS_PER_SWING do
		table.remove(out)
	end
	return out
end

-- Client aim is only a direction (range/arc/cooldowns stay server-side), so accepting it is
-- safe; anything that is not a finite, roughly unit Vector3 is ignored.
local function sanitizeAim(v: any): Vector3?
	if typeof(v) ~= "Vector3" then
		return nil
	end
	local flat = Vector3.new(v.X, 0, v.Z)
	local m = flat.Magnitude
	if m ~= m or m < 0.5 or m > 1.5 then
		return nil
	end
	return flat / m
end

local function defaultKnockback(action: string): number
	local d = CombatConfig.DefaultKnockback
	if action == "HeavyAttack" then
		return d.heavy
	elseif action == "Ultimate" then
		return d.ultimate
	elseif action == "Skill1" or action == "Skill2" then
		return d.skill
	end
	return d.light
end

-- Pushes a combatant. NPCs are server-owned, so the server applies a short LinearVelocity;
-- player characters are owned by their client, which applies the same push locally.
function CombatService.Knockback(target: Combatant, velocity: Vector3)
	if velocity.Magnitude < 1 then
		return
	end
	if target.player then
		Net.Server.Fire("CombatEvent", target.player, { kind = "Knockback", velocity = velocity, seconds = CombatConfig.KnockbackSeconds })
		return
	end
	local root = target.root
	local att = Instance.new("Attachment")
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = math.huge
	lv.VectorVelocity = velocity
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = root
	task.delay(CombatConfig.KnockbackSeconds, function()
		lv:Destroy()
		att:Destroy()
	end)
end

local function onCombatAction(player: Player, req: { [string]: any })
	local c = byPlayer[player]
	local data = DataService.GetData(player)
	if c == nil or data == nil or c.dead then
		return
	end
	local action, seq = req.action, req.seq
	if type(action) ~= "string" or not VALID_ACTIONS[action] or type(seq) ~= "number" or seq ~= seq then
		return
	end
	if action == "Flask" then
		local rules = c.rules :: CombatRules.State
		local now0 = os.clock()
		if (c.flask or 0) <= 0 or now0 < rules.stunnedUntil or now0 < rules.busyUntil then
			Net.Server.Fire("CombatEvent", player, { kind = "Rejected", seq = seq, reason = if (c.flask or 0) <= 0 then "FlaskEmpty" else "Busy" })
			return
		end
		c.flask = (c.flask or 0) - 1
		c.model:SetAttribute("Flask", c.flask)
		rules.busyUntil = now0 + CombatConfig.Flask.drinkSeconds
		rules.blockUntil = 0
		broadcast({ kind = "Action", sourceId = c.id, action = "Flask", seq = seq })
		task.delay(CombatConfig.Flask.drinkSeconds * 0.7, function()
			if not c.dead and byPlayer[player] == c then
				CombatService.Heal(c, c.humanoid.MaxHealth * CombatConfig.Flask.heal)
			end
		end)
		return
	end
	if action == "SpiritCall" then
		if CombatService.OnSpiritCall then
			CombatService.OnSpiritCall(player)
		end
		return
	end
	local now = os.clock()
	local style = StyleConfig.Get(data.fightingStyle)
	local hum = c.humanoid
	local airborne = hum.FloorMaterial == Enum.Material.Air
		or hum:GetState() == Enum.HumanoidStateType.Freefall
		or hum:GetState() == Enum.HumanoidStateType.Jumping
	local decision = CombatRules.Validate(c.rules :: CombatRules.State, data.equippedWeapon, action, seq, now, { airborne = airborne })
	if not decision.ok then
		Net.Server.Fire("CombatEvent", player, { kind = "Rejected", seq = seq, reason = decision.reason })
		return
	end
	local stats = CombatService.PlayerStats(player)
	local dodgeMult = (1 - (stats.Haste or 0)) * style.dashCooldown
	CombatRules.Commit(c.rules :: CombatRules.State, decision, now, dodgeMult, { speed = style.speed, parryWindowBonus = style.parryWindowBonus })
	syncUltimate(c)
	if action == "Dodge" then
		c.dodgeAt = now
		c.dodgeDir = sanitizeAim(req.move) or c.root.CFrame.LookVector
	end
	broadcast({ kind = "Action", sourceId = c.id, action = action, moveId = decision.moveId, seq = seq, route = decision.kind, speed = style.speed })

	local moveId = decision.moveId
	local move = moveId and WeaponConfig.Moves[moveId]
	if move == nil or move.damage <= 0 then
		return
	end
	local power = ProgressionService.GetPower(player)
	local aim = sanitizeAim(req.aim)
	local kb = move.knockback or defaultKnockback(action)
	task.delay(move.windup / style.speed, function()
		-- Interrupted by posture break or death during windup: no hit.
		local rules = c.rules :: CombatRules.State
		if c.dead or os.clock() < rules.stunnedUntil or byPlayer[player] ~= c then
			return
		end
		-- A riposte (first hit right after a perfect parry) hits much harder.
		local riposte = os.clock() < rules.riposteUntil
		local mult = if riposte then CombatConfig.RiposteMultiplier + style.riposteBonus else 1
		local hitAny = false
		local attackMult = 1 + (CombatService.PlayerStats(player).Attack or 0)
		for _, target in CombatService.TargetsInArc(c, move.range + (move.step or 0) * 0.5, move.arcDegrees, aim) do
			hitAny = true
			-- Severing Blow: an enemy with broken posture is finished (bosses lose a big chunk).
			local shadow = target.kind == "Enemy" and target.unaware == true and not target.dead
			if target.kind ~= "Player" and (shadow or Posture.IsBroken(target.posture, os.clock())) then
				local sever = if target.kind == "Boss" then target.humanoid.MaxHealth * CombatConfig.Severing.bossFraction else target.humanoid.Health + 1
				target.posture.brokenUntil = os.clock()
				target.posture.value = 0
				target.model:SetAttribute("Broken", false)
				CombatService.ApplyHit(c, target, {
					damage = sever,
					postureDamage = 0,
					moveId = moveId :: string,
					knockback = kb * 2,
					severing = true,
					shadow = shadow,
				})
				continue
			end
			local critMult, crit = CombatService.RollCrit(player)
			CombatService.ApplyHit(c, target, {
				crit = crit,
				damage = CombatRules.ScaleDamage(move.damage, power, rng:NextNumber()) * style.damage * mult * attackMult * critMult,
				postureDamage = move.postureDamage * style.posture * mult,
				perilous = false,
				moveId = moveId :: string,
				knockback = kb * style.knockback,
				launch = move.launch,
				riposte = riposte,
			})
		end
		if riposte and hitAny then
			rules.riposteUntil = 0
		end
	end)
end

local playerCounter = 0
local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if humanoid == nil or root == nil then
		return
	end
	local old = byPlayer[player]
	if old then
		CombatService.Unregister(old.id)
	end
	local data = DataService.WaitForData(player, 20)
	local level = if data then data.level else 1
	statCache[player] = nil
	humanoid.MaxHealth = maxHealthFor(player, level)
	humanoid.Health = humanoid.MaxHealth
	playerCounter += 1
	local c: Combatant = {
		id = "P" .. player.UserId .. "_" .. playerCounter,
		kind = "Player",
		team = "Players",
		defId = nil,
		model = character,
		root = root,
		humanoid = humanoid,
		player = player,
		posture = Posture.new(CombatConfig.PlayerMaxPosture, CombatConfig.PostureRegenPerSecond, CombatConfig.PostureRegenDelay),
		brokenSeconds = CombatConfig.PostureBrokenStun,
		power = 0,
		rules = CombatRules.NewState(),
		invulnerable = false,
		dead = false,
		contributions = {},
	}
	c.flask = CombatConfig.Flask.charges
	character:SetAttribute("Flask", c.flask)
	c.breath = true
	character:SetAttribute("Breath", true)
	CombatService.Register(c)
	humanoid.Died:Connect(function()
		c.dead = true
	end)
end

function CombatService.Init() end

function CombatService.Start()
	Net.Server.On("CombatAction", onCombatAction)
	-- Level ups raise max health immediately and heal to full.
	ProgressionService.LevelUp:Connect(function(player: Player, level: number)
		local c = byPlayer[player]
		if c and not c.dead then
			c.humanoid.MaxHealth = maxHealthFor(player, level)
			c.humanoid.Health = c.humanoid.MaxHealth
		end
	end)
	-- Spirit party changes: new stats, new max health (keeps the same health fraction).
	SpiritService.CollectionChanged:Connect(function(player: Player)
		statCache[player] = nil
		local c = byPlayer[player]
		local data = DataService.GetData(player)
		if c and data and not c.dead then
			local frac = c.humanoid.Health / math.max(1, c.humanoid.MaxHealth)
			c.humanoid.MaxHealth = maxHealthFor(player, data.level)
			c.humanoid.Health = c.humanoid.MaxHealth * frac
		end
	end)
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		statCache[player] = nil
		local c = byPlayer[player]
		if c then
			CombatService.Unregister(c.id)
		end
	end)

	-- Posture regen + replication at 10 Hz.
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		local step = acc
		acc = 0
		local now = os.clock()
		for _, c in combatants do
			-- Players heal quickly once they have been out of combat for a moment.
			if c.player and not c.dead then
				local hum = c.humanoid
				-- Healing areas also refill the Spring Flask and Second Breath.
				if (c.flask or 0) < CombatConfig.Flask.charges or not c.breath then
					local p = c.root.Position
					for _, h in healAreas do
						if (Vector3.new(p.X, 0, p.Z) - h.center).Magnitude <= h.radius then
							c.flask = CombatConfig.Flask.charges
							c.model:SetAttribute("Flask", c.flask)
							c.breath = true
							c.model:SetAttribute("Breath", true)
							break
						end
					end
				end
				if hum.Health > 0 and hum.Health < hum.MaxHealth then
					local rate = if now - (lastHurtAt[c] or 0) >= CombatConfig.OutOfCombatRegenDelay then CombatConfig.OutOfCombatRegenPerSecond else 0
					-- Healing areas (hot springs) work even mid-fight.
					local pos = c.root.Position
					for _, h in healAreas do
						if (Vector3.new(pos.X, 0, pos.Z) - h.center).Magnitude <= h.radius then
							rate = math.max(rate, h.rate)
						end
					end
					if rate > 0 then
						hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * rate * step)
					end
				end
			end
			if c.shield and c.shield > 0 and c.shieldUntil and now >= c.shieldUntil then
				c.shield = 0
				syncShield(c)
			end
			local before = c.posture.value
			local hpFrac = c.humanoid.Health / math.max(1, c.humanoid.MaxHealth)
			local regen = CombatConfig.PostureHealthFloor + (1 - CombatConfig.PostureHealthFloor) * hpFrac
			if c.rules and CombatRules.IsGuarding(c.rules, now) then
				regen *= CombatConfig.GuardPostureRegen
			end
			Posture.Update(c.posture, now, step * regen)
			if c.model:GetAttribute("Broken") == true and not Posture.IsBroken(c.posture, now) then
				c.model:SetAttribute("Broken", false)
			end
			if math.abs(before - c.posture.value) > 0.5 or (before > 0 and c.posture.value == 0) then
				c.model:SetAttribute("Posture", Posture.Fraction(c.posture))
			end
		end
	end)
end

return CombatService
