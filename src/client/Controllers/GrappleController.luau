--!strict
-- GrappleController: the grappling hook. Aim near a glowing hook point (CollectionService tag
-- "GrapplePoint": lookout towers, gate towers) and press V: a chain shoots out and pulls
-- you up onto the platform. Movement is client-owned, so this is purely local.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MovementConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MovementConfig"))
local Fx = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Fx"))
local InputController = require(script.Parent.InputController)
local MovementController = require(script.Parent.MovementController)
local AnimationController = require(script.Parent.AnimationController)

local GrappleController = { Name = "GrappleController", Priority = 62 }

local player = Players.LocalPlayer
local CFG = MovementConfig.Grapple
local target: BasePart? = nil
local readyAt = 0
local marker: BillboardGui? = nil

local function rootOf(): (Model?, BasePart?)
	local ch = player.Character
	local r = ch and ch:FindFirstChild("HumanoidRootPart")
	if ch and r and r:IsA("BasePart") then
		return ch, r
	end
	return nil, nil
end

local function landPoint(p: BasePart): Vector3
	local at = p:GetAttribute("LandAt")
	return if typeof(at) == "Vector3" then at else p.Position + Vector3.new(0, 2, 0)
end

-- Best hook point: in range, near the screen center, with a clear line to it.
local function findTarget(): BasePart?
	local ch, root = rootOf()
	local cam = workspace.CurrentCamera
	if ch == nil or root == nil or cam == nil then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ch }
	local best, bestDot = nil, CFG.minDot
	local look = cam.CFrame.LookVector
	for _, inst in CollectionService:GetTagged("GrapplePoint") do
		if inst:IsA("BasePart") and inst:IsDescendantOf(workspace) then
			local to = inst.Position - root.Position
			local d = to.Magnitude
			if d > 6 and d <= CFG.range then
				local dot = (inst.Position - cam.CFrame.Position).Unit:Dot(look)
				if dot > bestDot then
					local hit = workspace:Raycast(root.Position + Vector3.new(0, 2, 0), to, params)
					-- Hitting the tower itself near the hook still counts as a clear line.
					if hit == nil or (hit.Position - inst.Position).Magnitude < 9 then
						best, bestDot = inst, dot
					end
				end
			end
		end
	end
	return best
end

local function buildMarker(): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "GrappleMarker"
	gui.Size = UDim2.fromOffset(64, 64)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(34, 34)
	ring.Rotation = 45
	ring.BackgroundTransparency = 1
	ring.Parent = gui
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(255, 205, 110)
	st.Thickness = 3
	st.Parent = ring
	local key = Instance.new("TextLabel")
	key.AnchorPoint = Vector2.new(0.5, 0)
	key.Position = UDim2.new(0.5, 0, 1, -6)
	key.Size = UDim2.fromOffset(60, 16)
	key.BackgroundTransparency = 1
	key.Font = Enum.Font.GothamBold
	key.TextSize = 13
	key.TextColor3 = Color3.fromRGB(255, 225, 160)
	key.TextStrokeTransparency = 0.3
	key.Text = "[V] HOOK"
	key.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

-- The chain: a beam from your right hand to the hook point for the pull's duration.
local function chain(ch: Model, to: BasePart, seconds: number)
	local hand = ch:FindFirstChild("RightHand") or ch:FindFirstChild("Right Arm") or ch:FindFirstChild("HumanoidRootPart")
	if hand == nil or not hand:IsA("BasePart") then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Parent = hand
	local a1 = Instance.new("Attachment")
	a1.Parent = to
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 0.25
	beam.Width1 = 0.25
	beam.Color = ColorSequence.new(Color3.fromRGB(200, 195, 185))
	beam.LightEmission = 0.3
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Parent = hand
	for _, x in { a0, a1, beam } :: { Instance } do
		Debris:AddItem(x, seconds + 0.05)
	end
end

local function pull()
	local t = target
	local ch, root = rootOf()
	if t == nil or ch == nil or root == nil or os.clock() < readyAt then
		return
	end
	local hum = ch:FindFirstChildOfClass("Humanoid")
	if hum == nil or hum.Health <= 0 then
		return
	end
	local land = landPoint(t)
	local seconds = math.max(CFG.minSeconds, (land - root.Position).Magnitude / CFG.speed)
	readyAt = os.clock() + seconds + CFG.cooldown
	chain(ch, t, seconds)
	Fx.CameraPunch(6)
	AnimationController.Play(ch, "LightAttack", nil, { windup = 0.05, active = seconds, recovery = 0.2 }, "Air")
	-- ArcTo lands 3 studs above the given point.
	MovementController.ArcTo(land - Vector3.new(0, 3, 0), seconds, CFG.arc)
end

function GrappleController.Init() end

function GrappleController.Start()
	marker = buildMarker()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		target = findTarget()
		local m = marker
		if m then
			m.Adornee = target :: any
			m.Enabled = target ~= nil and os.clock() >= readyAt
		end
	end)
	InputController.ActionPressed:Connect(function(action: string)
		if action == "Grapple" then
			pull()
		end
	end)
end

return GrappleController
