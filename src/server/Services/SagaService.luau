--!strict
-- SagaService: NPCs and the main questline (SagaConfig + Logic/SagaLogic).
--   * Builds every NPC (RigBuilder look, anchored, facing its spot) with a "Talk" prompt.
--   * Talking runs SagaLogic.Talk: start / hand in quests (rewards) or idle chatter; the client
--     shows it as a dialogue box (StoryEvent kind "Dialogue").
--   * Kills (EnemyService.Defeated), boss wins (BossService.BossDefeated) and reaching places
--     (checked every second) advance the current step.
--   * NPC positions are published in ReplicatedStorage.NpcDirectory for markers/waypoints.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local SagaConfig = require(Config:WaitForChild("SagaConfig"))
local Signal = require(Shared:WaitForChild("Signal"))
local RealmConfig = require(Config:WaitForChild("RealmConfig"))

local Logic = script.Parent.Parent:WaitForChild("Logic")
local SagaLogic = require(Logic:WaitForChild("SagaLogic"))
local RigBuilder = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("RigBuilder"))

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local HubService = require(script.Parent.HubService)
local EnemyService = require(script.Parent.EnemyService)
local BossService = require(script.Parent.BossService)

local SagaService = { Name = "SagaService", Priority = 34, QuestFinished = Signal.new() }

local npcModels: { [string]: Model } = {}
local npcPositions: { [string]: Vector3 } = {}

local function ground(pos: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	for _, name in { "Npcs", "EnemySpawns", "SpiritFollowers" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(ignore, f)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 200, 0), Vector3.new(0, -500, 0), params)
	return if hit then hit.Position else pos
end

local function npcWorld(n: SagaConfig.NpcDef): Vector3
	if n.hub then
		local c = HubService.Center()
		return ground(Vector3.new(c.X + n.at[1], c.Y, c.Z + n.at[2]))
	end
	return ground(RealmConfig.World(n.realm, n.at))
end

local function state(player: Player): SagaLogic.State?
	local data = DataService.GetData(player)
	return if data then (data :: any).saga else nil
end

local function changed(player: Player)
	DataService.Changed(player, "saga")
end

local function giveRewards(player: Player, r: { ember: number, xp: number, jade: number }, title: string)
	ProgressionService.AddEmber(player, r.ember, "Quest:" .. title)
	ProgressionService.AddXp(player, r.xp)
	if r.jade > 0 then
		ProgressionService.AddJade(player, r.jade, "Quest:" .. title)
	end
end

function SagaService.Talk(player: Player, npcId: string)
	local st = state(player)
	local npc = SagaConfig.Npc(npcId)
	local model = npcModels[npcId]
	if st == nil or npc == nil then
		return
	end
	local ch = player.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	-- Face the player while talking.
	local npcRoot = model and model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") and npcRoot and npcRoot:IsA("BasePart") then
		if (root.Position - npcRoot.Position).Magnitude > 20 then
			return
		end
		local p = npcRoot.Position
		npcRoot.CFrame = CFrame.lookAt(p, Vector3.new(root.Position.X, p.Y, root.Position.Z))
	end
	local result = SagaLogic.Talk(st, npcId)
	if result.kind ~= "Chatter" then
		changed(player)
	end
	Net.Server.Fire("StoryEvent", player, {
		kind = "Dialogue",
		npc = npc.name,
		title = npc.title,
		lines = result.lines,
		result = result.kind,
		quest = result.questTitle,
	})
	if result.kind == "Finish" and result.rewards then
		giveRewards(player, result.rewards, result.questTitle or "")
		SagaService.QuestFinished:Fire(player, result.questId)
		Net.Server.Fire("StoryEvent", player, { kind = "QuestComplete", title = result.questTitle, ember = result.rewards.ember, xp = result.rewards.xp, jade = result.rewards.jade })
	elseif result.kind == "Start" then
		Net.Server.Fire("StoryEvent", player, { kind = "QuestStarted", title = result.questTitle })
	end
end

local function buildNpc(n: SagaConfig.NpcDef, folder: Folder)
	local model = RigBuilder.Build(n.look, n.name)
	if model == nil then
		return
	end
	model.Name = n.name
	local pos = npcWorld(n)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if hum == nil or root == nil or not root:IsA("BasePart") then
		model:Destroy()
		return
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.MaxHealth = math.huge
	hum.Health = math.huge
	local height = hum.HipHeight + root.Size.Y / 2
	model:PivotTo(CFrame.new(pos + Vector3.new(0, height, 0)) * CFrame.Angles(0, math.rad(n.facing or 0), 0))
	root.Anchored = true
	model:SetAttribute("NpcId", n.id)
	game:GetService("CollectionService"):AddTag(model, "Npc")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = n.name
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		SagaService.Talk(player, n.id)
	end)
	-- Name plate.
	local bb = Instance.new("BillboardGui")
	bb.Name = "NamePlate"
	bb.Size = UDim2.fromOffset(220, 44)
	bb.StudsOffset = Vector3.new(0, 3.6, 0)
	bb.MaxDistance = 60
	local head = model:FindFirstChild("Head")
	bb.Adornee = if head and head:IsA("BasePart") then head else root
	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0.55, 0)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextSize = 16
	name.TextColor3 = Color3.fromRGB(255, 235, 190)
	name.TextStrokeTransparency = 0.3
	name.Text = n.name
	name.Parent = bb
	local title = name:Clone()
	title.Position = UDim2.fromScale(0, 0.55)
	title.Size = UDim2.new(1, 0, 0.45, 0)
	title.Font = Enum.Font.Gotham
	title.TextSize = 12
	title.TextColor3 = Color3.fromRGB(200, 195, 185)
	title.Text = n.title
	title.Parent = bb
	bb.Parent = model
	model.Parent = folder
	npcModels[n.id] = model
	npcPositions[n.id] = pos
	local dir = ReplicatedStorage:FindFirstChild("NpcDirectory")
	if dir then
		local entry = Instance.new("Configuration")
		entry.Name = n.id
		entry:SetAttribute("Position", pos)
		entry:SetAttribute("DisplayName", n.name)
		entry.Parent = dir
	end
end

function SagaService.Init()
	local d = Instance.new("Folder")
	d.Name = "NpcDirectory"
	d.Parent = ReplicatedStorage
end

function SagaService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "Npcs"
	folder.Parent = workspace
	for _, n in SagaConfig.Npcs do
		local ok, err = pcall(buildNpc :: any, n, folder)
		if not ok then
			warn("[SagaService] NPC", n.id, "failed:", err)
		end
	end

	EnemyService.Defeated:Connect(function(enemyId: string?, contributions: { [Player]: number })
		if enemyId == nil then
			return
		end
		for player, dealt in contributions do
			local st = state(player)
			if st and dealt > 0 and SagaLogic.Kill(st, enemyId) then
				changed(player)
			end
		end
	end)
	BossService.BossDefeated:Connect(function(bossId: string, participants: { Player })
		for _, player in participants do
			local st = state(player)
			if st and SagaLogic.Boss(st, bossId) then
				changed(player)
				Net.Server.Fire("Notify", player, "Info", "Quest updated - return to the quest giver")
			end
		end
	end)
	-- Reach steps: check positions once a second.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local st = state(player)
				local ch = player.Character
				local root = ch and ch:FindFirstChild("HumanoidRootPart")
				if st and root and root:IsA("BasePart") then
					local realm = RealmConfig.At(root.Position)
					local o = RealmConfig.Realms[realm].origin
					if SagaLogic.Reach(st, realm, root.Position.X - o[1], root.Position.Z - o[3]) then
						changed(player)
						Net.Server.Fire("Notify", player, "Info", "Objective reached")
					end
				end
			end
		end
	end)
end

return SagaService
