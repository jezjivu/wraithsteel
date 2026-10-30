--!strict
-- MovementConfig: dynamic movement (client-side, the player's own physics). Owner: Agent B.

local MovementConfig = {}

MovementConfig.BaseFov = 70
MovementConfig.WalkSpeed = 16
MovementConfig.SprintSpeed = 25 -- hold Shift / L3
MovementConfig.SprintFovBoost = 7

MovementConfig.DoubleJumpPower = 48 -- upward studs/s for the air jump
MovementConfig.AirJumps = 1

-- Dash: eased burst (fast start, smooth stop) with afterimages.
MovementConfig.Dash = {
	distance = 18, -- studs at style multiplier 1
	seconds = 0.32,
	hop = 6, -- small upward kick when dashing from the ground
	afterimageEvery = 0.035, -- seconds between ghost snapshots
	afterimageFade = 0.32,
	fovKick = 9,
	blur = 8,
}

-- Lean into movement (all player characters; purely visual).
MovementConfig.Lean = { forwardDegrees = 9, sideDegrees = 10, smoothing = 8, fullSpeed = 25 }

-- Air slam (air attack): plunge speed and landing shockwave.
MovementConfig.Plunge = { speed = 70, shockRadius = 14 }

return MovementConfig
