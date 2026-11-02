--!strict
-- CreatureAnimator: animates part-built beasts (World/CreatureBuilder) on every client.
-- Joints are Motor6Ds named Spine, Neck, Jaw, Hip_*, Knee_*, Tail1..4; there is no Animator
-- on these rigs, so their C0s are posed directly (base C0 * offset).
--   * trotting gait from the root's speed (diagonal leg pairs), breathing, swaying tail
--   * attack poses from Telegraph events (BossConfig move `pose`): windup -> strike -> recover
--   * hit wobble on damage

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local CombatController = require(script.Parent.CombatController)
local EffectsController = require(script.Parent.EffectsController)

local CreatureAnimator = { Name = "CreatureAnimator", Priority = 53 }

type Angles = { number }
type PoseSet = { [string]: Angles }

-- Degrees {x, y, z}. +X on a hip swings the leg forward; +X on Spine/Neck lifts the front;
-- -X on Jaw opens the mouth.
local POSES: { [string]: { windup: PoseSet, strike: PoseSet, spin: boolean? } } = {
	Swipe = {
		windup = { Hip_FR = { 85, 0, 25 }, Knee_FR = { -50, 0, 0 }, Spine = { 8, 20, 0 }, Neck = { 10, -15, 0 }, Jaw = { -20, 0, 0 } },
		strike = { Hip_FR = { 20, 0, -40 }, Knee_FR = { -10, 0, 0 }, Spine = { -4, -25, 0 }, Neck = { -5, 20, 0 }, Jaw = { -30, 0, 0 } },
	},
	Pounce = {
		windup = { Spine = { -10, 0, 0 }, Hip_FL = { -25, 0, 0 }, Hip_FR = { -25, 0, 0 }, Hip_BL = { 30, 0, 0 }, Hip_BR = { 30, 0, 0 }, Knee_BL = { -60, 0, 0 }, Knee_BR = { -60, 0, 0 }, Neck = { -10, 0, 0 } },
		strike = { Spine = { 14, 0, 0 }, Hip_FL = { 75, 0, 0 }, Hip_FR = { 75, 0, 0 }, Hip_BL = { -45, 0, 0 }, Hip_BR = { -45, 0, 0 }, Neck = { 10, 0, 0 }, Jaw = { -40, 0, 0 } },
	},
	Rear = {
		windup = { Spine = { 38, 0, 0 }, Hip_FL = { 70, 0, 0 }, Hip_FR = { 70, 0, 0 }, Knee_FL = { -60, 0, 0 }, Knee_FR = { -60, 0, 0 }, Hip_BL = { -20, 0, 0 }, Hip_BR = { -20, 0, 0 }, Neck = { 20, 0, 0 }, Jaw = { -35, 0, 0 } },
		strike = { Spine = { -12, 0, 0 }, Hip_FL = { 10, 0, 0 }, Hip_FR = { 10, 0, 0 }, Neck = { -15, 0, 0 }, Jaw = { -10, 0, 0 } },
	},
	Roar = {
		windup = { Neck = { 35, 0, 0 }, Jaw = { -15, 0, 0 }, Spine = { 10, 0, 0 } },
		strike = { Neck = { 15, 0, 0 }, Jaw = { -50, 0, 0 }, Spine = { 4, 0, 0 } },
	},
	Spit = {
		windup = { Neck = { 25, 0, 0 }, Jaw = { -10, 0, 0 }, Spine = { 6, 0, 0 } },
		strike = { Neck = { -18, 0, 0 }, Jaw = { -45, 0, 0 }, Spine = { -6, 0, 0 } },
	},
	Spin = {
		windup = { Spine = { 0, 40, 0 }, Neck = { 0, -20, 0 } },
		strike = { Spine = { 0, -40, 0 } },
		spin = true,
	},
}

type Action = { pose: string, start: number, windup: number, active: number, recovery: number }
type Beast = { motors: { [string]: Motor6D }, base: { [Motor6D]: CFrame }, phase: number, action: Action?, wobbleUntil: number }

local beasts: { [Model]: Beast } = {}

local function track(model: Instance)
	if not model:IsA("Model") or model:GetAttribute("Creature") == nil or beasts[model] then
		return
	end
	local motors: { [string]: Motor6D } = {}
	local base: { [Motor6D]: CFrame } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
			base[d] = d.C0
		end
	end
	beasts[model] = { motors = motors, base = base, phase = 0, action = nil, wobbleUntil = 0 }
end

local function ang(a: Angles?, k: number): CFrame
	if a == nil then
		return CFrame.new()
	end
	return CFrame.Angles(math.rad(a[1] * k), math.rad(a[2] * k), math.rad(a[3] * k))
end

local function lerpAng(a: Angles?, b: Angles?, t: number): Angles
	local x = a or { 0, 0, 0 }
	local y = b or { 0, 0, 0 }
	return { x[1] + (y[1] - x[1]) * t, x[2] + (y[2] - x[2]) * t, x[3] + (y[3] - x[3]) * t }
end

local function ease(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Attack offsets for this frame (nil = no action).
local function actionOffsets(a: Action, now: number): { [string]: Angles }?
	local def = POSES[a.pose]
	if def == nil then
		return nil
	end
	local t = now - a.start
	local from: PoseSet, to: PoseSet, k: number
	local spin = 0
	if t < a.windup then
		from, to, k = {}, def.windup, ease(t / a.windup)
	elseif t < a.windup + a.active then
		local f = (t - a.windup) / a.active
		from, to, k = def.windup, def.strike, ease(math.min(1, f * 1.6))
		if def.spin then
			spin = f * 360
		end
	elseif t < a.windup + a.active + a.recovery then
		from, to, k = def.strike, {}, ease((t - a.windup - a.active) / a.recovery)
	else
		return nil
	end
	local out: { [string]: Angles } = {}
	local keys: { [string]: boolean } = {}
	for name in from do
		keys[name] = true
	end
	for name in to do
		keys[name] = true
	end
	for name in keys do
		out[name] = lerpAng(from[name], to[name], k)
	end
	if spin ~= 0 then
		local s = out.Spine or { 0, 0, 0 }
		out.Spine = { s[1], s[2] + spin, s[3] }
	end
	return out
end

-- Drones: rotor spin, body bob + tilt into movement, eye flick, recoil on attacks.
local function animateDrone(model: Model, b: Beast, dt: number, now: number)
	local root = model.PrimaryPart
	if root == nil then
		return
	end
	local v = root.CFrame:VectorToObjectSpace(root.AssemblyLinearVelocity)
	b.phase += dt * 25
	local rotor = b.motors.Rotor
	if rotor and b.base[rotor] then
		rotor.C0 = b.base[rotor] * CFrame.Angles(0, b.phase, 0)
	end
	local body = b.motors.Body
	if body and b.base[body] then
		local tilt = CFrame.Angles(math.rad(math.clamp(v.Z * 1.5, -20, 20)), 0, math.rad(math.clamp(-v.X * 1.5, -20, 20)))
		local bob = CFrame.new(0, math.sin(now * 2.5) * 0.5, 0)
		local recoil = CFrame.new()
		local a = b.action
		if a then
			local t = now - a.start
			if t < a.windup then
				recoil = CFrame.Angles(math.rad(-15 * (t / a.windup)), 0, 0) -- rear back while charging
			elseif t < a.windup + a.active + a.recovery then
				recoil = CFrame.new(0, 0, 0.6) * CFrame.Angles(math.rad(10), 0, 0)
			else
				b.action = nil
			end
		end
		if now < b.wobbleUntil then
			recoil = recoil * CFrame.Angles(0, 0, math.sin(now * 50) * 0.3)
		end
		body.C0 = b.base[body] * bob * tilt * recoil
	end
	local eye = b.motors.Eye
	if eye and b.base[eye] then
		eye.C0 = b.base[eye] * CFrame.Angles(0, math.sin(now * 1.3) * 0.4, 0)
	end
end

local function animate(model: Model, b: Beast, dt: number, now: number)
	if model:GetAttribute("Creature") == "Drone" then
		animateDrone(model, b, dt, now)
		return
	end
	local root = model.PrimaryPart
	if root == nil then
		return
	end
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local amount = math.clamp(speed / 16, 0, 1)
	b.phase += dt * (2 + amount * 7)
	local sw = math.sin(b.phase) * 34 * amount
	local lift = math.max(0, math.sin(b.phase)) * 45 * amount
	local lift2 = math.max(0, -math.sin(b.phase)) * 45 * amount
	local breathe = math.sin(now * 2) * 2
	-- Trot: FL+BR together, FR+BL together.
	local offsets: { [string]: Angles } = {
		Hip_FL = { sw, 0, 0 },
		Hip_BR = { sw, 0, 0 },
		Hip_FR = { -sw, 0, 0 },
		Hip_BL = { -sw, 0, 0 },
		Knee_FL = { -lift, 0, 0 },
		Knee_BR = { -lift, 0, 0 },
		Knee_FR = { -lift2, 0, 0 },
		Knee_BL = { -lift2, 0, 0 },
		Spine = { breathe * 0.5, math.sin(b.phase * 0.5) * 3 * amount, 0 },
		Neck = { -breathe, math.sin(now * 0.7) * 8, 0 },
		Jaw = { -math.max(0, math.sin(now * 0.9)) * 6, 0, 0 },
	}
	for i = 1, 4 do
		offsets["Tail" .. i] = { 8 + math.sin(now * 3 - i * 0.6) * 6, math.sin(now * 2.2 - i * 0.7) * (14 + i * 4), 0 }
	end
	local a = b.action
	if a then
		local act = actionOffsets(a, now)
		if act == nil then
			b.action = nil
		else
			for name, val in act do
				local cur = offsets[name] or { 0, 0, 0 }
				offsets[name] = { cur[1] * 0.3 + val[1], cur[2] * 0.3 + val[2], cur[3] * 0.3 + val[3] }
			end
		end
	end
	if now < b.wobbleUntil then
		local w = (b.wobbleUntil - now) * 40
		local s = offsets.Spine or { 0, 0, 0 }
		offsets.Spine = { s[1] - w * 0.4, s[2], s[3] + math.sin(now * 40) * w * 0.3 }
	end
	for name, val in offsets do
		local m = b.motors[name]
		local base = m and b.base[m]
		if m and base then
			m.C0 = base * ang(val, 1)
		end
	end
end

function CreatureAnimator.Init() end

function CreatureAnimator.Start()
	for _, m in CollectionService:GetTagged("Combatant") do
		track(m)
	end
	CollectionService:GetInstanceAddedSignal("Combatant"):Connect(function(m)
		task.defer(track, m)
	end)
	CombatController.EventReceived:Connect(function(e)
		if e.kind == "Telegraph" then
			local model = EffectsController.ModelFor(e.sourceId)
			local b = model and beasts[model]
			if b then
				b.action = {
					pose = if type(e.pose) == "string" then e.pose else "Swipe",
					start = os.clock(),
					windup = math.max(0.15, tonumber(e.windup) or 0.5),
					active = math.max(0.1, tonumber(e.active) or 0.2),
					recovery = math.max(0.2, tonumber(e.recovery) or 0.5),
				}
			end
		elseif e.kind == "Damage" then
			local model = EffectsController.ModelFor(e.targetId)
			local b = model and beasts[model]
			if b and (tonumber(e.damage) or 0) > 0 then
				b.wobbleUntil = os.clock() + 0.25
			end
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		for model, b in beasts do
			if model.Parent == nil then
				beasts[model] = nil
			else
				animate(model, b, dt, now)
			end
		end
	end)
end

return CreatureAnimator
