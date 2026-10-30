--!strict
-- AnimationConfig: procedural (code-driven) combat poses used until real animations are
-- uploaded. AnimationController blends R15 joints between these poses using each move's
-- windup / active / recovery timing from WeaponConfig, so every weapon class moves differently.
-- Angles are degrees {x, y, z} applied to Motor6D.Transform.
-- TODO(Studio/Agent B): tune by eye in Studio; replace with real animations when uploaded
-- (a move with a non-placeholder animationId plays that instead).

export type Pose = {
	shoulder: { number }?, -- RightShoulder
	elbow: { number }?, -- RightElbow
	leftShoulder: { number }?, -- LeftShoulder
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

AnimationConfig.Styles = {
	SlashRight = {
		windup = { shoulder = { 100, 70, 0 }, elbow = { 20, 0, 0 }, waist = { 0, 35, 0 }, leftHip = { -15, 0, 0 }, rightHip = { 20, 0, 0 }, leftKnee = { -25, 0, 0 }, rightKnee = { -15, 0, 0 } },
		strike = { shoulder = { 85, -70, 0 }, elbow = { 5, 0, 0 }, waist = { 0, -30, 0 }, leftHip = { -40, 0, 0 }, rightHip = { 30, 0, 0 }, leftKnee = { -35, 0, 0 }, rightKnee = { -10, 0, 0 } },
		weaponWindup = { -35, 0, -75 },
		weaponStrike = { 15, 0, 80 },
	},
	SlashLeft = {
		windup = { shoulder = { 85, -60, 0 }, elbow = { 10, 0, 0 }, waist = { 0, -30, 0 }, leftHip = { 20, 0, 0 }, rightHip = { -15, 0, 0 }, leftKnee = { -15, 0, 0 }, rightKnee = { -25, 0, 0 } },
		strike = { shoulder = { 100, 65, 0 }, elbow = { 15, 0, 0 }, waist = { 0, 35, 0 }, leftHip = { 30, 0, 0 }, rightHip = { -40, 0, 0 }, leftKnee = { -10, 0, 0 }, rightKnee = { -35, 0, 0 } },
		weaponWindup = { -35, 0, 75 },
		weaponStrike = { 15, 0, -80 },
	},
	Overhead = {
		windup = { shoulder = { 170, 0, 0 }, elbow = { 30, 0, 0 }, waist = { -10, 0, 0 }, root = { 8, 0, 0 }, leftHip = { -10, 0, 0 }, rightHip = { 15, 0, 0 }, leftKnee = { -10, 0, 0 } },
		strike = { shoulder = { 60, 0, 0 }, elbow = { 0, 0, 0 }, waist = { 15, 0, 0 }, root = { -8, 0, 0 }, leftHip = { -45, 0, 0 }, rightHip = { 35, 0, 0 }, leftKnee = { -50, 0, 0 }, rightKnee = { -20, 0, 0 } },
		weaponWindup = { -120, 0, 0 },
		weaponStrike = { 35, 0, 0 },
	},
	Thrust = {
		windup = { shoulder = { 70, 0, 0 }, elbow = { 80, 0, 0 }, waist = { 0, 25, 0 }, leftHip = { -10, 0, 0 }, rightHip = { 25, 0, 0 }, rightKnee = { -30, 0, 0 } },
		strike = { shoulder = { 90, 0, 0 }, elbow = { 0, 0, 0 }, waist = { 0, -15, 0 }, root = { -6, 0, 0 }, leftHip = { -55, 0, 0 }, rightHip = { 40, 0, 0 }, leftKnee = { -40, 0, 0 } },
		weaponWindup = { 0, 0, 0, -1.2 },
		weaponStrike = { 0, 0, 0, 1.4 },
	},
	Spin = {
		windup = { shoulder = { 90, 60, 0 }, leftShoulder = { 0, 0, -40 }, waist = { 0, 40, 0 }, leftHip = { -20, 0, -15 }, rightHip = { 20, 0, 15 } },
		strike = { shoulder = { 90, -40, 0 }, leftShoulder = { 0, 0, -40 }, waist = { 0, -20, 0 }, leftHip = { -25, 0, -20 }, rightHip = { 25, 0, 20 } },
		spin = true,
		weaponWindup = { -20, 0, -80 },
		weaponStrike = { 0, 0, 80 },
	},
	Guard = {
		windup = { shoulder = { 80, -50, 0 }, elbow = { 60, 0, 0 }, leftShoulder = { 40, 30, 0 } },
		strike = { shoulder = { 80, -50, 0 }, elbow = { 60, 0, 0 }, leftShoulder = { 40, 30, 0 } },
		weaponWindup = { 0, 0, 85 },
		weaponStrike = { 0, 0, 85 },
	},
	Dodge = {
		windup = { root = { -20, 0, 0 }, shoulder = { -30, 0, 0 }, leftShoulder = { -30, 0, 0 }, leftHip = { -40, 0, 0 }, rightHip = { 30, 0, 0 }, leftKnee = { -40, 0, 0 }, rightKnee = { -20, 0, 0 } },
		strike = { root = { -30, 0, 0 }, shoulder = { -50, 0, 0 }, leftShoulder = { -50, 0, 0 }, leftHip = { -55, 0, 0 }, rightHip = { 40, 0, 0 }, leftKnee = { -60, 0, 0 } },
	},
	Flinch = {
		windup = { root = { 12, 0, 0 }, waist = { 10, 15, 0 }, shoulder = { 30, 0, 0 } },
		strike = { root = { 6, 0, 0 } },
		weaponWindup = { -20, 0, -30 },
		weaponStrike = { 0, 0, 0 },
	},
	Flip = {
		windup = { leftHip = { 60, 0, 0 }, rightHip = { 60, 0, 0 }, leftKnee = { -90, 0, 0 }, rightKnee = { -90, 0, 0 }, shoulder = { 40, 0, 0 }, leftShoulder = { 40, 0, 0 } },
		strike = { leftHip = { 70, 0, 0 }, rightHip = { 70, 0, 0 }, leftKnee = { -100, 0, 0 }, rightKnee = { -100, 0, 0 } },
		spin = true,
		spinAxis = "X",
	},
	AirSlam = {
		windup = { shoulder = { 175, 0, 0 }, leftShoulder = { 120, 0, 0 }, root = { 15, 0, 0 }, leftKnee = { -70, 0, 0 }, rightKnee = { -70, 0, 0 }, leftHip = { 40, 0, 0 }, rightHip = { 40, 0, 0 } },
		strike = { shoulder = { 40, 0, 0 }, root = { -25, 0, 0 }, waist = { 25, 0, 0 }, leftKnee = { -60, 0, 0 }, rightHip = { 30, 0, 0 } },
		weaponWindup = { -160, 0, 0 },
		weaponStrike = { 50, 0, 0 },
	},
	DashStrike = {
		windup = { shoulder = { 60, 50, 0 }, waist = { 0, 50, 0 }, root = { -20, 0, 0 }, leftHip = { -30, 0, 0 }, rightHip = { 35, 0, 0 } },
		strike = { shoulder = { 90, -80, 0 }, waist = { 0, -40, 0 }, root = { -25, 0, 0 }, leftHip = { -60, 0, 0 }, rightHip = { 45, 0, 0 }, leftKnee = { -30, 0, 0 } },
		weaponWindup = { -10, 0, -90 },
		weaponStrike = { 10, 0, 100 },
	},
	Finisher = {
		windup = { shoulder = { 30, 0, 0 }, root = { 20, 0, 0 }, leftKnee = { -70, 0, 0 }, rightKnee = { -70, 0, 0 }, leftHip = { 40, 0, 0 }, rightHip = { 40, 0, 0 } },
		strike = { shoulder = { 180, 0, 0 }, leftShoulder = { 90, 0, 0 }, root = { -15, 0, 0 }, waist = { -15, 0, 0 } },
		spin = true,
		weaponWindup = { 40, 0, 0 },
		weaponStrike = { -150, 0, 0 },
	},
	Stagger = {
		windup = { root = { 25, 0, 8 }, waist = { 20, 25, 0 }, shoulder = { 60, 30, 0 }, leftShoulder = { 60, 0, 0 }, leftKnee = { -30, 0, 0 } },
		strike = { root = { 15, 0, -5 }, waist = { 10, -10, 0 } },
		weaponWindup = { -60, 0, 40 },
		weaponStrike = { -30, 0, 0 },
	},
	Ultimate = {
		windup = { shoulder = { 175, 0, 0 }, leftShoulder = { 175, 0, 0 }, waist = { -15, 0, 0 }, root = { 10, 0, 0 }, leftKnee = { -60, 0, 0 }, rightKnee = { -60, 0, 0 }, leftHip = { 30, 0, 0 }, rightHip = { 30, 0, 0 } },
		strike = { shoulder = { 70, 0, 0 }, leftShoulder = { 40, 0, 0 }, waist = { 20, 0, 0 }, root = { -10, 0, 0 }, leftHip = { -50, 0, 0 }, rightHip = { 40, 0, 0 }, leftKnee = { -45, 0, 0 } },
		spin = true,
		weaponWindup = { -150, 0, 0 },
		weaponStrike = { 40, 0, 0 },
	},
} :: { [string]: Style }

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
