--!strict
-- KunaiController: Shadow Kunai (B). Sends the aim (lock-on target, else the camera's look) to
-- KunaiService and draws every kunai in flight from the server's CombatEvent "Kunai".

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local CombatConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CombatConfig"))
local Fx = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Fx"))
local InputController = require(script.Parent.InputController)
local CombatController = require(script.Parent.CombatController)
local CameraController = require(script.Parent.CameraController)
local AnimationController = require(script.Parent.AnimationController)

local KunaiController = { Name = "KunaiController", Priority = 63 }

local player = Players.LocalPlayer

local function aimDirection(): Vector3?
	local ch = player.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local target = CameraController.Target()
	local tr = target and target:FindFirstChild("HumanoidRootPart")
	local dir = if tr and tr:IsA("BasePart") then tr.Position - root.Position else (workspace.CurrentCamera :: Camera).CFrame.LookVector
	local flat = Vector3.new(dir.X, 0, dir.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else nil
end

local function throw()
	local ch = player.Character
	if ch == nil or (tonumber(ch:GetAttribute("Kunai")) or 0) <= 0 then
		if ch then
			Fx.CenterText("NO KUNAI - rest at a waystone", Color3.fromRGB(200, 160, 150), 20, 0.6)
		end
		return
	end
	local dir = aimDirection()
	if dir == nil then
		return
	end
	local root = ch:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		-- Face the throw.
		root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	end
	AnimationController.Play(ch, "CastPush", nil, { windup = 0.05, active = 0.1, recovery = 0.2 })
	Net.Client.Fire("ThrowKunai", dir)
end

-- A spinning dark blade with a faint trail.
local function fly(from: Vector3, to: Vector3, hit: boolean)
	local dist = (to - from).Magnitude
	local seconds = math.max(0.05, dist / CombatConfig.Kunai.speed)
	local blade = Instance.new("Part")
	blade.Name = "Kunai"
	blade.Size = Vector3.new(0.25, 0.25, 1.6)
	blade.Color = Color3.fromRGB(40, 40, 46)
	blade.Material = Enum.Material.Metal
	blade.Anchored = true
	blade.CanCollide = false
	blade.CanQuery = false
	blade.CanTouch = false
	blade.CFrame = CFrame.lookAt(from, to)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0, 0.7)
	a0.Parent = blade
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0, -0.7)
	a1.Parent = blade
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(Color3.fromRGB(200, 200, 230))
	trail.Lifetime = 0.15
	trail.LightEmission = 0.6
	trail.Parent = blade
	blade.Parent = workspace
	TweenService:Create(blade, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(to, to + (to - from)) }):Play()
	Debris:AddItem(blade, seconds + 0.05)
	if hit then
		task.delay(seconds, function()
			Fx.Burst(to, { color = Color3.fromRGB(255, 230, 180), count = 10, speed = 14, size = 0.3, lifetime = 0.25 })
		end)
	end
end

function KunaiController.Init() end

function KunaiController.Start()
	InputController.ActionPressed:Connect(function(action: string)
		if action == "Kunai" then
			throw()
		end
	end)
	CombatController.EventReceived:Connect(function(e)
		if e.kind == "Kunai" and typeof(e.from) == "Vector3" and typeof(e.to) == "Vector3" then
			fly(e.from, e.to, e.hit == true)
		end
	end)
end

return KunaiController
