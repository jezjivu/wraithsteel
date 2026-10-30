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
}

export type Style = {
	windup: Pose, -- reached at the end of windup
	strike: Pose, -- reached at the end of the active window
	spin: boolean?, -- rotate the whole body 360 degrees during active frames
}

local AnimationConfig = {}

AnimationConfig.Styles = {
	SlashRight = {
		windup = { shoulder = { 100, 70, 0 }, elbow = { 20, 0, 0 }, waist = { 0, 35, 0 } },
		strike = { shoulder = { 85, -70, 0 }, elbow = { 5, 0, 0 }, waist = { 0, -30, 0 } },
	},
	SlashLeft = {
		windup = { shoulder = { 85, -60, 0 }, elbow = { 10, 0, 0 }, waist = { 0, -30, 0 } },
		strike = { shoulder = { 100, 65, 0 }, elbow = { 15, 0, 0 }, waist = { 0, 35, 0 } },
	},
	Overhead = {
		windup = { shoulder = { 170, 0, 0 }, elbow = { 30, 0, 0 }, waist = { -10, 0, 0 }, root = { 8, 0, 0 } },
		strike = { shoulder = { 60, 0, 0 }, elbow = { 0, 0, 0 }, waist = { 15, 0, 0 }, root = { -8, 0, 0 } },
	},
	Thrust = {
		windup = { shoulder = { 70, 0, 0 }, elbow = { 80, 0, 0 }, waist = { 0, 25, 0 } },
		strike = { shoulder = { 90, 0, 0 }, elbow = { 0, 0, 0 }, waist = { 0, -15, 0 }, root = { -6, 0, 0 } },
	},
	Spin = {
		windup = { shoulder = { 90, 60, 0 }, leftShoulder = { 0, 0, -40 }, waist = { 0, 40, 0 } },
		strike = { shoulder = { 90, -40, 0 }, leftShoulder = { 0, 0, -40 }, waist = { 0, -20, 0 } },
		spin = true,
	},
	Guard = {
		windup = { shoulder = { 80, -50, 0 }, elbow = { 60, 0, 0 }, leftShoulder = { 40, 30, 0 } },
		strike = { shoulder = { 80, -50, 0 }, elbow = { 60, 0, 0 }, leftShoulder = { 40, 30, 0 } },
	},
	Dodge = {
		windup = { root = { -15, 0, 0 }, shoulder = { 20, 0, 0 }, leftShoulder = { 20, 0, 0 } },
		strike = { root = { -25, 0, 0 }, shoulder = { 30, 0, 0 }, leftShoulder = { 30, 0, 0 } },
	},
	Ultimate = {
		windup = { shoulder = { 175, 0, 0 }, leftShoulder = { 175, 0, 0 }, waist = { -15, 0, 0 }, root = { 10, 0, 0 } },
		strike = { shoulder = { 70, 0, 0 }, leftShoulder = { 40, 0, 0 }, waist = { 20, 0, 0 }, root = { -10, 0, 0 } },
		spin = true,
	},
} :: { [string]: Style }

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

-- Enemy telegraph highlight colors (windup flash before their attacks land).
AnimationConfig.TelegraphColor = { 255, 245, 220 }
AnimationConfig.PerilousColor = { 255, 40, 40 }

return AnimationConfig
