--!strict
-- AnimationController: procedural body animation (no uploaded assets needed).
--
-- Every character holding a weapon stands in a combat stance (sword ready, knees bent) and
-- every swing, guard, dodge, flip and cast moves the WHOLE body - arms, torso, hips, legs -
-- with the weapon, timed by the move's windup / active / recovery from WeaponConfig.
-- Runs on every client for every visible character (own input + CombatEvent broadcasts).
--
-- How joints are posed: each joint's anchor (Motor6D.C0, or Attachment0.CFrame for the newer
-- AnimationConstraint avatar joints) is rotated in the parent part's axes:
--     anchor = CFrame.new(base.Position) * offset * base.Rotation
-- The Animator owns Motor6D.Transform / AnimationConstraint.Transform and overwrites them
-- every frame, so the anchor is the only place a script pose reliably shows up. Works for
-- R15 and R6 rigs, with Motor6D or AnimationConstraint joints.
--
-- API:
--   AnimationController.Play(model, action, moveId?, timing?, route?, speed?)
--   AnimationController.StyleFor(action, moveId?, route?) -> string
--   AnimationController.HitStop(seconds, scale)   -- freeze-frame feel on big impacts

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Config = ReplicatedStorage:WaitForChild("Config")
local AnimationConfig = require(Config:WaitForChild("AnimationConfig"))
local WeaponConfig = require(Config:WaitForChild("WeaponConfig"))
local CombatConfig = require(Config:WaitForChild("CombatConfig"))
local MovementConfig = require(Config:WaitForChild("MovementConfig"))

local AnimBuilder = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("AnimBuilder"))

local AnimationController = { Name = "AnimationController", Priority = 15 }

-- Joints -------------------------------------------------------------------------------------
-- Pose key -> the moving part (Part1) on R15, then on R6.
local JOINT_PARTS: { [string]: { string } } = {
	shoulder = { "RightUpperArm", "Right Arm" },
	elbow = { "RightLowerArm" },
	leftShoulder = { "LeftUpperArm", "Left Arm" },
	leftElbow = { "LeftLowerArm" },
	waist = { "UpperTorso" },
	root = { "LowerTorso", "Torso" },
	leftHip = { "LeftUpperLeg", "Left Leg" },
	rightHip = { "RightUpperLeg", "Right Leg" },
	leftKnee = { "LeftLowerLeg" },
	rightKnee = { "RightLowerLeg" },
}
local JOINTS = { "shoulder", "elbow", "leftShoulder", "leftElbow", "waist", "root", "leftHip", "rightHip", "leftKnee", "rightKnee" }

-- The thing we write: a Motor6D (C0) or an AnimationConstraint's Attachment0 (CFrame).
type Joint = { anchor: Instance, prop: string }
type Rig = { joints: { [string]: Joint }, phase: number, npc: boolean, lean: CFrame, warned: boolean }

local rigs: { [Model]: Rig } = {}

local function findJoint(model: Model, partNames: { string }): Joint?
	for _, partName in partNames do
		local part = model:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			-- Joints usually live inside the moving part; search the whole model as a fallback.
			for pass = 1, 2 do
				local list: { Instance } = if pass == 1 then part:GetChildren() else model:GetDescendants()
				for _, d in list do
					if d:IsA("Motor6D") and d.Part1 == part then
						return { anchor = d :: Instance, prop = "C0" }
					elseif d:IsA("AnimationConstraint") then
						local a0, a1 = d.Attachment0, d.Attachment1
						if a0 and a1 and a1.Parent == part then
							return { anchor = a0 :: Instance, prop = "CFrame" }
						end
					end
				end
			end
		end
	end
	return nil
end

local function rigOf(model: Model, npc: boolean): Rig?
	local rig = rigs[model]
	if rig then
		-- Rebuild if a joint was replaced (respawn, rig rebuild, scaling).
		local stale = false
		for _, j in rig.joints do
			if j.anchor.Parent == nil then
				stale = true
				break
			end
		end
		if not stale then
			return rig
		end
	end
	local joints: { [string]: Joint } = {}
	for key, parts in JOINT_PARTS do
		local j = findJoint(model, parts)
		if j then
			joints[key] = j
		end
	end
	if next(joints) == nil then
		if rig == nil or not rig.warned then
			local kinds = {}
			for _, d in model:GetDescendants() do
				if d:IsA("JointInstance") or d:IsA("Constraint") then
					kinds[d.ClassName] = true
				end
			end
			local list = {}
			for k in kinds do
				table.insert(list, k)
			end
			warn("[AnimationController] no posable joints on", model:GetFullName(), "joint types found:", table.concat(list, ", "))
		end
		rigs[model] = { joints = {}, phase = 0, npc = npc, lean = CFrame.new(), warned = true }
		return nil
	end
	local new: Rig = { joints = joints, phase = if rig then rig.phase else 0, npc = npc, lean = CFrame.new(), warned = false }
	rigs[model] = new
	return new
end

-- Base anchors (captured once per anchor, also saved as attribute BaseAnchor).
local baseOf: { [Instance]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
local pending: { [Joint]: CFrame } = {}
local posedLast: { [Joint]: boolean } = {}

local function baseFor(j: Joint): CFrame
	local b = baseOf[j.anchor]
	if b then
		return b
	end
	local saved = j.anchor:GetAttribute("BaseAnchor")
	local base: CFrame = if typeof(saved) == "CFrame" then saved else (j.anchor :: any)[j.prop]
	baseOf[j.anchor] = base
	j.anchor:SetAttribute("BaseAnchor", base)
	return base
end

local function pose(j: Joint, offset: CFrame)
	baseFor(j)
	local cur = pending[j]
	pending[j] = if cur then cur * offset else offset
end

local lastOffset: { [Joint]: CFrame } = setmetatable({}, { __mode = "k" }) :: any

local function flushPoses()
	for j, offset in pending do
		lastOffset[j] = offset
		if j.anchor.Parent then
			local base = baseOf[j.anchor]
			;(j.anchor :: any)[j.prop] = CFrame.new(base.Position) * offset * base.Rotation
		end
		posedLast[j] = true
	end
	for j in posedLast do
		if not pending[j] then
			posedLast[j] = nil
			local base = baseOf[j.anchor]
			if base and j.anchor.Parent then
				(j.anchor :: any)[j.prop] = base
			end
		end
	end
	table.clear(pending)
end

-- Playing moves --------------------------------------------------------------------------------
type Playing = {
	style: AnimationConfig.Style,
	start: number,
	windup: number,
	active: number,
	recovery: number,
	rest: AnimationConfig.Pose, -- stance the move starts from and returns to
	grip: Weld?, -- HeldWeapon grip weld (swung around its BaseC0)
	trail: Trail?,
}

local playing: { [Model]: Playing } = {}

-- Finds the held weapon's grip weld and trail on a rig (players and NPCs).
local function weaponParts(model: Model): (Weld?, Trail?)
	local held = model:FindFirstChild("HeldWeapon")
	local handle = held and held:FindFirstChild("Handle")
	if handle == nil then
		return nil, nil
	end
	local weld = handle:FindFirstChild("GripWeld")
	local trail = handle:FindFirstChild("SwingTrail")
	return (if weld and weld:IsA("Weld") then weld else nil), (if trail and trail:IsA("Trail") then trail else nil)
end

local function restoreWeapon(p: Playing)
	local grip = p.grip
	if grip and grip.Parent then
		local base = grip:GetAttribute("BaseC0")
		if typeof(base) == "CFrame" then
			grip.C0 = base
		end
	end
	if p.trail then
		p.trail.Enabled = false
	end
end

-- Combat stance for whatever the model holds (empty pose when unarmed).
local EMPTY: AnimationConfig.Pose = {}
local function stanceFor(model: Model): AnimationConfig.Pose
	local held = model:FindFirstChild("HeldWeapon")
	if held == nil then
		return EMPTY
	end
	local id = held:GetAttribute("WeaponId")
	local def = if type(id) == "string" then WeaponConfig.Weapons[id] else nil
	local name = if def then AnimationConfig.StanceByClass[def.class] else nil
	return AnimationConfig.Stances[name or "OneHanded"] or EMPTY
end

-- Generated animation tracks (primary path) --------------------------------------------------
-- Poses are baked into real KeyframeSequences (UI/AnimBuilder) and played by the character's
-- own Animator. Joint posing (anchors) below is only the fallback if that is unavailable.
type TrackState = {
	animator: Animator,
	loaded: { [string]: AnimationTrack },
	action: AnimationTrack?,
	actionIsGuard: boolean,
	stanceName: string?,
	stanceUpper: AnimationTrack?,
	stanceLower: AnimationTrack?,
	walk: AnimationTrack?,
}
local trackStates: { [Model]: TrackState } = {}

local function trackStateOf(model: Model): TrackState?
	if not AnimBuilder.Available() then
		return nil
	end
	local st = trackStates[model]
	if st and st.animator.Parent then
		return st
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum == nil then
		return nil
	end
	local animator = hum:FindFirstChildOfClass("Animator")
	if animator == nil then
		local a = Instance.new("Animator")
		a.Parent = hum
		animator = a
	end
	local new: TrackState = { animator = animator :: Animator, loaded = {}, action = nil, actionIsGuard = false }
	trackStates[model] = new
	return new
end

local function loadTrack(st: TrackState, id: string): AnimationTrack?
	local t = st.loaded[id]
	if t then
		return t
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local ok, track = pcall(function()
		return st.animator:LoadAnimation(anim)
	end)
	if not ok or not track then
		warn("[AnimationController] LoadAnimation failed:", track)
		return nil
	end
	st.loaded[id] = track
	return track
end

local function poseOf(style: AnimationConfig.Pose?, rest: AnimationConfig.Pose, keys: { [string]: boolean }): { [string]: { number } }
	local out: { [string]: { number } } = {}
	for k in keys do
		out[k] = ((style or {}) :: any)[k] or (rest :: any)[k] or { 0, 0, 0 }
	end
	return out
end

local function r2(x: number): string
	return string.format("%.2f", x)
end

-- A move as keyframes: rest -> windup -> strike (spins add in-between frames) -> hold -> rest.
-- Footwork + torso added to every move that does not specify them itself: the hips coil
-- into the windup and uncoil through the strike, the lead leg steps in, the body leans in.
local AUTO_WINDUP: { [string]: { number } } = { waist = { -6, 28, 0 }, root = { 6, 10, 0 }, rightHip = { 18, 0, 0 }, leftKnee = { -22, 0, 0 }, rightKnee = { -18, 0, 0 } }
local AUTO_STRIKE: { [string]: { number } } = { waist = { 10, -30, 0 }, root = { -10, -12, 0 }, leftHip = { -32, 0, 0 }, rightHip = { 26, 0, 0 }, leftKnee = { -30, 0, 0 }, rightKnee = { -12, 0, 0 } }

local function withAuto(pose: AnimationConfig.Pose, auto: { [string]: { number } }): { [string]: { number } }
	local out: { [string]: { number } } = {}
	for k, v in auto do
		out[k] = v
	end
	for k, v in pose :: any do
		out[k] = v
	end
	return out
end

-- a + (b - a) * k for every joint (k > 1 overshoots).
local function mix(a: { [string]: { number } }, b: { [string]: { number } }, k: number): { [string]: { number } }
	local out: { [string]: { number } } = {}
	for name, x in a do
		local y = b[name] or x
		out[name] = { x[1] + (y[1] - x[1]) * k, x[2] + (y[2] - x[2]) * k, x[3] + (y[3] - x[3]) * k }
	end
	return out
end

-- A move as keyframes with anticipation, overshoot and settle (so it doesn't look stiff):
--   rest -> 75% windup -> coiled windup -> overshot strike -> strike -> relaxed -> settle -> rest
local NO_FOOTWORK = { HitReact = true, HitHeavy = true, BlockRecoil = true, DeflectStrike = true, Kneel = true, DashForward = true, SideStep = true, Sweep = true, Guard = true, Dodge = true, Drink = true, Flip = true, Stagger = true, Flinch = true, Grasp = true, CastGuard = true, AirSlam = true }

local function moveFrames(styleName: string, style: AnimationConfig.Style, rest: AnimationConfig.Pose, windup: number, active: number, recovery: number): { AnimBuilder.Frame }
	local isMove = not NO_FOOTWORK[styleName] and not style.spin
	local wPose = if isMove then withAuto(style.windup, AUTO_WINDUP) else (style.windup :: any)
	local sPose = if isMove then withAuto(style.strike, AUTO_STRIKE) else (style.strike :: any)
	local keys: { [string]: boolean } = {}
	for _, p in { rest :: any, wPose, sPose } do
		for k in p do
			keys[k] = true
		end
	end
	local R = poseOf(nil, rest, keys)
	local W = poseOf(wPose, rest, keys)
	local S = poseOf(sPose, rest, keys)
	local frames: { AnimBuilder.Frame } = {}
	table.insert(frames, { t = 0, pose = R })
	table.insert(frames, { t = windup * 0.7, pose = mix(R, W, 0.85) })
	table.insert(frames, { t = windup, pose = mix(R, W, 1.08) })
	if style.spin then
		for i = 1, 3 do
			local k = i / 4
			local mid = mix(W, S, k)
			local spin = 90 * i
			local r = mid.root or { 0, 0, 0 }
			if style.spinAxis == "X" then
				mid.root = { r[1] - spin, r[2], r[3] }
			else
				mid.root = { r[1], r[2] + spin, r[3] }
			end
			table.insert(frames, { t = windup + active * k, pose = mid })
		end
	else
		table.insert(frames, { t = windup + active * 0.55, pose = mix(W, S, 1.15) })
	end
	local strikeEnd = windup + active
	local rec = math.max(recovery, AnimationConfig.BlendOut + 0.05)
	table.insert(frames, { t = strikeEnd, pose = S })
	table.insert(frames, { t = strikeEnd + rec * 0.3, pose = mix(S, R, 0.15) })
	table.insert(frames, { t = strikeEnd + rec * 0.8, pose = mix(S, R, 1.06) })
	table.insert(frames, { t = strikeEnd + rec, pose = R })
	return frames
end

local function stanceNameFor(model: Model): string?
	local held = model:FindFirstChild("HeldWeapon")
	if held == nil then
		return nil
	end
	local id = held:GetAttribute("WeaponId")
	local def = if type(id) == "string" then WeaponConfig.Weapons[id] else nil
	return (if def then AnimationConfig.StanceByClass[def.class] else nil) or "OneHanded"
end

local LOWER = { root = true, leftHip = true, rightHip = true, leftKnee = true, rightKnee = true }

-- Upper body stance (arms + torso, overrides the default arm swing) and lower body stance
-- (legs/hips, faded out while moving so the walk cycle shows).
local function updateStance(model: Model, st: TrackState, still: number)
	local name = stanceNameFor(model)
	if name ~= st.stanceName then
		if st.stanceUpper then
			st.stanceUpper:Stop(0.2)
		end
		if st.stanceLower then
			st.stanceLower:Stop(0.2)
		end
		st.stanceUpper, st.stanceLower, st.stanceName = nil, nil, name
		local stance = name and AnimationConfig.Stances[name]
		if stance then
			local upper: { [string]: { number } } = {}
			local lower: { [string]: { number } } = {}
			for k, a in stance :: any do
				if LOWER[k] then
					lower[k] = a
				else
					upper[k] = a
				end
			end
			local breathe = AnimationConfig.Walk.idleBreathDegrees
			local function shifted(dw: number, dyaw: number, darm: number): { [string]: { number } }
				local out = table.clone(upper)
				local w = upper.waist or { 0, 0, 0 }
				out.waist = { w[1] + dw, w[2] + dyaw, w[3] }
				local sh = upper.shoulder or { 0, 0, 0 }
				out.shoulder = { sh[1] + darm, sh[2], sh[3] }
				local ls = upper.leftShoulder or { 0, 0, 0 }
				out.leftShoulder = { ls[1] - darm * 0.6, ls[2], ls[3] }
				return out
			end
			local upId = AnimBuilder.Get("StanceUpper_" .. (name :: string), {
				{ t = 0, pose = shifted(0, 0, 0) },
				{ t = 0.9, pose = shifted(breathe, 3, 3) },
				{ t = 1.8, pose = shifted(breathe * 0.4, -2, -2) },
				{ t = 2.7, pose = shifted(0, 0, 0) },
			}, { loop = true, priority = Enum.AnimationPriority.Idle }, model)
			local lowId = AnimBuilder.Get("StanceLower_" .. (name :: string), { { t = 0, pose = lower }, { t = 2, pose = lower } }, { loop = true, priority = Enum.AnimationPriority.Idle }, model)
			if upId then
				local t = loadTrack(st, upId)
				if t then
					t:Play(0.25, 1, 1)
					st.stanceUpper = t
				end
			end
			if lowId then
				local t = loadTrack(st, lowId)
				if t then
					t:Play(0.25, 1, 1)
					st.stanceLower = t
				end
			end
		end
	end
	if st.stanceLower then
		st.stanceLower:AdjustWeight(math.max(still, 0.001), 0.15)
	end
end

-- Procedural walk cycle for NPCs (they have no Animate script).
local function updateWalk(model: Model, st: TrackState, speed: number, armed: boolean)
	local cfg = AnimationConfig.Walk
	if st.walk == nil then
		local frames: { AnimBuilder.Frame } = {}
		local steps = 8
		local length = 1 / cfg.cyclesPerSecond
		for i = 0, steps do
			local ph = i / steps * math.pi * 2
			local sn = math.sin(ph)
			local pose: { [string]: { number } } = {
				leftHip = { cfg.legSwingDegrees * sn, 0, 0 },
				rightHip = { -cfg.legSwingDegrees * sn, 0, 0 },
				leftKnee = { -cfg.kneeBendDegrees * math.max(0, sn), 0, 0 },
				rightKnee = { -cfg.kneeBendDegrees * math.max(0, -sn), 0, 0 },
			}
			if not armed then
				pose.shoulder = { cfg.armSwingDegrees * sn, 0, 0 }
				pose.leftShoulder = { -cfg.armSwingDegrees * sn, 0, 0 }
			end
			table.insert(frames, { t = length * i / steps, pose = pose })
		end
		local id = AnimBuilder.Get(if armed then "WalkArmed" else "Walk", frames, { loop = true, priority = Enum.AnimationPriority.Movement }, model)
		local t = id and loadTrack(st, id)
		if t then
			t:Play(0.2, 0.001, 1)
			st.walk = t
		end
	end
	local walk = st.walk
	if walk then
		local amount = math.clamp(speed / cfg.fullSpeed, 0, 1)
		walk:AdjustWeight(math.max(amount, 0.001), 0.15)
		walk:AdjustSpeed(math.max(0.4, amount * 1.2))
	end
end

-- Virtual animation clock: advances slower during hit-stop.
local vnow = 0
local timeScale = 1
local stopUntil = 0

function AnimationController.HitStop(seconds: number, scale: number)
	stopUntil = math.max(stopUntil, os.clock() + seconds)
	timeScale = math.min(timeScale, scale)
end

function AnimationController.StyleFor(action: string, moveId: string?, route: string?): string
	if route == "Air" then
		return "AirSlam"
	elseif route == "Dash" then
		return "DashStrike"
	elseif route == "Finisher" then
		return "Finisher"
	elseif action == "Flip" or action == "Stagger" then
		return action
	elseif action == "Parry" then
		return "Guard"
	elseif action == "Dodge" then
		return "Dodge"
	elseif action == "Ultimate" then
		return "Ultimate"
	elseif action == "HeavyAttack" and moveId == nil then
		return "Overhead" -- enemy heavy/perilous telegraphs
	elseif action == "AltAttack" then
		return "SlashLeft" -- enemy alternate swing
	elseif action == "Flinch" then
		return "Flinch"
	elseif AnimationConfig.Styles[action] then
		return action -- explicit style name (casts, perilous telegraphs, ...)
	end
	if moveId then
		local explicit = AnimationConfig.MoveStyles[moveId]
		if explicit then
			return explicit
		end
		local move = WeaponConfig.Moves[moveId]
		if move then
			if move.damage == 0 then
				return "Guard"
			elseif move.arcDegrees >= 300 then
				return "Spin"
			elseif move.arcDegrees <= 45 then
				return "Thrust"
			elseif action == "HeavyAttack" then
				return "Overhead"
			end
		end
		local n = tonumber(string.match(moveId, "(%d+)$"))
		if n and n % 2 == 0 then
			return "SlashLeft"
		end
	end
	return "SlashRight"
end

export type Timing = { windup: number, active: number, recovery: number }

-- timing overrides the move's frame data (used for enemy telegraphs, which have no moveId here).
function AnimationController.Play(model: Model, action: string, moveId: string?, timing: Timing?, route: string?, speed: number?)
	if model:GetAttribute("Creature") ~= nil then
		return -- beasts are animated by CreatureAnimator
	end
	local styleName = AnimationController.StyleFor(action, moveId, route)
	local style = AnimationConfig.Styles[styleName]
	if style == nil then
		return
	end
	local windup, active, recovery
	if timing then
		windup, active, recovery = timing.windup, timing.active, timing.recovery
	elseif action == "Parry" then
		windup, active, recovery = 0.05, AnimationConfig.GuardHold, 0.1
	elseif action == "Dodge" then
		windup, active, recovery = 0.05, CombatConfig.DodgeDuration, 0.1
	else
		local move = moveId and WeaponConfig.Moves[moveId]
		if move == nil then
			return
		end
		local sp = speed or 1
		windup, active, recovery = move.windup / sp, math.max(move.active, 0.08), move.recovery / sp
	end
	local previous = playing[model]
	if previous then
		restoreWeapon(previous)
	end
	local grip, trail = weaponParts(model)
	local rest = stanceFor(model)
	windup, active = math.max(windup, 0.03), math.max(active, 0.03)
	playing[model] = {
		style = style,
		start = vnow,
		windup = windup,
		active = active,
		recovery = recovery,
		rest = rest,
		grip = grip,
		trail = trail,
	}
	-- Body: a real animation track built from the same poses.
	local st = trackStateOf(model)
	if st then
		local key = table.concat({ styleName, stanceNameFor(model) or "None", r2(windup), r2(active), r2(recovery) }, "|")
		local id = AnimBuilder.Get(key, moveFrames(styleName, style, rest, windup, active, recovery), { priority = Enum.AnimationPriority.Action }, model)
		local track = id and loadTrack(st, id)
		if track then
			if st.action and st.action ~= track then
				st.action:Stop(0.08)
			end
			track:Play(0.06, 1, timeScale)
			st.action = track
			st.actionIsGuard = action == "Parry"
		end
	end
end

-- True while the model is in the windup/active part of an attack (reactions must not cut
-- an enemy's swing short: the server's timing is what counts).
local guardHeld: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local REACTIONS = { HitReact = true, HitHeavy = true, BlockRecoil = true, DeflectStrike = true, Kneel = true }
function AnimationController.IsAttacking(model: Model): boolean
	local p = playing[model]
	if p == nil then
		return false
	end
	for name, st in AnimationConfig.Styles do
		if st == p.style and REACTIONS[name] then
			return false
		end
	end
	return vnow < p.start + p.windup + p.active
end

-- Short reaction (hit / block / deflect) unless the model is mid-attack.
function AnimationController.React(model: Model, styleName: string, seconds: number?)
	if AnimationController.IsAttacking(model) then
		return
	end
	local s = seconds or 0.3
	local p = playing[model]
	local wasGuard = p ~= nil and p.style == AnimationConfig.Styles.Guard and guardHeld[model] == true
	AnimationController.Play(model, styleName, nil, { windup = s * 0.18, active = s * 0.3, recovery = s * 0.6 })
	if wasGuard then
		-- Still holding guard after the recoil: raise it again.
		task.delay(s * 0.85, function()
			if guardHeld[model] and model.Parent then
				AnimationController.HoldGuard(model, true)
			end
		end)
	end
end

-- Keeps a guard pose up while the guard button is held (Sekiro-style hold-to-guard).
function AnimationController.HoldGuard(model: Model, held: boolean)
	guardHeld[model] = held
	local p = playing[model]
	if held then
		AnimationController.Play(model, "Parry", nil, { windup = 0.06, active = 30, recovery = 0.12 })
	elseif p and p.style == AnimationConfig.Styles.Guard then
		-- Jump straight to the recovery part of the guard.
		p.start = vnow - p.windup - p.active
		local st = trackStates[model]
		if st and st.action and st.actionIsGuard then
			st.action:Stop(0.15)
			st.action = nil
		end
	end
end

local function angles(a: { number }?): CFrame
	if a == nil then
		return CFrame.new()
	end
	return CFrame.Angles(math.rad(a[1]), math.rad(a[2]), math.rad(a[3]))
end

local function lerpAngles(a: { number }?, b: { number }?, t: number): CFrame?
	if a == nil and b == nil then
		return nil
	end
	local x = a or { 0, 0, 0 }
	local y = b or { 0, 0, 0 }
	return CFrame.Angles(
		math.rad(x[1] + (y[1] - x[1]) * t),
		math.rad(x[2] + (y[2] - x[2]) * t),
		math.rad(x[3] + (y[3] - x[3]) * t)
	)
end

local function ease(t: number): number
	t = math.clamp(t, 0, 1)
	return 1 - (1 - t) * (1 - t)
end

-- Joint angles of a pose, falling back to the rest stance for joints the pose leaves out.
local function jointOf(pose: AnimationConfig.Pose, rest: AnimationConfig.Pose, name: string): { number }?
	return (pose :: any)[name] or (rest :: any)[name]
end

-- Returns the full-body offsets for this frame, or nil when the move has finished.
local function attackOffsets(p: Playing, now: number): { [string]: CFrame }?
	local t = now - p.start
	local rest = p.rest
	local fromPose: AnimationConfig.Pose, toPose: AnimationConfig.Pose, k: number
	local spinAngle = 0
	if t < p.windup then
		fromPose, toPose, k = rest, p.style.windup, ease(t / p.windup)
	elseif t < p.windup + p.active then
		local a = (t - p.windup) / p.active
		fromPose, toPose, k = p.style.windup, p.style.strike, ease(a)
		if p.style.spin then
			spinAngle = a * 360
		end
	else
		local r = t - p.windup - p.active
		local hold = p.recovery * 0.4
		local out = math.max(AnimationConfig.BlendOut, p.recovery - hold)
		if r > hold + out then
			restoreWeapon(p)
			return nil
		end
		fromPose, toPose, k = p.style.strike, rest, if r < hold then 0 else ease((r - hold) / out)
	end
	-- Weapon swing around the grip (on top of the arm motion).
	local grip = p.grip
	if grip and grip.Parent then
		local base = grip:GetAttribute("BaseC0")
		if typeof(base) == "CFrame" then
			local wFrom = if fromPose == p.style.windup then p.style.weaponWindup elseif fromPose == p.style.strike then p.style.weaponStrike else nil
			local wTo = if toPose == p.style.windup then p.style.weaponWindup elseif toPose == p.style.strike then p.style.weaponStrike else nil
			local a = wFrom or { 0, 0, 0, 0 }
			local b = wTo or { 0, 0, 0, 0 }
			local function lerp(i: number): number
				local x, y = a[i] or 0, b[i] or 0
				return x + (y - x) * k
			end
			grip.C0 = base * CFrame.new(0, lerp(4), 0) * CFrame.Angles(math.rad(lerp(1)), math.rad(lerp(2)), math.rad(lerp(3)))
		end
	end
	if p.trail then
		p.trail.Enabled = t >= p.windup - AnimationConfig.TrailLead and t <= p.windup + p.active + AnimationConfig.TrailLinger
	end

	local offsets: { [string]: CFrame } = {}
	for _, name in JOINTS do
		local offset = lerpAngles(jointOf(fromPose, rest, name), jointOf(toPose, rest, name), k)
		if name == "root" and spinAngle ~= 0 then
			local spin = if p.style.spinAxis == "X" then CFrame.Angles(math.rad(-spinAngle), 0, 0) else CFrame.Angles(0, math.rad(spinAngle), 0)
			offset = (offset or CFrame.new()) * spin
		end
		if offset then
			offsets[name] = offset
		end
	end
	return offsets
end

local function speedOf(model: Model): number
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local v = root.AssemblyLinearVelocity
		return Vector3.new(v.X, 0, v.Z).Magnitude
	end
	return 0
end

-- Idle stance: arms always; legs only while standing still (the walk cycle owns them when moving).
local LEG_JOINTS = { leftHip = true, rightHip = true, leftKnee = true, rightKnee = true, root = true }
local function stanceOffsets(model: Model, speed: number): { [string]: CFrame }
	local stance = stanceFor(model)
	local out: { [string]: CFrame } = {}
	local still = 1 - math.clamp(speed / 6, 0, 1)
	local breathe = math.sin(os.clock() * 2.2) * AnimationConfig.Walk.idleBreathDegrees
	for name, a in stance :: any do
		if LEG_JOINTS[name] then
			if still > 0.01 then
				out[name] = CFrame.Angles(math.rad(a[1] * still), math.rad(a[2] * still), math.rad(a[3] * still))
			end
		else
			out[name] = angles(a)
		end
	end
	if out.waist or next(stance) then
		out.waist = (out.waist or CFrame.new()) * CFrame.Angles(math.rad(breathe), 0, 0)
	end
	return out
end

-- Procedural walk cycle for NPC rigs (they have no Animate script).
local function walkOffsets(rig: Rig, speed: number, dt: number, armed: boolean): { [string]: CFrame }
	local cfg = AnimationConfig.Walk
	local amount = math.clamp(speed / cfg.fullSpeed, 0, 1)
	rig.phase += dt * cfg.cyclesPerSecond * math.pi * 2 * math.max(amount, 0.2)
	local swing = math.sin(rig.phase) * math.rad(cfg.legSwingDegrees) * amount
	local arm = math.sin(rig.phase) * math.rad(cfg.armSwingDegrees) * amount * (if armed then 0.35 else 1)
	local bend = math.rad(cfg.kneeBendDegrees) * amount
	return {
		leftHip = CFrame.Angles(swing, 0, 0),
		rightHip = CFrame.Angles(-swing, 0, 0),
		leftKnee = CFrame.Angles(-bend * math.max(0, math.sin(rig.phase)), 0, 0),
		rightKnee = CFrame.Angles(-bend * math.max(0, -math.sin(rig.phase)), 0, 0),
		leftShoulder = CFrame.Angles(-arm, 0, 0),
		shoulder = CFrame.Angles(arm, 0, 0),
	}
end

local function isPlayerCharacter(model: Model): boolean
	return Players:GetPlayerFromCharacter(model) ~= nil
end

local frame = 0
local lastScale = 1
local npcSet: { [Model]: boolean } = {}

local function trackNpc(model: Instance)
	if model:IsA("Model") and not isPlayerCharacter(model) and model:GetAttribute("Creature") == nil then
		npcSet[model] = true
	end
end

-- Poses one rig for this frame.
local function animate(model: Model, rig: Rig?, now: number, dt: number)
	local speed = speedOf(model)
	local armed = model:FindFirstChild("HeldWeapon") ~= nil
	local st = trackStateOf(model)
	if st then
		-- Tracks drive the body; here only the weapon swing / trail and blend weights update.
		local p = playing[model]
		if p and attackOffsets(p, now) == nil then
			playing[model] = nil
		end
		updateStance(model, st, 1 - math.clamp(speed / 6, 0, 1))
		if not isPlayerCharacter(model) then
			updateWalk(model, st, speed, armed)
		end
		return
	end
	if rig == nil then
		return
	end
	local offsets: { [string]: CFrame }
	local p = playing[model]
	local attack = if p then attackOffsets(p, now) else nil
	if p and attack == nil then
		playing[model] = nil
	end
	offsets = attack or stanceOffsets(model, speed)
	if rig.npc then
		for name, w in walkOffsets(rig, speed, dt, armed) do
			offsets[name] = w * (offsets[name] or CFrame.new())
		end
	else
		-- Momentum lean (forward when running, bank on turns).
		local L = MovementConfig.Lean
		local root = model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local v = root.CFrame:VectorToObjectSpace(root.AssemblyLinearVelocity)
			local fwd = math.clamp(-v.Z / L.fullSpeed, -1, 1)
			local side = math.clamp(v.X / L.fullSpeed, -1, 1)
			local target = CFrame.Angles(math.rad(-L.forwardDegrees * fwd), 0, math.rad(-L.sideDegrees * side))
			rig.lean = rig.lean:Lerp(target, math.min(1, dt * L.smoothing))
			offsets.root = rig.lean * (offsets.root or CFrame.new())
		end
	end
	for name, offset in offsets do
		local j = rig.joints[name]
		if j then
			pose(j, offset)
		end
	end
end

function AnimationController.Init() end

function AnimationController.Start()
	for _, m in CollectionService:GetTagged("Combatant") do
		trackNpc(m)
	end
	CollectionService:GetInstanceAddedSignal("Combatant"):Connect(function(m)
		task.defer(trackNpc, m)
	end)
	CollectionService:GetInstanceRemovedSignal("Combatant"):Connect(function(m)
		npcSet[m :: any] = nil
		rigs[m :: any] = nil
	end)

	-- PreSimulation (= Stepped) runs after the Animator has posed the rig this frame.
	RunService.PreSimulation:Connect(function(dt: number)
		if os.clock() >= stopUntil then
			timeScale = 1
		end
		vnow += dt * timeScale
		local now = vnow
		frame += 1
		local cam = workspace.CurrentCamera
		local camPos = if cam then cam.CFrame.Position else Vector3.zero

		for _, plr in Players:GetPlayers() do
			local ch = plr.Character
			if ch and ch.Parent then
				local rig = if AnimBuilder.Available() then nil else rigOf(ch, false)
				animate(ch, rig, now, dt)
			end
		end
		-- NPCs. LOD: far ones are not animated (unless mid-attack); mid-distance every other frame.
		for model in npcSet do
			if model.Parent == nil then
				npcSet[model] = nil
				rigs[model] = nil
				playing[model] = nil
				continue
			end
			local root = model.PrimaryPart
			if root and playing[model] == nil then
				local d = (root.Position - camPos).Magnitude
				if d > AnimationConfig.Lod.far or (d > AnimationConfig.Lod.near and frame % 2 == 0) then
					-- Hold the last pose instead of snapping back to neutral.
					local rig = rigs[model]
					if rig then
						for _, j in rig.joints do
							local last = lastOffset[j]
							if last and not pending[j] then
								pending[j] = last
							end
						end
					end
					continue
				end
			end
			local rig = if AnimBuilder.Available() then nil else rigOf(model, true)
			animate(model, rig, now, dt)
		end
		for model in playing do
			if model.Parent == nil then
				playing[model] = nil
			end
		end
		for model in rigs do
			if model.Parent == nil then
				rigs[model] = nil
			end
		end
		for model, st in trackStates do
			if model.Parent == nil then
				trackStates[model] = nil
			elseif st.action and timeScale ~= lastScale then
				st.action:AdjustSpeed(timeScale) -- hit-stop slows the swing too
			end
		end
		lastScale = timeScale
		flushPoses()
	end)
end

return AnimationController
