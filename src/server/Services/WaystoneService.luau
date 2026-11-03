--!strict
-- WaystoneService: rest shrines (WaystoneConfig, plus any realm waystones RealmService adds).
--   * Rest (E): full heal, Spring Flask + Second Breath refilled, becomes your respawn point,
--     attunes the waystone for fast travel. The client also opens the Travel panel.
--   * TravelWaystone(id): teleport to an attuned waystone (not in combat, not in a boss arena).
--   * Respawn: you come back at the last waystone you rested at.
-- Waystone models are built at runtime (Workspace.Waystones) so saved Studio worlds get them too.
--
-- API:
--   WaystoneService.Register(id, name, position)   -- realms add their own waystones
--   WaystoneService.Position(id) -> Vector3?

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local WaystoneConfig = require(Config:WaitForChild("WaystoneConfig"))

local DataService = require(script.Parent.DataService)
local CombatService = require(script.Parent.CombatService)
local HubService = require(script.Parent.HubService)

local WaystoneService = { Name = "WaystoneService", Priority = 33 }

type Entry = { id: string, name: string, position: Vector3 }
local entries: { [string]: Entry } = {}
local lastTravel: { [Player]: number } = {}
local folder: Folder? = nil

local function ground(x: number, z: number, fallbackY: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	for _, name in { "Waystones", "SpiritFollowers" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(ignore, f)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(Vector3.new(x, fallbackY + 300, z), Vector3.new(0, -700, 0), params)
	return if hit then hit.Position.Y else fallbackY
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.CanTouch = false
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- Stone pillar with a floating glowing core and a ring at its foot.
local function build(e: Entry)
	local f = folder
	if f == nil then
		return
	end
	local m = Instance.new("Model")
	m.Name = "Waystone_" .. e.id
	local base = e.position
	local glow = rgb(WaystoneConfig.Color)
	block(m, "Plinth", Vector3.new(1, 9, 9), CFrame.new(base + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(110, 108, 104), Enum.Material.Slate, Enum.PartType.Cylinder)
	local ring = block(m, "Ring", Vector3.new(0.2, 8, 8), CFrame.new(base + Vector3.new(0, 1.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), glow, Enum.Material.Neon, Enum.PartType.Cylinder)
	ring.Transparency = 0.4
	ring.CanCollide = false
	block(m, "Pillar", Vector3.new(2, 7, 2), CFrame.new(base + Vector3.new(0, 4.5, 0)), Color3.fromRGB(90, 88, 92), Enum.Material.Basalt)
	block(m, "Cap", Vector3.new(3, 0.8, 3), CFrame.new(base + Vector3.new(0, 8.4, 0)), Color3.fromRGB(70, 68, 72), Enum.Material.Basalt)
	local core = block(m, "Core", Vector3.new(1.6, 1.6, 1.6), CFrame.new(base + Vector3.new(0, 10.2, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)), glow, Enum.Material.Neon)
	core.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = 18
	light.Brightness = 2
	light.Parent = core
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(glow)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.3, 0)
	sparks.Lifetime = NumberRange.new(1, 2)
	sparks.Rate = 8
	sparks.Speed = NumberRange.new(1, 2)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Parent = core
	local point = block(m, "StationPoint", Vector3.new(4, 6, 4), CFrame.new(base + Vector3.new(0, 3, 0)), glow, Enum.Material.SmoothPlastic)
	point.Transparency = 1
	point.CanCollide = false
	point:SetAttribute("Station", "Waystone")
	point:SetAttribute("WaystoneId", e.id)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Rest & Travel"
	prompt.ObjectText = e.name
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 0.4
	prompt.Parent = point
	prompt.Triggered:Connect(function(player)
		WaystoneService.Rest(player, e.id)
	end)
	-- Name plate.
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 30)
	bb.StudsOffset = Vector3.new(0, 13, 0)
	bb.MaxDistance = 90
	bb.Adornee = point
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = 16
	t.TextColor3 = glow
	t.TextStrokeTransparency = 0.3
	t.Text = e.name
	t.Parent = bb
	bb.Parent = point
	m.Parent = f
end

local directory: Folder? = nil

function WaystoneService.Register(id: string, name: string, position: Vector3, realm: string?)
	local e = { id = id, name = name, position = position }
	entries[id] = e
	build(e)
	-- Clients list waystones from ReplicatedStorage (far ones are not streamed in).
	local dir = directory
	if dir then
		local entry = Instance.new("Configuration")
		entry.Name = id
		entry:SetAttribute("DisplayName", name)
		entry:SetAttribute("Position", position)
		entry:SetAttribute("Realm", realm or "japan")
		entry:SetAttribute("Order", #dir:GetChildren() + 1)
		entry.Parent = dir
	end
end

function WaystoneService.Position(id: string): Vector3?
	local e = entries[id]
	return e and e.position
end

function WaystoneService.Rest(player: Player, id: string)
	local data = DataService.GetData(player)
	local c = CombatService.GetByPlayer(player)
	local e = entries[id]
	if data == nil or c == nil or e == nil or c.dead then
		return
	end
	if (c.root.Position - e.position).Magnitude > 16 then
		return
	end
	local first = data.waystones[id] ~= true
	data.waystones[id] = true
	data.respawnWaystone = id
	DataService.Changed(player, "waystones", "respawnWaystone")
	CombatService.Rest(c)
	Net.Server.FireAll("CombatEvent", { kind = "Rest", targetId = c.id })
	Net.Server.Fire("Notify", player, "Info", if first then "Waystone attuned: " .. e.name else "Rested at " .. e.name)
end

local function travel(player: Player, id: string): (boolean, string?)
	local data = DataService.GetData(player)
	local c = CombatService.GetByPlayer(player)
	local e = entries[id]
	if data == nil or c == nil or e == nil or c.dead then
		return false, "Unknown waystone"
	end
	if data.waystones[id] ~= true then
		return false, "Rest at that waystone first"
	end
	if CombatService.SinceHurt(c) < WaystoneConfig.CombatLockSeconds then
		return false, "You can't travel in the middle of a fight"
	end
	if player:GetAttribute("InArena") == true then
		return false, "Finish the duel first"
	end
	local now = os.clock()
	if now - (lastTravel[player] or 0) < WaystoneConfig.TravelCooldown then
		return false, "Catch your breath first"
	end
	lastTravel[player] = now
	local target = e.position + Vector3.new(0, 4, 6)
	pcall(function()
		player:RequestStreamAroundAsync(target, 5)
	end)
	c.model:PivotTo(CFrame.lookAt(target, e.position + Vector3.new(0, 4, 0)))
	Net.Server.FireAll("CombatEvent", { kind = "Rest", targetId = c.id })
	return true, nil
end

function WaystoneService.Init()
	local d = Instance.new("Folder")
	d.Name = "WaystoneDirectory"
	d.Parent = ReplicatedStorage
	directory = d
	local f = Instance.new("Folder")
	f.Name = "Waystones"
	f.Parent = workspace
	folder = f
end

function WaystoneService.Start()
	-- Built-in waystones (the hub one sits next to the plaza).
	for _, w in WaystoneConfig.Waystones do
		local x, z = w.at[1], w.at[2]
		if w.id == "hub" then
			local c = HubService.Center()
			x, z = c.X + WaystoneConfig.HubOffset[1], c.Z + WaystoneConfig.HubOffset[2]
		end
		if entries[w.id] == nil then
			WaystoneService.Register(w.id, w.name, Vector3.new(x, ground(x, z, 0), z))
		end
	end
	Net.Server.OnInvoke("TravelWaystone", travel)
	-- Respawn at the last waystone you rested at.
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			player:SetAttribute("InArena", false)
			local data = DataService.WaitForData(player, 10)
			local id = data and data.respawnWaystone
			local e = if id and id ~= "hub" then entries[id] else nil
			if e then
				task.wait(0.2)
				local root = character:WaitForChild("HumanoidRootPart", 5)
				if root and character.Parent then
					pcall(function()
						player:RequestStreamAroundAsync(e.position, 5)
					end)
					character:PivotTo(CFrame.new(e.position + Vector3.new(0, 4, 6)))
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		lastTravel[p] = nil
	end)
end

return WaystoneService
