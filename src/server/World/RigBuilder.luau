--!strict
-- RigBuilder: builds a real R15 humanoid rig in code (Players:CreateHumanoidModelFromDescription,
-- default blocky body, no uploaded assets) from an EnemyConfig.RigLook: body colors, a simple
-- part-built headwear, an optional glow, a held weapon (Shared/WeaponModels) and uniform scale.
-- Enemies and bosses use this until Studio rigs exist in ServerStorage.Enemies / .Bosses.
-- Returns nil if the engine call fails (callers fall back to a block placeholder).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local WeaponModels = require(Shared:WaitForChild("WeaponModels"))
local Outfits = require(script.Parent.Outfits)
local EnemyConfig = require(Config:WaitForChild("EnemyConfig"))

type RigLook = EnemyConfig.RigLook

local RigBuilder = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- Adds a non-colliding, massless part positioned relative to `base` and welded to it.
local function attach(model: Model, base: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CFrame = base.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = p
	weld.Parent = p
	p.Parent = model
	return p
end

local function light(part: BasePart, color: Color3, range: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = 1.5
	l.Parent = part
end

local headwear: { [string]: (Model, BasePart, RigLook) -> () } = {
	Hood = function(model, head, look)
		local c = rgb(look.accent or look.body)
		local s = head.Size
		attach(model, head, "Hood", Vector3.new(s.X * 1.25, s.Y * 0.7, s.Z * 1.2), CFrame.new(0, s.Y * 0.3, s.Z * 0.12), c, Enum.Material.Fabric)
		attach(model, head, "HoodBack", Vector3.new(s.X * 1.2, s.Y * 1.1, s.Z * 0.35), CFrame.new(0, 0, s.Z * 0.6), c, Enum.Material.Fabric)
	end,
	Helm = function(model, head, look)
		local c = rgb(look.accent or { 90, 90, 100 })
		local s = head.Size
		attach(model, head, "Helm", Vector3.new(s.X * 1.15, s.Y * 0.55, s.Z * 1.15), CFrame.new(0, s.Y * 0.35, 0), c, Enum.Material.Metal)
		attach(model, head, "Brim", Vector3.new(s.X * 1.6, s.Y * 0.1, s.Z * 1.6), CFrame.new(0, s.Y * 0.12, 0), c, Enum.Material.Metal)
	end,
	Horns = function(model, head, look)
		local c = rgb(look.accent or { 40, 30, 25 })
		local s = head.Size
		for _, side in { -1, 1 } do
			attach(model, head, "Horn", Vector3.new(s.X * 0.18, s.Y * 0.8, s.Z * 0.18), CFrame.new(side * s.X * 0.4, s.Y * 0.75, 0) * CFrame.Angles(0, 0, math.rad(-25 * side)), c, Enum.Material.SmoothPlastic)
		end
	end,
	Lantern = function(model, head, look)
		local c = rgb(look.glow or look.accent or { 255, 190, 90 })
		local s = head.Size
		attach(model, head, "LanternStem", Vector3.new(0.1, s.Y * 0.6, 0.1), CFrame.new(0, s.Y * 0.8, 0), Color3.fromRGB(40, 35, 30), Enum.Material.Metal)
		local lamp = attach(model, head, "Lantern", Vector3.new(s.X * 0.5, s.Y * 0.6, s.Z * 0.5), CFrame.new(0, s.Y * 1.35, 0), c, Enum.Material.Neon)
		light(lamp, c, 12)
	end,
	Sack = function(model, head, look)
		local s = head.Size
		attach(model, head, "Sack", Vector3.new(s.X * 1.15, s.Y * 1.15, s.Z * 1.15), CFrame.new(), rgb(look.skin), Enum.Material.Fabric)
	end,
	Hair = function(model, head, look)
		local c = rgb(look.accent or { 30, 20, 20 })
		local s = head.Size
		attach(model, head, "Hair", Vector3.new(s.X * 1.08, s.Y * 0.45, s.Z * 1.08), CFrame.new(0, s.Y * 0.35, s.Z * 0.05), Color3.fromRGB(25, 18, 18), Enum.Material.SmoothPlastic)
		attach(model, head, "Bun", Vector3.new(s.X * 0.5, s.X * 0.5, s.X * 0.5), CFrame.new(0, s.Y * 0.75, s.Z * 0.25), c, Enum.Material.Neon, Enum.PartType.Ball)
	end,
	-- Cyber visor: a glowing slit band and a chrome jaw plate.
	Visor = function(model, head, look)
		local s = head.Size
		local glow = rgb(look.glow or { 60, 230, 255 })
		attach(model, head, "VisorBand", Vector3.new(s.X * 1.12, s.Y * 0.28, s.Z * 1.12), CFrame.new(0, s.Y * 0.08, 0), Color3.fromRGB(25, 25, 32), Enum.Material.Metal)
		local slit = attach(model, head, "VisorGlow", Vector3.new(s.X * 0.9, s.Y * 0.1, 0.05), CFrame.new(0, s.Y * 0.08, -s.Z * 0.57), glow, Enum.Material.Neon)
		light(slit, glow, 10)
		attach(model, head, "JawPlate", Vector3.new(s.X * 0.9, s.Y * 0.3, s.Z * 0.3), CFrame.new(0, -s.Y * 0.32, -s.Z * 0.42), rgb(look.accent or { 160, 160, 175 }), Enum.Material.Metal)
	end,
	-- Hoplite helmet with a tall horsehair crest.
	Crest = function(model, head, look)
		local s = head.Size
		local bronze = Color3.fromRGB(180, 120, 60)
		attach(model, head, "Helmet", Vector3.new(s.X * 1.18, s.Y * 1.05, s.Z * 1.18), CFrame.new(0, s.Y * 0.08, 0), bronze, Enum.Material.Metal)
		attach(model, head, "Crest", Vector3.new(s.X * 0.22, s.Y * 0.8, s.Z * 1.5), CFrame.new(0, s.Y * 0.85, s.Z * 0.1), rgb(look.accent or { 170, 30, 30 }), Enum.Material.Fabric)
		attach(model, head, "EyeSlit", Vector3.new(s.X * 0.7, s.Y * 0.12, 0.05), CFrame.new(0, s.Y * 0.1, -s.Z * 0.6), Color3.fromRGB(10, 10, 10), Enum.Material.SmoothPlastic)
	end,
	-- Laurel wreath (Greek nobles / the Archon).
	Laurel = function(model, head, look)
		local s = head.Size
		local gold = rgb(look.glow or { 255, 205, 90 })
		attach(model, head, "Laurel", Vector3.new(s.Y * 0.18, s.X * 1.2, s.X * 1.2), CFrame.new(0, s.Y * 0.38, 0) * CFrame.Angles(0, 0, math.rad(90)), gold, Enum.Material.Neon, Enum.PartType.Cylinder)
	end,
	Bell = function(model, head, look)
		local c = rgb(look.body)
		local s = head.Size
		attach(model, head, "BellCrown", Vector3.new(s.Y * 2.2, s.X * 2.2, s.X * 2.2), CFrame.new(0, s.Y * 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)), c, Enum.Material.Metal, Enum.PartType.Cylinder)
		local slit = attach(model, head, "BellSlit", Vector3.new(s.X * 1.2, s.Y * 0.15, 0.05), CFrame.new(0, 0, -s.Z * 1.11), rgb(look.glow or { 255, 200, 120 }), Enum.Material.Neon)
		light(slit, rgb(look.glow or { 255, 200, 120 }), 14)
	end,
}

function RigBuilder.Build(look: RigLook, name: string): Model?
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = rgb(look.skin)
	desc.LeftArmColor = rgb(look.skin)
	desc.RightArmColor = rgb(look.skin)
	desc.TorsoColor = rgb(look.body)
	desc.LeftLegColor = rgb(look.legs)
	desc.RightLegColor = rgb(look.legs)
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or result == nil then
		warn("[RigBuilder] could not build rig:", result)
		return nil
	end
	local model = result :: Model
	model.Name = name

	Outfits.Apply(model, look :: any, attach)
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") and look.headwear then
		local build = headwear[look.headwear]
		if build then
			build(model, head, look)
		end
	end
	local torso = model:FindFirstChild("UpperTorso")
	if look.glow and torso and torso:IsA("BasePart") then
		light(torso, rgb(look.glow), 10)
	end
	if look.weapon then
		WeaponModels.AttachToHand(model, look.weapon, "HeldWeapon")
	end
	if look.scale ~= 1 then
		pcall(function()
			model:ScaleTo(look.scale)
		end)
		-- ScaleTo scaled the grip weld; refresh the base clients swing from.
		for _, d in model:GetDescendants() do
			if d:IsA("Weld") and d.Name == "GripWeld" then
				d:SetAttribute("BaseC0", d.C0)
			end
		end
	end
	return model
end

return RigBuilder
