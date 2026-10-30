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
LightingConfig.SunRays = { Intensity = 0.06, Spread = 0.7 }

return LightingConfig
