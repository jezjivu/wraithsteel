--!strict
-- BossService: boss encounters driven by Logic/BossStateMachine (data in BossConfig).
-- One encounter per arena. Participants are the players near the arena when it starts
-- (PartyService will supply parties in Phase 3). Bosses ignore attack tokens.
--
-- Studio setup (TODO(Studio/Agent D + C)):
--   Workspace.BossArenas/<Part> with attribute BossId = "rust_tiger"; BossService adds a
--   ProximityPrompt "Challenge" to it. Boss rig: ServerStorage.Bosses/<bossId> (placeholder block
--   otherwise). Animations: BossConfig move animationId (all placeholders today).
--
-- API:
--   BossService.StartEncounter(bossId, cframe, participants) -> encounterId?
--   BossService.BossDefeated: Signal(bossId, participants: {Player}, firstClears: {Player})

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local BossConfig = require(Config:WaitForChild("BossConfig"))

local Logic = script.Parent.Parent:WaitForChild("Logic")
local BossStateMachine = require(Logic:WaitForChild("BossStateMachine"))
local CombatRules = require(Logic:WaitForChild("CombatRules"))
local Posture = require(Logic:WaitForChild("Posture"))

local DataService = require(script.Parent.DataService)
local CombatService = require(script.Parent.CombatService)
local ProgressionService = require(script.Parent.ProgressionService)
local QuestService = require(script.Parent.QuestService)
local AnalyticsService = require(script.Parent.AnalyticsService)

type Combatant = CombatService.Combatant

local TICK = 0.1
local STATE_BROADCAST_INTERVAL = 0.5
local CHALLENGE_RADIUS = 60
local ARENA_FOLDER = "BossArenas"

type Encounter = {
	id: string,
	bossId: string,
	arena: BasePart?,
	c: Combatant,
	sm: BossStateMachine.Machine,
	participants: { Player },
	target: Combatant?,
	lastBroadcast: number,
	ended: boolean,
}

local BossService = {
	Name = "BossService",
	Priority = 31,
	BossDefeated = Signal.new(),
}

local encounters: { [string]: Encounter } = {}
local busyArenas: { [BasePart]: boolean } = {}
local counter = 0
local rng = Random.new()

local function placeholderBoss(bossId: string): Model
	-- TODO(Studio/Agent C): real rig in ServerStorage.Bosses/<bossId>.
	local model = Instance.new("Model")
	model.Name = bossId
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(6, 5, 10)
	root.Color = Color3.fromRGB(150, 80, 40)
	root.Material = Enum.Material.CorrodedMetal
	root.Parent = model
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 2.5
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

local function getRig(bossId: string): Model
	local folder = ServerStorage:FindFirstChild("Bosses")
	local template = folder and folder:FindFirstChild(bossId)
	if template and template:IsA("Model") then
		return template:Clone()
	end
	return placeholderBoss(bossId)
end

local function aliveParticipants(e: Encounter): { Combatant }
	local out = {}
	for _, p in e.participants do
		local pc = CombatService.GetByPlayer(p)
		if p.Parent == Players and pc and not pc.dead then
			table.insert(out, pc)
		end
	end
	return out
end

local function broadcastState(e: Encounter)
	Net.Server.FireList("BossState", e.participants, {
		encounterId = e.id,
		bossId = e.bossId,
		state = e.sm.state,
		phase = e.sm.phase,
		hpFrac = e.c.humanoid.Health / e.c.humanoid.MaxHealth,
		postureFrac = Posture.Fraction(e.c.posture),
	})
end

local function face(e: Encounter, pos: Vector3)
	local root = e.c.root
	local flat = Vector3.new(pos.X, root.Position.Y, pos.Z)
	if (flat - root.Position).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
end

local function doHits(e: Encounter, moveId: string)
	local def = BossConfig.Bosses[e.bossId]
	local m = def.moves[moveId]
	local hits = m.hits or 1
	if m.minRange and e.target then
		-- Gap closer: lunge toward the target over the active window.
		-- TODO(Studio/Agent C): replace with animation root motion once rigs exist.
		local hum = e.c.humanoid
		local base = def.walkSpeed
		hum.WalkSpeed = math.max(base, m.range / math.max(m.active, 0.1))
		hum:MoveTo(e.target.root.Position)
		task.delay(m.active, function()
			hum.WalkSpeed = base
		end)
	end
	for i = 1, hits do
		task.delay((i - 1) * (m.active / hits), function()
			if e.ended or e.sm.state ~= "Active" or e.sm.move ~= moveId then
				return
			end
			local pos = e.c.root.Position
			local look = e.c.root.CFrame.LookVector
			for _, pc in aliveParticipants(e) do
				local tp = pc.root.Position
				if CombatRules.InArc(pos.X, pos.Z, look.X, look.Z, tp.X, tp.Z, m.range, m.arcDegrees) then
					CombatService.ApplyHit(e.c, pc, {
						damage = m.damage,
						postureDamage = m.postureDamage,
						perilous = m.perilous,
						moveId = moveId,
					})
				end
			end
		end)
	end
end

local function finish(e: Encounter, victory: boolean)
	if e.ended then
		return
	end
	e.ended = true
	encounters[e.id] = nil
	if e.arena then
		busyArenas[e.arena] = nil
	end
	broadcastState(e)
	if victory then
		local def = BossConfig.Bosses[e.bossId]
		local firstClears = {}
		for _, p in e.participants do
			local data = DataService.GetData(p)
			if p.Parent == Players and data then
				local first = (data.bossesDefeated[e.bossId] or 0) == 0
				data.bossesDefeated[e.bossId] = (data.bossesDefeated[e.bossId] or 0) + 1
				DataService.Changed(p, "bossesDefeated")
				ProgressionService.AddEmber(p, def.rewards.ember, "Boss:" .. e.bossId)
				ProgressionService.AddXp(p, def.rewards.xp)
				if first then
					ProgressionService.AddJade(p, def.rewards.jadeFirstClear, "BossFirstClear:" .. e.bossId)
					table.insert(firstClears, p)
				end
				QuestService.Increment(p, "Boss:" .. e.bossId, 1)
				if e.bossId == "rust_tiger" then
					AnalyticsService.Onboarding(p, "RustTigerDefeated")
				end
			end
		end
		BossService.BossDefeated:Fire(e.bossId, e.participants, firstClears)
		task.delay(5, function()
			CombatService.Unregister(e.c.id)
			e.c.model:Destroy()
		end)
	else
		CombatService.Unregister(e.c.id)
		e.c.model:Destroy()
	end
end

function BossService.StartEncounter(bossId: string, cframe: CFrame, participants: { Player }, arena: BasePart?): string?
	local def = BossConfig.Bosses[bossId]
	if def == nil or #participants == 0 then
		return nil
	end
	counter += 1
	local id = "B" .. counter
	local model = getRig(bossId)
	model.Name = def.name
	model:PivotTo(cframe)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local hp = BossStateMachine.ScaledHealth(bossId, #participants)
	humanoid.MaxHealth = hp
	humanoid.Health = hp
	humanoid.WalkSpeed = def.walkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- boss bar UI instead
	model.Parent = workspace
	root:SetNetworkOwner(nil)

	local c: Combatant = {
		id = id,
		kind = "Boss",
		team = "Enemies",
		defId = bossId,
		model = model,
		root = root,
		humanoid = humanoid,
		player = nil,
		posture = Posture.new(def.maxPosture, def.postureRegen, 2),
		brokenSeconds = def.postureBrokenSeconds,
		power = 0,
		rules = nil,
		invulnerable = false,
		dead = false,
		contributions = {},
	}
	CombatService.Register(c)

	local e: Encounter
	local sm = BossStateMachine.new(bossId, function()
		return rng:NextNumber()
	end, function(event, ...)
		local args = { ... }
		if event == "MoveStarted" then
			if e.target then
				face(e, e.target.root.Position)
			end
			e.c.humanoid:MoveTo(e.c.root.Position)
			local m = def.moves[args[1]]
			Net.Server.FireList("CombatEvent", e.participants, {
				kind = "Telegraph",
				sourceId = id,
				moveId = args[1],
				perilous = args[2],
				windup = m.windup / def.phases[e.sm.phase].speedMultiplier,
				animationId = m.animationId,
			})
		elseif event == "MoveActive" then
			doHits(e, args[1])
		elseif event == "PhaseChanged" then
			Net.Server.FireList("StoryEvent", e.participants, { kind = "BossPhase", bossId = bossId, phase = args[1] })
		end
		if event == "StateChanged" then
			e.c.invulnerable = e.sm.invulnerable
			broadcastState(e)
		end
	end)
	e = {
		id = id,
		bossId = bossId,
		arena = arena,
		c = c,
		sm = sm,
		participants = table.clone(participants),
		target = nil,
		lastBroadcast = 0,
		ended = false,
	}
	encounters[id] = e
	if arena then
		busyArenas[arena] = true
	end
	Net.Server.FireList("StoryEvent", participants, { kind = "BossIntro", bossId = bossId, name = def.name, title = def.title })
	return id
end

local function tick(now: number)
	for _, e in encounters do
		local alive = aliveParticipants(e)
		if #alive == 0 then
			finish(e, false)
			continue
		end
		local pos = e.c.root.Position
		local best, bestDist = nil, math.huge
		for _, pc in alive do
			local d = (pc.root.Position - pos).Magnitude
			if d < bestDist then
				best, bestDist = pc, d
			end
		end
		e.target = best
		e.sm:Update(now, {
			hasTarget = best ~= nil,
			targetDistance = bestDist,
			hpFraction = e.c.humanoid.Health / e.c.humanoid.MaxHealth,
		})
		if e.sm.state == "Dead" then
			finish(e, true)
			continue
		end
		if e.sm.state == "Chase" and best then
			local speedMult = BossConfig.Bosses[e.bossId].phases[e.sm.phase].speedMultiplier
			e.c.humanoid.WalkSpeed = BossConfig.Bosses[e.bossId].walkSpeed * speedMult
			e.c.humanoid:MoveTo(best.root.Position)
		end
		if now - e.lastBroadcast >= STATE_BROADCAST_INTERVAL then
			e.lastBroadcast = now
			broadcastState(e)
		end
	end
end

local function setupArena(arena: BasePart)
	local bossId = arena:GetAttribute("BossId")
	if type(bossId) ~= "string" or BossConfig.Bosses[bossId] == nil then
		warn("[BossService] arena", arena:GetFullName(), "has invalid BossId")
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Challenge"
	prompt.ObjectText = BossConfig.Bosses[bossId].name
	prompt.HoldDuration = 1
	prompt.RequiresLineOfSight = false
	prompt.Parent = arena
	prompt.Triggered:Connect(function(player)
		if busyArenas[arena] then
			return
		end
		local participants = {}
		for _, p in Players:GetPlayers() do
			local pc = CombatService.GetByPlayer(p)
			if pc and not pc.dead and (pc.root.Position - arena.Position).Magnitude <= CHALLENGE_RADIUS then
				table.insert(participants, p)
			end
		end
		if table.find(participants, player) == nil then
			table.insert(participants, player)
		end
		BossService.StartEncounter(bossId, arena.CFrame + Vector3.new(0, 5, 0), participants, arena)
	end)
end

function BossService.Init() end

function BossService.Start()
	CombatService.PostureBroken:Connect(function(c)
		for _, e in encounters do
			if e.c == c then
				e.sm:Break(os.clock())
			end
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= TICK then
			acc = 0
			tick(os.clock())
		end
	end)

	local arenas = workspace:FindFirstChild(ARENA_FOLDER)
	if arenas then
		for _, part in arenas:GetChildren() do
			if part:IsA("BasePart") then
				setupArena(part)
			end
		end
	else
		warn("[BossService] Workspace." .. ARENA_FOLDER .. " not found - no boss arenas (build in Studio)")
	end
end

return BossService
