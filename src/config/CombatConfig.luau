--!strict
-- CombatConfig: global combat rules (posture, parry, dodge, validation tolerances). Owner: Agent B.

local CombatConfig = {}

-- Player defaults ---------------------------------------------------------------------------
CombatConfig.PlayerMaxHealth = 100
CombatConfig.PlayerHealthPerLevel = 6
CombatConfig.OutOfCombatRegenDelay = 5 -- seconds without taking damage before fast regen
CombatConfig.OutOfCombatRegenPerSecond = 0.08 -- fraction of max health per second
CombatConfig.PlayerMaxPosture = 100
CombatConfig.PostureRegenPerSecond = 18 -- while not blocking/attacking
CombatConfig.PostureRegenDelay = 1.2 -- seconds after last posture damage before regen
CombatConfig.PostureBrokenStun = 1.6 -- seconds stunned when posture breaks
CombatConfig.PostureBrokenDamageMultiplier = 1.5 -- damage taken while broken

-- Parry / block -----------------------------------------------------------------------------
CombatConfig.ParryWindow = 0.2 -- seconds after pressing Parry that a hit is deflected (perfect)
CombatConfig.BlockAfterParry = true -- holding past the window becomes a block
CombatConfig.BlockDamageMultiplier = 0.2 -- health damage taken while blocking
CombatConfig.BlockPostureMultiplier = 1.0 -- posture damage taken while blocking
CombatConfig.ParryPostureReflect = 0.6 -- fraction of the attack's posture damage dealt back to attacker
CombatConfig.ParryCooldown = 0.35 -- after a whiffed parry
CombatConfig.ParrySpamPenalty = 0.15 -- extra cooldown per consecutive whiff (anti-mash)

-- Dodge -------------------------------------------------------------------------------------
CombatConfig.DodgeDuration = 0.35
CombatConfig.DodgeIFrames = 0.25
CombatConfig.DodgeCooldown = 0.8
CombatConfig.DodgeDistance = 14

-- Server validation (guide §8.2: server is authoritative, client only requests) --------------
CombatConfig.Validation = {
	RangeTolerance = 3, -- studs added to a move's range for latency
	FacingConeDegrees = 100, -- target must be within this cone of the attacker's facing
	MaxActionsPerSecond = 8,
	MinSeqStep = 1, -- seq must strictly increase
	MaxPingCompensation = 0.25, -- seconds
	ComboResetSeconds = 1.1, -- light combo resets if next press is later than this
}

-- Client aim assist (presentation only; the server still checks range/arc from its own positions).
CombatConfig.AimAssist = {
	range = 16, -- studs: enemies this close can be soft-locked
	coneDegrees = 80, -- ...if within this cone of the camera direction
	faceOnAttack = true, -- turn the character toward the aim direction when attacking
}

-- Perilous attacks (red flash): cannot be parried or blocked; must be dodged.
CombatConfig.PerilousTelegraphSeconds = 0.6

-- Damage formula ----------------------------------------------------------------------------
-- damage = move.damage * (1 + attackerPower / PowerToDamageScale) * random(0.95, 1.05)
CombatConfig.PowerToDamageScale = 100
CombatConfig.DamageVariance = 0.05

return CombatConfig
