--!strict
-- AnimationConfig: procedural (code-driven) combat poses used until real animations are
-- uploaded. AnimationController blends R15 joints between these poses using each move's
-- windup / active / recovery timing from WeaponConfig, so every weapon class moves differently.
-- Angles are degrees {x, y, z} in the parent part's axes (R15 / R6, Motor6D or
-- AnimationConstraint joints). +X on a shoulder/hip swings the limb FORWARD, -X on a knee bends
-- it, +Z on the right shoulder lifts the arm out to the side (use -Z for the left arm).
-- TODO(Studio/Agent B): tune by eye in Studio; replace with real animations when uploaded
-- (a move with a non-placeholder animationId plays that instead).

export type Pose = {
	shoulder: { number }?, -- RightShoulder
	elbow: { number }?, -- RightElbow
	leftShoulder: { number }?, -- LeftShoulder
	leftElbow: { number }?, -- LeftElbow
	waist: { number }?, -- Waist (UpperTorso twist)
	root: { number }?, -- Root (whole-body lean / spin)
	leftHip: { number }?, -- legs: stances, lunges, tucks
	rightHip: { number }?,
	leftKnee: { number }?,
	rightKnee: { number }?,
}

export type Style = {
	windup: Pose, -- reached at the end of windup
	strike: Pose, -- reached at the end of the active window
	spin: boolean?, -- rotate the whole body 360 degrees during active frames
	spinAxis: "X" | "Y" | nil, -- Y (default) = pirouette, X = forward flip
	-- Weapon swing around the grip, in the weapon's own space (+Y = blade direction):
	-- {x, y, z} degrees plus optional 4th value = push along the blade (studs).
	weaponWindup: { number }?,
	weaponStrike: { number }?,
}

local AnimationConfig = {}

-- How to read a pose (verified with tools/render_poses.py, WeaponConfig.GripRotation = -125):
--   right shoulder {X, Y, Z}: Z lifts the arm OUT to the side, then Y sweeps that arm level
--     around the body (+Y = toward the front / across to the left), then X pitches it
--     (X 90 = straight forward). Left shoulder mirrors Z (out = negative) and Y (forward = -Y).
--   elbow / knee: X bends. waist / root: -X leans FORWARD, +X leans back; +Y turns to the
--     LEFT. root may add a shift (studs) after the angles.
--   weapon {X, Y, Z [, push]}: around the grip. X -45 lays the blade along the forearm (reach),
--     X 0 = the natural 45-degree guard angle, X +45 = blade square to the forearm;
--     Z swings it sideways (+ = left), push slides it along the blade.
AnimationConfig.Styles = {
	-- Forehand: blade cocked behind the right shoulder, swept level through the target.
	SlashRight = {
		windup = { shoulder = { 10, -40, 90 }, elbow = { 25, 0, 0 }, leftShoulder = { 35, 0, -25 }, leftElbow = { 50, 0, 0 }, waist = { 4, -35, 0 }, root = { 6, -14, 0, 0, -0.5, 0.6 }, leftHip = { 18, 0, -6 }, rightHip = { -26, 0, 10 }, leftKnee = { -32, 0, 0 }, rightKnee = { -30, 0, 0 } },
		strike = { shoulder = { 0, 100, 85 }, elbow = { 5, 0, 0 }, leftShoulder = { 15, 0, -50 }, leftElbow = { 20, 0, 0 }, waist = { -10, 35, 0 }, root = { -12, 14, 0, 0, -0.9, -1.4 }, leftHip = { -50, 0, -4 }, rightHip = { 38, 0, 6 }, leftKnee = { -46, 0, 0 }, rightKnee = { -12, 0, 0 } },
		weaponWindup = { -45, 0, 0 },
		weaponStrike = { -50, 0, 0 },
	},
	-- Backhand: blade across the body at the left, swept out to the right.
	SlashLeft = {
		windup = { shoulder = { 10, 125, 80 }, elbow = { 35, 0, 0 }, leftShoulder = { 25, 0, -40 }, leftElbow = { 40, 0, 0 }, waist = { 4, 35, 0 }, root = { 6, 14, 0, 0, -0.5, 0.6 }, leftHip = { 18, 0, -6 }, rightHip = { -26, 0, 10 }, leftKnee = { -32, 0, 0 }, rightKnee = { -30, 0, 0 } },
		strike = { shoulder = { 5, 60, 90 }, elbow = { 5, 0, 0 }, leftShoulder = { 25, 0, -25 }, leftElbow = { 30, 0, 0 }, waist = { -10, -35, 0 }, root = { -12, -14, 0, 0, -0.9, -1.4 }, leftHip = { -50, 0, -4 }, rightHip = { 38, 0, 6 }, leftKnee = { -46, 0, 0 }, rightKnee = { -12, 0, 0 } },
		weaponWindup = { -45, 0, 0 },
		weaponStrike = { -50, 0, 0 },
	},
	-- Two-handed vertical cut: blade raised behind the head, chopped down along the arms.
	Overhead = {
		windup = { shoulder = { 170, 0, -8 }, elbow = { 60, 0, 0 }, leftShoulder = { 165, 0, 12 }, leftElbow = { 70, 0, 0 }, waist = { 14, 0, 0 }, root = { 8, 0, 0, 0, -0.3, 0.5 }, leftHip = { 18, 0, -6 }, rightHip = { -26, 0, 10 }, leftKnee = { -32, 0, 0 }, rightKnee = { -30, 0, 0 } },
		strike = { shoulder = { 55, 0, -14 }, elbow = { 0, 0, 0 }, leftShoulder = { 55, 0, 18 }, leftElbow = { 8, 0, 0 }, waist = { -22, 0, 0 }, root = { -14, 0, 0, 0, -1.1, -1.6 }, leftHip = { -50, 0, -4 }, rightHip = { 38, 0, 6 }, leftKnee = { -46, 0, 0 }, rightKnee = { -12, 0, 0 } },
		weaponWindup = { 45, 0, 0 },
		weaponStrike = { -50, 0, 0 },
	},
	-- Blade drawn back at the hip, then driven straight out with a long lunge.
	Thrust = {
		windup = { shoulder = { -15, 0, 18 }, elbow = { 100, 0, 0 }, leftShoulder = { 45, 0, -15 }, leftElbow = { 70, 0, 0 }, waist = { 0, -30, 0 }, root = { 4, -12, 0, 0, -0.5, 0.8 }, leftHip = { 18, 0, -6 }, rightHip = { -26, 0, 10 }, leftKnee = { -32, 0, 0 }, rightKnee = { -30, 0, 0 } },
		strike = { shoulder = { 88, 0, -6 }, elbow = { 0, 0, 0 }, leftShoulder = { -25, 0, -30 }, leftElbow = { 10, 0, 0 }, waist = { -4, 22, 0 }, root = { -16, 10, 0, 0, -1.2, -2.2 }, leftHip = { -50, 0, -4 }, rightHip = { 38, 0, 6 }, leftKnee = { -46, 0, 0 }, rightKnee = { -12, 0, 0 } },
		weaponWindup = { -45, 0, 0 },
		weaponStrike = { -45, 0, 0, 0.6 },
	},
	-- Whirl: blade held out level at arm's length while the whole body turns.
	Spin = {
		windup = { shoulder = { 0, -40, 90 }, elbow = { 10, 0, 0 }, leftShoulder = { 0, 0, -80 }, leftElbow = { 10, 0, 0 }, waist = { 0, -30, 0 }, root = { 0, 0, 0, 0, -0.6, 0 }, leftHip = { -20, 0, -15 }, rightHip = { 20, 0, 15 }, leftKnee = { -30, 0, 0 }, rightKnee = { -30, 0, 0 } },
		strike = { shoulder = { 0, 40, 90 }, elbow = { 0, 0, 0 }, leftShoulder = { 0, 0, -80 }, leftElbow = { 0, 0, 0 }, waist = { 0, 25, 0 }, root = { 0, 0, 0, 0, -0.6, 0 }, leftHip = { -25, 0, -20 }, rightHip = { 25, 0, 20 }, leftKnee = { -30, 0, 0 }, rightKnee = { -30, 0, 0 } },
		spin = true,
		weaponWindup = { -45, 0, 0 },
		weaponStrike = { -45, 0, 0 },
	},
	-- Draw cut: blade tucked low at the left hip, drawn across to the right in one line.
	DashStrike = {
		windup = { shoulder = { 25, 130, 40 }, elbow = { 70, 0, 0 }, leftShoulder = { 20, 0, 20 }, leftElbow = { 70, 0, 0 }, waist = { -8, 40, 0 }, root = { -10, 16, 0, 0, -1.0, 0 }, leftHip = { 40, 0, -8 }, rightHip = { -30, 0, 10 }, leftKnee = { -70, 0, 0 }, rightKnee = { -60, 0, 0 } },
		strike = { shoulder = { 10, 40, 95 }, elbow = { 0, 0, 0 }, leftShoulder = { -30, 0, -40 }, leftElbow = { 10, 0, 0 }, waist = { -12, -40, 0 }, root = { -24, -18, 0, 0, -1.3, -1.8 }, leftHip = { -50, 0, -4 }, rightHip = { 38, 0, 6 }, leftKnee = { -46, 0, 0 }, rightKnee = { -12, 0, 0 } },
		weaponWindup = { -50, 0, 0 },
		weaponStrike = { -50, 0, 0 },
	},
	-- Rising launcher: from low behind, up through the target to the sky (with a spin).
	Finisher = {
		windup = { shoulder = { -30, 0, 25 }, elbow = { 15, 0, 0 }, leftShoulder = { 20, 0, -30 }, leftElbow = { 40, 0, 0 }, waist = { -18, -25, 0 }, root = { 16, -10, 0, 0, -1.2, 0.4 }, leftHip = { 40, 0, -8 }, rightHip = { -30, 0, 10 }, leftKnee = { -70, 0, 0 }, rightKnee = { -60, 0, 0 } },
		strike = { shoulder = { 178, 0, -5 }, elbow = { 0, 0, 0 }, leftShoulder = { 120, 0, -40 }, leftElbow = { 20, 0, 0 }, waist = { 14, 15, 0 }, root = { -10, 0, 0, 0, 0.4, -0.8 }, leftHip = { -30, 0, 0 }, rightHip = { 20, 0, 0 }, leftKnee = { -10, 0, 0 }, rightKnee = { -50, 0, 0 } },
		spin = true,
		weaponWindup = { -50, 0, 0 },
		weaponStrike = { -45, 0, 0 },
	},
	-- Hold-to-guard: blade slanted across the body, left hand bracing behind it.
	Guard = {
		windup = { shoulder = { 65, 0, -20 }, elbow = { 65, 0, 0 }, leftShoulder = { 62, 0, 30 }, leftElbow = { 80, 0, 0 }, waist = { -4, -12, 0 }, root = { 4, 8, 0, 0, -0.5, 0.3 }, leftHip = { 24, 0, -6 }, rightHip = { -18, 0, 8 }, leftKnee = { -32, 0, 0 }, rightKnee = { -28, 0, 0 } },
		strike = { shoulder = { 65, 0, -20 }, elbow = { 65, 0, 0 }, leftShoulder = { 62, 0, 30 }, leftElbow = { 80, 0, 0 }, waist = { -4, -12, 0 }, root = { 4, 8, 0, 0, -0.5, 0.3 }, leftHip = { 24, 0, -6 }, rightHip = { -18, 0, 8 }, leftKnee = { -32, 0, 0 }, rightKnee = { -28, 0, 0 } },
		weaponWindup = { 0, 0, 55 },
		weaponStrike = { 0, 0, 55 },
	},
	Dodge = {
		windup = { root = { -20, 0, 0 }, shoulder = { -30, 0, 15 }, elbow = { 20, 0, 0 }, leftShoulder = { -30, 0, -15 }, leftHip = { -40, 0, 0 }, rightHip = { 30, 0, 0 }, leftKnee = { -40, 0, 0 }, rightKnee = { -20, 0, 0 } },
		strike = { root = { -30, 0, 0 }, shoulder = { -50, 0, 20 }, elbow = { 10, 0, 0 }, leftShoulder = { -50, 0, -20 }, leftHip = { -55, 0, 0 }, rightHip = { 40, 0, 0 }, leftKnee = { -60, 0, 0 } },
		weaponWindup = { -45, 0, 0 },
		weaponStrike = { -45, 0, 0 },
	},
	-- Interrupted (enemies): jolted back, blade knocked up and out.
	Flinch = {
		windup = { root = { 12, 0, 0, 0, 0, 0.5 }, waist = { 12, 15, 0 }, shoulder = { 70, 0, 40 }, elbow = { 30, 0, 0 }, leftShoulder = { 20, 0, -35 } },
		strike = { root = { 6, 0, 0 }, waist = { 4, 5, 0 } },
		weaponWindup = { 40, 0, -30 },
		weaponStrike = { 10, 0, 0 },
	},
	Flip = {
		windup = { leftHip = { 60, 0, 0 }, rightHip = { 60, 0, 0 }, leftKnee = { -90, 0, 0 }, rightKnee = { -90, 0, 0 }, shoulder = { 40, 0, 10 }, elbow = { 60, 0, 0 }, leftShoulder = { 40, 0, -10 } },
		strike = { leftHip = { 70, 0, 0 }, rightHip = { 70, 0, 0 }, leftKnee = { -100, 0, 0 }, rightKnee = { -100, 0, 0 }, shoulder = { 30, 0, 10 }, elbow = { 70, 0, 0 } },
		spin = true,
		spinAxis = "X",
		weaponWindup = { -30, 0, 0 },
		weaponStrike = { -30, 0, 0 },
	},
	-- Plunging air attack: both hands high, blade hammered down along the arms.
	AirSlam = {
		windup = { shoulder = { 175, 0, -5 }, elbow = { 50, 0, 0 }, leftShoulder = { 170, 0, 10 }, leftElbow = { 60, 0, 0 }, root = { 15, 0, 0 }, waist = { 12, 0, 0 }, leftKnee = { -70, 0, 0 }, rightKnee = { -70, 0, 0 }, leftHip = { 40, 0, 0 }, rightHip = { 40, 0, 0 } },
		strike = { shoulder = { 35, 0, -12 }, elbow = { 0, 0, 0 }, leftShoulder = { 35, 0, 15 }, leftElbow = { 5, 0, 0 }, root = { -25, 0, 0 }, waist = { -25, 0, 0 }, leftKnee = { -60, 0, 0 }, rightKnee = { -20, 0, 0 }, leftHip = { 20, 0, 0 }, rightHip = { 30, 0, 0 } },
		weaponWindup = { 40, 0, 0 },
		weaponStrike = { -60, 0, 0 },
	},
	-- Spinning flash cut that ends in a rising arc.
	Ultimate = {
		windup = { shoulder = { 170, 0, -8 }, elbow = { 60, 0, 0 }, leftShoulder = { 165, 0, 12 }, leftElbow = { 70, 0, 0 }, waist = { 15, 0, 0 }, root = { 10, 0, 0, 0, -0.4, 0 }, leftKnee = { -60, 0, 0 }, rightKnee = { -60, 0, 0 }, leftHip = { 30, 0, 0 }, rightHip = { 30, 0, 0 } },
		strike = { shoulder = { 55, 0, -14 }, elbow = { 0, 0, 0 }, leftShoulder = { 55, 0, 18 }, leftElbow = { 8, 0, 0 }, waist = { -20, 0, 0 }, root = { -10, 0, 0, 0, -1.0, 0 }, leftHip = { -50, 0, 0 }, rightHip = { 40, 0, 0 }, leftKnee = { -45, 0, 0 } },
		spin = true,
		weaponWindup = { 45, 0, 0 },
		weaponStrike = { -50, 0, 0 },
	},
	-- Reactions (EffectsController): getting hit, guarding a hit, deflecting, posture broken.
	HitReact = {
		windup = { root = { 16, 0, 8, 0, -0.3, 0.9 }, waist = { 14, -14, 0 }, shoulder = { 20, 0, 30 }, elbow = { 30, 0, 0 }, leftShoulder = { 25, 0, -30 }, leftHip = { -14, 0, 0 }, rightHip = { 10, 0, 0 }, leftKnee = { -10, 0, 0 }, rightKnee = { -30, 0, 0 } },
		strike = { root = { 8, 0, 3 }, waist = { 6, -6, 0 }, shoulder = { 30, 0, 20 }, elbow = { 30, 0, 0 }, leftShoulder = { 20, 0, -20 } },
		weaponWindup = { 20, 0, 0 },
		weaponStrike = { 0, 0, 0 },
	},
	HitHeavy = {
		windup = { root = { 28, 0, 12, 0, -0.8, 1.8 }, waist = { 24, -22, 0 }, shoulder = { -10, 0, 60 }, elbow = { 20, 0, 0 }, leftShoulder = { 10, 0, -60 }, leftHip = { -30, 0, 0 }, rightHip = { 25, 0, 0 }, leftKnee = { -45, 0, 0 }, rightKnee = { -50, 0, 0 } },
		strike = { root = { 14, 0, 5 }, waist = { 10, -10, 0 }, shoulder = { 20, 0, 30 }, elbow = { 20, 0, 0 }, leftShoulder = { 20, 0, -30 }, leftKnee = { -30, 0, 0 }, rightKnee = { -30, 0, 0 } },
		weaponWindup = { 40, 0, 0 },
		weaponStrike = { 10, 0, 0 },
	},
	-- A guarded hit shoves the guard back into the body.
	BlockRecoil = {
		windup = { shoulder = { 55, 0, -20 }, elbow = { 85, 0, 0 }, leftShoulder = { 52, 0, 30 }, leftElbow = { 95, 0, 0 }, waist = { 10, -12, 0 }, root = { 10, 8, 0, 0, -0.7, 0.9 }, leftHip = { 12, 0, -6 }, rightHip = { -26, 0, 8 }, leftKnee = { -40, 0, 0 }, rightKnee = { -40, 0, 0 } },
		strike = { shoulder = { 65, 0, -20 }, elbow = { 65, 0, 0 }, leftShoulder = { 62, 0, 30 }, leftElbow = { 80, 0, 0 }, waist = { -4, -12, 0 }, root = { 4, 8, 0, 0, -0.5, 0.3 }, leftKnee = { -32, 0, 0 }, rightKnee = { -28, 0, 0 } },
		weaponWindup = { 10, 0, 60 },
		weaponStrike = { 0, 0, 55 },
	},
	-- A perfect deflect: the blade meets the strike across the body, then snaps it away.
	DeflectStrike = {
		windup = { shoulder = { 70, 0, -25 }, elbow = { 55, 0, 0 }, leftShoulder = { 60, 0, 30 }, leftElbow = { 80, 0, 0 }, waist = { 0, 15, 0 }, root = { -4, 6, 0, 0, -0.4, 0 }, leftHip = { -20, 0, 0 }, rightHip = { 15, 0, 0 }, leftKnee = { -20, 0, 0 }, rightKnee = { -20, 0, 0 } },
		strike = { shoulder = { 75, -10, 45 }, elbow = { 15, 0, 0 }, leftShoulder = { 30, 0, -30 }, leftElbow = { 40, 0, 0 }, waist = { -4, -25, 0 }, root = { -10, -10, 0, 0, -0.6, -0.6 }, leftHip = { -35, 0, 0 }, rightHip = { 25, 0, 0 }, leftKnee = { -30, 0, 0 }, rightKnee = { -15, 0, 0 } },
		weaponWindup = { 0, 0, 60 },
		weaponStrike = { -30, 0, -40 },
	},
	-- Posture broken: down on one knee, blade dragging.
	Kneel = {
		windup = { root = { -8, 0, 0, 0, -1.6, 0 }, waist = { -20, 0, 0 }, leftHip = { 85, 0, 0 }, leftKnee = { -95, 0, 0 }, rightHip = { -10, 0, 0 }, rightKnee = { -95, 0, 0 }, shoulder = { 15, 0, 15 }, leftShoulder = { 30, 0, -10 } },
		strike = { root = { -10, 0, 0, 0, -1.7, 0 }, waist = { -24, 0, 0 }, leftHip = { 80, 0, 0 }, leftKnee = { -95, 0, 0 }, rightHip = { -10, 0, 0 }, rightKnee = { -95, 0, 0 }, shoulder = { 10, 0, 15 }, leftShoulder = { 25, 0, -10 } },
		weaponWindup = { 30, 0, 0 },
		weaponStrike = { 40, 0, 0 },
	},
	-- Directional dashes (MovementController picks one from the dash direction).
	DashForward = {
		windup = { root = { -28, 0, 0, 0, -0.6, 0 }, waist = { 10, 0, 0 }, shoulder = { -45, 0, 15 }, leftShoulder = { -45, 0, -15 }, leftHip = { 45, 0, 0 }, rightHip = { -35, 0, 0 }, leftKnee = { -50, 0, 0 }, rightKnee = { -30, 0, 0 } },
		strike = { root = { -32, 0, 0, 0, -0.9, 0 }, waist = { 12, 0, 0 }, shoulder = { -55, 0, 20 }, leftShoulder = { -55, 0, -20 }, leftHip = { 55, 0, 0 }, rightHip = { -40, 0, 0 }, leftKnee = { -60, 0, 0 }, rightKnee = { -25, 0, 0 } },
		weaponWindup = { -45, 0, 0 },
		weaponStrike = { -45, 0, 0 },
	},
	SideStep = {
		windup = { root = { 0, 0, 22, 0, -0.7, 0 }, waist = { 0, 0, -10 }, shoulder = { 20, 0, 50 }, leftShoulder = { 20, 0, -50 }, leftHip = { 0, 0, -30 }, rightHip = { 0, 0, 20 }, leftKnee = { -30, 0, 0 }, rightKnee = { -40, 0, 0 } },
		strike = { root = { 0, 0, 28 }, waist = { 0, 0, -12 }, shoulder = { 25, 0, 60 }, leftShoulder = { 25, 0, -60 }, leftHip = { 0, 0, -35 }, rightHip = { 0, 0, 25 }, leftKnee = { -40, 0, 0 }, rightKnee = { -50, 0, 0 } },
		weaponWindup = { -30, 0, 0 },
		weaponStrike = { -30, 0, 0 },
	},
	-- Execution (Severing Blow cinematic): two-handed draw back over the right shoulder, then
	-- one flat cut across.
	Execute = {
		windup = { shoulder = { 30, -35, 85 }, elbow = { 70, 0, 0 }, leftShoulder = { 60, -60, -10 }, leftElbow = { 70, 0, 0 }, waist = { 0, -45, 0 }, root = { 4, -20, 0, 0, -0.7, 0.6 }, leftHip = { 25, 0, 0 }, rightHip = { -20, 0, 0 }, leftKnee = { -35, 0, 0 }, rightKnee = { -30, 0, 0 } },
		strike = { shoulder = { 5, 110, 85 }, elbow = { 0, 0, 0 }, leftShoulder = { 20, 0, -55 }, leftElbow = { 20, 0, 0 }, waist = { -8, 45, 0 }, root = { -12, 20, 0, 0, -1, -0.9 }, leftHip = { -50, 0, 0 }, rightHip = { 35, 0, 0 }, leftKnee = { -45, 0, 0 }, rightKnee = { -15, 0, 0 } },
		weaponWindup = { -20, 0, 0 },
		weaponStrike = { -50, 0, 0 },
	},
	-- Spring Flask: left hand lifts the flask to the mouth, head tips back; blade held low.
	Drink = {
		windup = { leftShoulder = { 120, 30, 0 }, leftElbow = { 110, 0, 0 }, waist = { 8, 0, 0 }, shoulder = { 10, 0, 15 }, elbow = { 20, 0, 0 } },
		strike = { leftShoulder = { 140, 35, 0 }, leftElbow = { 120, 0, 0 }, waist = { 18, 0, 0 }, shoulder = { 10, 0, 15 }, elbow = { 20, 0, 0 } },
		weaponWindup = { 20, 0, 0 },
		weaponStrike = { 20, 0, 0 },
	},
	-- Perilous telegraphs (enemies): a crouched low sweep at the ankles and a two-handed grab.
	Sweep = {
		windup = { shoulder = { -10, -50, 80 }, elbow = { 15, 0, 0 }, leftShoulder = { 20, 0, -40 }, waist = { -18, -40, 0 }, root = { 14, -14, 0, 0, -1.4, 0 }, leftHip = { 50, 0, -8 }, rightHip = { -20, 0, 10 }, leftKnee = { -85, 0, 0 }, rightKnee = { -75, 0, 0 } },
		strike = { shoulder = { -15, 110, 80 }, elbow = { 0, 0, 0 }, leftShoulder = { 20, 0, -60 }, waist = { -18, 40, 0 }, root = { 14, 14, 0, 0, -1.5, -0.8 }, leftHip = { 50, 0, -8 }, rightHip = { -20, 0, 10 }, leftKnee = { -85, 0, 0 }, rightKnee = { -75, 0, 0 } },
		weaponWindup = { -50, 0, 0 },
		weaponStrike = { -55, 0, 0 },
	},
	Grasp = {
		windup = { shoulder = { 60, 0, 40 }, leftShoulder = { 60, 0, -40 }, elbow = { 60, 0, 0 }, leftElbow = { 60, 0, 0 }, waist = { 15, 0, 0 }, root = { 8, 0, 0 } },
		strike = { shoulder = { 100, 0, -8 }, leftShoulder = { 100, 0, 8 }, elbow = { 0, 0, 0 }, leftElbow = { 0, 0, 0 }, waist = { -20, 0, 0 }, root = { -15, 0, 0, 0, -0.4, -1.2 }, leftHip = { -40, 0, 0 }, rightHip = { 30, 0, 0 } },
		weaponWindup = { 30, 0, 0 },
		weaponStrike = { 30, 0, 0 },
	},
	-- Severing Blow (finishing a posture-broken enemy): two-handed downward plunge.
	Sever = {
		windup = { shoulder = { 165, 0, -6 }, elbow = { 70, 0, 0 }, leftShoulder = { 160, 0, 10 }, leftElbow = { 75, 0, 0 }, waist = { 20, 0, 0 }, root = { 8, 0, 0 }, leftKnee = { -30, 0, 0 } },
		strike = { shoulder = { 40, 0, -12 }, elbow = { 0, 0, 0 }, leftShoulder = { 40, 0, 14 }, leftElbow = { 5, 0, 0 }, waist = { -35, 0, 0 }, root = { -15, 0, 0, 0, -1.2, -0.8 }, leftHip = { -60, 0, 0 }, rightHip = { 30, 0, 0 }, leftKnee = { -60, 0, 0 }, rightKnee = { -40, 0, 0 } },
		weaponWindup = { 60, 0, 0 },
		weaponStrike = { -85, 0, 0 },
	},
	-- Qi arts (SpellController plays these by name with explicit timing).
	CastPush = {
		windup = { shoulder = { -10, 0, 20 }, elbow = { 90, 0, 0 }, leftShoulder = { 40, 0, -15 }, leftElbow = { 80, 0, 0 }, waist = { 0, -30, 0 }, leftHip = { -10, 0, 0 }, rightHip = { 20, 0, 0 } },
		strike = { shoulder = { 90, 0, -4 }, elbow = { 0, 0, 0 }, leftShoulder = { 90, 0, 4 }, leftElbow = { 0, 0, 0 }, waist = { 0, 15, 0 }, root = { -6, 0, 0 }, leftHip = { -35, 0, 0 }, rightHip = { 30, 0, 0 }, leftKnee = { -30, 0, 0 } },
		weaponWindup = { -45, 0, 0 },
		weaponStrike = { -45, 0, 0 },
	},
	CastSky = {
		windup = { shoulder = { 40, 0, 10 }, elbow = { 40, 0, 0 }, leftShoulder = { 60, 0, 0 }, root = { 8, 0, 0 }, leftKnee = { -30, 0, 0 }, rightKnee = { -30, 0, 0 }, leftHip = { 15, 0, 0 }, rightHip = { 15, 0, 0 } },
		strike = { shoulder = { 178, 0, -10 }, elbow = { 0, 0, 0 }, leftShoulder = { 175, 0, 15 }, waist = { 15, 0, 0 }, root = { -8, 0, 0 } },
		weaponWindup = { -30, 0, 0 },
		weaponStrike = { -45, 0, 0 },
	},
	CastSpin = {
		windup = { shoulder = { 0, -20, 90 }, leftShoulder = { 0, 0, -90 }, leftHip = { -20, 0, -15 }, rightHip = { 20, 0, 15 } },
		strike = { shoulder = { 0, 20, 90 }, leftShoulder = { 0, 0, -90 }, leftHip = { -25, 0, -20 }, rightHip = { 25, 0, 20 } },
		spin = true,
		weaponWindup = { -45, 0, 0 },
		weaponStrike = { -45, 0, 0 },
	},
	CastGuard = {
		windup = { shoulder = { 65, 0, -20 }, elbow = { 65, 0, 0 }, leftShoulder = { 62, 0, 30 }, leftElbow = { 80, 0, 0 }, waist = { -10, 0, 0 }, leftKnee = { -25, 0, 0 }, rightKnee = { -25, 0, 0 } },
		strike = { shoulder = { 90, 0, 20 }, elbow = { 10, 0, 0 }, leftShoulder = { 90, 0, -20 }, leftElbow = { 10, 0, 0 }, waist = { 10, 0, 0 } },
		weaponWindup = { 0, 0, 55 },
		weaponStrike = { -45, 0, 0 },
	},
	Stagger = {
		windup = { root = { 25, 0, 8, 0, 0, 0.8 }, waist = { 20, 25, 0 }, shoulder = { 60, 0, 50 }, elbow = { 20, 0, 0 }, leftShoulder = { 40, 0, -40 }, leftKnee = { -30, 0, 0 } },
		strike = { root = { 15, 0, -5 }, waist = { 10, -10, 0 }, shoulder = { 20, 0, 30 } },
		weaponWindup = { 40, 0, -20 },
		weaponStrike = { 20, 0, 0 },
	},
} :: { [string]: Style }

-- Death (AnimationController.PlayDeath): the blow lands, the knees go, the body folds forward
-- and stays down while it dissolves. Keys are seconds from the killing blow.
AnimationConfig.Death = {
	{ t = 0.12, pose = { root = { 22, 0, 6, 0, -0.2, 0.8 }, waist = { 22, -12, 0 }, shoulder = { 40, 0, 50 }, elbow = { 30, 0, 0 }, leftShoulder = { 30, 0, -45 }, leftHip = { -18, 0, 0 }, rightHip = { 12, 0, 0 }, leftKnee = { -20, 0, 0 }, rightKnee = { -30, 0, 0 } } },
	{ t = 0.55, pose = { root = { 10, 0, 4, 0, -1.4, 0.4 }, waist = { -18, -8, 0 }, shoulder = { 10, 0, 25 }, elbow = { 10, 0, 0 }, leftShoulder = { 15, 0, -25 }, leftElbow = { 10, 0, 0 }, leftHip = { 80, 0, 0 }, rightHip = { 70, 0, 0 }, leftKnee = { -100, 0, 0 }, rightKnee = { -105, 0, 0 } } },
	{ t = 1.1, pose = { root = { -70, 0, 8, 0, -2.4, -1.2 }, waist = { -25, 10, 0 }, shoulder = { 150, 0, 30 }, elbow = { 20, 0, 0 }, leftShoulder = { 160, 0, -30 }, leftElbow = { 25, 0, 0 }, leftHip = { 60, 0, 0 }, rightHip = { 40, 0, 0 }, leftKnee = { -80, 0, 0 }, rightKnee = { -50, 0, 0 } } },
	{ t = 1.35, pose = { root = { -82, 0, 10, 0, -2.6, -1.4 }, waist = { -20, 10, 0 }, shoulder = { 165, 0, 35 }, elbow = { 15, 0, 0 }, leftShoulder = { 168, 0, -35 }, leftElbow = { 20, 0, 0 }, leftHip = { 30, 0, 0 }, rightHip = { 20, 0, 0 }, leftKnee = { -40, 0, 0 }, rightKnee = { -30, 0, 0 } } },
}

-- Combat stances: the rest pose of every armed character (moves start from and return to it,
-- so arms and body always stay connected to the weapon). Legs fade out while walking.
AnimationConfig.Stances = {
	-- Mid guard: sword hand forward at the navel, blade angled up at the opponent's throat;
	-- left hand raised by the chest, weight forward, knees bent.
	OneHanded = {
		shoulder = { 40, 10, -14 }, elbow = { 48, 0, 0 },
		leftShoulder = { 42, -8, 22 }, leftElbow = { 62, 0, 0 },
		waist = { -6, -10, 0 }, root = { -4, 10, 0, 0, -0.45, 0 },
		leftHip = { 24, 0, -4 }, rightHip = { -16, 0, 6 }, leftKnee = { -26, 0, 0 }, rightKnee = { -22, 0, 0 },
	},
	-- Long weapons: rear hand at the hip, front hand far up the shaft, side-on, point forward.
	TwoHanded = {
		shoulder = { 20, 15, 5 }, elbow = { 70, 0, 0 },
		leftShoulder = { 55, -15, 25 }, leftElbow = { 25, 0, 0 },
		waist = { -6, -25, 0 }, root = { -4, 22, 0, 0, -0.5, 0 },
		leftHip = { 28, 0, -6 }, rightHip = { -20, 0, 8 }, leftKnee = { -30, 0, 0 }, rightKnee = { -26, 0, 0 },
	},
	-- Townsfolk (unarmed NPCs): relaxed, hands clasped in front, weight on one leg.
	Relaxed = {
		shoulder = { 18, 0, -12 }, elbow = { 55, 0, 0 },
		leftShoulder = { 18, 0, 12 }, leftElbow = { 55, 0, 0 },
		waist = { -2, 6, 0 }, root = { 0, -4, 2 },
		leftHip = { 6, 0, -3 }, rightHip = { -4, 0, 2 }, rightKnee = { -8, 0, 0 },
	},
	-- Fans: both arms open and loose, like a dancer about to turn.
	Open = {
		shoulder = { 30, 0, 30 }, elbow = { 35, 0, 0 },
		leftShoulder = { 50, 0, -22 }, leftElbow = { 45, 0, 0 },
		waist = { -4, -8, 0 }, leftHip = { 18, 0, -4 }, rightHip = { -12, 0, 4 }, leftKnee = { -18, 0, 0 }, rightKnee = { -16, 0, 0 },
	},
} :: { [string]: Pose }
AnimationConfig.StanceByClass = { Jian = "OneHanded", Dao = "OneHanded", Spear = "TwoHanded", Staff = "TwoHanded", Greatblade = "TwoHanded", Fan = "Open" } :: { [string]: string }

-- Which cast pose each art kind uses.
AnimationConfig.CastStyles = {
	Flurry = "Spin",
	Blink = "DashStrike",
	SlashWave = "SlashRight",
	Fissure = "Overhead",
	Rising = "Finisher",
	Storm = "Spin",
	SkyFall = "AirSlam",
	Chain = "DashStrike",
} :: { [string]: string }

-- Trails glow from slightly before the active window until slightly after it.
AnimationConfig.TrailLead = 0.04
AnimationConfig.TrailLinger = 0.08

-- Parry/guard and dodge timings (they are not WeaponConfig moves).
AnimationConfig.GuardHold = 0.45
AnimationConfig.BlendOut = 0.18 -- seconds to return to neutral after recovery

-- Explicit style per move id; anything not listed is inferred (see AnimationController.StyleFor).
AnimationConfig.MoveStyles = {
	jian_light_3 = "Thrust",
	jian_heavy = "Thrust",
	jian_light_4 = "Overhead",
	dao_light_3 = "Overhead",
	dao_heavy = "Overhead",
	spear_light_3 = "Spin",
	staff_light_3 = "SlashRight",
	staff_light_4 = "Overhead",
	staff_heavy = "Overhead",
	gb_light_3 = "Overhead",
	gb_heavy = "Overhead",
	fan_heavy = "Thrust",
} :: { [string]: string }

-- Procedural walk cycle for code-built NPC rigs (they have no Animate script).
AnimationConfig.Walk = {
	fullSpeed = 14, -- studs/s at which the cycle reaches full swing
	cyclesPerSecond = 1.4,
	legSwingDegrees = 35,
	armSwingDegrees = 25,
	kneeBendDegrees = 40,
	idleBreathDegrees = 1.5,
}

-- Animation level of detail for NPCs (studs from the camera).
AnimationConfig.Lod = { near = 60, far = 160 }

-- Enemy telegraph highlight colors (windup flash before their attacks land).
AnimationConfig.TelegraphColor = { 255, 245, 220 }
AnimationConfig.PerilousColor = { 255, 40, 40 }

return AnimationConfig
