--!strict
-- EffectsController: client-side combat feedback. Pure presentation; never decides outcomes.
--   * floating damage numbers + outcome words (PARRY!, BLOCK, DODGE, POSTURE BROKEN)
--   * white hit flash, parry spark burst, camera shake when you are hit / parry / break
--   * enemy windup telegraphs: white flash, or red flash + "!" for perilous (dodge-only) attacks
--   * health + posture bars over enemies (bosses use the HUD boss bar instead)
--   * other players' swings animated through AnimationController; swing/hit sounds
--
-- API:
--   EffectsController.ModelFor(combatantId) -> Model?

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local FormatNumber = require(Shared:WaitForChild("FormatNumber"))
local EffectsConfig = require(Config:WaitForChild("EffectsConfig"))
local AnimationConfig = require(Config:WaitForChild("AnimationConfig"))
local CombatConfig = require(Config:WaitForChild("CombatConfig"))

local CombatController = require(script.Parent.CombatController)
local HUDController = require(script.Parent.HUDController)
local DataController = require(script.Parent.DataController)
local Fx = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Fx"))
local AnimationController = require(script.Parent.AnimationController)

local EffectsController = { Name = "EffectsController", Priority = 25 }

local COMBATANT_TAG = "Combatant"
local localPlayer = Players.LocalPlayer
local byId: { [string]: Model } = {}
local lastLevel: number? = nil

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

function EffectsController.ModelFor(id: string?): Model?
	if id == nil then
		return nil
	end
	local m = byId[id]
	if m and m.Parent then
		return m
	end
	return nil
end

local function anchorPart(model: Model): BasePart?
	local p = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if p and p:IsA("BasePart") then
		return p
	end
	return nil
end

local function isLocal(model: Model?): boolean
	return model ~= nil and model == localPlayer.Character
end

-- Sounds -------------------------------------------------------------------------------------
local function playSound(id: string, at: BasePart?, pitch: number?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = EffectsConfig.Sounds.volume
	s.PlaybackSpeed = (pitch or 1) * (0.92 + math.random() * 0.16)
	s.Parent = at or workspace
	s:Play()
	Debris:AddItem(s, 3)
end

-- Camera shake -------------------------------------------------------------------------------
local shakeUntil = 0
local shakeStrength = 0
local function shake(strength: number)
	shakeStrength = math.max(shakeStrength, strength)
	shakeUntil = os.clock() + EffectsConfig.Shake.seconds
end

-- Floating text ------------------------------------------------------------------------------
local function floatText(part: BasePart, text: string, color: Color3, size: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, size + 10)
	gui.StudsOffset = Vector3.new((math.random() - 0.5) * 2, 2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	gui.Adornee = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = size
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Text = text
	label.Parent = gui
	gui.Parent = part
	local cfg = EffectsConfig.DamageNumber
	local info = TweenInfo.new(cfg.lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = gui.StudsOffset + Vector3.new(0, cfg.rise, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(cfg.lifetime * 0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, cfg.lifetime * 0.5), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(gui, cfg.lifetime + 0.1)
end

local function flash(model: Model, color: Color3, seconds: number, fillTransparency: number?)
	local h = Instance.new("Highlight")
	h.FillColor = color
	h.OutlineColor = color
	h.FillTransparency = fillTransparency or 0.35
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
	TweenService:Create(h, TweenInfo.new(seconds), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	Debris:AddItem(h, seconds + 0.05)
end

local function spark(part: BasePart, color: Color3)
	for _ = 1, 8 do
		local p = Instance.new("Part")
		p.Size = Vector3.new(0.15, 0.15, 0.9)
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		local dir = Vector3.new(math.random() - 0.5, math.random() - 0.2, math.random() - 0.5).Unit
		p.CFrame = CFrame.lookAt(part.Position, part.Position + dir)
		p.Parent = workspace
		TweenService:Create(p, TweenInfo.new(0.25), { CFrame = p.CFrame + dir * 3, Transparency = 1, Size = Vector3.new(0.05, 0.05, 0.3) }):Play()
		Debris:AddItem(p, 0.3)
	end
end

-- Enemy bars ---------------------------------------------------------------------------------
local function attachBars(model: Model)
	if Players:GetPlayerFromCharacter(model) or model:GetAttribute("CombatantKind") == "Boss" then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local part = anchorPart(model)
	if humanoid == nil or part == nil then
		return
	end
	local cfg = EffectsConfig.Bars
	local gui = Instance.new("BillboardGui")
	gui.Name = "CombatBars"
	gui.Size = UDim2.fromOffset(cfg.width, 34)
	gui.StudsOffset = Vector3.new(0, cfg.offsetY, 0)
	gui.MaxDistance = cfg.maxDistance
	gui.AlwaysOnTop = true
	gui.Adornee = part
	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0, 14)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextSize = 13
	name.TextColor3 = Color3.fromRGB(240, 230, 215)
	name.TextStrokeTransparency = 0.3
	name.Text = model.Name
	name.Parent = gui
	local function bar(y: number, color: { number }): Frame
		local back = Instance.new("Frame")
		back.Position = UDim2.fromOffset(0, y)
		back.Size = UDim2.new(1, 0, 0, cfg.height - (if y > 20 then 4 else 0))
		back.BackgroundColor3 = Color3.fromRGB(20, 18, 22)
		back.BorderSizePixel = 0
		back.Parent = gui
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = rgb(color)
		fill.BorderSizePixel = 0
		fill.Parent = back
		return fill
	end
	local hp = bar(15, cfg.health)
	local posture = bar(15 + cfg.height + 2, cfg.posture)
	local function refresh()
		hp.Size = UDim2.fromScale(math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1), 1)
		local p = tonumber(model:GetAttribute("Posture")) or 0
		posture.Size = UDim2.fromScale(math.clamp(p, 0, 1), 1)
		gui.Enabled = humanoid.Health > 0
	end
	humanoid.HealthChanged:Connect(refresh)
	model:GetAttributeChangedSignal("Posture"):Connect(refresh)
	refresh()
	gui.Parent = part
end

local function track(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local id = model:GetAttribute("CombatantId")
	if type(id) == "string" then
		byId[id] = model
	end
	model:GetAttributeChangedSignal("CombatantId"):Connect(function()
		local newId = model:GetAttribute("CombatantId")
		if type(newId) == "string" then
			byId[newId] = model
		end
	end)
	task.defer(attachBars, model)
	-- Enemies dissolve into embers when they die.
	if Players:GetPlayerFromCharacter(model) == nil then
		task.defer(function()
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Died:Connect(function()
					Fx.Dissolve(model, rgb(EffectsConfig.Death.color), EffectsConfig.Death.seconds)
				end)
			end
		end)
	end
end

-- Event handlers -----------------------------------------------------------------------------
local function onDamage(e: { [string]: any })
	local target = EffectsController.ModelFor(e.targetId)
	local part = target and anchorPart(target)
	if target == nil or part == nil then
		return
	end
	local source = EffectsController.ModelFor(e.sourceId)
	local mine = isLocal(target)
	local fromMe = isLocal(source)
	local outcome = EffectsConfig.Outcome[e.outcome] or EffectsConfig.Outcome.Hit
	if e.outcome == "Hit" or e.outcome == "Blocked" then
		if (e.damage or 0) > 0 then
			local cfg = EffectsConfig.DamageNumber
			local color = if mine then rgb(EffectsConfig.Outcome.TakenHit.color) else rgb(outcome.color)
			local size = if e.damage >= cfg.bigHitThreshold then cfg.bigHitSize else cfg.size
			floatText(part, FormatNumber.Short(math.floor(e.damage + 0.5)), color, size)
		end
		if e.outcome == "Blocked" then
			floatText(part, outcome.text :: string, rgb(outcome.color), 18)
		end
		flash(target, rgb(EffectsConfig.HitFlash.color), EffectsConfig.HitFlash.seconds)
		playSound(EffectsConfig.Sounds.hit, part, 0.7)
		local sparkColor = if e.outcome == "Blocked" then rgb(EffectsConfig.Guard.color) elseif mine then Color3.fromRGB(255, 90, 70) else rgb(EffectsConfig.Sparks.color)
		Fx.Burst(part.Position, { color = sparkColor, count = if (e.damage or 0) >= EffectsConfig.DamageNumber.bigHitThreshold then 28 else 14, speed = 22, size = 0.45, lifetime = 0.35 })
		if fromMe then
			AnimationController.HitStop(EffectsConfig.HitStop.hit, 0.15)
			HUDController.ComboHit()
			if e.riposte then
				AnimationController.HitStop(EffectsConfig.HitStop.riposte, 0.08)
				Fx.CenterText("RIPOSTE", rgb(EffectsConfig.Riposte.color), 54, 0.6)
				Fx.Burst(part.Position, { texture = Fx.Textures.Fire, color = rgb(EffectsConfig.Riposte.color), count = 40, speed = 34, size = 1.1, lifetime = 0.55 })
				Fx.Shockwave(part.Position - Vector3.new(0, 2, 0), rgb(EffectsConfig.Riposte.color), 12, 0.35)
				Fx.CameraPunch(EffectsConfig.Shake.bigHitFov * 1.5)
			end
		end
		Fx.LightFlash(part.Position, sparkColor, 10, 0.15)
		if fromMe and (e.damage or 0) >= EffectsConfig.DamageNumber.bigHitThreshold then
			Fx.CameraPunch(EffectsConfig.Shake.bigHitFov)
		end
		if mine then
			shake(EffectsConfig.Shake.takenHit)
		end
	elseif e.outcome == "Parried" then
		floatText(part, outcome.text :: string, rgb(outcome.color), 30)
		spark(part, rgb(outcome.color))
		playSound(EffectsConfig.Sounds.parry, part, 1.6)
		Fx.Glint(part.Position, rgb(outcome.color))
		Fx.Burst(part.Position, { color = rgb(outcome.color), count = 36, speed = 30, size = 0.6, lifetime = 0.45 })
		Fx.Shockwave(part.Position - Vector3.new(0, 2, 0), rgb(outcome.color), 8, 0.3)
		if mine then
			-- Perfect parry: freeze-frame, drained colors, radial streaks, DEFLECT stamp.
			AnimationController.HitStop(EffectsConfig.HitStop.parry, 0.05)
			Fx.ColorPulse(-0.7, 0.35, Color3.fromRGB(255, 240, 210), 0.45)
			Fx.Streaks(rgb(outcome.color), 22, 0.35)
			Fx.CenterText("DEFLECT", rgb(outcome.color), 64, 0.45)
			Fx.ScreenFlash(Color3.new(1, 1, 1), 0.35, 0.18)
			Fx.CameraPunch(-EffectsConfig.Shake.bigHitFov * 1.5)
			Fx.Pillar(part.Position - Vector3.new(0, 2.5, 0), rgb(outcome.color), 14)
			HUDController.ComboHit()
		end
		if mine or fromMe then
			shake(EffectsConfig.Shake.parry)
		end
	elseif e.outcome == "Dodged" then
		floatText(part, outcome.text :: string, rgb(outcome.color), 20)
	end
	if e.broken then
		local b = EffectsConfig.Outcome.Broken
		floatText(part, b.text :: string, rgb(b.color), 26)
		flash(target, rgb(b.color), 0.5, 0.2)
		Fx.Shockwave(part.Position - Vector3.new(0, 2.5, 0), rgb(b.color), 14, 0.45)
		Fx.Burst(part.Position, { texture = Fx.Textures.Fire, color = rgb(b.color), count = 30, speed = 16, size = 1, lifetime = 0.7 })
		if mine or fromMe then
			shake(EffectsConfig.Shake.broken)
		end
	end
end

local function weaponPoint(model: Model, name: string): Vector3?
	local held = model:FindFirstChild("HeldWeapon")
	local handle = held and held:FindFirstChild("Handle")
	local att = handle and handle:FindFirstChild(name)
	if att and att:IsA("Attachment") then
		return att.WorldPosition
	end
	return nil
end

local function onTelegraph(e: { [string]: any })
	local model = EffectsController.ModelFor(e.sourceId)
	if model == nil then
		return
	end
	local windup = math.max(0.15, tonumber(e.windup) or 0.4)
	local active = math.max(0.08, tonumber(e.active) or 0.2)
	local recovery = math.max(0.1, tonumber(e.recovery) or 0.4)
	local color = rgb(if e.perilous then AnimationConfig.PerilousColor else AnimationConfig.TelegraphColor)
	flash(model, color, windup, if e.perilous then 0.15 else 0.6)
	local part = anchorPart(model)
	if e.perilous and part then
		floatText(part, "!", color, 46)
	end
	-- Swing the rig + weapon with the server's exact timing (the hit lands at windup end).
	local action = if e.perilous then "HeavyAttack" elseif math.random() < 0.5 then "LightAttack" else "AltAttack"
	AnimationController.Play(model, action, nil, { windup = windup, active = active, recovery = recovery })
	-- Parry cue: the blade glints exactly when a press of F would land inside the parry window.
	local glintAt = math.max(0, windup - CombatConfig.ParryWindow * 0.8)
	task.delay(glintAt, function()
		if model.Parent == nil then
			return
		end
		local where = weaponPoint(model, "Glint") or (part and part.Position)
		if where then
			Fx.Glint(where, if e.perilous then rgb(AnimationConfig.PerilousColor) else rgb(EffectsConfig.Glint.color))
			playSound(EffectsConfig.Sounds.parry, part, if e.perilous then 0.6 else 2.2)
		end
	end)
end

local function onFlinch(e: { [string]: any })
	local model = EffectsController.ModelFor(e.sourceId)
	if model == nil then
		return
	end
	AnimationController.Play(model, "Flinch", nil, { windup = 0.08, active = 0.12, recovery = 0.2 })
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		Fx.Burst(root.Position - Vector3.new(0, 2.5, 0), { texture = Fx.Textures.Smoke, color = Color3.fromRGB(170, 160, 150), count = 6, speed = 4, size = 1.5, lifetime = 0.5, lightEmission = 0, acceleration = Vector3.new(0, 2, 0) })
	end
end

local function onGuard(e: { [string]: any })
	local model = EffectsController.ModelFor(e.sourceId)
	if model == nil then
		return
	end
	local seconds = tonumber(e.seconds) or 1
	AnimationController.Play(model, "Parry", nil, { windup = 0.08, active = seconds, recovery = 0.15 })
	local h = Instance.new("Highlight")
	h.FillColor = rgb(EffectsConfig.Guard.color)
	h.OutlineColor = rgb(EffectsConfig.Guard.color)
	h.FillTransparency = 0.75
	h.OutlineTransparency = 0.2
	h.Parent = model
	Debris:AddItem(h, seconds)
	local part = anchorPart(model)
	if part then
		floatText(part, "GUARD", rgb(EffectsConfig.Guard.color), 18)
	end
end

local function onAction(e: { [string]: any })
	local model = EffectsController.ModelFor(e.sourceId)
	if model == nil or isLocal(model) then
		return -- own character already animated by CombatController prediction
	end
	AnimationController.Play(model, e.action, e.moveId, nil, e.route, tonumber(e.speed))
	local part = anchorPart(model)
	if e.moveId and part then
		playSound(if e.action == "HeavyAttack" then EffectsConfig.Sounds.heavy else EffectsConfig.Sounds.swing, part)
	end
end

function EffectsController.Init() end

function EffectsController.Start()
	for _, m in CollectionService:GetTagged(COMBATANT_TAG) do
		track(m)
	end
	CollectionService:GetInstanceAddedSignal(COMBATANT_TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(COMBATANT_TAG):Connect(function(m: Instance)
		local id = m:GetAttribute("CombatantId")
		if type(id) == "string" and byId[id] == (m :: any) then
			byId[id] = nil
		end
	end)

	CombatController.EventReceived:Connect(function(e)
		if e.kind == "Damage" then
			onDamage(e)
		elseif e.kind == "Telegraph" then
			onTelegraph(e)
		elseif e.kind == "Action" then
			onAction(e)
		elseif e.kind == "Flinch" then
			onFlinch(e)
		elseif e.kind == "Stagger" then
			local model = EffectsController.ModelFor(e.sourceId)
			local part = model and anchorPart(model)
			if model and part then
				local seconds = math.max(0.4, tonumber(e.seconds) or 0.7)
				AnimationController.Play(model, "Stagger", nil, { windup = 0.08, active = seconds - 0.25, recovery = 0.2 })
				floatText(part, "STAGGERED", rgb(EffectsConfig.Riposte.color), 24)
				flash(model, rgb(EffectsConfig.Riposte.color), seconds, 0.5)
			end
		elseif e.kind == "Guard" then
			onGuard(e)
		end
	end)

	CombatController.LocalAction:Connect(function(action, moveId, route)
		local ch = localPlayer.Character
		local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
		if route and hrp and hrp:IsA("BasePart") then
			local c = rgb(EffectsConfig.Routes[route] or EffectsConfig.Ultimate.color)
			Fx.Burst(hrp.Position, { color = c, count = 16, speed = 16, size = 0.5, lifetime = 0.35 })
			if route == "Finisher" then
				Fx.Shockwave(hrp.Position - Vector3.new(0, 2.5, 0), c, 9, 0.35)
			end
		end
		local character = localPlayer.Character
		local part = character and anchorPart(character)
		if moveId and part then
			playSound(if action == "HeavyAttack" then EffectsConfig.Sounds.heavy else EffectsConfig.Sounds.swing, part)
		end
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			if action == "Dodge" then
				Fx.Burst(root.Position - Vector3.new(0, 2.5, 0), { texture = Fx.Textures.Smoke, color = Color3.fromRGB(200, 195, 185), count = 10, speed = 6, size = 2, lifetime = 0.6, lightEmission = 0, acceleration = Vector3.new(0, 3, 0) })
			elseif action == "Ultimate" then
				Fx.ScreenFlash(rgb(EffectsConfig.Ultimate.color), 0.35, 0.4)
				Fx.Shockwave(root.Position - Vector3.new(0, 2.5, 0), rgb(EffectsConfig.Ultimate.color), 18, 0.6)
				Fx.Pillar(root.Position - Vector3.new(0, 2.5, 0), rgb(EffectsConfig.Ultimate.color), 24)
				Fx.CameraPunch(EffectsConfig.Shake.bigHitFov * 2)
			elseif action == "Parry" then
				Fx.Burst(root.Position + root.CFrame.LookVector * 2, { color = rgb(EffectsConfig.Guard.color), count = 6, speed = 6, size = 0.4, lifetime = 0.25 })
			end
		end
	end)

	-- Level up: pillar of light on your character.
	DataController.Changed:Connect(function(key, value)
		if key == "level" and lastLevel and value > lastLevel then
			local character = localPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				Fx.Pillar(root.Position - Vector3.new(0, 2.5, 0), rgb(EffectsConfig.LevelUp.color), 40)
				Fx.ScreenFlash(rgb(EffectsConfig.LevelUp.color), 0.2, 0.5)
			end
		end
		if key == "level" then
			lastLevel = value
		end
	end)

	-- Camera shake: offset the camera slightly each frame while shaking.
	game:GetService("RunService"):BindToRenderStep("WraithsteelShake", Enum.RenderPriority.Camera.Value + 1, function()
		if os.clock() < shakeUntil then
			local cam = workspace.CurrentCamera
			local s = shakeStrength
			cam.CFrame = cam.CFrame * CFrame.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
		else
			shakeStrength = 0
		end
	end)
end

return EffectsController
