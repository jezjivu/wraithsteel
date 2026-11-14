--!strict
-- ClothController: swings hanging cloth on code-built rigs (World/Outfits `hang`: Motor6Ds
-- named "Sway<piece>"). Capes, scarf tails, robe and hakama panels trail behind movement,
-- lift when the body turns, and flutter a little at rest. Only rigs near the camera animate.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local ClothController = { Name = "ClothController", Priority = 64 }

type Cloth = { motor: Motor6D, base: CFrame, phase: number, swing: number, side: number }
type Rig = { root: BasePart, cloths: { Cloth }, lastYaw: number, turn: number }

local rigs: { [Model]: Rig } = {}
local NEAR = 130 -- studs from the camera
local MAX_SWING = math.rad(65)

local function track(model: Instance)
	if not model:IsA("Model") or rigs[model] then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local cloths: { Cloth } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and string.sub(d.Name, 1, 4) == "Sway" then
			table.insert(cloths, { motor = d, base = d.C0, phase = math.random() * 6.28, swing = 0, side = 0 })
		end
	end
	if #cloths > 0 then
		local _, yaw = root.CFrame:ToEulerAnglesYXZ()
		rigs[model] = { root = root, cloths = cloths, lastYaw = yaw, turn = 0 }
	end
end

function ClothController.Init() end

function ClothController.Start()
	for _, m in CollectionService:GetTagged("Combatant") do
		task.defer(track, m)
	end
	CollectionService:GetInstanceAddedSignal("Combatant"):Connect(function(m)
		task.delay(0.5, track, m)
	end)
	-- Townsfolk are not combatants: pick them up from the NPC folder too.
	task.spawn(function()
		local folder = workspace:WaitForChild("Npcs", 30)
		if folder then
			for _, m in folder:GetChildren() do
				track(m)
			end
			folder.ChildAdded:Connect(function(m)
				task.delay(0.5, track, m)
			end)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local cam = workspace.CurrentCamera
		if cam == nil then
			return
		end
		local camPos = cam.CFrame.Position
		local now = os.clock()
		for model, rig in rigs do
			if model.Parent == nil or rig.root.Parent == nil then
				rigs[model] = nil
				continue
			end
			if (rig.root.Position - camPos).Magnitude > NEAR then
				continue
			end
			local v = rig.root.CFrame:VectorToObjectSpace(rig.root.AssemblyLinearVelocity)
			local _, yaw = rig.root.CFrame:ToEulerAnglesYXZ()
			local dyaw = (yaw - rig.lastYaw + math.pi) % (2 * math.pi) - math.pi
			rig.lastYaw = yaw
			rig.turn += ((dyaw / math.max(dt, 1e-3)) - rig.turn) * math.min(1, dt * 6)
			local forward = -v.Z -- +Z is backward in object space
			local k = math.min(1, dt * 7)
			for _, c in rig.cloths do
				-- Moving forward pushes the cloth's free end backward (negative X on a hanging
				-- piece); sideways motion and turning swing it out on Z; a slow flutter on top.
				local targetX = math.clamp(-forward * 0.06, -MAX_SWING, MAX_SWING) + math.sin(now * 2.1 + c.phase) * 0.05 * (1 + math.min(1, math.abs(forward) / 10))
				local targetZ = math.clamp(-v.X * 0.05 - rig.turn * 0.12, -MAX_SWING, MAX_SWING) + math.sin(now * 1.6 + c.phase * 1.7) * 0.03
				c.swing += (targetX - c.swing) * k
				c.side += (targetZ - c.side) * k
				c.motor.C0 = c.base * CFrame.Angles(c.swing, 0, c.side)
			end
		end
	end)
end

return ClothController
