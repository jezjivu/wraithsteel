--!strict
-- SpiritFollowerController: renders every player's equipped Spirits as floating companions
-- (client-side only, built by Shared/SpiritModels from the SpiritParty player attribute).
-- Companions trail behind their player in a fan, bob, flap wings/fins and sway tails.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local SpiritModels = require(Shared:WaitForChild("SpiritModels"))
local SpiritConfig = require(Config:WaitForChild("SpiritConfig"))

local SpiritFollowerController = { Name = "SpiritFollowerController", Priority = 50 }

type Animated = { part: BasePart, base: CFrame, flap: number?, tail: boolean }
type Follower = { model: Model, parts: { Animated }, pivot: CFrame, seed: number }

local folder: Folder? = nil
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
				if f.pivot.Position.Y < -500 then
					f.pivot = target
				else
					f.pivot = f.pivot:Lerp(target, alpha)
				end
				local flapAngle = math.sin(now * 10 + f.seed) * math.rad(35)
				local tailAngle = math.sin(now * 4 + f.seed) * math.rad(20)
				for _, a in f.parts do
					local rel = a.base
					if a.flap then
						rel = CFrame.Angles(0, 0, flapAngle * a.flap) * rel
					elseif a.tail then
						rel = CFrame.Angles(0, tailAngle, 0) * rel
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
end

return SpiritFollowerController
