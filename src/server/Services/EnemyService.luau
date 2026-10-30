--!strict
-- EnemyService: spawns regular enemies and runs their AI.
--   * AI runs on Logic/AIScheduler (batched, staggered, EnemyConfig.AITickRate Hz).
--   * Logic/AttackDirector limits how many enemies attack one player at once (attack tokens);
--     enemies without a token circle at their preferred range.
--   * Hits are resolved through CombatService.ApplyHit (players can parry/block/dodge).
--
-- Studio setup (TODO(Studio/Agent D + C)):
--   Workspace.EnemySpawns/<Part>  attributes: EnemyId (string), Count (number), RespawnSeconds (number)
--   ServerStorage.Enemies/<EnemyId>  rig Model with Humanoid + HumanoidRootPart.
--   Without a rig, a grey placeholder block is spawned so the loop is playtestable.
--
-- API:
--   EnemyService.Spawn(enemyId, cframe) -> Combatant
--   EnemyService.Defeated: Signal(enemyId, contributions)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local Odds = require(Shared:WaitForChild("Odds"))
local Signal = require(Shared:WaitForChild("Signal"))
local EnemyConfig = require(Config:WaitForChild("EnemyConfig"))
local EconomyConfig = require(Config:WaitForChild("EconomyConfig"))
local PartyConfig = require(Config:WaitForChild("PartyConfig"))

local Logic = script.Parent.Parent:WaitForChild("Logic")
local AIScheduler = require(Logic:WaitForChild("AIScheduler"))
local AttackDirector = require(Logic:WaitForChild("AttackDirector"))
local CombatRules = require(Logic:WaitForChild("CombatRules"))
local Posture = require(Logic:WaitForChild("Posture"))

local RigBuilder = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("RigBuilder"))
local CombatService = require(script.Parent.CombatService)
local ProgressionService = require(script.Parent.ProgressionService)
local QuestService = require(script.Parent.QuestService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local PartyService = require(script.Parent.PartyService)

type Combatant = CombatService.Combatant

type Brain = {
	c: Combatant,
	def: EnemyConfig.EnemyDef,
	home: Vector3,
	target: Combatant?,
	busyUntil: number,
	stunnedUntil: number,
	nextAttackAt: number,
	circleAngle: number,
	token: number, -- bumped on flinch/break to cancel queued combo strikes
	activeFrom: number, -- current strike's active window (flinch can't interrupt it)
	activeTo: number,
	flinchReadyAt: number,
}

local EnemyService = {
	Name = "EnemyService",
	Priority = 30,
	Defeated = Signal.new(),
}

local scheduler = AIScheduler.new(EnemyConfig.AITickRate, EnemyConfig.MaxEnemiesPerTickSlice)
local director = AttackDirector.new(EnemyConfig.AttackTokensPerPlayer, EnemyConfig.AttackTokenDuration, EnemyConfig.AttackTokenCooldown)
local brains: { [string]: Brain } = {}
local rng = Random.new()
local counter = 0

local function placeholderRig(name: string): Model
	-- TODO(Studio/Agent C): replace with real rigs in ServerStorage.Enemies.
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = false
	root.Parent = model
	local body = Instance.new("Part")
	body.Name = "Torso"
	body.Size = Vector3.new(2.5, 4, 1.5)
	body.Color = Color3.fromRGB(110, 100, 95)
	body.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = body
	weld.Parent = root
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.5, 1.5, 1.5)
	head.Color = Color3.fromRGB(150, 70, 60)
	head.Position = Vector3.new(0, 2.75, 0)
	head.Parent = model
	local weld2 = Instance.new("WeldConstraint")
	weld2.Part0 = body
	weld2.Part1 = head
	weld2.Parent = body
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 2
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

local function getRig(enemyId: string): Model
	local folder = ServerStorage:FindFirstChild(EnemyConfig.TemplateFolderName)
	local template = folder and folder:FindFirstChild(enemyId)
	if template and template:IsA("Model") then
		return template:Clone()
	end
	-- No Studio rig yet: build a code-made R15 humanoid from the config look.
	local def = EnemyConfig.Enemies[enemyId]
	if def and def.look then
		local rig = RigBuilder.Build(def.look, def.name)
		if rig then
			return rig
		end
	end
	return placeholderRig(enemyId)
end

local function nearestPlayer(b: Brain): (Combatant?, number)
	local best, bestDist = nil, math.huge
	local pos = b.c.root.Position
	for _, player in Players:GetPlayers() do
		local pc = CombatService.GetByPlayer(player)
		if pc and not pc.dead then
			local d = (pc.root.Position - pos).Magnitude
			if d < bestDist and d <= b.def.aggroRange and (pc.root.Position - b.home).Magnitude <= b.def.leashRange then
				best, bestDist = pc, d
			end
		end
	end
	return best, bestDist
end

local function chooseAttack(b: Brain, dist: number): string?
	local entries = {}
	for id, a in b.def.attacks do
		if dist <= a.range + 1 then
			table.insert(entries, { id = id, weight = a.weight })
		end
	end
	if #entries == 0 then
		return nil
	end
	table.sort(entries, function(x, y)
		return x.id < y.id
	end)
	return Odds.Roll(entries, 1, function()
		return rng:NextNumber()
	end)
end

local function face(b: Brain, pos: Vector3)
	local root = b.c.root
	local flat = Vector3.new(pos.X, root.Position.Y, pos.Z)
	if (flat - root.Position).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
end

-- Surges the (server-owned) rig forward during a strike's active frames.
local function lunge(b: Brain, studs: number, seconds: number)
	local root = b.c.root
	local dir = root.CFrame.LookVector
	local speed = studs / math.max(seconds, 0.05)
	local untilT = os.clock() + seconds
	task.spawn(function()
		while os.clock() < untilT and not b.c.dead and root.Parent do
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(dir.X * speed, v.Y, dir.Z * speed)
			task.wait()
		end
	end)
end

-- One strike: telegraph now, hit at windup end. Returns nothing; checks `token` so a flinch
-- or posture break cancels strikes that are still queued.
local function strike(b: Brain, attackId: string, token: number)
	local a = b.def.attacks[attackId]
	if a == nil or b.c.dead or b.token ~= token then
		return
	end
	local target = b.target
	if target then
		face(b, target.root.Position)
	end
	local start = os.clock()
	b.activeFrom = start + a.windup
	b.activeTo = start + a.windup + a.active
	Net.Server.FireAll("CombatEvent", {
		kind = "Telegraph",
		sourceId = b.c.id,
		moveId = attackId,
		perilous = a.perilous == true,
		windup = a.windup,
		active = a.active,
		recovery = a.recovery,
		animationId = a.animationId,
	})
	task.delay(a.windup, function()
		if b.c.dead or b.token ~= token or os.clock() < b.stunnedUntil then
			return
		end
		if a.lunge then
			lunge(b, a.lunge, a.active)
		end
		local pos = b.c.root.Position
		local look = b.c.root.CFrame.LookVector
		for _, player in Players:GetPlayers() do
			local pc = CombatService.GetByPlayer(player)
			if pc and not pc.dead then
				local tp = pc.root.Position
				if CombatRules.InArc(pos.X, pos.Z, look.X, look.Z, tp.X, tp.Z, a.range + (a.lunge or 0), a.arcDegrees) then
					CombatService.ApplyHit(b.c, pc, {
						damage = a.damage,
						postureDamage = a.postureDamage,
						perilous = a.perilous,
						moveId = attackId,
					})
				end
			end
		end
	end)
end

-- Starts a single attack or (sometimes) a combo string beginning with it.
local function startAttack(b: Brain, attackId: string, now: number)
	local sequence = { attackId }
	local combos = b.def.combos
	if combos and #combos > 0 and rng:NextNumber() < (b.def.comboChance or 0) then
		sequence = combos[rng:NextInteger(1, #combos)]
	end
	b.c.humanoid:MoveTo(b.c.root.Position)
	local token = b.token
	local t = 0
	for i, id in sequence do
		local a = b.def.attacks[id]
		if a then
			task.delay(t, strike, b, id, token)
			t += a.windup + a.active + (if i < #sequence then EnemyConfig.ComboGap else a.recovery)
		end
	end
	b.busyUntil = now + t
	task.delay(t, function()
		director:Release(b.c.id, os.clock())
	end)
	b.nextAttackAt = now + t + b.def.attackCooldown
end

-- Called when this enemy takes a hit: light enemies flinch (outside their active frames),
-- some raise a guard that soaks health damage until their posture breaks.
local function onHurt(b: Brain)
	local now = os.clock()
	if b.c.dead then
		return
	end
	local inActive = now >= b.activeFrom and now <= b.activeTo
	if b.def.flinch and not inActive and now >= b.flinchReadyAt then
		b.token += 1
		b.flinchReadyAt = now + EnemyConfig.FlinchCooldown
		b.stunnedUntil = math.max(b.stunnedUntil, now + EnemyConfig.FlinchSeconds)
		b.busyUntil = 0
		director:Release(b.c.id, now)
		Net.Server.FireAll("CombatEvent", { kind = "Flinch", sourceId = b.c.id })
	end
	local guard = b.def.guardChance
	if guard and not inActive and (b.c.guardUntil or 0) < now and rng:NextNumber() < guard then
		b.c.guardUntil = now + EnemyConfig.GuardSeconds
		Net.Server.FireAll("CombatEvent", { kind = "Guard", sourceId = b.c.id, seconds = EnemyConfig.GuardSeconds })
	end
end

local function think(b: Brain, _dt: number, now: number)
	if b.c.dead or now < b.busyUntil or now < b.stunnedUntil then
		return
	end
	local target, dist = nearestPlayer(b)
	b.target = target
	local humanoid = b.c.humanoid
	if target == nil then
		director:Release(b.c.id, now)
		if (b.c.root.Position - b.home).Magnitude > 4 then
			humanoid:MoveTo(b.home)
		end
		return
	end
	if now >= b.nextAttackAt then
		local attackId = chooseAttack(b, dist)
		if attackId and director:Request(b.c.id, target.id, now) then
			startAttack(b, attackId, now)
			return
		end
	end
	local tp = target.root.Position
	if dist > b.def.preferredRange + 2 then
		humanoid:MoveTo(tp)
	else
		-- Circle at preferred range while waiting for a token / cooldown.
		b.circleAngle += 0.35
		local offset = Vector3.new(math.cos(b.circleAngle), 0, math.sin(b.circleAngle)) * b.def.preferredRange
		humanoid:MoveTo(tp + offset)
		face(b, tp)
	end
end

function EnemyService.Spawn(enemyId: string, cframe: CFrame, onDespawn: (() -> ())?): Combatant?
	local def = EnemyConfig.Enemies[enemyId]
	if def == nil then
		warn("[EnemyService] unknown enemy", enemyId)
		return nil
	end
	counter += 1
	local id = "E" .. counter
	local model = getRig(enemyId)
	model.Name = def.name
	model:PivotTo(cframe)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	-- Stand the rig on the spawn point (scaled bosses have tall hips).
	model:PivotTo(cframe + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
	humanoid.MaxHealth = def.maxHealth
	humanoid.Health = def.maxHealth
	humanoid.WalkSpeed = def.walkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- client draws its own bars
	-- With instance streaming, send the whole rig at once (animations need every joint).
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.Parent = workspace
	root:SetNetworkOwner(nil)

	local c: Combatant = {
		id = id,
		kind = "Enemy",
		team = "Enemies",
		defId = enemyId,
		model = model,
		root = root,
		humanoid = humanoid,
		player = nil,
		posture = Posture.new(def.maxPosture, def.postureRegen, 1.5),
		brokenSeconds = EnemyConfig.PostureBrokenSeconds,
		power = 0,
		rules = nil,
		invulnerable = false,
		dead = false,
		contributions = {},
	}
	CombatService.Register(c)
	local brain: Brain = {
		c = c,
		def = def,
		home = cframe.Position,
		target = nil,
		busyUntil = 0,
		stunnedUntil = 0,
		nextAttackAt = 0,
		circleAngle = rng:NextNumber() * math.pi * 2,
		token = 0,
		activeFrom = 0,
		activeTo = 0,
		flinchReadyAt = 0,
	}
	brains[id] = brain
	scheduler:Add(id, function(dt, now)
		think(brain, dt, now)
	end, os.clock())

	humanoid.Died:Connect(function()
		scheduler:Remove(id)
		director:Release(id, os.clock())
		task.delay(EnemyConfig.DespawnAfterDeath, function()
			CombatService.Unregister(id)
			brains[id] = nil
			model:Destroy()
			if onDespawn then
				onDespawn()
			end
		end)
	end)
	return c
end

local function rewardKill(c: Combatant, contributions: { [Player]: number })
	local def = c.defId and EnemyConfig.Enemies[c.defId]
	if def == nil or def.training then
		return
	end
	-- Everyone who hit it, plus their party members nearby, gets the full reward.
	local recipients: { [Player]: boolean } = {}
	for player, dealt in contributions do
		if dealt > 0 and player.Parent == Players then
			for _, member in PartyService.MembersNear(player, PartyConfig.ShareRadius) do
				recipients[member] = true
			end
		end
	end
	for player in recipients do
		if player.Parent == Players then
			ProgressionService.AddEmber(player, def.emberReward + EconomyConfig.EnemyEmberBase, "Enemy:" .. (c.defId :: string))
			ProgressionService.AddXp(player, def.xpReward + EconomyConfig.EnemyXpBase)
			QuestService.Increment(player, "EnemiesDefeated", 1)
			AnalyticsService.Onboarding(player, "FirstEnemyDefeated")
		end
	end
	EnemyService.Defeated:Fire(c.defId, contributions)
end

local function runSpawner(spawnPart: BasePart)
	local enemyId = spawnPart:GetAttribute("EnemyId")
	if type(enemyId) ~= "string" then
		warn("[EnemyService] spawn", spawnPart:GetFullName(), "has no EnemyId attribute")
		return
	end
	local count = tonumber(spawnPart:GetAttribute("Count")) or 1
	local respawn = tonumber(spawnPart:GetAttribute("RespawnSeconds")) or EnemyConfig.DefaultRespawnSeconds
	local scatter = tonumber(spawnPart:GetAttribute("Scatter")) or EnemyConfig.DefaultSpawnScatter
	local function spawnOne()
		local offset = Vector3.new(rng:NextNumber(-scatter, scatter), 3, rng:NextNumber(-scatter, scatter))
		EnemyService.Spawn(enemyId, spawnPart.CFrame + offset, function()
			task.delay(respawn, spawnOne)
		end)
	end
	for _ = 1, count do
		spawnOne()
	end
end

function EnemyService.Init() end

function EnemyService.Start()
	CombatService.Died:Connect(function(c, contributions)
		if c.kind == "Enemy" then
			rewardKill(c, contributions)
		end
	end)
	CombatService.Damaged:Connect(function(c, attacker)
		local b = brains[c.id]
		if b and attacker and attacker.player then
			onHurt(b)
		end
	end)
	CombatService.PostureBroken:Connect(function(c)
		local b = brains[c.id]
		if b then
			b.token += 1
			c.guardUntil = nil
			b.stunnedUntil = os.clock() + c.brokenSeconds
			b.busyUntil = 0
			director:Release(c.id, os.clock())
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local pc = CombatService.GetByPlayer(player)
		if pc then
			director:RemoveTarget(pc.id)
		end
	end)

	RunService.Heartbeat:Connect(function()
		scheduler:Step(os.clock())
	end)

	local spawns = workspace:FindFirstChild(EnemyConfig.SpawnFolderName)
	if spawns then
		for _, part in spawns:GetChildren() do
			if part:IsA("BasePart") then
				task.spawn(runSpawner, part)
			end
		end
	else
		warn("[EnemyService] Workspace." .. EnemyConfig.SpawnFolderName .. " not found - no enemies spawned (build it in Studio)")
	end
end

return EnemyService
