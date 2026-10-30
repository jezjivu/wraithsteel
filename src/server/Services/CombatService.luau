--!strict
-- CombatService: server-authoritative combat (guide §8.2 rule 3).
-- Clients send CombatAction requests ({action, seq}); this service validates them with
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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local CombatConfig = require(Config:WaitForChild("CombatConfig"))
local WeaponConfig = require(Config:WaitForChild("WeaponConfig"))

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
}

export type Hit = {
	damage: number,
	postureDamage: number,
	perilous: boolean?,
	moveId: string,
}

local MAX_TARGETS_PER_SWING = 4
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
}

local combatants: { [string]: Combatant } = {}
local byPlayer: { [Player]: Combatant } = {}
local rng = Random.new()

function CombatService.Register(c: Combatant)
	combatants[c.id] = c
	if c.player then
		byPlayer[c.player] = c
	end
	c.model:SetAttribute("CombatantId", c.id)
end

function CombatService.Unregister(id: string)
	local c = combatants[id]
	if c then
		combatants[id] = nil
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
	end
	if Posture.Add(target.posture, postureDamage, now, target.brokenSeconds) then
		if target.rules then
			target.rules.stunnedUntil = now + target.brokenSeconds
		end
		CombatService.PostureBroken:Fire(target)
		if attacker and attacker.player then
			QuestService.Increment(attacker.player, "PostureBreaks", 1)
		end
	end

	-- Parry reflects posture damage back to the attacker.
	if res.outcome == "Parried" and attacker then
		if Posture.Add(attacker.posture, res.reflectPosture, now, attacker.brokenSeconds) then
			CombatService.PostureBroken:Fire(attacker)
		end
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
	})
	CombatService.Damaged:Fire(target, attacker, res)

	if target.humanoid.Health <= 0 and not target.dead then
		target.dead = true
		CombatService.Died:Fire(target, target.contributions)
	end
	return res
end

-- Finds enemies of `attacker` inside the move's arc, using server positions only.
function CombatService.TargetsInArc(attacker: Combatant, range: number, arcDegrees: number): { Combatant }
	local out = {}
	local pos = attacker.root.Position
	local look = attacker.root.CFrame.LookVector
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
	local decision = CombatRules.Validate(c.rules :: CombatRules.State, data.equippedWeapon, action, seq, now)
	if not decision.ok then
		Net.Server.Fire("CombatEvent", player, { kind = "Rejected", seq = seq, reason = decision.reason })
		return
	end
	local dodgeMult = 1 + SpiritLogic.PassiveTotal(data :: any, "DodgeCooldown")
	CombatRules.Commit(c.rules :: CombatRules.State, decision, now, dodgeMult)
	broadcast({ kind = "Action", sourceId = c.id, action = action, moveId = decision.moveId, seq = seq })

	local moveId = decision.moveId
	local move = moveId and WeaponConfig.Moves[moveId]
	if move == nil or move.damage <= 0 then
		return
	end
	local power = ProgressionService.GetPower(player)
	task.delay(move.windup, function()
		-- Interrupted by posture break or death during windup: no hit.
		local rules = c.rules :: CombatRules.State
		if c.dead or os.clock() < rules.stunnedUntil or byPlayer[player] ~= c then
			return
		end
		for _, target in CombatService.TargetsInArc(c, move.range, move.arcDegrees) do
			CombatService.ApplyHit(c, target, {
				damage = CombatRules.ScaleDamage(move.damage, power, rng:NextNumber()),
				postureDamage = move.postureDamage,
				perilous = false,
				moveId = moveId :: string,
			})
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
	Net.Server.On("EquipWeapon", function(player, weaponId)
		local data = DataService.GetData(player)
		if data and data.weapons[weaponId] and WeaponConfig.Weapons[weaponId] then
			data.equippedWeapon = weaponId
			DataService.Changed(player, "equippedWeapon")
			ProgressionService.RefreshPower(player)
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
			local before = c.posture.value
			Posture.Update(c.posture, now, step)
			if math.abs(before - c.posture.value) > 0.5 or (before > 0 and c.posture.value == 0) then
				c.model:SetAttribute("Posture", Posture.Fraction(c.posture))
			end
		end
	end)
end

return CombatService
