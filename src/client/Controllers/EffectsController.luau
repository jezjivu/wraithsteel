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

local CombatController = require(script.Parent.CombatController)
local AnimationController = require(script.Parent.AnimationController)

local EffectsController = { Name = "EffectsController", Priority = 25 }

local COMBATANT_TAG = "Combatant"
local localPlayer = Players.LocalPlayer
local byId: { [string]: Model } = {}

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
		if mine then
			shake(EffectsConfig.Shake.takenHit)
		end
	elseif e.outcome == "Parried" then
		floatText(part, outcome.text :: string, rgb(outcome.color), 30)
		spark(part, rgb(outcome.color))
		playSound(EffectsConfig.Sounds.parry, part, 1.6)
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
		if mine or fromMe then
			shake(EffectsConfig.Shake.broken)
		end
	end
end

local function onTelegraph(e: { [string]: any })
	local model = EffectsController.ModelFor(e.sourceId)
	if model == nil then
		return
	end
	local color = rgb(if e.perilous then AnimationConfig.PerilousColor else AnimationConfig.TelegraphColor)
	flash(model, color, math.max(0.2, tonumber(e.windup) or 0.4), if e.perilous then 0.15 else 0.55)
	local part = anchorPart(model)
	if e.perilous and part then
		floatText(part, "!", color, 46)
	end
	-- Rigged enemies (once real rigs exist) also get a procedural wind-up pose.
	local windup = math.max(0.15, tonumber(e.windup) or 0.4)
	AnimationController.Play(model, if e.perilous then "HeavyAttack" else "LightAttack", nil, { windup = windup, active = 0.2, recovery = 0.4 })
end

local function onAction(e: { [string]: any })
	local model = EffectsController.ModelFor(e.sourceId)
	if model == nil or isLocal(model) then
		return -- own character already animated by CombatController prediction
	end
	AnimationController.Play(model, e.action, e.moveId)
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
		end
	end)

	CombatController.LocalAction:Connect(function(action, moveId)
		local character = localPlayer.Character
		local part = character and anchorPart(character)
		if moveId and part then
			playSound(if action == "HeavyAttack" then EffectsConfig.Sounds.heavy else EffectsConfig.Sounds.swing, part)
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
