--!strict
-- LightingConfig: dusk wuxia mood (warm sun, soft fog, bloom so neon lanterns glow).
-- AmbienceService applies it at startup unless Lighting has attribute KeepStudioLighting = true
-- (set that once Agent D tunes lighting by hand in Studio).

local LightingConfig = {}

LightingConfig.Lighting = {
	ClockTime = 17.4,
	Brightness = 2.2,
	Ambient = { 70, 60, 70 },
	OutdoorAmbient = { 120, 105, 110 },
	EnvironmentDiffuseScale = 0.6,
	EnvironmentSpecularScale = 0.5,
	GlobalShadows = true,
}

LightingConfig.Atmosphere = {
	Density = 0.32,
	Offset = 0.15,
	Color = { 230, 190, 160 },
	Decay = { 120, 90, 110 },
	Glare = 0.2,
	Haze = 1.4,
}

LightingConfig.Bloom = { Intensity = 0.7, Size = 28, Threshold = 1.6 }
LightingConfig.ColorCorrection = { Saturation = 0.08, Contrast = 0.06, TintColor = { 255, 245, 235 } }
LightingConfig.Clouds = { Cover = 0.55, Density = 0.6, Color = { 255, 225, 215 } }
LightingConfig.SunRays = { Intensity = 0.06, Spread = 0.7 }

-- Ashen Valley day/night cycle (client, synced by server time so everyone shares the sky).
-- Keys: hour -> brightness / ambient / outdoor ambient; values blend between keys.
LightingConfig.DayNight = {
	enabled = true,
	cycleMinutes = 24, -- one full day
	startHour = 17, -- offset so the hour is the same on every server at a given time
	nightFrom = 20, -- hours counted as night (night-only spawns walk)
	nightTo = 5.5,
	keys = {
		{ hour = 0, brightness = 0.9, ambient = { 45, 48, 80 }, outdoor = { 70, 78, 120 } },
		{ hour = 5.5, brightness = 1.2, ambient = { 70, 60, 80 }, outdoor = { 110, 95, 120 } },
		{ hour = 8, brightness = 2.4, ambient = { 80, 75, 75 }, outdoor = { 135, 128, 122 } },
		{ hour = 13, brightness = 2.8, ambient = { 85, 82, 80 }, outdoor = { 145, 140, 135 } },
		{ hour = 17.4, brightness = 2.2, ambient = { 70, 60, 70 }, outdoor = { 120, 105, 110 } },
		{ hour = 20, brightness = 1.1, ambient = { 55, 48, 75 }, outdoor = { 85, 80, 115 } },
		{ hour = 24, brightness = 0.9, ambient = { 45, 48, 80 }, outdoor = { 70, 78, 120 } },
	},
}

-- Per-realm moods (client RealmAmbienceController tweens to these; japan = the values above).
-- weather: "Rain" | "Motes" | nil
LightingConfig.Realms = {
	neon = {
		ClockTime = 0.2,
		Brightness = 1.2,
		Ambient = { 70, 50, 110 },
		OutdoorAmbient = { 60, 70, 120 },
		Atmosphere = { Density = 0.42, Offset = 0.05, Color = { 110, 70, 160 }, Decay = { 40, 30, 80 }, Glare = 0, Haze = 2.2 },
		Bloom = { Intensity = 1.1, Size = 32, Threshold = 1.2 },
		ColorCorrection = { Saturation = 0.25, Contrast = 0.12, TintColor = { 220, 225, 255 } },
		weather = "Rain",
	},
	greek = {
		ClockTime = 13.2,
		Brightness = 3.2,
		Ambient = { 110, 100, 90 },
		OutdoorAmbient = { 170, 160, 150 },
		Atmosphere = { Density = 0.22, Offset = 0.2, Color = { 200, 220, 245 }, Decay = { 150, 180, 220 }, Glare = 0.5, Haze = 0.8 },
		Bloom = { Intensity = 0.5, Size = 24, Threshold = 2 },
		ColorCorrection = { Saturation = 0.12, Contrast = 0.05, TintColor = { 255, 250, 238 } },
		weather = "Motes",
	},
}

return LightingConfig
