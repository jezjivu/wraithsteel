--!strict
-- CombatConfig: global combat rules (posture, parry, dodge, validation tolerances). Owner: Agent B.

local CombatConfig = {}

-- Player defaults ---------------------------------------------------------------------------
CombatConfig.PlayerMaxHealth = 100
CombatConfig.PlayerHealthPerLevel = 6
-- Critical hits (spirit CritChance / CritDamage stats add to these).
CombatConfig.Crit = { baseChance = 0.05, baseDamage = 0.5 }
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

-- Combo routes & counters -------------------------------------------------------------------
CombatConfig.DashAttackWindow = 0.45 -- light attack this soon after a dash = dash strike
CombatConfig.RiposteWindow = 0.8 -- after a perfect parry, the next hit is a riposte
CombatConfig.RiposteMultiplier = 1.5 -- damage + posture multiplier on a riposte (plus style bonus)
CombatConfig.ParriedStaggerSeconds = 0.7 -- enemies whose attack is parried stagger this long
CombatConfig.DefaultKnockback = { light = 6, heavy = 22, skill = 18, ultimate = 40 } -- studs/s
CombatConfig.KnockbackSeconds = 0.18 -- how long a knockback push lasts

-- Lock-on camera (CameraController): Tab / middle mouse / R3.
CombatConfig.LockOn = {
	range = 45, -- studs to acquire a target
	breakRange = 70, -- lock releases beyond this
	distance = 11, -- camera distance behind the player
	height = 4.5,
	shoulder = 2.5, -- sideways offset (over the right shoulder)
	smoothing = 10,
}

-- Perilous attacks (red flash): cannot be parried or blocked. Each kind has its own answer:
--   Pierce (thrust/charge): dash INTO it -> Needle Counter (no damage, crushes its posture)
--   Sweep (low/ground wave): be in the air -> Crane Leap (no damage, your next strike is empowered)
--   Grasp (grab/curse): dash away (i-frames)
CombatConfig.PerilousTelegraphSeconds = 0.6
CombatConfig.Counter = {
	window = 0.45, -- a dash this recent counts for a Needle Counter
	towardDot = 0.35, -- dash direction must point this much toward the attacker
	reflectPosture = 2.5, -- x the attack's posture damage, dealt to the attacker
	stagger = 1.2, -- seconds the countered attacker reels
}

-- Guard: hold F. A press is a timed deflect (ParryWindow); holding keeps a block up.
CombatConfig.GuardMaxHold = 12 -- seconds a single hold can last

-- Posture recovers faster with high health and while guarding (low health = slow recovery).
CombatConfig.PostureHealthFloor = 0.25 -- regen multiplier at 0 health (1 at full)
CombatConfig.GuardPostureRegen = 1.6 -- regen multiplier while holding guard

-- Severing Blow: strike an enemy whose posture is broken. Regular enemies die; bosses lose a
-- large chunk of health (their phases do the rest).
CombatConfig.Severing = { bossFraction = 0.3, hitStop = 0.35 }

-- Enemy deflects: guarding enemies may deflect your strike outright (no damage).
CombatConfig.Deflect = {
	targetPosture = 0.35, -- x the strike's posture damage, still added to the deflecting enemy
	attackerPosture = 0.3, -- x the strike's posture damage, added to YOU
	counterDelay = 0.15, -- the enemy counterattacks this soon after a deflect
}

-- Damage formula ----------------------------------------------------------------------------
-- damage = move.damage * (1 + attackerPower / PowerToDamageScale) * random(0.95, 1.05)
CombatConfig.PowerToDamageScale = 100
CombatConfig.DamageVariance = 0.05

return CombatConfig
