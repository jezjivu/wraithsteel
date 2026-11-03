--!strict
-- LostEmberController: shows where your dropped Ember is (profile.lostEmber, server:
-- LostEmberService): a smouldering ember wisp with a tall beam and a label, visible only to you.

local TweenService = game:GetService("TweenService")

local DataController = require(script.Parent.DataController)

local LostEmberController = { Name = "LostEmberController", Priority = 61 }

local marker: Model? = nil

local function clear()
	if marker then
		marker:Destroy()
		marker = nil
	end
end

local function show(pile: { [string]: any })
	clear()
	local amount = tonumber(pile.amount) or 0
	if amount <= 0 then
		return
	end
	local pos = Vector3.new(tonumber(pile.x) or 0, tonumber(pile.y) or 0, tonumber(pile.z) or 0)
	local m = Instance.new("Model")
	m.Name = "LostEmber"
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(1.6, 1.6, 1.6)
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.Material = Enum.Material.Neon
	core.Color = Color3.fromRGB(255, 120, 50)
	core.CFrame = CFrame.new(pos + Vector3.new(0, 1.2, 0))
	core.Parent = m
	TweenService:Create(core, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { CFrame = core.CFrame + Vector3.new(0, 0.8, 0), Size = Vector3.new(2, 2, 2) }):Play()
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 130, 60)
	light.Range = 14
	light.Brightness = 2
	light.Parent = core
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 150, 60), Color3.fromRGB(200, 40, 20))
	fire.LightEmission = 1
	fire.Size = NumberSequence.new(1.2, 0)
	fire.Lifetime = NumberRange.new(0.6, 1.1)
	fire.Rate = 20
	fire.Speed = NumberRange.new(1, 3)
	fire.Parent = core
	-- Tall faint beam so you can find it from afar.
	local beam = Instance.new("Part")
	beam.Name = "Beam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 120, 50)
	beam.Transparency = 0.75
	beam.Size = Vector3.new(0.6, 80, 0.6)
	beam.CFrame = CFrame.new(pos + Vector3.new(0, 40, 0))
	beam.Parent = m
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(180, 40)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 600
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = 16
	t.TextColor3 = Color3.fromRGB(255, 170, 100)
	t.TextStrokeTransparency = 0.3
	t.Text = string.format("LOST EMBER  %d", amount)
	t.Parent = gui
	gui.Adornee = core
	gui.Parent = core
	m.Parent = workspace
	marker = m
end

function LostEmberController.Init() end

function LostEmberController.Start()
	task.spawn(function()
		DataController.WaitForSnapshot()
		local pile = DataController.Get("lostEmber")
		if type(pile) == "table" then
			show(pile)
		end
	end)
	DataController.Changed:Connect(function(key, value)
		if key == "lostEmber" then
			if type(value) == "table" then
				show(value)
			else
				clear()
			end
		end
	end)
end

return LostEmberController
