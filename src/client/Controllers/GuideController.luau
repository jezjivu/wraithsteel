--!strict
-- GuideController: new-player guidance. Shows the current objective computed from
-- profile data (right edge), and a controls card at the start (H toggles it). Presentation only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local FormatNumber = require(Shared:WaitForChild("FormatNumber"))
local Net = require(Shared:WaitForChild("Net"))
local GuideConfig = require(Config:WaitForChild("GuideConfig"))
local WeaponConfig = require(Config:WaitForChild("WeaponConfig"))
local ChapterConfig = require(Config:WaitForChild("ChapterConfig"))
local BossConfig = require(Config:WaitForChild("BossConfig"))
local HubConfig = require(Config:WaitForChild("HubConfig"))
local MapConfig = require(Config:WaitForChild("MapConfig"))
local RealmConfig = require(Config:WaitForChild("RealmConfig"))
local SagaConfig = require(Config:WaitForChild("SagaConfig"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local DataController = require(script.Parent.DataController)

local GuideController = { Name = "GuideController", Priority = 42 }

local C = Kit.Colors
local objectiveLabel: TextLabel? = nil
local controlsCard: Frame? = nil

local function count(t: { [any]: any }?): number
	local n = 0
	if t then
		for _ in t do
			n += 1
		end
	end
	return n
end

-- Cheapest weapon the player does not own yet (for the "buy a weapon" step).
local function cheapestNewWeapon(owned: { [string]: boolean }): number
	local best = math.huge
	for id, w in WeaponConfig.Weapons do
		if not owned[id] and w.currency == "Ember" and w.unlockChapter == 0 and w.price > 0 then
			best = math.min(best, w.price)
		end
	end
	return if best == math.huge then 0 else best
end

-- World position of a hub station (from the built hub, or computed from HubConfig).
local stationCache: { [string]: Vector3 } = {}
local function stationPos(kind: string): Vector3?
	local cached = stationCache[kind]
	if cached then
		return cached
	end
	local hub = workspace:FindFirstChild("Hub")
	if hub then
		for _, d in hub:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("Station") == kind then
				stationCache[kind] = d.Position
				return d.Position
			end
		end
	end
	for _, st in HubConfig.Stations do
		if st.kind == kind then
			local o = HubConfig.Origin
			local a = math.rad(st.angle)
			return Vector3.new(o[1] + math.sin(a) * HubConfig.StallRing, o[2], o[3] - math.cos(a) * HubConfig.StallRing)
		end
	end
	return nil
end

local function arenaPos(bossId: string): Vector3?
	for _, a in MapConfig.BossArenas do
		if a.bossId == bossId then
			return Vector3.new(a.at[1], 0, a.at[2])
		end
	end
	for id, r in RealmConfig.Realms do
		for _, a in r.arenas do
			if a.bossId == bossId then
				return RealmConfig.World(id, a.at)
			end
		end
	end
	return nil
end

local function npcPos(id: string): Vector3?
	local dir = ReplicatedStorage:FindFirstChild("NpcDirectory")
	local entry = dir and dir:FindFirstChild(id)
	local p = entry and entry:GetAttribute("Position")
	return if typeof(p) == "Vector3" then p else nil
end

-- Nearest spawn of any of these enemies (for "go fight" waypoints).
local function spawnPos(enemies: { string }): Vector3?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local from = if root and root:IsA("BasePart") then root.Position else Vector3.zero
	local best, bestD = nil, math.huge
	local function consider(p: Vector3)
		local d = (p - from).Magnitude
		if d < bestD then
			best, bestD = p, d
		end
	end
	for _, s in MapConfig.EnemySpawns do
		if table.find(enemies, s.enemyId) then
			consider(Vector3.new(s.at[1], 0, s.at[2]))
		end
	end
	for id, r in RealmConfig.Realms do
		for _, s in r.spawns do
			if table.find(enemies, s.enemyId) then
				consider(RealmConfig.World(id, s.at))
			end
		end
	end
	return best
end

-- Main questline objective (mirrors server Logic/SagaLogic.Objective).
local function sagaObjective(): (string?, string?, Vector3?)
	local saga = DataController.Get("saga")
	if type(saga) ~= "table" then
		return nil, nil, nil
	end
	local q = SagaConfig.Quests[saga.quest]
	if q == nil then
		return "The story so far is complete. More gates await...", nil, nil
	end
	local giver = SagaConfig.Npc(q.giver)
	local giverName = if giver then giver.name else q.giver
	if not saga.started then
		return string.format("%s - talk to %s", q.title, giverName), giverName, npcPos(q.giver)
	end
	local step = q.steps[saga.step]
	if step == nil then
		return string.format("%s - return to %s", q.title, giverName), giverName, npcPos(q.giver)
	end
	if step.kind == "Kill" then
		return string.format("%s - %s (%d/%d)", q.title, step.text, saga.progress, step.count or 1), "Enemies", spawnPos(step.enemies or {})
	elseif step.kind == "Boss" then
		local boss = BossConfig.Bosses[step.bossId or ""]
		return string.format("%s - %s", q.title, step.text), if boss then boss.name else "Boss", arenaPos(step.bossId or "")
	elseif step.kind == "Reach" and step.at then
		return string.format("%s - %s", q.title, step.text), "Destination", RealmConfig.World(step.realm or "japan", step.at)
	end
	local npc = SagaConfig.Npc(step.npc or "")
	return string.format("%s - %s", q.title, step.text), if npc then npc.name else nil, npcPos(step.npc or "")
end

-- Returns objective text plus an optional waypoint (name + world position).
function GuideController.Objective(): (string, string?, Vector3?)
	local T = GuideConfig.Text
	if not DataController.IsLoaded() then
		return "Loading...", nil, nil
	end
	local level = DataController.Get("level") or 1
	local owned = DataController.Get("weapons") or {}
	local defeated = DataController.Get("bossesDefeated") or {}
	if (DataController.Get("hatchedTotal") or 0) == 0 then
		return T.openLantern, "Lantern Shrine", stationPos("LanternShrine")
	elseif #(DataController.Get("equippedSpirits") or {}) == 0 then
		return T.equipSpirit, "Spirit Shrine", stationPos("SpiritShrine")
	end
	local sagaText, sagaName, sagaPos = sagaObjective()
	if sagaText then
		return sagaText, sagaName, sagaPos
	end
	if false then
		return "", nil, nil
	elseif level < GuideConfig.LevelGoal then
		local first = MapConfig.EnemySpawns[1]
		return string.format(T.fightWilds, GuideConfig.LevelGoal), "Enemies", Vector3.new(first.at[1], 0, first.at[2])
	elseif count(owned) < 2 then
		return string.format(T.buyWeapon, FormatNumber.Commas(cheapestNewWeapon(owned))), "Weapon Smith", stationPos("WeaponSmith")
	end
	local chapter = DataController.Get("chapter") or 0
	local def = ChapterConfig.Chapters[chapter]
	if def then
		for _, bossId in def.bosses do
			local boss = BossConfig.Bosses[bossId]
			if boss and (defeated[bossId] or 0) == 0 then
				return string.format(T.chapterBoss, boss.name, chapter), boss.name, arenaPos(bossId)
			end
		end
	end
	return T.allDone, nil, nil
end

function GuideController.CurrentObjective(): string
	local text = GuideController.Objective()
	return text
end

-- Waypoint: a pulsing light beacon at the target, a distance label, and a screen-edge arrow
-- when the target is off-screen. Client-only visuals.
local beacon: Part? = nil
local beaconLabel: TextLabel? = nil
local edgeArrow: TextLabel? = nil
local waypointName: string? = nil
local waypointPos: Vector3? = nil

local function buildWaypoint(gui: ScreenGui)
	local cfg = GuideConfig.Waypoint
	local color = Color3.fromRGB(cfg.color[1], cfg.color[2], cfg.color[3])
	local p = Instance.new("Part")
	p.Name = "ObjectiveBeacon"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.55
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(cfg.beamHeight, 1.6, 1.6)
	p.Parent = workspace
	beacon = p
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 46)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 8, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 100000
	bb.Adornee = p
	bb.Parent = gui
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = 16
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.3
	l.Parent = bb
	beaconLabel = l
	local arrow = Instance.new("TextLabel")
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(44, 44)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBlack
	arrow.TextSize = 36
	arrow.TextColor3 = color
	arrow.TextStrokeTransparency = 0.2
	arrow.Text = ">"
	arrow.Visible = false
	arrow.Parent = gui
	edgeArrow = arrow
end

local bossFightUntil = 0

local function updateWaypoint()
	local p, label, arrow = beacon, beaconLabel, edgeArrow
	if p == nil or label == nil or arrow == nil then
		return
	end
	local target = waypointPos
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	local cfg = GuideConfig.Waypoint
	if target == nil or root == nil or not root:IsA("BasePart") or cam == nil then
		p.Transparency = 1
		label.Visible = false
		arrow.Visible = false
		return
	end
	local dist = (Vector3.new(target.X, 0, target.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
	-- Hidden near the target and during boss fights (the beam stood right where the boss is).
	local near = dist < cfg.hideWithin or os.clock() < bossFightUntil
	local pulse = 0.5 + math.sin(os.clock() * 3) * 0.12
	p.Transparency = if near then 1 else pulse
	p.CFrame = CFrame.new(target + Vector3.new(0, cfg.beamHeight / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	label.Visible = not near
	label.Text = string.format("%s  ·  %dm", waypointName or "Objective", math.floor(dist))
	-- Screen-edge arrow when the beacon is off-screen.
	local screenPos, onScreen = cam:WorldToViewportPoint(target + Vector3.new(0, 6, 0))
	if onScreen or near then
		arrow.Visible = false
		return
	end
	local vp = cam.ViewportSize
	local c = vp / 2
	local dir = Vector2.new(screenPos.X, screenPos.Y) - c
	if screenPos.Z < 0 then
		dir = -dir -- behind the camera
	end
	if dir.Magnitude < 1 then
		dir = Vector2.new(0, -1)
	end
	dir = dir.Unit
	local edge = c + dir * (math.min(vp.X, vp.Y) / 2 - 40)
	arrow.Position = UDim2.fromOffset(edge.X, edge.Y)
	arrow.Rotation = math.deg(math.atan2(dir.Y, dir.X))
	arrow.Visible = true
end

local function refresh()
	local text, name, pos = GuideController.Objective()
	waypointName, waypointPos = name, pos
	local label = objectiveLabel
	if label then
		label.Text = text
	end
end

function GuideController.Init()
	local gui = Kit.Screen(Players.LocalPlayer:WaitForChild("PlayerGui"), "Guide", 4)

	local box = Instance.new("Frame")
	-- Right edge, above the middle: clear of Roblox's player list (top right) and chat (top left).
	box.AnchorPoint = Vector2.new(1, 0.5)
	box.Position = UDim2.new(1, -10, 0.36, 0)
	box.Size = UDim2.fromOffset(300, 74)
	box.BackgroundColor3 = C.Ink
	box.BackgroundTransparency = 0.2
	box.Parent = gui
	local corner = Instance.new("UIStroke")
	corner.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	corner.Color = C.Steel
	corner.Transparency = 0.45
	corner.Parent = box
	Kit.Brackets(box, nil, 10)
	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(10, 4)
	title.Size = UDim2.new(1, -20, 0, 20)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 15
	title.TextColor3 = C.Gold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "OBJECTIVE"
	title.Parent = box
	local text = Instance.new("TextLabel")
	text.Position = UDim2.fromOffset(10, 24)
	text.Size = UDim2.new(1, -20, 1, -28)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.Gotham
	text.TextSize = 14
	text.TextWrapped = true
	text.TextColor3 = C.Text
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.Parent = box
	objectiveLabel = text

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(1, 1)
	card.Position = UDim2.new(1, -10, 1, -110)
	card.Size = UDim2.fromOffset(300, 24 * #GuideConfig.Controls + 34)
	card.BackgroundColor3 = C.Ink
	card.BackgroundTransparency = 0.15
	card.Parent = gui
	local c2 = Instance.new("UIStroke")
	c2.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	c2.Color = C.Steel
	c2.Transparency = 0.45
	c2.Parent = card
	Kit.Brackets(card, nil, 10)
	local head = Instance.new("TextLabel")
	head.Position = UDim2.fromOffset(10, 4)
	head.Size = UDim2.new(1, -20, 0, 24)
	head.BackgroundTransparency = 1
	head.Font = Enum.Font.GothamBold
	head.TextSize = 16
	head.TextColor3 = C.Gold
	head.TextXAlignment = Enum.TextXAlignment.Left
	head.Text = "Controls"
	head.Parent = card
	for i, line in GuideConfig.Controls do
		local l = Instance.new("TextLabel")
		l.Position = UDim2.fromOffset(10, 6 + 24 * i)
		l.Size = UDim2.new(1, -20, 0, 22)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.Gotham
		l.TextSize = 14
		l.TextColor3 = C.Text
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Text = line
		l.Parent = card
	end
	controlsCard = card
	buildWaypoint(gui)
end

function GuideController.Start()
	DataController.Changed:Connect(refresh)
	refresh()
	-- NPC positions / kill-spawn targets can change as you move around: refresh now and then.
	task.spawn(function()
		while true do
			task.wait(3)
			refresh()
		end
	end)
	game:GetService("RunService").RenderStepped:Connect(updateWaypoint)
	Net.Client.On("BossState", function(st)
		if st.state ~= "Dead" and (tonumber(st.hpFrac) or 0) > 0 then
			bossFightUntil = os.clock() + 3
		else
			bossFightUntil = 0
		end
	end)
	task.delay(GuideConfig.ControlsCardSeconds, function()
		if controlsCard then
			controlsCard.Visible = false
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.H and controlsCard then
			controlsCard.Visible = not controlsCard.Visible
		end
	end)
end

return GuideController
