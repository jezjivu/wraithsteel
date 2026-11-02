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
	-- Reactions (EffectsController): getting hit, guarding a hit, deflecting, posture broken.
	HitReact = {
		windup = { root = { 16, 0, 8, 0, -0.3, 0.9 }, waist = { 20, -14, 0 }, shoulder = { 20, 0, 30 }, leftShoulder = { 25, 0, -30 }, leftHip = { -14, 0, 0 }, rightHip = { 10, 0, 0 }, leftKnee = { -10, 0, 0 }, rightKnee = { -30, 0, 0 } },
		strike = { root = { 8, 0, 3 }, waist = { 10, -6, 0 }, shoulder = { 30, 0, 20 }, leftShoulder = { 20, 0, -20 } },
		weaponWindup = { -30, 0, -20 },
		weaponStrike = { -10, 0, 0 },
	},
	HitHeavy = {
		windup = { root = { 28, 0, 12, 0, -0.8, 1.8 }, waist = { 30, -22, 0 }, shoulder = { -10, 0, 60 }, leftShoulder = { 10, 0, -60 }, leftHip = { -30, 0, 0 }, rightHip = { 25, 0, 0 }, leftKnee = { -45, 0, 0 }, rightKnee = { -50, 0, 0 } },
		strike = { root = { 14, 0, 5 }, waist = { 12, -10, 0 }, shoulder = { 20, 0, 30 }, leftShoulder = { 20, 0, -30 }, leftKnee = { -30, 0, 0 }, rightKnee = { -30, 0, 0 } },
		weaponWindup = { -60, 0, -30 },
		weaponStrike = { -20, 0, 0 },
	},
	BlockRecoil = {
		windup = { shoulder = { 95, -55, 0 }, elbow = { 75, 0, 0 }, leftShoulder = { 50, 35, 0 }, root = { 10, 0, 0, 0, -0.5, 0.8 }, waist = { 8, 0, 0 }, leftKnee = { -30, 0, 0 }, rightKnee = { -30, 0, 0 }, rightHip = { -15, 0, 0 } },
		strike = { shoulder = { 80, -50, 0 }, elbow = { 60, 0, 0 }, leftShoulder = { 40, 30, 0 }, leftKnee = { -20, 0, 0 }, rightKnee = { -20, 0, 0 } },
		weaponWindup = { 15, 0, 95 },
		weaponStrike = { 0, 0, 85 },
	},
	-- A perfect deflect snaps the blade across the incoming strike and pushes back.
	DeflectStrike = {
		windup = { shoulder = { 110, -70, 0 }, elbow = { 40, 0, 0 }, waist = { 0, 35, 0 }, root = { -6, 0, 0, 0, -0.4, 0 }, leftHip = { -20, 0, 0 }, rightHip = { 15, 0, 0 }, leftKnee = { -20, 0, 0 }, rightKnee = { -20, 0, 0 } },
		strike = { shoulder = { 115, 40, 0 }, elbow = { 10, 0, 0 }, waist = { 0, -25, 0 }, root = { -10, 0, 0, 0, -0.6, -0.6 }, leftHip = { -35, 0, 0 }, rightHip = { 25, 0, 0 }, leftKnee = { -30, 0, 0 }, rightKnee = { -15, 0, 0 } },
		weaponWindup = { 20, 0, 100 },
		weaponStrike = { -10, 0, -60 },
	},
	-- Posture broken: down on one knee, weapon lowered.
	Kneel = {
		windup = { root = { 22, 0, 0, 0, -1.6, 0 }, waist = { 20, 0, 0 }, leftHip = { 85, 0, 0 }, leftKnee = { -95, 0, 0 }, rightHip = { -10, 0, 0 }, rightKnee = { -95, 0, 0 }, shoulder = { 15, 0, 15 }, leftShoulder = { 30, 0, -10 } },
		strike = { root = { 18, 0, 0, 0, -1.7, 0 }, waist = { 24, 0, 0 }, leftHip = { 80, 0, 0 }, leftKnee = { -95, 0, 0 }, rightHip = { -10, 0, 0 }, rightKnee = { -95, 0, 0 }, shoulder = { 10, 0, 15 }, leftShoulder = { 25, 0, -10 } },
		weaponWindup = { 60, 0, 0 },
		weaponStrike = { 70, 0, 0 },
	},
	-- Directional dashes (MovementController picks one from the dash direction).
	DashForward = {
		windup = { root = { -28, 0, 0, 0, -0.6, 0 }, waist = { -10, 0, 0 }, shoulder = { -45, 0, 15 }, leftShoulder = { -45, 0, -15 }, leftHip = { 45, 0, 0 }, rightHip = { -35, 0, 0 }, leftKnee = { -50, 0, 0 }, rightKnee = { -30, 0, 0 } },
		strike = { root = { -32, 0, 0, 0, -0.9, 0 }, waist = { -12, 0, 0 }, shoulder = { -55, 0, 20 }, leftShoulder = { -55, 0, -20 }, leftHip = { 55, 0, 0 }, rightHip = { -40, 0, 0 }, leftKnee = { -60, 0, 0 }, rightKnee = { -25, 0, 0 } },
		weaponWindup = { -40, 0, 0 },
		weaponStrike = { -50, 0, 0 },
	},
	SideStep = {
		windup = { root = { 0, 0, 22, 0, -0.7, 0 }, waist = { 0, 0, -10 }, shoulder = { 20, 0, 50 }, leftShoulder = { 20, 0, -50 }, leftHip = { 0, 0, -30 }, rightHip = { 0, 0, 20 }, leftKnee = { -30, 0, 0 }, rightKnee = { -40, 0, 0 } },
		strike = { root = { 0, 0, 28 }, waist = { 0, 0, -12 }, shoulder = { 25, 0, 60 }, leftShoulder = { 25, 0, -60 }, leftHip = { 0, 0, -35 }, rightHip = { 0, 0, 25 }, leftKnee = { -40, 0, 0 }, rightKnee = { -50, 0, 0 } },
	},
	-- Spring Flask: left hand lifts the flask to the mouth, head tips back.
	Drink = {
		windup = { leftShoulder = { 120, 30, 0 }, leftElbow = { 110, 0, 0 }, waist = { -8, 0, 0 } },
		strike = { leftShoulder = { 140, 35, 0 }, leftElbow = { 120, 0, 0 }, waist = { -18, 0, 0 } },
	},
	-- Perilous telegraphs (enemies): low sweep and two-handed grab.
	Sweep = {
		windup = { shoulder = { 40, 70, 30 }, elbow = { 20, 0, 0 }, waist = { 10, 50, 0 }, root = { 15, 0, 0 }, leftHip = { 40, 0, 0 }, rightHip = { 30, 0, 0 }, leftKnee = { -70, 0, 0 }, rightKnee = { -80, 0, 0 } },
		strike = { shoulder = { 30, -90, 30 }, elbow = { 0, 0, 0 }, waist = { 10, -50, 0 }, root = { 15, 0, 0 }, leftHip = { 40, 0, 0 }, rightHip = { 30, 0, 0 }, leftKnee = { -70, 0, 0 }, rightKnee = { -80, 0, 0 } },
		weaponWindup = { -10, 0, -100 },
		weaponStrike = { -10, 0, 100 },
	},
	Grasp = {
		windup = { shoulder = { 60, 0, 40 }, leftShoulder = { 60, 0, -40 }, elbow = { 60, 0, 0 }, leftElbow = { 60, 0, 0 }, waist = { -15, 0, 0 }, root = { 8, 0, 0 } },
		strike = { shoulder = { 100, 0, 0 }, leftShoulder = { 100, 0, 0 }, elbow = { 0, 0, 0 }, leftElbow = { 0, 0, 0 }, waist = { 20, 0, 0 }, root = { -15, 0, 0 }, leftHip = { -40, 0, 0 }, rightHip = { 30, 0, 0 } },
	},
	-- Severing Blow (finishing a posture-broken enemy): two-handed downward plunge.
	Sever = {
		windup = { shoulder = { 170, 0, 0 }, leftShoulder = { 160, 0, 0 }, waist = { -20, 0, 0 }, root = { 8, 0, 0 }, leftKnee = { -30, 0, 0 } },
		strike = { shoulder = { 40, 0, 0 }, leftShoulder = { 40, 0, 0 }, waist = { 35, 0, 0 }, root = { -15, 0, 0 }, leftHip = { -60, 0, 0 }, rightHip = { 30, 0, 0 }, leftKnee = { -60, 0, 0 }, rightKnee = { -40, 0, 0 } },
		weaponWindup = { -170, 0, 0 },
		weaponStrike = { 60, 0, 0 },
	},
	-- Qi arts (SpellController plays these by name with explicit timing).
	CastPush = {
		windup = { shoulder = { 40, 30, 0 }, leftShoulder = { 40, -30, 0 }, elbow = { 70, 0, 0 }, waist = { 0, 30, 0 }, leftHip = { -10, 0, 0 }, rightHip = { 20, 0, 0 } },
		strike = { shoulder = { 95, 0, 0 }, leftShoulder = { 95, 0, 0 }, elbow = { 0, 0, 0 }, waist = { 0, -15, 0 }, root = { -6, 0, 0 }, leftHip = { -35, 0, 0 }, rightHip = { 30, 0, 0 }, leftKnee = { -30, 0, 0 } },
		weaponWindup = { -40, 0, 0 },
		weaponStrike = { -20, 0, 0 },
	},
	CastSky = {
		windup = { shoulder = { 60, 0, 0 }, leftShoulder = { 60, 0, 0 }, root = { 8, 0, 0 }, leftKnee = { -30, 0, 0 }, rightKnee = { -30, 0, 0 }, leftHip = { 15, 0, 0 }, rightHip = { 15, 0, 0 } },
		strike = { shoulder = { 175, 0, -15 }, leftShoulder = { 175, 0, 15 }, waist = { -15, 0, 0 }, root = { -8, 0, 0 } },
		weaponWindup = { -60, 0, 0 },
		weaponStrike = { -150, 0, 0 },
	},
	CastSpin = {
		windup = { shoulder = { 90, 0, 60 }, leftShoulder = { 90, 0, -60 }, leftHip = { -20, 0, -15 }, rightHip = { 20, 0, 15 } },
		strike = { shoulder = { 90, 0, 80 }, leftShoulder = { 90, 0, -80 }, leftHip = { -25, 0, -20 }, rightHip = { 25, 0, 20 } },
		spin = true,
		weaponWindup = { -20, 0, -80 },
		weaponStrike = { 0, 0, 80 },
	},
	CastGuard = {
		windup = { shoulder = { 80, -60, 0 }, leftShoulder = { 80, 60, 0 }, elbow = { 80, 0, 0 }, waist = { 10, 0, 0 }, leftKnee = { -25, 0, 0 }, rightKnee = { -25, 0, 0 } },
		strike = { shoulder = { 60, 40, 0 }, leftShoulder = { 60, -40, 0 }, elbow = { 20, 0, 0 }, waist = { -10, 0, 0 } },
		weaponWindup = { 0, 0, 85 },
		weaponStrike = { 0, 0, 40 },
	},
} :: { [string]: Style }

-- Combat stances: the rest pose of every armed character (moves start from and return to it,
-- so arms and body always stay connected to the weapon). Legs fade out while walking.
AnimationConfig.Stances = {
	-- Blade low and forward in the right hand, left hand guarding, knees bent, weight forward.
	OneHanded = {
		shoulder = { 38, -12, 8 }, elbow = { 42, 0, 0 },
		leftShoulder = { 22, 18, -10 }, leftElbow = { 55, 0, 0 },
		waist = { 6, -14, 0 }, root = { -4, 12, 0, 0, -0.45, 0 },
		leftHip = { 24, 0, -4 }, rightHip = { -16, 0, 6 }, leftKnee = { -26, 0, 0 }, rightKnee = { -22, 0, 0 },
	},
	-- Two hands on the shaft/hilt, weapon across the body.
	TwoHanded = {
		shoulder = { 42, -25, 6 }, elbow = { 38, 0, 0 },
		leftShoulder = { 55, 32, -6 }, leftElbow = { 48, 0, 0 },
		waist = { 6, -22, 0 }, root = { -4, 20, 0, 0, -0.5, 0 },
		leftHip = { 26, 0, -6 }, rightHip = { -18, 0, 8 }, leftKnee = { -28, 0, 0 }, rightKnee = { -24, 0, 0 },
	},
	-- Townsfolk (unarmed NPCs): relaxed, hands clasped in front, weight on one leg.
	Relaxed = {
		shoulder = { 18, 0, -12 }, elbow = { 55, 0, 0 },
		leftShoulder = { 18, 0, 12 }, leftElbow = { 55, 0, 0 },
		waist = { 2, 6, 0 }, root = { 0, -4, 2 },
		leftHip = { 6, 0, -3 }, rightHip = { -4, 0, 2 }, rightKnee = { -8, 0, 0 },
	},
	-- Fans: both arms open and loose.
	Open = {
		shoulder = { 30, 0, 22 }, elbow = { 35, 0, 0 },
		leftShoulder = { 30, 0, -22 }, leftElbow = { 35, 0, 0 },
		waist = { 4, -8, 0 }, leftHip = { 18, 0, -4 }, rightHip = { -12, 0, 4 }, leftKnee = { -18, 0, 0 }, rightKnee = { -16, 0, 0 },
	},
} :: { [string]: Pose }
AnimationConfig.StanceByClass = { Jian = "OneHanded", Dao = "OneHanded", Spear = "TwoHanded", Staff = "TwoHanded", Greatblade = "TwoHanded", Fan = "Open" } :: { [string]: string }

-- Which cast pose each art kind uses.
AnimationConfig.CastStyles = {
	Projectile = "CastPush",
	Blink = "DashStrike",
	Barrier = "CastGuard",
	Seal = "CastSky",
	Storm = "CastSpin",
	Lance = "CastPush",
	Bell = "CastSky",
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
