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
	-- Rear the head back with the jaw wide, then snap forward and shut it.
	Bite = {
		windup = { Spine = { 6, 0, 0 }, Neck = { 28, 0, 0 }, Jaw = { -45, 0, 0 }, Hip_FL = { -15, 0, 0 }, Hip_FR = { -15, 0, 0 }, Hip_BL = { 20, 0, 0 }, Hip_BR = { 20, 0, 0 }, Knee_BL = { -30, 0, 0 }, Knee_BR = { -30, 0, 0 } },
		strike = { Spine = { -8, 0, 0 }, Neck = { -30, 0, 0 }, Jaw = { -2, 0, 0 }, Hip_FL = { 35, 0, 0 }, Hip_FR = { 30, 0, 0 }, Hip_BL = { -25, 0, 0 }, Hip_BR = { -25, 0, 0 } },
	},
	-- Spotted you: head thrown back in a howl.
	Howl = {
		windup = { Neck = { 45, 0, 0 }, Jaw = { -20, 0, 0 }, Spine = { 12, 0, 0 }, Hip_FL = { 10, 0, 0 }, Hip_FR = { 10, 0, 0 } },
		strike = { Neck = { 55, 0, 0 }, Jaw = { -50, 0, 0 }, Spine = { 14, 0, 0 } },
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
	local paper = model:GetAttribute("Creature") == "Wisp"
	local charging = b.action ~= nil and now - b.action.start < b.action.windup
	b.phase += dt * (if paper then (if charging then 9 else 1.6) else 25) -- talismans drift (whirl when charging), rotors spin
	local rotor = b.motors.Rotor
	if rotor and b.base[rotor] then
		rotor.C0 = b.base[rotor] * CFrame.Angles(0, b.phase, 0)
	end
	local body = b.motors.Body
	if body and b.base[body] then
		local tilt = CFrame.Angles(math.rad(math.clamp(v.Z * 1.5, -20, 20)), 0, math.rad(math.clamp(-v.X * 1.5, -20, 20)))
		local bob = CFrame.new(0, math.sin(now * 2.5) * 0.5, 0)
		if paper and charging then
			-- Gathering fire: the lantern trembles.
			bob = CFrame.new(0, 0.3, 0) * CFrame.Angles(math.rad(math.sin(now * 40) * 3), 0, math.rad(math.cos(now * 37) * 3))
		elseif paper then
			-- A lantern on an invisible string: slow pendulum sway, a lazy turn, a deeper bob.
			bob = CFrame.new(0, math.sin(now * 1.7) * 0.7, 0)
				* CFrame.Angles(math.rad(math.sin(now * 1.1) * 7), math.sin(now * 0.4) * 0.5, math.rad(math.sin(now * 1.3 + 1) * 9))
		end
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
	-- Cloth streamers ripple and trail behind the movement.
	for k = 1, 3 do
		local s1, s2 = b.motors["Streamer" .. k], b.motors["StreamerTip" .. k]
		local trail = math.clamp(v.Z * 2.5, -35, 35)
		if s1 and b.base[s1] then
			s1.C0 = b.base[s1] * CFrame.Angles(math.rad(trail + math.sin(now * 3 + k * 2) * 14), 0, math.rad(math.sin(now * 2.3 + k) * 10))
		end
		if s2 and b.base[s2] then
			s2.C0 = b.base[s2] * CFrame.Angles(math.rad(trail * 0.6 + math.sin(now * 3 + k * 2 - 0.9) * 22), 0, 0)
		end
	end
end

-- Mech (biped war machine). +X on a shoulder/hip swings the limb forward, +Z on the right
-- shoulder lifts the arm out sideways (-Z for the left), -X on the waist bends forward, +X on
-- the neck tips the head back.
local BIPED_POSES: { [string]: { windup: PoseSet, strike: PoseSet, spin: boolean? } } = {
	-- Wind back, then a straight piston punch with the whole body behind it.
	Punch = {
		windup = { Shoulder_R = { -30, 0, 30 }, Elbow_R = { 80, 0, 0 }, Waist = { 8, -35, 0 }, Shoulder_L = { 60, 0, -20 }, Hip_R = { -20, 0, 0 }, Knee_L = { -25, 0, 0 } },
		strike = { Shoulder_R = { 95, 0, -5 }, Elbow_R = { 0, 0, 0 }, Waist = { -12, 30, 0 }, Shoulder_L = { 20, 0, -30 }, Hip_L = { -35, 0, 0 }, Knee_L = { -30, 0, 0 }, Hip_R = { 25, 0, 0 } },
	},
	-- Both fists up, then down into the ground; knees buckle with the impact.
	Slam = {
		windup = { Shoulder_R = { 175, 0, 15 }, Shoulder_L = { 175, 0, -15 }, Elbow_R = { 30, 0, 0 }, Elbow_L = { 30, 0, 0 }, Waist = { 18, 0, 0 }, Neck = { 15, 0, 0 }, Hip_L = { 10, 0, 0 }, Hip_R = { 10, 0, 0 } },
		strike = { Shoulder_R = { 60, 0, 10 }, Shoulder_L = { 60, 0, -10 }, Elbow_R = { 0, 0, 0 }, Elbow_L = { 0, 0, 0 }, Waist = { -40, 0, 0 }, Hip_L = { -45, 0, 0 }, Hip_R = { -45, 0, 0 }, Knee_L = { -60, 0, 0 }, Knee_R = { -60, 0, 0 }, Neck = { -20, 0, 0 } },
	},
	-- Both rocket pods raised and aimed; recoil on firing.
	Aim = {
		windup = { Shoulder_R = { 95, 0, 15 }, Shoulder_L = { 95, 0, -15 }, Elbow_R = { 10, 0, 0 }, Elbow_L = { 10, 0, 0 }, Waist = { 5, 0, 0 }, Hip_R = { -20, 0, 0 }, Knee_R = { -20, 0, 0 }, Hip_L = { 15, 0, 0 } },
		strike = { Shoulder_R = { 110, 0, 20 }, Shoulder_L = { 110, 0, -20 }, Elbow_R = { 25, 0, 0 }, Elbow_L = { 25, 0, 0 }, Waist = { 14, 0, 0 }, Neck = { 10, 0, 0 }, Hip_R = { -25, 0, 0 }, Knee_R = { -30, 0, 0 } },
	},
	-- Head lowered, braced stance, the visor fires.
	Laser = {
		windup = { Neck = { -20, 0, 0 }, Waist = { -18, 0, 0 }, Shoulder_R = { 30, 0, 50 }, Shoulder_L = { 30, 0, -50 }, Hip_L = { 25, 0, -10 }, Hip_R = { -20, 0, 10 }, Knee_L = { -30, 0, 0 }, Knee_R = { -20, 0, 0 } },
		strike = { Neck = { -10, 0, 0 }, Waist = { -8, 0, 0 }, Shoulder_R = { 40, 0, 65 }, Shoulder_L = { 40, 0, -65 }, Hip_L = { 30, 0, -10 }, Hip_R = { -25, 0, 10 }, Knee_L = { -35, 0, 0 }, Knee_R = { -25, 0, 0 } },
	},
	-- Crouch, then a thruster launch with legs tucked and fists raised.
	Leap = {
		windup = { Hip_L = { 70, 0, 0 }, Hip_R = { 70, 0, 0 }, Knee_L = { -100, 0, 0 }, Knee_R = { -100, 0, 0 }, Waist = { -30, 0, 0 }, Shoulder_R = { -40, 0, 30 }, Shoulder_L = { -40, 0, -30 } },
		strike = { Hip_L = { 85, 0, 0 }, Hip_R = { 85, 0, 0 }, Knee_L = { -110, 0, 0 }, Knee_R = { -110, 0, 0 }, Waist = { -10, 0, 0 }, Shoulder_R = { 175, 0, 10 }, Shoulder_L = { 170, 0, -10 }, Neck = { 20, 0, 0 } },
	},
	Spin = {
		windup = { Shoulder_R = { 90, 0, 85 }, Shoulder_L = { 90, 0, -85 }, Waist = { 0, -60, 0 }, Hip_L = { 20, 0, -10 }, Hip_R = { 20, 0, 10 }, Knee_L = { -30, 0, 0 }, Knee_R = { -30, 0, 0 } },
		strike = { Shoulder_R = { 90, 0, 85 }, Shoulder_L = { 90, 0, -85 }, Waist = { 0, 60, 0 }, Hip_L = { 20, 0, -10 }, Hip_R = { 20, 0, 10 }, Knee_L = { -30, 0, 0 }, Knee_R = { -30, 0, 0 } },
		spin = true,
	},
}

local function animateBiped(model: Model, b: Beast, dt: number, now: number)
	local root = model.PrimaryPart
	if root == nil then
		return
	end
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local amount = math.clamp(speed / 12, 0, 1)
	b.phase += dt * (1.5 + amount * 5)
	local sw = math.sin(b.phase)
	local breathe = math.sin(now * 1.6) * 3
	local offsets: { [string]: Angles } = {
		Hip_L = { sw * 30 * amount, 0, 0 },
		Hip_R = { -sw * 30 * amount, 0, 0 },
		Knee_L = { -math.max(0, sw) * 40 * amount, 0, 0 },
		Knee_R = { -math.max(0, -sw) * 40 * amount, 0, 0 },
		Shoulder_L = { -sw * 20 * amount + 15, 0, -14 },
		Shoulder_R = { 15 + sw * 20 * amount, 0, 14 }, -- heavy arms swing with the stride
		Elbow_R = { 25, 0, 0 },
		Elbow_L = { 25, 0, 0 },
		Waist = { -6 + breathe * 0.4, math.sin(b.phase * 0.5) * 5 * amount, 0 },
		Neck = { breathe * 0.6 - 4, math.sin(now * 0.6) * 10, 0 },
		Jaw = { -math.max(0, math.sin(now * 0.8)) * 8, 0, 0 },
		Root = { 0, 0, math.sin(b.phase) * 3 * amount },
	}
	local a = b.action
	if a then
		local def = BIPED_POSES[a.pose]
		local t = now - a.start
		if def == nil or t > a.windup + a.active + a.recovery then
			b.action = nil
		else
			local from: PoseSet, to: PoseSet, k: number
			local spin = 0
			if t < a.windup then
				from, to, k = {}, def.windup, ease(t / a.windup)
			elseif t < a.windup + a.active then
				local f = (t - a.windup) / a.active
				from, to, k = def.windup, def.strike, ease(math.min(1, f * 1.6))
				if def.spin then
					spin = f * 720
				end
			else
				from, to, k = def.strike, {}, ease((t - a.windup - a.active) / a.recovery)
			end
			local keys: { [string]: boolean } = {}
			for n in from do
				keys[n] = true
			end
			for n in to do
				keys[n] = true
			end
			for n in keys do
				local val = lerpAng(from[n], to[n], k)
				local cur = offsets[n] or { 0, 0, 0 }
				offsets[n] = { cur[1] * 0.25 + val[1], cur[2] * 0.25 + val[2], cur[3] * 0.25 + val[3] }
			end
			if spin ~= 0 then
				local w = offsets.Waist or { 0, 0, 0 }
				offsets.Waist = { w[1], w[2] + spin, w[3] }
			end
		end
	end
	if now < b.wobbleUntil then
		local w = (b.wobbleUntil - now) * 30
		local s = offsets.Waist or { 0, 0, 0 }
		offsets.Waist = { s[1] + w * 0.5, s[2], s[3] + math.sin(now * 40) * w * 0.3 }
	end
	for name, val in offsets do
		local m = b.motors[name]
		local base = m and b.base[m]
		if m and base then
			m.C0 = base * ang(val, 1)
		end
	end
end

local function familyOf(model: Model): string
	local f = model:GetAttribute("CreatureFamily")
	if type(f) == "string" then
		return f
	end
	local c = model:GetAttribute("Creature")
	return if c == "Mech" then "Biped" elseif c == "Drone" or c == "Wisp" then "Hover" else "Quadruped"
end

local function animate(model: Model, b: Beast, dt: number, now: number)
	local family = familyOf(model)
	if family == "Biped" then
		animateBiped(model, b, dt, now)
		return
	end
	if family == "Hover" then
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
	if amount > 0.75 then
		-- Gallop: front legs reach together, back legs drive together, the spine flexes and the
		-- head pumps with each bound.
		local g = math.sin(b.phase)
		local reach = 42 * amount
		offsets.Hip_FL = { g * reach, 0, 0 }
		offsets.Hip_FR = { g * reach * 0.85, 0, 0 }
		offsets.Hip_BL = { -g * reach, 0, 0 }
		offsets.Hip_BR = { -g * reach * 0.85, 0, 0 }
		offsets.Knee_FL = { -math.max(0, -g) * 70, 0, 0 }
		offsets.Knee_FR = { -math.max(0, -g) * 60, 0, 0 }
		offsets.Knee_BL = { -math.max(0, g) * 55, 0, 0 }
		offsets.Knee_BR = { -math.max(0, g) * 50, 0, 0 }
		offsets.Spine = { g * 7, 0, 0 }
		offsets.Neck = { -g * 10 - 6, 0, 0 }
	elseif amount < 0.05 then
		-- Idle: sniff the air now and then, weight shifting.
		local sniff = math.max(0, math.sin(now * 0.45)) ^ 4
		offsets.Neck = { -breathe - sniff * 14, math.sin(now * 0.7) * 10, 0 }
		offsets.Jaw = { -sniff * 4 - math.max(0, math.sin(now * 0.9)) * 4, 0, 0 }
	end
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
		if e.kind == "Alert" then
			local model = EffectsController.ModelFor(e.sourceId)
			local b = model and beasts[model]
			if model and b and familyOf(model) == "Quadruped" and b.action == nil then
				b.action = { pose = "Howl", start = os.clock(), windup = 0.35, active = 0.6, recovery = 0.5 }
			end
		elseif e.kind == "Telegraph" then
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
