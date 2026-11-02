--!strict
-- BossService: boss encounters driven by Logic/BossStateMachine (data in BossConfig).
-- One encounter per arena. Participants are the players near the arena when it starts
-- (PartyService will supply parties in Phase 3). Bosses ignore attack tokens.
--
-- Studio setup (TODO(Studio/Agent D + C)):
--   Workspace.BossArenas/<Part> with attribute BossId = "bell_engine"; BossService adds a
--   ProximityPrompt "Challenge" to it. Boss rig: ServerStorage.Bosses/<bossId> (placeholder block
--   otherwise). Animations: BossConfig move animationId (all placeholders today).
--
-- API:
--   BossService.StartEncounter(bossId, cframe, participants, arena?, opts?) -> encounterId?
--     opts (EncounterOpts) makes it an open-world encounter (world bosses)
--   BossService.IsActive(encounterId) -> boolean
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
local World = script.Parent.Parent:WaitForChild("World")
local RigBuilder = require(World:WaitForChild("RigBuilder"))
local CreatureBuilder = require(World:WaitForChild("CreatureBuilder"))
local ArenaBuilder = require(World:WaitForChild("ArenaBuilder"))
local ArenaConfig = require(Config:WaitForChild("ArenaConfig"))
local HazardService = require(script.Parent.HazardService)
local CombatService = require(script.Parent.CombatService)
local ProgressionService = require(script.Parent.ProgressionService)
local QuestService = require(script.Parent.QuestService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local PartyService = require(script.Parent.PartyService)

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
	openWorld: EncounterOpts?, -- set for world bosses: players join by proximity
	endsAt: number, -- os.clock() deadline (math.huge for story bosses)
	slot: number?, -- instanced arena slot (story bosses)
	arenaCenter: Vector3?,
	returnTo: CFrame?, -- where participants go back to after the fight
}

-- Options for open-world (world boss) encounters.
export type EncounterOpts = {
	joinRadius: number,
	minContribution: number, -- fraction of max health dealt to earn rewards
	durationSeconds: number,
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
	-- No Studio rig yet: a part-built creature, or a code-made R15 humanoid from the look.
	local def = BossConfig.Bosses[bossId]
	if def and (def :: any).creature then
		local creature = CreatureBuilder.Build((def :: any).creature, def.look)
		if creature then
			return creature
		end
	end
	if def and def.look then
		local rig = RigBuilder.Build(def.look, def.name)
		if rig then
			return rig
		end
	end
	return placeholderBoss(bossId)
end

local function inArena(e: Encounter, pos: Vector3): boolean
	local c = e.arenaCenter
	if c == nil then
		return true
	end
	local d = pos - c
	return Vector3.new(d.X, 0, d.Z).Magnitude <= ArenaConfig.Radius + 20 and math.abs(d.Y) < 80
end

local function aliveParticipants(e: Encounter): { Combatant }
	local out = {}
	for _, p in e.participants do
		local pc = CombatService.GetByPlayer(p)
		-- In an instanced arena only players actually inside count (respawned players are out).
		if p.Parent == Players and pc and not pc.dead and inArena(e, pc.root.Position) then
			table.insert(out, pc)
		end
	end
	return out
end

-- Instanced arenas -----------------------------------------------------------------------------
local slotsUsed: { [number]: boolean } = {}
local arenaModels: { [number]: Model } = {}

local function slotCenter(i: number): Vector3
	local o = ArenaConfig.Origin
	return Vector3.new(o[1] + (i - 1) * ArenaConfig.Spacing, o[2], o[3])
end

local function claimSlot(bossId: string): (number?, Vector3?)
	for i = 1, ArenaConfig.Slots do
		if not slotsUsed[i] then
			slotsUsed[i] = true
			local center = slotCenter(i)
			if arenaModels[i] then
				arenaModels[i]:Destroy()
			end
			local folder = workspace:FindFirstChild("BossArenaInstances")
			if folder == nil then
				local f = Instance.new("Folder")
				f.Name = "BossArenaInstances"
				f.Parent = workspace
				folder = f
			end
			local theme = ArenaConfig.Themes[bossId] or ArenaConfig.Themes.Default
			local m = ArenaBuilder.Build(center, theme)
			m.Name = "Arena" .. i .. "_" .. bossId
			m.Parent = folder
			arenaModels[i] = m
			return i, center
		end
	end
	return nil, nil
end

local function releaseSlot(i: number)
	slotsUsed[i] = nil
	local m = arenaModels[i]
	if m then
		arenaModels[i] = nil
		m:Destroy()
	end
end

local function teleport(player: Player, cf: CFrame, inArena: boolean?)
	player:SetAttribute("InArena", inArena == true)
	pcall(function()
		player:RequestStreamAroundAsync(cf.Position, 5)
	end)
	local ch = player.Character
	if ch and ch.Parent then
		ch:PivotTo(cf)
		local root = ch:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

-- Sends everyone still inside the arena back to the shrine.
local function sendBack(e: Encounter)
	local back = e.returnTo
	if back == nil then
		return
	end
	for i, p in e.participants do
		local pc = CombatService.GetByPlayer(p)
		if p.Parent == Players and pc and inArena(e, pc.root.Position) then
			task.spawn(teleport, p, back * CFrame.new((i - 1) * 3, 0, 0))
		end
	end
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

local function rgbOr(c: { number }?): { number }
	return c or { 255, 140, 60 }
end

-- Ranged / ground moves through HazardService. Returns true if the move was one of those.
local function doHazard(e: Encounter, moveId: string, m: BossConfig.BossMove): boolean
	local kind = m.kind or "Melee"
	if kind == "Melee" then
		return false
	end
	local root = e.c.root
	local mouth = root.Position + root.CFrame.LookVector * (root.Size.Z * 0.5 + 2) + Vector3.new(0, 2, 0)
	local target = e.target
	local aimAt = if target then target.root.Position else root.Position + root.CFrame.LookVector * 20
	local color = rgbOr(m.color)
	if kind == "Projectile" or kind == "Volley" then
		local count = if kind == "Volley" then m.count or 5 else 1
		local spread = if kind == "Volley" then m.spread or 50 else 0
		local base = aimAt - mouth
		for i = 1, count do
			local angle = if count > 1 then -spread / 2 + spread * (i - 1) / (count - 1) else 0
			local dir = CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(base)
			HazardService.Projectile(e.c, mouth, dir, {
				speed = m.speed or 50,
				radius = m.radius or 1.5,
				range = m.range + 20,
				damage = m.damage,
				posture = m.postureDamage,
				color = color,
				size = if m.deflectable then 3.2 else 1.6,
				deflectable = m.deflectable,
				reflectDamage = m.reflectDamage,
				reflectPosture = m.reflectPosture,
				visual = m.visual,
				moveId = moveId,
			})
		end
	elseif kind == "Wave" then
		HazardService.Wave(e.c, root.Position - Vector3.new(0, root.Size.Y / 2 + e.c.humanoid.HipHeight - 0.5, 0), {
			speed = m.speed or 40,
			maxRadius = m.radius or m.range,
			band = 3,
			damage = m.damage,
			posture = m.postureDamage,
			color = color,
			moveId = moveId,
		})
	elseif kind == "Laser" or kind == "LaserSweep" then
		-- From the visor, aimed where the target stands now; sweeps fan across the arena.
		local eye = root.Position + Vector3.new(0, root.Size.Y * 0.5 + 2, 0) + root.CFrame.LookVector * 2
		local base = aimAt - eye
		local count = if kind == "LaserSweep" then m.count or 5 else 1
		local spread = if kind == "LaserSweep" then m.spread or 90 else 0
		local stagger = if count > 1 then (m.active or 1) / count else 0
		for i = 1, count do
			local ang = if count > 1 then -spread / 2 + spread * (i - 1) / (count - 1) else 0
			local dir = CFrame.Angles(0, math.rad(ang), 0):VectorToWorldSpace(base)
			task.delay((i - 1) * stagger, function()
				if e.ended or e.c.dead then
					return
				end
				HazardService.Laser(e.c, Vector3.new(eye.X, aimAt.Y, eye.Z), dir, {
					length = m.range,
					width = m.radius or 3,
					delay = m.delay or 0.8,
					damage = m.damage,
					posture = m.postureDamage,
					color = color,
					moveId = moveId,
				})
			end)
		end
	elseif kind == "Leap" then
		-- Jump onto the target's spot: marked circle, an arcing flight, a crash + toll ring.
		local hum = e.c.humanoid
		local landing = aimAt
		local flight = m.delay or 1.1
		local hipOffset = hum.HipHeight + root.Size.Y / 2
		HazardService.Rain(e.c, { landing - Vector3.new(0, 2.5, 0) }, {
			radius = m.radius or 12,
			delay = flight,
			damage = m.damage,
			posture = m.postureDamage,
			color = color,
			moveId = moveId,
		})
		local start = root.Position
		local finish = Vector3.new(landing.X, landing.Y - 2.5 + hipOffset, landing.Z)
		root.Anchored = true
		task.spawn(function()
			local t0 = os.clock()
			while true do
				local t = math.min(1, (os.clock() - t0) / flight)
				if e.ended or e.c.dead then
					break
				end
				local p = start:Lerp(finish, t) + Vector3.new(0, math.sin(t * math.pi) * 32, 0)
				local flat = Vector3.new(finish.X, p.Y, finish.Z)
				root.CFrame = if (flat - p).Magnitude > 0.5 then CFrame.lookAt(p, flat) else CFrame.new(p) * root.CFrame.Rotation
				if t >= 1 then
					break
				end
				task.wait()
			end
			root.Anchored = false
			if not e.ended and not e.c.dead then
				HazardService.Wave(e.c, landing - Vector3.new(0, 2.5, 0), {
					speed = 38,
					maxRadius = 34,
					band = 3,
					damage = math.floor(m.damage * 0.6),
					posture = m.postureDamage,
					color = color,
					moveId = moveId,
				})
			end
		end)
	elseif kind == "Rain" then
		local points = {}
		local alive = aliveParticipants(e)
		local count = m.count or 6
		for i = 1, count do
			local pc = alive[((i - 1) % math.max(1, #alive)) + 1]
			local center = if pc then pc.root.Position else root.Position
			-- First eruption right under each player, the rest scattered around them.
			local off = if i <= #alive then Vector3.zero else Vector3.new(rng:NextNumber(-14, 14), 0, rng:NextNumber(-14, 14))
			table.insert(points, center + off - Vector3.new(0, 2.5, 0))
		end
		HazardService.Rain(e.c, points, {
			radius = m.radius or 7,
			delay = m.delay or 1.1,
			damage = m.damage,
			posture = m.postureDamage,
			color = color,
			moveId = moveId,
		})
	end
	return true
end

local function doHits(e: Encounter, moveId: string)
	local def = BossConfig.Bosses[e.bossId]
	local m = def.moves[moveId]
	if doHazard(e, moveId, m) then
		return
	end
	local hits = m.hits or 1
	if not m.minRange and e.target then
		-- Regular strikes step the boss's body into the swing.
		local hum = e.c.humanoid
		local base = def.walkSpeed
		hum.WalkSpeed = base * BossConfig.StrikeStepSpeed
		hum:MoveTo(e.c.root.Position + e.c.root.CFrame.LookVector * BossConfig.StrikeStep)
		task.delay(m.active, function()
			hum.WalkSpeed = base
		end)
	end
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
						perilousKind = m.perilousKind,
						moveId = moveId,
						knockback = if m.perilous then BossConfig.Knockback.perilous elseif m.arcDegrees >= 300 then BossConfig.Knockback.wide else BossConfig.Knockback.normal,
						launch = if m.perilous then BossConfig.Knockback.perilousLaunch else nil,
					})
				end
			end
		end)
	end
end

-- Open-world encounters: any player who comes near joins (and gets the intro + boss bar).
local function joinNearby(e: Encounter)
	local opts = e.openWorld :: EncounterOpts
	local pos = e.c.root.Position
	for _, p in Players:GetPlayers() do
		if table.find(e.participants, p) == nil then
			local pc = CombatService.GetByPlayer(p)
			if pc and not pc.dead and (pc.root.Position - pos).Magnitude <= opts.joinRadius then
				table.insert(e.participants, p)
				local def = BossConfig.Bosses[e.bossId]
				Net.Server.Fire("StoryEvent", p, { kind = "BossIntro", bossId = e.bossId, name = def.name, title = def.title })
			end
		end
	end
end

-- Who is rewarded on victory: story bosses = all participants; world bosses = everyone who
-- dealt at least minContribution of max health, plus their party members nearby.
local function rewardees(e: Encounter): { Player }
	local opts = e.openWorld
	if opts == nil then
		return e.participants
	end
	local need = e.c.humanoid.MaxHealth * opts.minContribution
	local set: { [Player]: boolean } = {}
	for player, dealt in e.c.contributions do
		if dealt >= need and player.Parent == Players then
			for _, member in PartyService.MembersNear(player, opts.joinRadius) do
				set[member] = true
			end
		end
	end
	local out = {}
	for p in set do
		table.insert(out, p)
	end
	return out
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
	local slot = e.slot
	if slot then
		task.delay(if victory then ArenaConfig.ReturnDelay else 2, function()
			sendBack(e)
			task.delay(1, releaseSlot, slot)
		end)
	end
	broadcastState(e)
	if victory then
		local def = BossConfig.Bosses[e.bossId]
		local firstClears = {}
		for _, p in rewardees(e) do
			local data = DataService.GetData(p)
			if p.Parent == Players and data then
				local first = (data.bossesDefeated[e.bossId] or 0) == 0
				data.bossesDefeated[e.bossId] = (data.bossesDefeated[e.bossId] or 0) + 1
				DataService.Changed(p, "bossesDefeated")
				local ember = ProgressionService.AddEmber(p, def.rewards.ember, "Boss:" .. e.bossId)
				ProgressionService.AddXp(p, def.rewards.xp)
				if first then
					ProgressionService.AddJade(p, def.rewards.jadeFirstClear, "BossFirstClear:" .. e.bossId)
					table.insert(firstClears, p)
				end
				-- Victory card on the client (StoryController).
				Net.Server.Fire("StoryEvent", p, {
					kind = "BossDefeated",
					bossId = e.bossId,
					name = def.name,
					ember = ember,
					xp = def.rewards.xp,
					jade = if first then def.rewards.jadeFirstClear else 0,
					firstClear = first,
				})
				QuestService.Increment(p, "Boss:" .. e.bossId, 1)
				if e.bossId == "bell_engine" then
					AnalyticsService.Onboarding(p, "BellEngineDefeated")
				end
			end
		end
		BossService.BossDefeated:Fire(e.bossId, e.participants, firstClears)
		task.delay(5, function()
			CombatService.Unregister(e.c.id)
			e.c.model:Destroy()
		end)
	else
		Net.Server.FireList("StoryEvent", e.participants, { kind = "BossFailed", bossId = e.bossId, name = BossConfig.Bosses[e.bossId].name })
		CombatService.Unregister(e.c.id)
		e.c.model:Destroy()
	end
end

function BossService.StartEncounter(bossId: string, cframe: CFrame, participants: { Player }, arena: BasePart?, opts: EncounterOpts?): string?
	local def = BossConfig.Bosses[bossId]
	if def == nil or (#participants == 0 and opts == nil) then
		return nil
	end
	counter += 1
	local id = "B" .. counter
	local model = getRig(bossId)
	model.Name = def.name
	model:PivotTo(cframe)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	-- Stand the rig on the spawn point (scaled bosses have tall hips).
	model:PivotTo(cframe + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
	local hp = BossStateMachine.ScaledHealth(bossId, #participants)
	humanoid.MaxHealth = hp
	humanoid.Health = hp
	humanoid.WalkSpeed = def.walkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- boss bar UI instead
	-- With instance streaming, send the whole rig at once (animations need every joint).
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
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
		deflectChance = def.deflectChance or BossConfig.DefaultDeflect,
	}
	CombatService.Register(c)

	local e: Encounter
	-- Bosses deflect your strikes whenever they are not mid-attack (break their rhythm!).
	c.canDeflect = function()
		local st = if e then e.sm.state else "Idle"
		return st == "Idle" or st == "Chase" or st == "Recovery"
	end
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
				perilousKind = m.perilousKind,
				pose = m.pose,
				style = m.style,
				hazard = m.kind,
				windup = m.windup / def.phases[e.sm.phase].speedMultiplier,
				active = m.active,
				recovery = m.recovery / def.phases[e.sm.phase].speedMultiplier,
				hits = m.hits,
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
		openWorld = opts,
		endsAt = if opts then os.clock() + opts.durationSeconds else math.huge,
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
		if e.openWorld then
			joinNearby(e)
			if now >= e.endsAt then
				Net.Server.FireAll("Notify", "WorldBoss", BossConfig.Bosses[e.bossId].name .. " has gone back to sleep...")
				finish(e, false)
				continue
			end
		end
		local alive = aliveParticipants(e)
		if #alive == 0 and not e.openWorld then
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
		local center = e.arenaCenter
		if center then
			-- Nobody falls out of the arena: anyone below the floor is put back on it.
			for _, pc in alive do
				if pc.root.Position.Y < center.Y - ArenaConfig.FallLimit then
					pc.model:PivotTo(CFrame.new(center + Vector3.new(0, 5, ArenaConfig.Radius * 0.5)))
				end
			end
			local bp = e.c.root.Position - center
			if Vector3.new(bp.X, 0, bp.Z).Magnitude > ArenaConfig.Radius or bp.Y < -ArenaConfig.FallLimit then
				e.c.model:PivotTo(CFrame.new(center + Vector3.new(0, 8, 0)))
			end
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
		-- Party members fight together even if they wander a bit further from the arena.
		for _, member in PartyService.MembersNear(player, CHALLENGE_RADIUS * 2) do
			if table.find(participants, member) == nil then
				table.insert(participants, member)
			end
		end
		if table.find(participants, player) == nil then
			table.insert(participants, player)
		end
		local def = BossConfig.Bosses[bossId]
		local slot, center = nil, nil
		if def.kind == "Story" then
			slot, center = claimSlot(bossId)
		end
		if slot == nil or center == nil then
			-- No free arena: fight at the shrine (old behaviour).
			BossService.StartEncounter(bossId, arena.CFrame + Vector3.new(0, 5, 0), participants, arena)
			return
		end
		busyArenas[arena] = true
		local R = ArenaConfig.Radius
		local arenaCenter: Vector3 = center
		task.spawn(function()
			-- Into the arena: players on the south side facing the boss.
			for i, p in participants do
				local x = (i - (#participants + 1) / 2) * 5
				local pos = arenaCenter + Vector3.new(x, 4, R * 0.55)
				task.spawn(teleport, p, CFrame.lookAt(pos, arenaCenter + Vector3.new(0, 4, 0)), true)
			end
			task.wait(1.2)
			local bossPos = arenaCenter + Vector3.new(0, 0, -R * 0.45)
			local id = BossService.StartEncounter(bossId, CFrame.lookAt(bossPos, arenaCenter), participants, arena)
			local e = id and encounters[id]
			if e then
				e.slot = slot
				e.arenaCenter = arenaCenter
				e.returnTo = arena.CFrame + Vector3.new(0, 4, 8)
			else
				busyArenas[arena] = nil
				releaseSlot(slot :: number)
			end
		end)
	end)
end

function BossService.IsActive(encounterId: string): boolean
	return encounters[encounterId] ~= nil
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
