--!strict
-- ExecutionController: the Severing Blow / Shadow Strike cinematic (CombatEvent "Execution").
-- When YOUR blow finishes a posture-broken (or unaware) enemy:
--   letterbox bars -> camera cuts to a low side angle -> you step in front of the foe ->
--   slow-motion two-handed draw -> a crimson cut across the throat (white flash, ink streak
--   across the screen, red petals) -> the foe collapses as the blow lands -> camera returns.
-- Everyone else just sees the normal severing effects. Presentation only.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UI = script.Parent.Parent:WaitForChild("UI")
local Fx = require(UI:WaitForChild("Fx"))
local Kit = require(UI:WaitForChild("Kit"))

local CombatController = require(script.Parent.CombatController)
local EffectsController = require(script.Parent.EffectsController)
local AnimationController = require(script.Parent.AnimationController)
local InputController = require(script.Parent.InputController)

local ExecutionController = { Name = "ExecutionController", Priority = 54 }

local player = Players.LocalPlayer
local gui: ScreenGui? = nil
local running = false
local CRIMSON = Color3.fromRGB(220, 25, 40)

local function rootOf(m: Model?): BasePart?
	local r = m and m:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function bar(parent: Instance, top: boolean): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0, if top then 0 else 1)
	f.Position = UDim2.fromScale(0, if top then 0 else 1)
	f.Size = UDim2.new(1, 0, 0, 0)
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BorderSizePixel = 0
	f.ZIndex = 50
	f.Parent = parent
	return f
end

-- A diagonal crimson ink streak sweeping across the screen.
local function inkStreak(parent: Instance)
	local s = Instance.new("Frame")
	s.AnchorPoint = Vector2.new(0.5, 0.5)
	s.Position = UDim2.fromScale(-0.2, 0.5)
	s.Size = UDim2.new(1.6, 0, 0, 10)
	s.Rotation = -18
	s.BackgroundColor3 = CRIMSON
	s.BorderSizePixel = 0
	s.ZIndex = 51
	s.Parent = parent
	local core = Instance.new("Frame")
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Size = UDim2.new(1, 0, 0.3, 0)
	core.BackgroundColor3 = Color3.new(1, 1, 1)
	core.BorderSizePixel = 0
	core.ZIndex = 52
	core.Parent = s
	TweenService:Create(s, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1.6, 0, 0, 26) }):Play()
	task.delay(0.35, function()
		TweenService:Create(s, TweenInfo.new(0.45), { BackgroundTransparency = 1, Size = UDim2.new(1.6, 0, 0, 2) }):Play()
		TweenService:Create(core, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	end)
	task.delay(0.9, function()
		s:Destroy()
	end)
end

local function play(e: { [string]: any })
	local me = player.Character
	local target = EffectsController.ModelFor(e.targetId)
	local myRoot, tRoot = rootOf(me), rootOf(target)
	local cam = workspace.CurrentCamera
	local g = gui
	if running or me == nil or target == nil or myRoot == nil or tRoot == nil or cam == nil or g == nil then
		return
	end
	running = true
	local delaySeconds = tonumber(e.delay) or 1
	InputController.SetEnabled(false)

	-- Step in front of the foe, facing it.
	local tPos = tRoot.Position
	local away = myRoot.Position - tPos
	local flat = Vector3.new(away.X, 0, away.Z)
	local dir = if flat.Magnitude > 0.5 then flat.Unit else -tRoot.CFrame.LookVector
	local stand = tPos + dir * (3.6 + tRoot.Size.X * 0.4)
	stand = Vector3.new(stand.X, myRoot.Position.Y, stand.Z)
	myRoot.CFrame = CFrame.lookAt(stand, Vector3.new(tPos.X, stand.Y, tPos.Z))
	myRoot.AssemblyLinearVelocity = Vector3.zero

	-- Bodies: the foe sinks to a knee, you draw for the cut.
	if target:GetAttribute("Creature") == nil then
		AnimationController.Play(target, "Kneel", nil, { windup = 0.2, active = delaySeconds, recovery = 0.3 })
	end
	AnimationController.Play(me, "Execute", nil, { windup = delaySeconds * 0.5, active = 0.12, recovery = 0.7 })

	-- Letterbox.
	local top, bottom = bar(g, true), bar(g, false)
	for _, b in { top, bottom } do
		TweenService:Create(b, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Size = UDim2.new(1, 0, 0.13, 0) }):Play()
	end

	-- Camera: low side angle on both, slowly pushing in.
	local mid = (stand + tPos) / 2 + Vector3.new(0, 1.5, 0)
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local camFrom = mid + side * 11 + Vector3.new(0, 0.8, 0) + dir * 2
	local camTo = mid + side * 7.5 + Vector3.new(0, 1.6, 0) + dir * 1
	local oldType = cam.CameraType
	local oldFov = cam.FieldOfView
	cam.CameraType = Enum.CameraType.Scriptable
	local start = os.clock()
	local total = delaySeconds + 0.55
	RunService:BindToRenderStep("WraithsteelExecution", Enum.RenderPriority.Last.Value, function()
		local t = math.clamp((os.clock() - start) / total, 0, 1)
		local k = 1 - (1 - t) ^ 2
		cam.CFrame = CFrame.lookAt(camFrom:Lerp(camTo, k), mid)
	end)
	TweenService:Create(cam, TweenInfo.new(total, Enum.EasingStyle.Sine), { FieldOfView = 45 }):Play()
	Fx.ColorPulse(-0.6, 0.35, Color3.fromRGB(255, 225, 225), total)

	-- The cut.
	task.delay(delaySeconds * 0.5, function()
		AnimationController.HitStop(0.35, 0.05)
		Fx.ScreenFlash(Color3.new(1, 1, 1), 0.2, 0.12)
		inkStreak(g)
		local neck = tPos + Vector3.new(0, tRoot.Size.Y * 0.9, 0)
		Fx.Burst(neck, { color = CRIMSON, count = 40, speed = 22, size = 0.5, lifetime = 0.6, acceleration = Vector3.new(0, -12, 0) })
		Fx.Burst(neck, { texture = Fx.Textures.Sparkle, color = Color3.fromRGB(255, 170, 190), count = 30, speed = 12, size = 0.7, lifetime = 1.2, acceleration = Vector3.new(0, -4, 0) })
		Fx.Streaks(CRIMSON, 24, 0.4)
		Fx.CameraPunch(4)
	end)
	task.delay(total, function()
		RunService:UnbindFromRenderStep("WraithsteelExecution")
		cam.CameraType = if oldType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else oldType
		TweenService:Create(cam, TweenInfo.new(0.35), { FieldOfView = oldFov }):Play()
		for _, b in { top, bottom } do
			TweenService:Create(b, TweenInfo.new(0.3), { Size = UDim2.new(1, 0, 0, 0) }):Play()
		end
		task.delay(0.35, function()
			top:Destroy()
			bottom:Destroy()
		end)
		InputController.SetEnabled(true)
		running = false
	end)
end

function ExecutionController.Init()
	local g = Kit.Screen(player:WaitForChild("PlayerGui"), "Execution", 30)
	g.IgnoreGuiInset = true
	gui = g
end

function ExecutionController.Start()
	CombatController.EventReceived:Connect(function(e)
		if e.kind == "Execution" then
			local me = player.Character
			if me and EffectsController.ModelFor(e.sourceId) == me then
				play(e)
			end
		end
	end)
end

return ExecutionController
