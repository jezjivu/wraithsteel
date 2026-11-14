--!strict
-- ExplorationController: shows this player's own progress on world secrets
-- (server: ExplorationService). Opened shortcut gates swing open and stop colliding for you;
-- relics you already took disappear for you.

local TweenService = game:GetService("TweenService")

local DataController = require(script.Parent.DataController)

local ExplorationController = { Name = "ExplorationController", Priority = 60 }

-- Gate models already swung open (by instance: a model that streams out and back in is new).
local opened: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function openGate(model: Model, animate: boolean)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local side = p:GetAttribute("Side")
			local hinge = p:GetAttribute("Hinge")
			if type(side) == "number" and typeof(hinge) == "CFrame" then
				p.CanCollide = false
				-- Swing the leaf 100 degrees around its hinge, away from the opening side.
				local rel = hinge:ToObjectSpace(p.CFrame)
				local target = hinge * CFrame.Angles(0, math.rad(100 * side), 0) * rel
				if animate then
					TweenService:Create(p, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = target }):Play()
				else
					p.CFrame = target
				end
			elseif p.Name == "Bar" then
				p.Transparency = 1
				local pp = p:FindFirstChildOfClass("ProximityPrompt")
				if pp then
					pp.Enabled = false
				end
			end
		end
	end
end

local function hideRelic(model: Model)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Transparency = 1
		elseif p:IsA("ProximityPrompt") then
			p.Enabled = false
		elseif p:IsA("Light") then
			p.Enabled = false
		elseif p:IsA("ParticleEmitter") then
			p.Enabled = false
		end
	end
end

local function apply(animate: boolean)
	local folder = workspace:FindFirstChild("Exploration")
	if folder == nil then
		return
	end
	local shortcuts = DataController.Get("shortcuts") or {}
	local relics = DataController.Get("relics") or {}
	for _, m in folder:GetChildren() do
		if m:IsA("Model") then
			local sid = m:GetAttribute("Shortcut")
			local rid = m:GetAttribute("Relic")
			if type(sid) == "string" and shortcuts[sid] and not opened[m] then
				opened[m] = true
				openGate(m, animate)
			elseif type(rid) == "string" and relics[rid] then
				hideRelic(m)
			end
		end
	end
end

function ExplorationController.Init() end

function ExplorationController.Start()
	task.spawn(function()
		local folder = workspace:WaitForChild("Exploration", 60)
		if folder == nil then
			return
		end
		DataController.WaitForSnapshot()
		apply(false)
		folder.ChildAdded:Connect(function()
			task.wait(0.2)
			apply(false)
		end)
	end)
	DataController.Changed:Connect(function(key)
		if key == "shortcuts" or key == "relics" then
			apply(true)
		end
	end)
end

return ExplorationController
