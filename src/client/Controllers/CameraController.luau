--!strict
-- CameraController: lock-on targeting. Tab / middle mouse / R3 locks onto the nearest enemy in
-- front of the camera (press again to release, or to switch when the target dies). While locked:
-- the camera frames you and the target, your character keeps facing it, a red reticle marks it,
-- and CombatController's aim uses it (the server still validates every hit).
--
-- API:
--   CameraController.Target() -> Model?

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CombatConfig"))

local CameraController = { Name = "CameraController", Priority = 60 }

local localPlayer = Players.LocalPlayer
local target: Model? = nil
local reticle: BillboardGui? = nil

function CameraController.Target(): Model?
	return target
end

local function rootOf(m: Model?): BasePart?
	local r = m and m:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function alive(m: Model?): boolean
	local h = m and m:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0 and m ~= nil and m.Parent ~= nil
end

local function pick(): Model?
	local character = localPlayer.Character
	local root = rootOf(character)
	local cam = workspace.CurrentCamera
	if root == nil or cam == nil then
		return nil
	end
	local cfg = CombatConfig.LockOn
	local look = cam.CFrame.LookVector
	local best, bestScore = nil, math.huge
	for _, m in CollectionService:GetTagged("Combatant") do
		if m:IsA("Model") and m ~= character and Players:GetPlayerFromCharacter(m) == nil and alive(m) then
			local r = rootOf(m)
			if r then
				local d = r.Position - root.Position
				local dist = d.Magnitude
				if dist <= cfg.range and dist > 0.1 then
					local facing = d.Unit:Dot(look)
					if facing > -0.2 then
						local score = dist * (2 - facing)
						if score < bestScore then
							best, bestScore = m, score
						end
					end
				end
			end
		end
	end
	return best
end

local function setReticle(m: Model?)
	if reticle then
		reticle:Destroy()
		reticle = nil
	end
	local r = rootOf(m)
	if r == nil then
		return
	end
	local g = Instance.new("BillboardGui")
	g.Size = UDim2.fromOffset(36, 36)
	g.AlwaysOnTop = true
	g.Adornee = r
	local d = Instance.new("Frame")
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Position = UDim2.fromScale(0.5, 0.5)
	d.Size = UDim2.fromOffset(18, 18)
	d.Rotation = 45
	d.BackgroundTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 70, 60)
	stroke.Thickness = 3
	stroke.Parent = d
	d.Parent = g
	g.Parent = localPlayer:WaitForChild("PlayerGui")
	reticle = g
end

local function release()
	target = nil
	setReticle(nil)
	local hum = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.AutoRotate = true
	end
end

local function toggle(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if target then
		release()
	else
		target = pick()
		setReticle(target)
	end
	return Enum.ContextActionResult.Sink
end

function CameraController.Init() end

function CameraController.Start()
	ContextActionService:BindAction("WraithsteelLockOn", toggle, false, Enum.KeyCode.Tab, Enum.UserInputType.MouseButton3, Enum.KeyCode.ButtonR3)
	localPlayer.CharacterAdded:Connect(release)

	RunService:BindToRenderStep("WraithsteelLockOn", Enum.RenderPriority.Camera.Value + 2, function(dt: number)
		if target == nil then
			return
		end
		local character = localPlayer.Character
		local root = rootOf(character)
		local troot = rootOf(target)
		local cfg = CombatConfig.LockOn
		if root == nil or troot == nil or not alive(target) or (troot.Position - root.Position).Magnitude > cfg.breakRange then
			-- Target died or ran off: hop to the next one, or release.
			local nextTarget = if root then pick() else nil
			if nextTarget and nextTarget ~= target then
				target = nextTarget
				setReticle(target)
			else
				release()
			end
			return
		end
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.AutoRotate = false
		end
		-- Face the target (yaw only).
		local flat = Vector3.new(troot.Position.X, root.Position.Y, troot.Position.Z)
		if (flat - root.Position).Magnitude > 0.5 then
			root.CFrame = root.CFrame:Lerp(CFrame.lookAt(root.Position, flat), math.min(1, dt * 12))
		end
		-- Over-the-shoulder framing of player + target.
		local cam = workspace.CurrentCamera
		if cam then
			local toTarget = (troot.Position - root.Position)
			local dir = Vector3.new(toTarget.X, 0, toTarget.Z).Unit
			local right = dir:Cross(Vector3.yAxis)
			local camPos = root.Position - dir * cfg.distance + Vector3.yAxis * cfg.height + right * cfg.shoulder
			local focus = root.Position:Lerp(troot.Position, 0.5) + Vector3.yAxis * 1.5
			cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(camPos, focus), math.min(1, dt * cfg.smoothing))
		end
	end)
end

return CameraController
