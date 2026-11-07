--!strict
-- SpellController: Qi arts on Z / X / C and the Spirit Burst on T.
--   * sends CastSpell(spellId, aim, targetPoint) - the server validates and decides everything
--   * arts bar above the health meters: 3 art slots + Spirit Burst, cooldown sweeps, Qi bar
--   * draws every player's arts from "Spell" CombatEvents (UI/SpellFx); Ghost Step moves the
--     local character (it owns its physics) when the server confirms the cast
--
-- API:
--   SpellController.Changed: Signal()  -- loadout changed (Spellbook panel listens)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local SpellConfig = require(Config:WaitForChild("SpellConfig"))
local SpiritConfig = require(Config:WaitForChild("SpiritConfig"))
local AnimationConfig = require(Config:WaitForChild("AnimationConfig"))
local EffectsConfig = require(Config:WaitForChild("EffectsConfig"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Fx = require(UI:WaitForChild("Fx"))
local SpellFx = require(UI:WaitForChild("SpellFx"))

local InputController = require(script.Parent.InputController)
local CombatController = require(script.Parent.CombatController)
local MovementController = require(script.Parent.MovementController)
local AnimationController = require(script.Parent.AnimationController)
local DataController = require(script.Parent.DataController)
local EffectsController = require(script.Parent.EffectsController)
local NotificationController = require(script.Parent.NotificationController)

local SpellController = { Name = "SpellController", Priority = 45, Changed = Signal.new() }

local localPlayer = Players.LocalPlayer
local C = Kit.Colors
local readyAt: { [string]: number } = {} -- local clock
local cooldownOf: { [string]: number } = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function loadout(): { string }
	local l = DataController.Get("spellLoadout")
	return if type(l) == "table" then l else SpellConfig.DefaultLoadout
end

local function qi(): number
	local ch = localPlayer.Character
	return if ch then tonumber(ch:GetAttribute("Qi")) or 0 else 0
end

-- Arts bar -----------------------------------------------------------------------------------
type SlotUi = { frame: Frame, name: TextLabel, shade: Frame, timer: TextLabel, stroke: UIStroke, cost: TextLabel }
local slotUi: { SlotUi } = {}
local burstUi: SlotUi? = nil
local qiFill: Frame? = nil
local qiText: TextLabel? = nil

local function makeSlot(parent: Instance, x: number, key: string): SlotUi
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(58, 58)
	f.Position = UDim2.fromOffset(x, 0)
	f.BackgroundColor3 = C.Ink
	f.BackgroundTransparency = 0.15
	f.Parent = parent
	Kit.Corner(f, 10)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = 1.5
	stroke.Transparency = 0.25
	stroke.Color = C.Gold
	stroke.Parent = f
	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -8, 0, 20)
	name.Position = UDim2.new(0, 4, 1, -26)
	name.BackgroundTransparency = 1
	name.Font = Kit.BoldFont
	name.TextScaled = true
	name.TextColor3 = C.Text
	name.TextStrokeTransparency = 0.7
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 15
	cap.Parent = name
	name.ZIndex = 2
	name.Parent = f
	local k = Instance.new("TextLabel")
	k.Size = UDim2.fromOffset(18, 18)
	k.Position = UDim2.fromOffset(5, 5)
	k.BackgroundColor3 = C.Raised
	k.BackgroundTransparency = 0.1
	k.Font = Kit.HeavyFont
	k.TextSize = 12
	k.TextColor3 = C.Gold
	Kit.Corner(k, 5)
	k.Text = key
	k.ZIndex = 3
	k.Parent = f
	local cost = Instance.new("TextLabel")
	cost.Size = UDim2.fromOffset(30, 18)
	cost.Position = UDim2.new(1, -34, 0, 5)
	cost.BackgroundTransparency = 1
	cost.Font = Kit.BoldFont
	cost.TextSize = 12
	cost.TextXAlignment = Enum.TextXAlignment.Right
	cost.TextColor3 = Color3.fromRGB(140, 200, 255)
	cost.ZIndex = 3
	cost.Parent = f
	local shade = Instance.new("Frame")
	shade.AnchorPoint = Vector2.new(0, 1)
	shade.Position = UDim2.fromScale(0, 1)
	shade.Size = UDim2.fromScale(1, 0)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.35
	shade.ZIndex = 4
	shade.Parent = f
	Kit.Corner(shade, 10)
	local timer = Instance.new("TextLabel")
	timer.Size = UDim2.fromScale(1, 1)
	timer.BackgroundTransparency = 1
	timer.Font = Kit.HeavyFont
	timer.TextSize = 20
	timer.TextColor3 = Color3.new(1, 1, 1)
	timer.TextStrokeTransparency = 0.2
	timer.Text = ""
	timer.ZIndex = 5
	timer.Parent = f
	Instance.new("UIScale").Parent = f
	return { frame = f, name = name, shade = shade, timer = timer, stroke = stroke, cost = cost }
end

local function pulse(ui: SlotUi, color: Color3)
	local scale = ui.frame:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 1.18
	TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	ui.stroke.Color = color
end

local function shortName(name: string): string
	local first = string.match(name, "^(%S+)") or name
	return first
end

local function refreshSlots()
	local l = loadout()
	for i, ui in slotUi do
		local id = l[i] or ""
		local spell = SpellConfig.Spells[id]
		if spell then
			ui.name.Text = shortName(spell.name)
			ui.name.TextColor3 = rgb(spell.color)
			ui.stroke.Color = rgb(spell.color)
			ui.cost.Text = tostring(spell.qi)
		else
			ui.name.Text = "-"
			ui.name.TextColor3 = C.Muted
			ui.stroke.Color = C.Muted
			ui.cost.Text = ""
		end
	end
end

local function buildBar()
	local gui = Kit.Screen(localPlayer:WaitForChild("PlayerGui"), "ArtsBar", 4)
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -104)
	bar.Size = UDim2.fromOffset(4 * 58 + 3 * 10 + 16, 72)
	bar.BackgroundTransparency = 1
	bar.Parent = gui
	Kit.AutoScale(bar)
	for i = 1, SpellConfig.Slots do
		table.insert(slotUi, makeSlot(bar, (i - 1) * 68, SpellConfig.KeyLabels[i]))
	end
	local b = makeSlot(bar, SpellConfig.Slots * 68 + 16, "T")
	b.name.Text = "Burst"
	b.stroke.Color = Color3.fromRGB(200, 150, 255)
	b.name.TextColor3 = Color3.fromRGB(220, 190, 255)
	burstUi = b
	-- Qi bar under the slots.
	local qf = Instance.new("Frame")
	qf.Position = UDim2.fromOffset(0, 66)
	qf.Size = UDim2.new(1, 0, 0, 5)
	qf.BackgroundColor3 = C.Ink
	qf.BackgroundTransparency = 0.2
	qf.BorderSizePixel = 0
	qf.Parent = bar
	Kit.Corner(qf, 999)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 170, 255)
	fill.Parent = qf
	fill.BorderSizePixel = 0
	Kit.Corner(fill, 999)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(80, 140, 255), Color3.fromRGB(170, 230, 255))
	grad.Parent = fill
	local txt = Instance.new("TextLabel")
	txt.AnchorPoint = Vector2.new(0, 0)
	txt.Position = UDim2.new(0, 0, 0, 7) -- left: the style chip sits on the right
	txt.Size = UDim2.fromOffset(120, 14)
	txt.BackgroundTransparency = 1
	txt.Font = Kit.BoldFont
	txt.TextSize = 12
	txt.TextXAlignment = Enum.TextXAlignment.Left
	txt.TextColor3 = Color3.fromRGB(150, 200, 255)
	txt.TextStrokeTransparency = 0.6
	txt.ZIndex = 2
	txt.Parent = qf
	qiFill, qiText = fill, txt
	refreshSlots()
end

local function updateBar()
	local now = os.clock()
	local q = qi()
	local l = loadout()
	for i, ui in slotUi do
		local id = l[i] or ""
		local spell = SpellConfig.Spells[id]
		local remaining = math.max(0, (readyAt[id] or 0) - now)
		local total = cooldownOf[id] or (if spell then spell.cooldown else 1)
		ui.shade.Size = UDim2.fromScale(1, if remaining > 0 then math.clamp(remaining / total, 0, 1) else 0)
		ui.timer.Text = if remaining > 0 then string.format(if remaining < 1 then "%.1f" else "%d", remaining) else ""
		local affordable = spell ~= nil and q >= spell.qi
		ui.frame.BackgroundTransparency = if affordable then 0.15 else 0.5
		ui.name.TextTransparency = if affordable then 0 else 0.5
	end
	local b = burstUi
	if b then
		local readyServer = tonumber(localPlayer:GetAttribute("SpiritBurstReadyAt")) or 0
		local remaining = math.max(0, readyServer - workspace:GetServerTimeNow())
		b.shade.Size = UDim2.fromScale(1, if remaining > 0 then math.clamp(remaining / SpiritConfig.Burst.cooldown, 0, 1) else 0)
		b.timer.Text = if remaining > 0 then string.format("%d", math.ceil(remaining)) else ""
	end
	if qiFill and qiText then
		local max = SpellConfig.Qi.max
		qiFill.Size = UDim2.fromScale(math.clamp(q / max, 0, 1), 1)
		qiText.Text = string.format("Qi %d / %d", q, max)
	end
end

-- Casting ------------------------------------------------------------------------------------
local function castSlot(index: number)
	local id = loadout()[index] or ""
	local spell = SpellConfig.Spells[id]
	local ui = slotUi[index]
	if spell == nil then
		NotificationController.Show("Info", "Empty art slot - open the Arts menu to choose one.")
		return
	end
	local now = os.clock()
	if now < (readyAt[id] or 0) then
		if ui then
			pulse(ui, Color3.fromRGB(255, 80, 70))
		end
		return
	end
	if qi() < spell.qi then
		if ui then
			pulse(ui, Color3.fromRGB(90, 140, 255))
		end
		Fx.CenterText("NOT ENOUGH QI", Color3.fromRGB(120, 170, 255), 28, 0.4)
		return
	end
	local dir = CombatController.AimDirection()
	if dir then
		CombatController.FaceToward(dir)
	end
	local point = CombatController.AimTarget(spell.range or 40)
	Net.Client.Fire("CastSpell", id, dir, point)
	readyAt[id] = now + spell.cooldown -- the server's cooldown arrives with the cast event
	if ui then
		pulse(ui, rgb(spell.color))
	end
	local character = localPlayer.Character
	if character then
		local style = AnimationConfig.CastStyles[spell.kind] or "CastPush"
		local timing = { windup = 0.12, active = 0.2, recovery = 0.3 }
		if style == "DashStrike" then
			AnimationController.Play(character, "LightAttack", nil, timing, "Dash")
		else
			AnimationController.Play(character, style, nil, timing)
		end
	end
end

local function onSpell(e: { [string]: any })
	local spell = SpellConfig.Spells[e.spell]
	if spell == nil then
		return
	end
	local color = rgb(spell.color)
	local caster = EffectsController.ModelFor(e.sourceId)
	local mine = e.userId == localPlayer.UserId
	if mine and type(e.cooldown) == "number" then
		readyAt[e.spell] = os.clock() + e.cooldown
		cooldownOf[e.spell] = e.cooldown
	end
	if caster and not mine then
		local style = AnimationConfig.CastStyles[spell.kind] or "CastPush"
		if style ~= "DashStrike" then
			AnimationController.Play(caster, style, nil, { windup = 0.12, active = 0.2, recovery = 0.3 })
		end
	end
	local origin: Vector3 = if typeof(e.origin) == "Vector3" then e.origin else Vector3.zero
	local dir: Vector3 = if typeof(e.dir) == "Vector3" then e.dir else Vector3.zAxis
	local point: Vector3 = if typeof(e.point) == "Vector3" then e.point else origin
	if mine then
		Fx.CenterText(string.upper(spell.name), color, 30, 0.5)
	end
	SpellFx.Sound(EffectsConfig.Sounds.cast, origin, if spell.kind == "SkyFall" then 0.6 else 1.3)
	if spell.kind == "Flurry" then
		-- Flash next to the target, then the storm of cuts.
		if mine then
			local flat = Vector3.new(point.X - origin.X, 0, point.Z - origin.Z)
			local stop = if flat.Magnitude > 4 then point - flat.Unit * 3.5 else origin
			SpellFx.BlinkTrail(origin, stop, color)
			MovementController.ArcTo(stop, 0.1, 0)
			local ch = localPlayer.Character
			if ch then
				AnimationController.Play(ch, "Spin", nil, { windup = 0.1, active = (spell.ticks or 10) * (spell.interval or 0.08), recovery = 0.2 })
			end
		end
		SpellFx.ThousandCuts(point, color, spell.radius or 9, (spell.ticks or 10) * (spell.interval or 0.08) + 0.1)
		Fx.CenterText(if mine then "THOUSAND CUTS" else "", color, 36, 0.6)
	elseif spell.kind == "Blink" then
		if mine then
			local from, to = MovementController.Blink(dir, spell.range or 24)
			if from and to then
				SpellFx.BlinkTrail(from, to, color)
				for k = 1, 4 do
					local p = from:Lerp(to, k / 5)
					SpellFx.SlashArc(CFrame.lookAt(p, p + dir) * CFrame.Angles(0, 0, math.rad(60 * k)), color, 7, 0.22)
				end
			end
		else
			SpellFx.BlinkTrail(origin, point, color)
		end
	elseif spell.kind == "SlashWave" then
		SpellFx.CrescentWave(origin, dir, spell.range or 60, spell.speed or 120, color, (spell.width or 5) / 5)
		if (spell.width or 5) > 8 then
			Fx.CameraPunch(10)
		end
	elseif spell.kind == "Fissure" then
		SpellFx.Fissure(origin, dir, spell.range or 40, color, spell.delay or 0.25)
	elseif spell.kind == "Rising" then
		if caster then
			SpellFx.RisingDragon(caster, color)
		end
		if mine then
			MovementController.Launch(48)
		end
	elseif spell.kind == "Storm" then
		if caster then
			SpellFx.Storm(caster, color, spell.radius or 12, (spell.ticks or 5) * (spell.interval or 0.3))
			for k = 1, spell.ticks or 5 do
				task.delay((k - 1) * (spell.interval or 0.3), function()
					local r = caster:FindFirstChild("HumanoidRootPart")
					if r and r:IsA("BasePart") then
						SpellFx.SlashArc(CFrame.new(r.Position) * CFrame.Angles(0, k * 1.3, math.rad(85)), color, (spell.radius or 12) * 1.5, 0.2)
					end
				end)
			end
		end
	elseif spell.kind == "Chain" then
		-- Hop from target to target: trail + slash at each one.
		local points: { Vector3 } = {}
		if type(e.points) == "table" then
			for _, p in e.points do
				if typeof(p) == "Vector3" then
					table.insert(points, p)
				end
			end
		end
		local interval = spell.interval or 0.16
		local last = origin
		for i, p in points do
			local from = last
			task.delay((i - 1) * interval, function()
				local flat = Vector3.new(p.X - from.X, 0, p.Z - from.Z)
				local stop = if flat.Magnitude > 4 then p - flat.Unit * 3 else p
				SpellFx.BlinkTrail(from, stop, color)
				SpellFx.SlashArc(CFrame.lookAt(p, p + (if flat.Magnitude > 0.1 then flat.Unit else dir)) * CFrame.Angles(0, 0, math.rad(40 + 70 * i)), color, 9, 0.25)
				if mine then
					MovementController.ArcTo(stop, interval * 0.7, 1.5)
					Fx.CameraPunch(5)
				end
			end)
			last = p
		end
		if mine then
			local ch = localPlayer.Character
			if ch then
				AnimationController.Play(ch, "LightAttack", nil, { windup = 0.05, active = #points * interval, recovery = 0.2 }, "Dash")
			end
		end
	elseif spell.kind == "SkyFall" then
		SpellFx.SkyFall(point, color, spell.radius or 16, spell.delay or 0.8)
		if mine then
			MovementController.ArcTo(point, spell.delay or 0.8, 40)
			local ch = localPlayer.Character
			if ch then
				AnimationController.Play(ch, "LightAttack", nil, { windup = (spell.delay or 0.8) * 0.7, active = 0.2, recovery = 0.4 }, "Air")
			end
			Fx.ColorPulse(-0.4, 0.3, color, 1)
		end
	end
end

function SpellController.SetSlot(slot: number, spellId: string): (boolean, string?)
	local ok, err = Net.Client.Invoke("SetSpellSlot", slot, spellId)
	return ok == true, err
end

function SpellController.Init() end

function SpellController.Start()
	buildBar()
	InputController.ActionPressed:Connect(function(action: string)
		local n = tonumber(string.match(action, "^Spell(%d)$"))
		if n then
			castSlot(n)
		end
	end)
	DataController.Changed:Connect(function(key)
		if key == "spellLoadout" then
			refreshSlots()
			SpellController.Changed:Fire()
		end
	end)
	CombatController.EventReceived:Connect(function(e)
		if e.kind == "Spell" then
			onSpell(e)
		elseif e.kind == "SkillFx" then
			-- Skill-tree mechanics (SkillConfig): visible to everyone nearby.
			if e.fx == "RingingSteel" and typeof(e.pos) == "Vector3" then
				SpellFx.Nova(e.pos, Color3.fromRGB(255, 215, 130), 10, 0.4)
				SpellFx.Sound(EffectsConfig.Sounds.cast, e.pos, 1.8)
			elseif e.fx == "BloodRush" then
				local model = EffectsController.ModelFor(e.sourceId)
				local root = model and model:FindFirstChild("HumanoidRootPart")
				if model and root and root:IsA("BasePart") then
					local aura = Instance.new("ParticleEmitter")
					aura.Texture = Fx.Textures.Sparkle
					aura.Color = ColorSequence.new(Color3.fromRGB(255, 50, 60))
					aura.LightEmission = 1
					aura.Size = NumberSequence.new(0.6, 0)
					aura.Lifetime = NumberRange.new(0.3, 0.6)
					aura.Rate = 40
					aura.Speed = NumberRange.new(1, 3)
					aura.SpreadAngle = Vector2.new(180, 180)
					aura.Parent = root
					game:GetService("Debris"):AddItem(aura, tonumber(e.seconds) or 8)
				end
				if model == localPlayer.Character then
					Fx.CenterText("BLOOD RUSH", Color3.fromRGB(255, 70, 70), 32, 0.9)
				end
			end
		elseif e.kind == "SpellRejected" then
			readyAt[e.spell or ""] = 0
			if e.reason and e.reason ~= "Cooling down" then
				NotificationController.Show("Info", tostring(e.reason))
			end
		elseif e.kind == "BurstCooldown" then
			local b = burstUi
			if b then
				pulse(b, Color3.fromRGB(255, 80, 70))
			end
			if e.reason then
				NotificationController.Show("Info", tostring(e.reason))
			end
		end
	end)
	RunService.Heartbeat:Connect(updateBar)
end

return SpellController
