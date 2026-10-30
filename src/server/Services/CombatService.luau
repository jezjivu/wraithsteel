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
}

export type Hit = {
	damage: number,
	postureDamage: number,
	perilous: boolean?,
	moveId: string,
	knockback: number?, -- studs/s away from the attacker
	launch: number?, -- studs/s upward
	riposte: boolean?, -- empowered counter after a perfect parry (for effects)
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
}

local CombatService = {
	Name = "CombatService",
	Priority = 23,
	Damaged = Signal.new(),
	PostureBroken = Signal.new(),
	Died = Signal.new(),
	Staggered = Signal.new(), -- (combatant, seconds): its attack was parried
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

-- Mirrors ultimate charge (0..1) to the character for the HUD.
local function syncUltimate(c: Combatant)
	if c.rules then
		c.model:SetAttribute("Ultimate", c.rules.ultimateCharge / WeaponConfig.UltimateChargeMax)
	end
end

local function broadcast(payload: { [string]: any })
	Net.Server.FireAll("CombatEvent", payload)
end

-- Applies a hit to `target`. Players resolve parry/block/dodge; enemies/bosses take it directly.
function CombatService.ApplyHit(attacker: Combatant?, target: Combatant, hit: Hit): CombatRules.Resolution?
	if target.dead or target.invulnerable or target.humanoid.Health <= 0 then
		return nil
	end
	local now = os.clock()
	local res: CombatRules.Resolution
	if target.rules then
		res = CombatRules.ResolveIncoming(target.rules, hit, now)
	elseif target.guardUntil and now < target.guardUntil and not hit.perilous then
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
	if Posture.IsBroken(target.posture, now) then
		damage *= CombatConfig.PostureBrokenDamageMultiplier
	end
	local postureDamage = res.postureDamage
	if target.player then
		local data = DataService.GetData(target.player)
		if data then
			postureDamage *= 1 + SpiritLogic.PassiveTotal(data :: any, "PostureDamageTaken")
		end
	end
	if attacker and attacker.player then
		local data = DataService.GetData(attacker.player)
		if data then
			postureDamage *= 1 + SpiritLogic.PassiveTotal(data :: any, "PostureDamageDealt")
		end
		target.contributions[attacker.player] = (target.contributions[attacker.player] or 0) + damage
		if attacker.rules then
			attacker.rules.ultimateCharge = math.min(
				WeaponConfig.UltimateChargeMax,
				attacker.rules.ultimateCharge + postureDamage * WeaponConfig.UltimateChargePerPostureDamage
			)
		end
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

	-- Parry reflects posture damage back to the attacker, and staggers it.
	if res.outcome == "Parried" and attacker then
		CombatService.Staggered:Fire(attacker, CombatConfig.ParriedStaggerSeconds)
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
			local data = DataService.GetData(target.player)
			local bonus = if data then SpiritLogic.PassiveTotal(data :: any, "EmberOnParry") else 0
			if bonus > 0 then
				ProgressionService.AddEmber(target.player, bonus, "Parry")
			end
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
	local dodgeMult = (1 + SpiritLogic.PassiveTotal(data :: any, "DodgeCooldown")) * style.dashCooldown
	CombatRules.Commit(c.rules :: CombatRules.State, decision, now, dodgeMult, { speed = style.speed, parryWindowBonus = style.parryWindowBonus })
	syncUltimate(c)
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
		for _, target in CombatService.TargetsInArc(c, move.range + (move.step or 0) * 0.5, move.arcDegrees, aim) do
			hitAny = true
			CombatService.ApplyHit(c, target, {
				damage = CombatRules.ScaleDamage(move.damage, power, rng:NextNumber()) * style.damage * mult,
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
	humanoid.MaxHealth = CombatConfig.PlayerMaxHealth + (level - 1) * CombatConfig.PlayerHealthPerLevel
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
			c.humanoid.MaxHealth = CombatConfig.PlayerMaxHealth + (level - 1) * CombatConfig.PlayerHealthPerLevel
			c.humanoid.Health = c.humanoid.MaxHealth
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
			local before = c.posture.value
			Posture.Update(c.posture, now, step)
			if math.abs(before - c.posture.value) > 0.5 or (before > 0 and c.posture.value == 0) then
				c.model:SetAttribute("Posture", Posture.Fraction(c.posture))
			end
		end
	end)
end

return CombatService
