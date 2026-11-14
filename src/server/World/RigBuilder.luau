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
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.BreakJointsOnDeath = false -- clients play a death animation instead of a limb burst
	end

	Outfits.Apply(model, look :: any, attach)
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
