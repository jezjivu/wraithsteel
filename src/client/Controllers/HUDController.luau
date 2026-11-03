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
local EffectsConfig = require(Config:WaitForChild("EffectsConfig"))
local SkillLogic = require(Shared:WaitForChild("SkillLogic"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local DataController = require(script.Parent.DataController)

local HUDController = { Name = "HUDController", Priority = 41 }

-- Combo counter (right side): consecutive hits/parries within EffectsConfig.Combo.window.
local comboLabel: TextLabel? = nil
local comboCount = 0
local comboExpires = 0
function HUDController.ComboHit()
	local l = comboLabel
	if l == nil then
		return
	end
	local cfg = EffectsConfig.Combo
	local now = os.clock()
	comboCount = if now <= comboExpires then comboCount + 1 else 1
	comboExpires = now + cfg.window
	if comboCount < 2 then
		return
	end
	local hot = comboCount >= cfg.hotAt
	local c = if hot then cfg.hotColor else cfg.color
	l.TextColor3 = Color3.fromRGB(c[1], c[2], c[3])
	l.Text = comboCount .. " HITS"
	l.TextTransparency = 0
	l.TextStrokeTransparency = 0.3
	local scale = l:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = if hot then 1.5 else 1.3
	TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local mine = comboCount
	task.delay(cfg.window, function()
		if comboCount == mine and os.clock() >= comboExpires then
			TweenService:Create(l, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local C = Kit.Colors
local localPlayer = Players.LocalPlayer

local stats: TextLabel? = nil
local showDeathScreen: () -> ()

type Meter = { frame: Frame, fill: Frame, ghost: Frame, label: TextLabel, centered: boolean, last: number }

-- WRAITHSTEEL meters: a sharp steel-framed slot, a lit fill and a pale "ghost" that lingers
-- where you just lost value, then drains after it. Centered meters (posture) grow from the
-- middle outward.
local function meter(parent: Instance, pos: UDim2, size: UDim2, color: Color3, text: string, centered: boolean?): Meter
	local frame = Instance.new("Frame")
	frame.Position = pos
	frame.Size = size
	frame.BackgroundColor3 = C.Ink
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.Parent = parent
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = C.Steel
	st.Transparency = 0.35
	st.Parent = frame
	local anchor = if centered then Vector2.new(0.5, 0) else Vector2.new(0, 0)
	local at = if centered then UDim2.fromScale(0.5, 0) else UDim2.fromScale(0, 0)
	local ghost = Instance.new("Frame")
	ghost.AnchorPoint = anchor
	ghost.Position = at
	ghost.Size = UDim2.fromScale(if centered then 0 else 1, 1)
	ghost.BackgroundColor3 = Color3.fromRGB(245, 235, 215)
	ghost.BackgroundTransparency = 0.35
	ghost.BorderSizePixel = 0
	ghost.Parent = frame
	local fill = Instance.new("Frame")
	fill.AnchorPoint = anchor
	fill.Position = at
	fill.Size = UDim2.fromScale(if centered then 0 else 1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = frame
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150))
	g.Rotation = 90
	g.Parent = fill
	-- Bright leading edge.
	local tip = Instance.new("Frame")
	tip.AnchorPoint = Vector2.new(1, 0)
	tip.Position = UDim2.fromScale(1, 0)
	tip.Size = UDim2.new(0, 2, 1, 0)
	tip.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.6)
	tip.BorderSizePixel = 0
	tip.Visible = not centered
	tip.Parent = fill
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.TextColor3 = C.Text
	label.TextStrokeTransparency = 0.4
	label.Text = string.upper(text)
	label.ZIndex = 2
	label.Parent = frame
	return { frame = frame, fill = fill, ghost = ghost, label = label, centered = centered == true, last = if centered then 0 else 1 }
end

local function setMeter(m: Meter, frac: number, text: string?)
	local f = math.clamp(frac, 0, 1)
	m.fill.Size = UDim2.fromScale(f, 1)
	if f < m.last - 0.002 and not m.centered then
		-- Lost value: the ghost waits a beat, then drains to the new value.
		local target = UDim2.fromScale(f, 1)
		task.delay(0.35, function()
			if m.fill.Size == target then
				TweenService:Create(m.ghost, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = target }):Play()
			end
		end)
	elseif f > m.last or m.centered then
		m.ghost.Size = UDim2.fromScale(f, 1)
	end
	m.last = f
	if text then
		m.label.Text = string.upper(text)
	end
end

local health: Meter? = nil
local flaskLabel: TextLabel? = nil
local shieldFill: Frame? = nil
local posture: Meter? = nil
local ultimate: Meter? = nil
local bossFrame: Frame? = nil
local bossName: TextLabel? = nil
local bossHp: Meter? = nil
local bossPosture: Meter? = nil

local pointsChip: TextLabel? = nil
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
	-- Unspent skill points reminder.
	local chip = pointsChip
	if chip then
		local pts = SkillLogic.Available(DataController.Get("level") or 1, DataController.Get("skills") or {}, SkillLogic.Count(DataController.Get("relics")))
		chip.Visible = pts > 0
		chip.Text = string.format("✦ %d SKILL POINT%s  ·  MENU > SKILLS", pts, if pts == 1 then "" else "S")
	end
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
			local shield = tonumber(character:GetAttribute("Shield")) or 0
			local text = string.format("%d / %d", math.ceil(humanoid.Health), humanoid.MaxHealth)
			if shield > 0 then
				text ..= string.format("  +%d shield", math.ceil(shield * humanoid.MaxHealth))
			end
			setMeter(health, humanoid.Health / math.max(humanoid.MaxHealth, 1), text)
			local sf = shieldFill
			if sf then
				sf.Size = UDim2.fromScale(math.clamp(shield, 0, 1), 1)
				sf.Visible = shield > 0
			end
		end
		if flaskLabel then
			local n = tonumber(character:GetAttribute("Flask")) or 0
			local breath = character:GetAttribute("Breath") == true
			local kunai = tonumber(character:GetAttribute("Kunai")) or 0
			flaskLabel.Text = string.format("Flask x%d%s  ·  Kunai %d", n, if breath then " ✦" else "", kunai)
			flaskLabel.TextColor3 = if n > 0 then Color3.fromRGB(150, 220, 255) else Color3.fromRGB(150, 140, 140)
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
	character:GetAttributeChangedSignal("Shield"):Connect(refresh)
	character:GetAttributeChangedSignal("Flask"):Connect(refresh)
	character:GetAttributeChangedSignal("Breath"):Connect(refresh)
	character:GetAttributeChangedSignal("Kunai"):Connect(refresh)
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
	s.TextSize = 15
	s.Parent = gui
	local sst = Instance.new("UIStroke")
	sst.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	sst.Color = C.Steel
	sst.Transparency = 0.5
	sst.Parent = s
	Kit.BladeLine(s, UDim2.new(0, 0, 1, 0), UDim.new(1, 0))
	stats = s
	local chip = Instance.new("TextLabel")
	chip.Position = UDim2.fromOffset(10, 46)
	chip.Size = UDim2.fromOffset(300, 22)
	chip.BackgroundColor3 = C.Ink
	chip.BackgroundTransparency = 0.25
	chip.BorderSizePixel = 0
	chip.Font = Enum.Font.GothamBold
	chip.TextSize = 12
	chip.TextColor3 = C.Gold
	chip.Visible = false
	chip.Parent = gui
	local cst = Instance.new("UIStroke")
	cst.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cst.Color = C.Gold
	cst.Transparency = 0.4
	cst.Parent = chip
	pointsChip = chip

	-- Player meters (bottom center, above the default toolbar area).
	health = meter(gui, UDim2.new(0.5, -160, 1, -92), UDim2.fromOffset(320, 22), Color3.fromRGB(190, 55, 50), "Health")
	local fl = Instance.new("TextLabel")
	fl.Position = UDim2.new(0.5, -330, 1, -92)
	fl.Size = UDim2.fromOffset(164, 22)
	fl.BackgroundColor3 = C.Ink
	fl.BackgroundTransparency = 0.2
	fl.Font = Enum.Font.GothamBold
	fl.TextSize = 13
	fl.TextColor3 = Color3.fromRGB(150, 220, 255)
	fl.Text = "Flask"
	fl.Parent = gui
	local flc = Instance.new("UIStroke")
	flc.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	flc.Color = Color3.fromRGB(150, 220, 255)
	flc.Transparency = 0.5
	flc.Parent = fl
	flaskLabel = fl
	-- Shield overlay (pale jade over the health bar).
	local sf = Instance.new("Frame")
	sf.Size = UDim2.fromScale(0, 1)
	sf.BackgroundColor3 = Color3.fromRGB(150, 255, 200)
	sf.BackgroundTransparency = 0.45
	sf.BorderSizePixel = 0
	sf.Visible = false
	sf.ZIndex = 1
	sf.Parent = (health :: Meter).frame
	shieldFill = sf
	posture = meter(gui, UDim2.new(0.5, -160, 1, -66), UDim2.fromOffset(320, 14), Color3.fromRGB(235, 185, 70), "Posture", true)
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
	bossPosture = meter(bf, UDim2.fromOffset(60, 50), UDim2.new(1, -120, 0, 10), Color3.fromRGB(240, 190, 70), "", true)
	bossFrame = bf

	local combo = Instance.new("TextLabel")
	combo.AnchorPoint = Vector2.new(1, 0.5)
	combo.Position = UDim2.new(1, -24, 0.55, 0)
	combo.Size = UDim2.fromOffset(260, 60)
	combo.BackgroundTransparency = 1
	combo.Font = Enum.Font.Antique
	combo.TextSize = 46
	combo.TextXAlignment = Enum.TextXAlignment.Right
	combo.TextTransparency = 1
	combo.TextStrokeTransparency = 1
	combo.Parent = gui
	Instance.new("UIScale").Parent = combo
	comboLabel = combo

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

	-- Elite (mini-boss) bar: the nearest elite that has noticed you gets the top bar while no
	-- story boss is using it.
	local bossActive = false
	local bossSeenAt = 0
	local eliteShown: Model? = nil
	task.spawn(function()
		local CollectionService = game:GetService("CollectionService")
		while true do
			task.wait(0.2)
			local frame, nameL, hp, pos = bossFrame, bossName, bossHp, bossPosture
			local ch = localPlayer.Character
			local myRoot = ch and ch:FindFirstChild("HumanoidRootPart")
			-- Boss updates stream while a fight runs; silence means it ended (left the arena etc.).
			if bossActive and os.clock() - bossSeenAt > 3 then
				bossActive = false
				if frame then
					frame.Visible = false
				end
			end
			if frame and nameL and hp and pos and not bossActive and myRoot and myRoot:IsA("BasePart") then
				local best, bestD = nil, 55
				for _, m in CollectionService:GetTagged("Elite") do
					if m:IsA("Model") and m:IsDescendantOf(workspace) and m:GetAttribute("Unaware") ~= true then
						local r = m:FindFirstChild("HumanoidRootPart")
						local h = m:FindFirstChildOfClass("Humanoid")
						if r and r:IsA("BasePart") and h and h.Health > 0 then
							local d = (r.Position - myRoot.Position).Magnitude
							if d < bestD then
								best, bestD = m, d
							end
						end
					end
				end
				if best then
					local h = best:FindFirstChildOfClass("Humanoid") :: Humanoid
					local lives = tonumber(best:GetAttribute("Lives")) or 1
					eliteShown = best
					nameL.Text = best.Name .. (if lives > 1 then "   " .. string.rep("◆", lives) else "")
					frame.Visible = true
					local frac = h.Health / math.max(1, h.MaxHealth)
					setMeter(hp, frac, string.format("%d%%", math.ceil(frac * 100)))
					local pf = tonumber(best:GetAttribute("Posture")) or 0
					setMeter(pos, pf, if best:GetAttribute("Broken") == true then "BROKEN - strike now!" else "")
				elseif eliteShown then
					eliteShown = nil
					frame.Visible = false
				end
			end
		end
	end)

	Net.Client.On("BossState", function(st)
		bossActive = st.state ~= "Dead" and st.hpFrac > 0
		bossSeenAt = os.clock()
		eliteShown = nil
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
