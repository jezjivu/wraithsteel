--!strict
-- EffectsConfig: combat feedback (damage numbers, flashes, bars, shake, sounds). Owner: Agent B/D.
-- Sounds use Roblox's built-in content sounds (rbxasset://) until custom SFX are uploaded.
-- TODO(Studio/Agent D): replace with original uploaded SFX and log them in AssetLog.md.

local EffectsConfig = {}

EffectsConfig.DamageNumber = {
	lifetime = 0.9,
	rise = 3.5, -- studs
	size = 28,
	bigHitSize = 38, -- used when damage >= bigHitThreshold
	bigHitThreshold = 40,
}

-- Text + RGB color per outcome (damage numbers / outcome words).
EffectsConfig.Outcome = {
	Hit = { color = { 255, 245, 230 } },
	TakenHit = { color = { 255, 90, 80 } }, -- damage dealt to the local player
	Blocked = { text = "BLOCK", color = { 170, 180, 200 } },
	Parried = { text = "PARRY!", color = { 255, 215, 90 } },
	Dodged = { text = "DODGE", color = { 120, 200, 255 } },
	Broken = { text = "POSTURE BROKEN", color = { 255, 120, 40 } },
}

EffectsConfig.HitFlash = { color = { 255, 255, 255 }, seconds = 0.12 }
EffectsConfig.Sparks = { color = { 255, 200, 120 } } -- hit sparks
EffectsConfig.Glint = { color = { 255, 250, 220 } } -- enemy blade "parry now" flash
EffectsConfig.Guard = { color = { 120, 180, 255 } } -- blocks / enemy guard
EffectsConfig.Ultimate = { color = { 255, 210, 110 } }
EffectsConfig.LevelUp = { color = { 255, 225, 140 } }
EffectsConfig.Death = { color = { 255, 140, 60 }, seconds = 1.2 }
EffectsConfig.Riposte = { color = { 255, 120, 60 } }
EffectsConfig.Routes = { Finisher = { 255, 190, 90 }, Air = { 150, 210, 255 }, Dash = { 160, 255, 210 } }
-- Freeze-frame lengths (seconds) for impact feel.
EffectsConfig.HitStop = { hit = 0.05, riposte = 0.12, parry = 0.2 }
EffectsConfig.Combo = { window = 2.5, color = { 255, 215, 120 }, hotColor = { 255, 90, 60 }, hotAt = 15 }

EffectsConfig.Bars = {
	width = 120,
	height = 10,
	offsetY = 3.2, -- studs above the head / root
	health = { 200, 60, 50 },
	posture = { 240, 190, 70 },
	maxDistance = 90,
}

EffectsConfig.Shake = {
	takenHit = 0.25, -- studs of camera jitter
	parry = 0.15,
	broken = 0.4,
	seconds = 0.18,
	bigHitFov = 4, -- degrees of field-of-view punch on big hits
}

EffectsConfig.Sounds = {
	swing = "rbxasset://sounds/swordslash.wav",
	heavy = "rbxasset://sounds/swordlunge.wav",
	hit = "rbxasset://sounds/swordslash.wav",
	parry = "rbxasset://sounds/swordlunge.wav",
	volume = 0.5,
}

return EffectsConfig
