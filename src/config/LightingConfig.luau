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
