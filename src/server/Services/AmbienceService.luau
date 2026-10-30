--!strict
-- AmbienceService: applies LightingConfig (dusk sky, atmosphere, bloom, color grading) so the
-- placeholder world reads as WRAITHSTEEL instead of a default baseplate.
-- Skipped when Lighting has attribute KeepStudioLighting = true.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LightingConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("LightingConfig"))

local AmbienceService = { Name = "AmbienceService", Priority = 5 }

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function effect(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing then
		return existing
	end
	local e = Instance.new(className)
	e.Name = name
	e.Parent = Lighting
	return e
end

function AmbienceService.Init() end

function AmbienceService.Start()
	if Lighting:GetAttribute("KeepStudioLighting") == true then
		return
	end
	local L = LightingConfig.Lighting
	Lighting.ClockTime = L.ClockTime
	Lighting.Brightness = L.Brightness
	Lighting.Ambient = rgb(L.Ambient)
	Lighting.OutdoorAmbient = rgb(L.OutdoorAmbient)
	Lighting.EnvironmentDiffuseScale = L.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = L.EnvironmentSpecularScale
	Lighting.GlobalShadows = L.GlobalShadows

	local A = LightingConfig.Atmosphere
	local atmosphere = effect("Atmosphere", "WraithsteelAtmosphere") :: Atmosphere
	atmosphere.Density = A.Density
	atmosphere.Offset = A.Offset
	atmosphere.Color = rgb(A.Color)
	atmosphere.Decay = rgb(A.Decay)
	atmosphere.Glare = A.Glare
	atmosphere.Haze = A.Haze

	local bloom = effect("BloomEffect", "WraithsteelBloom") :: BloomEffect
	bloom.Intensity = LightingConfig.Bloom.Intensity
	bloom.Size = LightingConfig.Bloom.Size
	bloom.Threshold = LightingConfig.Bloom.Threshold

	local cc = effect("ColorCorrectionEffect", "WraithsteelGrade") :: ColorCorrectionEffect
	cc.Saturation = LightingConfig.ColorCorrection.Saturation
	cc.Contrast = LightingConfig.ColorCorrection.Contrast
	cc.TintColor = rgb(LightingConfig.ColorCorrection.TintColor)

	-- Dynamic clouds (live under Terrain).
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	local cc2 = clouds :: Clouds
	cc2.Cover = LightingConfig.Clouds.Cover
	cc2.Density = LightingConfig.Clouds.Density
	cc2.Color = rgb(LightingConfig.Clouds.Color)
	cc2.Parent = workspace.Terrain

	local rays = effect("SunRaysEffect", "WraithsteelSunRays") :: SunRaysEffect
	rays.Intensity = LightingConfig.SunRays.Intensity
	rays.Spread = LightingConfig.SunRays.Spread
end

return AmbienceService
