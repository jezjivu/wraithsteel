--!strict
-- SpiritFollowerController: renders every player's equipped Spirits as floating companions
-- (client-side only, built by Shared/SpiritModels from the SpiritParty player attribute).
-- Companions trail behind their player in a fan, bob, flap wings/fins and sway tails.
-- When the server reports a SpiritCast (SpiritAbilityService), the companion acts it out:
-- darting at the target, diving onto it, circling its owner to heal/shield, and so on.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local SpiritModels = require(Shared:WaitForChild("SpiritModels"))
local SpiritConfig = require(Config:WaitForChild("SpiritConfig"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Fx = require(UI:WaitForChild("Fx"))
local SpellFx = require(UI:WaitForChild("SpellFx"))
local CombatController = require(script.Parent.CombatController)
local EffectsController = require(script.Parent.EffectsController)

local SpiritFollowerController = { Name = "SpiritFollowerController", Priority = 50 }

type Animated = { part: BasePart, base: CFrame, flap: number?, tail: boolean, spin: boolean, orbit: number? }
type Action = { kind: string, start: number, duration: number, target: Vector3?, burst: boolean }
type Follower = { model: Model, parts: { Animated }, pivot: CFrame, seed: number, action: Action? }

local ACTION_SECONDS = { Bolt = 0.4, Chain = 0.45, Dive = 0.75, Pounce = 0.7, Toll = 0.9, Nova = 0.6, Bloom = 0.7, Heal = 0.9, Shield = 0.9 }

local folder: Folder? = nil
local actionPose: (act: any, t: number, root: BasePart, home: CFrame, now: number, seed: number) -> (CFrame, number)
local followers: { [Player]: { Follower } } = {}

local function clear(player: Player)
	local list = followers[player]
	if list then
		for _, f in list do
			f.model:Destroy()
		end
	end
	followers[player] = nil
end

local function rebuild(player: Player)
	clear(player)
	local spec = player:GetAttribute("SpiritParty")
	if type(spec) ~= "string" or spec == "" or folder == nil then
		return
	end
	local list: { Follower } = {}
	for entry in string.gmatch(spec, "[^,]+") do
		local id, mutation, rarity = string.match(entry, "^([^:]+):([^:]+):([^:]+)$")
		local model = id and SpiritModels.Build(id, mutation, rarity)
		if model then
			local pivot = model:GetPivot()
			local parts: { Animated } = {}
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					local flap = d:GetAttribute("Flap")
					table.insert(parts, {
						part = d,
						base = pivot:ToObjectSpace(d.CFrame),
						flap = if type(flap) == "number" then flap else nil,
						tail = d:GetAttribute("Tail") ~= nil,
						spin = d:GetAttribute("Spin") ~= nil,
						orbit = d:GetAttribute("Orbit") :: number?,
					})
				end
			end
			model.Parent = folder
			table.insert(list, { model = model, parts = parts, pivot = CFrame.new(0, -1000, 0), seed = math.random() * 10 })
		end
	end
	followers[player] = list
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("SpiritParty"):Connect(function()
		rebuild(player)
	end)
	rebuild(player)
end

-- Where a companion should be during its ability (and how snappily it gets there).
actionPose = function(act: Action, t: number, root: BasePart, home: CFrame, now: number, seed: number): (CFrame, number)
	local target = act.target or root.Position
	local kind = act.kind
	if kind == "Bolt" or kind == "Chain" then
		-- Lunge a third of the way toward the target and spit the attack.
		local k = math.sin(t * math.pi) * 0.35
		local p = home.Position:Lerp(target + Vector3.new(0, 2, 0), k)
		return CFrame.lookAt(p, target), 0.5
	elseif kind == "Dive" or kind == "Pounce" or kind == "Toll" then
		-- Arc onto the target, then fly home.
		local k = if t < 0.45 then t / 0.45 else 1 - (t - 0.45) / 0.55
		local p = home.Position:Lerp(target + Vector3.new(0, 1.5, 0), k) + Vector3.new(0, math.sin(k * math.pi) * 5, 0)
		return CFrame.lookAt(p, target) * CFrame.Angles(0, 0, t * math.pi * 4), 0.6
	elseif kind == "Nova" or kind == "Bloom" then
		-- Rise above the owner spinning.
		local p = root.Position + Vector3.new(0, 4 + math.sin(t * math.pi) * 3, 0)
		return CFrame.new(p) * CFrame.Angles(0, t * math.pi * 6, 0), 0.5
	else
		-- Heal / Shield: circle the owner.
		local a = t * math.pi * 4 + seed
		local p = root.Position + Vector3.new(math.cos(a) * 4, 1 + t * 2, math.sin(a) * 4)
		return CFrame.lookAt(p, root.Position), 0.5
	end
end

local function rootOf(model: Model?): BasePart?
	local r = model and model:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function onSpiritCast(e: { [string]: any })
	local player = Players:GetPlayerByUserId(tonumber(e.userId) or 0)
	local list = player and followers[player]
	local f = list and list[tonumber(e.slot) or 0]
	local c = e.color
	local color = if type(c) == "table" then Color3.fromRGB(c[1], c[2], c[3]) else Color3.new(1, 1, 1)
	local ownerModel = EffectsController.ModelFor(e.ownerId)
	local targets: { Vector3 } = {}
	if type(e.targetIds) == "table" then
		for _, id in e.targetIds do
			local r = rootOf(EffectsController.ModelFor(id))
			if r then
				table.insert(targets, r.Position)
			end
		end
	end
	local kind = tostring(e.abilityKind)
	local first = targets[1] or (if typeof(e.pos) == "Vector3" then e.pos else nil)
	local from = if f then f.pivot.Position else (if rootOf(ownerModel) then (rootOf(ownerModel) :: BasePart).Position else first)
	if f then
		f.action = { kind = kind, start = os.clock(), duration = ACTION_SECONDS[kind] or 0.6, target = first, burst = e.burst == true }
	end
	if from == nil then
		return
	end
	if kind == "Bolt" and first then
		SpellFx.Bolt(from, first, color, 0.25, 0.8)
	elseif kind == "Chain" then
		local prev = from
		for i, p in targets do
			task.delay((i - 1) * 0.07, function()
				SpellFx.Lightning(prev, p, color, 0.3)
			end)
			prev = p
		end
	elseif (kind == "Dive" or kind == "Pounce") and first then
		task.delay(0.3, function()
			SpellFx.Nova(first, color, if kind == "Dive" then 7 else 4, 0.35)
			Fx.Burst(first, { texture = Fx.Textures.Fire, color = color, count = 20, speed = 20, size = 1, lifetime = 0.4 })
		end)
	elseif kind == "Toll" and first then
		SpellFx.BellDrop(first, color, 10, 0.45)
	elseif kind == "Nova" or kind == "Bloom" then
		local center = if typeof(e.pos) == "Vector3" then e.pos else from
		SpellFx.Nova(center, color, 12, 0.5)
		if kind == "Bloom" and ownerModel then
			SpellFx.Heal(ownerModel, color)
		end
	elseif kind == "Heal" and ownerModel then
		SpellFx.Heal(ownerModel, color)
	elseif kind == "Shield" and ownerModel then
		SpellFx.Barrier(ownerModel, color, 6)
	end
end

local function onSpiritBurst(e: { [string]: any })
	local owner = rootOf(EffectsController.ModelFor(e.ownerId))
	if owner == nil then
		return
	end
	local color = Color3.fromRGB(200, 150, 255)
	Fx.Pillar(owner.Position - Vector3.new(0, 2.5, 0), color, 26)
	Fx.Shockwave(owner.Position - Vector3.new(0, 2.8, 0), color, 16, 0.5)
	if e.userId == Players.LocalPlayer.UserId then
		Fx.CenterText("SPIRIT BURST", color, 48, 0.6)
		Fx.ScreenFlash(color, 0.7, 0.2)
		Fx.CameraPunch(6)
	end
end

local bulkParts: { BasePart } = {}
local bulkCFrames: { CFrame } = {}

local function update(dt: number)
	local cfg = SpiritConfig.Follow
	local now = os.clock()
	local alpha = 1 - math.exp(-cfg.smoothing * dt)
	local cam = workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero
	table.clear(bulkParts)
	table.clear(bulkCFrames)
	for player, list in followers do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			-- Far-away companions are hidden entirely (no rendering, no updates).
			local visible = (root.Position - camPos).Magnitude <= cfg.cullDistance
			local n = #list
			for i, f in list do
				if not visible then
					if f.model.Parent ~= nil then
						f.model.Parent = nil
					end
					continue
				elseif f.model.Parent == nil then
					f.model.Parent = folder
				end
				-- Fan out behind the player.
				local spread = (i - (n + 1) / 2) * cfg.spacing
				local bob = math.sin(now * 2 + f.seed) * cfg.bob
				local target = root.CFrame * CFrame.new(spread, cfg.height - 2 + bob, cfg.distance + math.abs(spread) * 0.3)
				local act = f.action
				local follow = alpha
				if act then
					local t = (now - act.start) / act.duration
					if t >= 1 then
						f.action = nil
					else
						target, follow = actionPose(act, t, root, target, now, f.seed)
					end
				end
				if f.pivot.Position.Y < -500 then
					f.pivot = target
				else
					f.pivot = f.pivot:Lerp(target, follow)
				end
				local flapAngle = math.sin(now * 10 + f.seed) * math.rad(35)
				local tailAngle = math.sin(now * 4 + f.seed) * math.rad(20)
				for _, a in f.parts do
					local rel = a.base
					if a.flap then
						rel = CFrame.Angles(0, 0, flapAngle * a.flap) * rel
					elseif a.tail then
						rel = CFrame.Angles(0, tailAngle, 0) * rel
					elseif a.spin then
						rel = CFrame.Angles(0, now * 2, 0) * rel
					elseif a.orbit then
						rel = CFrame.Angles(0, now * 3 + a.orbit * math.pi, 0) * rel
					end
					table.insert(bulkParts, a.part)
					table.insert(bulkCFrames, f.pivot * rel)
				end
			end
		end
	end
	-- One engine call moves every companion part (much cheaper than setting CFrame per part).
	if #bulkParts > 0 then
		workspace:BulkMoveTo(bulkParts, bulkCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function SpiritFollowerController.Init()
	local f = Instance.new("Folder")
	f.Name = "SpiritFollowers"
	f.Parent = workspace
	folder = f
end

function SpiritFollowerController.Start()
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)
	RunService.RenderStepped:Connect(update)
	CombatController.EventReceived:Connect(function(e)
		if e.kind == "SpiritCast" then
			onSpiritCast(e)
		elseif e.kind == "SpiritBurst" then
			onSpiritBurst(e)
		end
	end)
end

return SpiritFollowerController
