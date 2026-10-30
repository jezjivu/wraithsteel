--!strict
-- HUDController: code-built HUD (placeholder style until Agent D designs the real one).
--   * top-left: Ember, Jade, Level, Power
--   * bottom-center: your Health, Posture and Ultimate meters
--   * top-center: boss bar (name, title, HP, posture, phase) during boss encounters
--   * zone banner when entering a new area (ZoneService)
-- Data sources: DataController, character Humanoid + attributes (Posture, Ultimate set by
-- CombatService), player attributes (Power, Level), BossState remote.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local FormatNumber = require(Shared:WaitForChild("FormatNumber"))
local BossConfig = require(Config:WaitForChild("BossConfig"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local DataController = require(script.Parent.DataController)

local HUDController = { Name = "HUDController", Priority = 41 }

local C = Kit.Colors
local localPlayer = Players.LocalPlayer

local stats: TextLabel? = nil
local showDeathScreen: () -> ()

type Meter = { frame: Frame, fill: Frame, label: TextLabel }

local function meter(parent: Instance, pos: UDim2, size: UDim2, color: Color3, text: string): Meter
	local frame = Instance.new("Frame")
	frame.Position = pos
	frame.Size = size
	frame.BackgroundColor3 = C.Ink
	frame.BorderSizePixel = 0
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = frame
	local c2 = Instance.new("UICorner")
	c2.CornerRadius = UDim.new(0, 6)
	c2.Parent = fill
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextColor3 = C.Text
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.ZIndex = 2
	label.Parent = frame
	return { frame = frame, fill = fill, label = label }
end

local function setMeter(m: Meter, frac: number, text: string?)
	m.fill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
	if text then
		m.label.Text = text
	end
end

local health: Meter? = nil
local posture: Meter? = nil
local ultimate: Meter? = nil
local bossFrame: Frame? = nil
local bossName: TextLabel? = nil
local bossHp: Meter? = nil
local bossPosture: Meter? = nil

local function refreshStats()
	local label = stats
	if label == nil then
		return
	end
	label.Text = string.format(
		"Ember %s   Jade %s   Lv %s   Power %s",
		FormatNumber.Short(DataController.Get("ember") or 0),
		FormatNumber.Short(DataController.Get("jade") or 0),
		tostring(DataController.Get("level") or 1),
		FormatNumber.Short(tonumber(localPlayer:GetAttribute("Power")) or 0)
	)
end

-- Big fading banner when entering a new zone (ZoneService sets Zone/ZoneName attributes).
local banner: TextLabel? = nil
local bannerSub: TextLabel? = nil
local function showZoneBanner()
	local b, sub = banner, bannerSub
	if b == nil or sub == nil then
		return
	end
	b.Text = tostring(localPlayer:GetAttribute("ZoneName") or "")
	sub.Text = tostring(localPlayer:GetAttribute("ZoneSubtitle") or "")
	for _, l in { b, sub } do
		l.TextTransparency = 0
		l.TextStrokeTransparency = 0.4
		TweenService:Create(l, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 2), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
	end
end

-- "Fallen" overlay while waiting to respawn in the hub.
local hudGui: ScreenGui? = nil
showDeathScreen = function()
	local g = hudGui
	if g == nil then
		return
	end
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.fromRGB(40, 0, 0)
	f.BackgroundTransparency = 1
	f.ZIndex = 20
	f.Parent = g
	local t = Instance.new("TextLabel")
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.42)
	t.Size = UDim2.new(1, 0, 0, 80)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.Antique
	t.TextSize = 72
	t.TextColor3 = Color3.fromRGB(220, 50, 40)
	t.TextTransparency = 1
	t.Text = "FALLEN"
	t.ZIndex = 21
	t.Parent = f
	local s2 = t:Clone()
	s2.Position = UDim2.fromScale(0.5, 0.52)
	s2.Font = Enum.Font.GothamMedium
	s2.TextSize = 22
	s2.TextColor3 = Color3.fromRGB(230, 220, 210)
	s2.Text = "Your spirit returns to Ninefold Crossing..."
	s2.Parent = f
	TweenService:Create(f, TweenInfo.new(0.8), { BackgroundTransparency = 0.45 }):Play()
	TweenService:Create(t, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
	TweenService:Create(s2, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.4), { TextTransparency = 0 }):Play()
	localPlayer.CharacterAdded:Once(function()
		local fade = TweenInfo.new(0.6)
		TweenService:Create(f, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(t, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(s2, fade, { TextTransparency = 1 }):Play()
		task.delay(0.7, function()
			f:Destroy()
		end)
	end)
end

local function bindCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid == nil then
		return
	end
	local function refresh()
		if health then
			setMeter(health, humanoid.Health / math.max(humanoid.MaxHealth, 1), string.format("%d / %d", math.ceil(humanoid.Health), humanoid.MaxHealth))
		end
		if posture then
			local p = tonumber(character:GetAttribute("Posture")) or 0
			setMeter(posture, p, if p >= 0.75 then "Posture - careful!" else "Posture")
		end
		if ultimate then
			local u = tonumber(character:GetAttribute("Ultimate")) or 0
			setMeter(ultimate, u, if u >= 1 then "Ultimate READY (G)" else "Ultimate")
		end
	end
	humanoid.Died:Connect(showDeathScreen)
	humanoid.HealthChanged:Connect(refresh)
	character:GetAttributeChangedSignal("Posture"):Connect(refresh)
	character:GetAttributeChangedSignal("Ultimate"):Connect(refresh)
	refresh()
end

function HUDController.Init()
	local gui = Kit.Screen(localPlayer:WaitForChild("PlayerGui"), "HUD", 3)
	hudGui = gui

	local s = Instance.new("TextLabel")
	s.Position = UDim2.fromOffset(10, 10)
	s.Size = UDim2.fromOffset(400, 30)
	s.BackgroundColor3 = C.Ink
	s.BackgroundTransparency = 0.25
	s.TextColor3 = C.Gold
	s.Font = Enum.Font.GothamBold
	s.TextSize = 16
	s.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = s
	stats = s

	-- Player meters (bottom center, above the default toolbar area).
	health = meter(gui, UDim2.new(0.5, -160, 1, -92), UDim2.fromOffset(320, 22), Color3.fromRGB(190, 55, 50), "Health")
	posture = meter(gui, UDim2.new(0.5, -160, 1, -66), UDim2.fromOffset(320, 14), Color3.fromRGB(235, 185, 70), "Posture")
	ultimate = meter(gui, UDim2.new(0.5, -160, 1, -48), UDim2.fromOffset(320, 10), Color3.fromRGB(120, 170, 255), "")

	-- Boss bar (top center).
	local bf = Instance.new("Frame")
	bf.AnchorPoint = Vector2.new(0.5, 0)
	bf.Position = UDim2.new(0.5, 0, 0, 52)
	bf.Size = UDim2.fromOffset(520, 64)
	bf.BackgroundTransparency = 1
	bf.Visible = false
	bf.Parent = gui
	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0, 24)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBlack
	name.TextSize = 20
	name.TextColor3 = C.Gold
	name.TextStrokeTransparency = 0.3
	name.Parent = bf
	bossName = name
	bossHp = meter(bf, UDim2.fromOffset(0, 28), UDim2.new(1, 0, 0, 18), Color3.fromRGB(180, 40, 40), "")
	bossPosture = meter(bf, UDim2.fromOffset(60, 50), UDim2.new(1, -120, 0, 10), Color3.fromRGB(240, 190, 70), "")
	bossFrame = bf

	local zb = Instance.new("TextLabel")
	zb.AnchorPoint = Vector2.new(0.5, 0)
	zb.Position = UDim2.fromScale(0.5, 0.22)
	zb.Size = UDim2.fromOffset(600, 50)
	zb.BackgroundTransparency = 1
	zb.Font = Enum.Font.Antique
	zb.TextSize = 44
	zb.TextColor3 = C.Gold
	zb.TextTransparency = 1
	zb.TextStrokeTransparency = 1
	zb.Parent = gui
	banner = zb
	local zs = Instance.new("TextLabel")
	zs.AnchorPoint = Vector2.new(0.5, 0)
	zs.Position = UDim2.new(0.5, 0, 0.22, 52)
	zs.Size = UDim2.fromOffset(600, 26)
	zs.BackgroundTransparency = 1
	zs.Font = Enum.Font.GothamMedium
	zs.TextSize = 20
	zs.TextColor3 = C.Text
	zs.TextTransparency = 1
	zs.TextStrokeTransparency = 1
	zs.Parent = gui
	bannerSub = zs
end

function HUDController.Start()
	DataController.Changed:Connect(refreshStats)
	localPlayer:GetAttributeChangedSignal("Power"):Connect(refreshStats)
	refreshStats()

	localPlayer:GetAttributeChangedSignal("Zone"):Connect(showZoneBanner)

	localPlayer.CharacterAdded:Connect(bindCharacter)
	if localPlayer.Character then
		task.spawn(bindCharacter, localPlayer.Character)
	end

	Net.Client.On("BossState", function(st)
		local frame = bossFrame
		if frame == nil or bossName == nil or bossHp == nil or bossPosture == nil then
			return
		end
		frame.Visible = st.state ~= "Dead" and st.hpFrac > 0
		local def = BossConfig.Bosses[st.bossId]
		local phaseText = if st.phase > 1 then "  ·  Phase " .. st.phase else ""
		bossName.Text = (if def then def.name .. " - " .. def.title else st.bossId) .. phaseText
		setMeter(bossHp, st.hpFrac, string.format("%d%%", math.ceil(st.hpFrac * 100)))
		setMeter(bossPosture, st.postureFrac, if st.state == "Broken" then "BROKEN - strike now!" else "")
	end)
end

return HUDController
