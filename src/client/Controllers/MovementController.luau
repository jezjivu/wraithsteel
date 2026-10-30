--!strict
-- MovementController: the local player's dynamic movement (their character's physics is
-- client-owned, so movement feel lives here; the server still validates combat).
--   * Dash: camera-relative, eased burst with afterimage ghosts, wind burst, blur + FOV kick;
--     works in the air (air dashes per jump from the fighting style)
--   * Double jump with a flip, sprint (Shift / L3) with FOV boost
--   * Surge (attack step-in root motion), Plunge (air slam), Knockback (pushes from hits)
--
-- API:
--   MovementController.CanDash() -> boolean
--   MovementController.Dash()
--   MovementController.Surge(studs, seconds)
--   MovementController.Plunge()
--   MovementController.Blink(dir, distance) -> (from, to)  -- Ghost Step teleport

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = ReplicatedStorage:WaitForChild("Config")
local MovementConfig = require(Config:WaitForChild("MovementConfig"))
local StyleConfig = require(Config:WaitForChild("StyleConfig"))

local Fx = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Fx"))
local AnimationController = require(script.Parent.AnimationController)

local MovementController = { Name = "MovementController", Priority = 16 }

local player = Players.LocalPlayer
local airJumpsUsed = 0
local airDashesUsed = 0
local sprinting = false
local plunging = false

local function parts(): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character and hum and root and root:IsA("BasePart") then
		return character, hum, root
	end
	return nil, nil, nil
end

local function style(): StyleConfig.StyleDef
	local id = player:GetAttribute("FightingStyle")
	return StyleConfig.Get(if type(id) == "string" then id else nil)
end

local function styleColor(): Color3
	local c = style().color
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function airborne(hum: Humanoid): boolean
	return hum.FloorMaterial == Enum.Material.Air
end

-- Drives the root with a world-space velocity curve for `seconds` (LinearVelocity so it wins
-- over the humanoid controller). keepY = leave vertical velocity to gravity.
local function drive(root: BasePart, seconds: number, velocityAt: (t: number) -> Vector3, keepY: boolean)
	local att = Instance.new("Attachment")
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	-- PerAxis force limits: the default (Magnitude, MaxForce 1000) is far too weak against the
	-- humanoid's ground friction, which is why ground dashes barely moved. keepY = no vertical
	-- force at all, so gravity / jumps still act normally.
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	lv.MaxAxesForce = if keepY then Vector3.new(1e6, 0, 1e6) else Vector3.new(1e6, 1e6, 1e6)
	lv.Parent = root
	local start = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local t = (os.clock() - start) / seconds
		if t >= 1 or root.Parent == nil then
			conn:Disconnect()
			lv:Destroy()
			att:Destroy()
			return
		end
		local v = velocityAt(t)
		lv.VectorVelocity = if keepY then Vector3.new(v.X, 0, v.Z) else v
	end)
end

-- Ghost copies of the character's visible parts, tinted and fading (dash trail).
local function afterimage(character: Model, color: Color3)
	local folder = Instance.new("Folder")
	folder.Name = "Afterimage"
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 0.9 then
			local ok, ghost = pcall(function()
				return d:Clone()
			end)
			if ok and ghost then
				for _, c in ghost:GetChildren() do
					if not (c:IsA("SpecialMesh") or c:IsA("Decal")) then
						c:Destroy()
					end
				end
				ghost.Anchored = true
				ghost.CanCollide = false
				ghost.CanQuery = false
				ghost.CanTouch = false
				ghost.CastShadow = false
				ghost.Material = Enum.Material.Neon
				ghost.Color = color
				ghost.Transparency = 0.45
				ghost.CFrame = d.CFrame
				ghost.Parent = folder
				TweenService:Create(ghost, TweenInfo.new(MovementConfig.Dash.afterimageFade), { Transparency = 1 }):Play()
			end
		end
	end
	folder.Parent = workspace
	Debris:AddItem(folder, MovementConfig.Dash.afterimageFade + 0.05)
end

local function blurPulse(size: number, seconds: number)
	local blur = Instance.new("BlurEffect")
	blur.Size = size
	blur.Parent = Lighting
	TweenService:Create(blur, TweenInfo.new(seconds), { Size = 0 }):Play()
	Debris:AddItem(blur, seconds + 0.05)
end

function MovementController.CanDash(): boolean
	local _, hum = parts()
	if hum == nil then
		return false
	end
	if airborne(hum) then
		return airDashesUsed < style().airDashes
	end
	return true
end

function MovementController.Dash()
	local character, hum, root = parts()
	if character == nil or hum == nil or root == nil then
		return
	end
	local inAir = airborne(hum)
	if inAir then
		airDashesUsed += 1
	end
	local cfg = MovementConfig.Dash
	local dir = hum.MoveDirection
	if dir.Magnitude < 0.1 then
		dir = -root.CFrame.LookVector -- no input: back-step
	end
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local distance = cfg.distance * style().dashDistance
	-- Eased burst: v(t) = v0 * (1 - t)^1.5, integral over the dash = distance.
	local v0 = distance / (0.4 * cfg.seconds)
	if not inAir then
		-- Small hop so the dash clears bumps and doesn't scrape along the floor.
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, cfg.hop), v.Z)
	end
	drive(root, cfg.seconds, function(t)
		local k = (1 - t) ^ 1.5
		return dir * v0 * k
	end, not inAir)

	local color = styleColor()
	AnimationController.Play(character, "Dodge", nil)
	Fx.Burst(root.Position - Vector3.new(0, 2.6, 0), { texture = Fx.Textures.Smoke, color = Color3.fromRGB(215, 210, 200), count = 14, speed = 10, size = 2.4, lifetime = 0.6, lightEmission = 0, acceleration = Vector3.new(0, 4, 0) })
	Fx.Burst(root.Position, { color = color, count = 18, speed = 26, size = 0.4, lifetime = 0.3, spread = 40 })
	Fx.Shockwave(root.Position - Vector3.new(0, 2.6, 0), color, 6, 0.25)
	Fx.CameraPunch(cfg.fovKick)
	blurPulse(cfg.blur, cfg.seconds)
	local flash = Instance.new("Highlight")
	flash.FillColor = color
	flash.OutlineColor = color
	flash.FillTransparency = 0.6
	flash.Parent = character
	TweenService:Create(flash, TweenInfo.new(cfg.seconds), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	Debris:AddItem(flash, cfg.seconds + 0.05)
	task.spawn(function()
		local untilT = os.clock() + cfg.seconds
		while os.clock() < untilT and character.Parent do
			afterimage(character, color)
			task.wait(cfg.afterimageEvery)
		end
	end)
end

-- Attack step-in: short forward surge during the active frames.
function MovementController.Surge(studs: number, seconds: number)
	local _, _, root = parts()
	if root == nil or studs <= 0 then
		return
	end
	local dir = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local v = studs / math.max(seconds, 0.05)
	drive(root, seconds, function(t)
		return dir * v * (1.4 - t * 0.8)
	end, true)
end

-- Air slam: dive to the ground, shockwave on landing.
function MovementController.Plunge()
	local character, hum, root = parts()
	if character == nil or hum == nil or root == nil or plunging then
		return
	end
	plunging = true
	root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X * 0.3, -MovementConfig.Plunge.speed, root.AssemblyLinearVelocity.Z * 0.3)
	local color = styleColor()
	task.spawn(function()
		local deadline = os.clock() + 1.5
		while airborne(hum) and os.clock() < deadline do
			task.wait()
		end
		plunging = false
		local p = root.Position - Vector3.new(0, 2.6, 0)
		Fx.Shockwave(p, color, MovementConfig.Plunge.shockRadius, 0.4)
		Fx.Burst(p, { texture = Fx.Textures.Smoke, color = Color3.fromRGB(190, 180, 165), count = 24, speed = 22, size = 2.5, lifetime = 0.7, lightEmission = 0, acceleration = Vector3.new(0, 6, 0) })
		Fx.Burst(p, { color = color, count = 20, speed = 30, size = 0.5, lifetime = 0.4 })
		Fx.CameraPunch(6)
	end)
end

-- Ghost Step: teleport along `dir`, stopping short of walls.
function MovementController.Blink(dir: Vector3, distance: number): (Vector3?, Vector3?)
	local character, _, root = parts()
	if character == nil or root == nil then
		return nil, nil
	end
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 1e-3 then
		return nil, nil
	end
	flat = flat.Unit
	local from = root.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, workspace:FindFirstChild("SpiritFollowers") or character }
	local hit = workspace:Raycast(from, flat * distance, params)
	local travel = if hit then math.max(0, (hit.Position - from).Magnitude - 2) else distance
	local to = from + flat * travel
	afterimage(character, styleColor())
	root.CFrame = CFrame.lookAt(to, to + flat)
	root.AssemblyLinearVelocity = flat * 20
	Fx.CameraPunch(8)
	blurPulse(10, 0.25)
	return from, to
end

function MovementController.Knockback(velocity: Vector3, seconds: number)
	local _, _, root = parts()
	if root == nil then
		return
	end
	drive(root, seconds, function(t)
		return velocity * (1 - t)
	end, velocity.Y <= 0.1)
end

local function setSprint(on: boolean)
	local _, hum = parts()
	sprinting = on
	if hum then
		hum.WalkSpeed = if on then MovementConfig.SprintSpeed else MovementConfig.WalkSpeed
	end
	local cam = workspace.CurrentCamera
	if cam then
		local fov = MovementConfig.BaseFov + (if on then MovementConfig.SprintFovBoost else 0)
		Fx.SetBaseFov(fov)
		TweenService:Create(cam, TweenInfo.new(0.25), { FieldOfView = fov }):Play()
	end
end

local function onCharacter(character: Model)
	local hum = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if hum == nil then
		return
	end
	airJumpsUsed, airDashesUsed, plunging = 0, 0, false
	hum.WalkSpeed = if sprinting then MovementConfig.SprintSpeed else MovementConfig.WalkSpeed
	hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
			airJumpsUsed = 0
			airDashesUsed = 0
		end
	end)
end

function MovementController.Init() end

function MovementController.Start()
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	-- Double jump with a flip.
	UserInputService.JumpRequest:Connect(function()
		local character, hum, root = parts()
		if character == nil or hum == nil or root == nil then
			return
		end
		if airborne(hum) and airJumpsUsed < MovementConfig.AirJumps and root.AssemblyLinearVelocity.Y < 30 then
			airJumpsUsed += 1
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(v.X, MovementConfig.DoubleJumpPower, v.Z)
			AnimationController.Play(character, "Flip", nil, { windup = 0.05, active = 0.4, recovery = 0.1 })
			Fx.Shockwave(root.Position - Vector3.new(0, 2.6, 0), styleColor(), 5, 0.3)
			Fx.Burst(root.Position - Vector3.new(0, 2.6, 0), { color = styleColor(), count = 12, speed = 12, size = 0.4, lifetime = 0.35, acceleration = Vector3.new(0, -20, 0) })
		end
	end)

	ContextActionService:BindAction("WraithsteelSprint", function(_, state)
		if state == Enum.UserInputState.Begin then
			setSprint(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			setSprint(false)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
end

return MovementController
