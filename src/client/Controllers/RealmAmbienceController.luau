--!strict
-- RealmAmbienceController: each realm has its own sky, light and weather (client-side only).
-- Follows the player attribute "Realm" (RealmService): tweens Lighting, the Atmosphere, Bloom
-- and color grading to LightingConfig.Realms[realm] (Ashen Valley = the base LightingConfig),
-- and runs weather around the camera (neon rain, golden dust motes). Blinking rooftop lights
-- in Neon Verge flash here too.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LightingConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("LightingConfig"))

local RealmAmbienceController = { Name = "RealmAmbienceController", Priority = 60 }

local player = Players.LocalPlayer
local weatherPart: Part? = nil

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function tween(inst: Instance?, props: { [string]: any })
	if inst then
		TweenService:Create(inst, TweenInfo.new(2.5, Enum.EasingStyle.Sine), props):Play()
	end
end

local function setWeather(kind: string?)
	if weatherPart then
		weatherPart:Destroy()
		weatherPart = nil
	end
	if kind == nil then
		return
	end
	local p = Instance.new("Part")
	p.Name = "Weather"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(120, 1, 120)
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.EmissionDirection = Enum.NormalId.Bottom
	if kind == "Rain" then
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(170, 200, 255))
		e.LightEmission = 0.4
		e.Size = NumberSequence.new(0.12)
		e.Lifetime = NumberRange.new(1, 1.4)
		e.Rate = 600
		e.Speed = NumberRange.new(70, 90)
		e.Transparency = NumberSequence.new(0.35)
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.Squash = NumberSequence.new(-2.5)
	else
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(255, 225, 150))
		e.LightEmission = 0.8
		e.Size = NumberSequence.new(0.25, 0)
		e.Lifetime = NumberRange.new(5, 8)
		e.Rate = 30
		e.Speed = NumberRange.new(0.5, 1.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0.5, 0.3, 0)
	end
	e.Parent = p
	p.Parent = workspace
	weatherPart = p
end

local function apply(realm: string)
	local base = LightingConfig.Lighting
	local r = (LightingConfig.Realms :: any)[realm]
	local L = r or base
	tween(Lighting, {
		ClockTime = L.ClockTime,
		Brightness = L.Brightness,
		Ambient = rgb(L.Ambient),
		OutdoorAmbient = rgb(L.OutdoorAmbient),
	})
	local A = if r then r.Atmosphere else LightingConfig.Atmosphere
	tween(Lighting:FindFirstChildOfClass("Atmosphere"), {
		Density = A.Density,
		Offset = A.Offset,
		Color = rgb(A.Color),
		Decay = rgb(A.Decay),
		Glare = A.Glare,
		Haze = A.Haze,
	})
	local B = if r then r.Bloom else LightingConfig.Bloom
	tween(Lighting:FindFirstChildOfClass("BloomEffect"), { Intensity = B.Intensity, Size = B.Size, Threshold = B.Threshold })
	local C = if r then r.ColorCorrection else LightingConfig.ColorCorrection
	tween(Lighting:FindFirstChild("WraithsteelGrade"), { Saturation = C.Saturation, Contrast = C.Contrast, TintColor = rgb(C.TintColor) })
	setWeather(if r then r.weather else nil)
end

-- Valley sky at the current server time (hours 0-24 + blended lighting values).
local function valleySky(): (number, number, Color3, Color3)
	local D = LightingConfig.DayNight
	local cycle = D.cycleMinutes * 60
	-- Offset so a fresh server starts at dusk (the valley's signature look).
	local hour = ((workspace:GetServerTimeNow() / cycle) * 24 + 17) % 24
	local keys = D.keys
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if hour >= a.hour and hour <= b.hour then
			local t = (hour - a.hour) / math.max(1e-3, b.hour - a.hour)
			return hour, a.brightness + (b.brightness - a.brightness) * t, rgb(a.ambient):Lerp(rgb(b.ambient), t), rgb(a.outdoor):Lerp(rgb(b.outdoor), t)
		end
	end
	return hour, keys[1].brightness, rgb(keys[1].ambient), rgb(keys[1].outdoor)
end

function RealmAmbienceController.Init() end

function RealmAmbienceController.Start()
	local current = ""
	local function check()
		local realm = tostring(player:GetAttribute("Realm") or "japan")
		if realm ~= current then
			current = realm
			apply(realm)
		end
	end
	player:GetAttributeChangedSignal("Realm"):Connect(check)
	task.delay(2, check)
	-- Day/night in the Ashen Valley (other realms keep their fixed mood).
	if LightingConfig.DayNight.enabled then
		task.spawn(function()
			task.wait(3) -- after the realm mood tween
			while true do
				if current == "japan" then
					local hour, brightness, ambient, outdoor = valleySky()
					Lighting.ClockTime = hour
					Lighting.Brightness = brightness
					Lighting.Ambient = ambient
					Lighting.OutdoorAmbient = outdoor
				end
				task.wait(0.5)
			end
		end)
	end
	RunService.RenderStepped:Connect(function()
		local p = weatherPart
		local cam = workspace.CurrentCamera
		if p and cam then
			p.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 40, 0))
		end
	end)
end

return RealmAmbienceController
