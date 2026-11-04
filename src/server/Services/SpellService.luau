--!strict
-- SpellService: Qi arts (SpellConfig), server-authoritative.
-- Clients send CastSpell(spellId, aim?, point?) - only a direction and a desired target point.
-- The server checks the slot, level, cooldown and Qi (Logic/SpellLogic), clamps the target to
-- the spell's range, finds victims from server positions and applies hits via CombatService.
-- Every client gets a "Spell" CombatEvent to draw it (UI/SpellFx); the caster also gets the
-- cooldown. Qi is mirrored to the character as attributes Qi / QiMax for the HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local SpellConfig = require(Config:WaitForChild("SpellConfig"))

local Logic = script.Parent.Parent:WaitForChild("Logic")
local CombatRules = require(Logic:WaitForChild("CombatRules"))
local SpellLogic = require(Logic:WaitForChild("SpellLogic"))

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local CombatService = require(script.Parent.CombatService)

type Combatant = CombatService.Combatant

local SpellService = { Name = "SpellService", Priority = 32 }

local states: { [Player]: SpellLogic.State } = {}
local owners: { [Player]: Combatant } = {} -- combatant the state belongs to (reset on respawn)
local rng = Random.new()

local function stateFor(player: Player, c: Combatant): SpellLogic.State
	local st = states[player]
	if st == nil or owners[player] ~= c then
		st = SpellLogic.NewState()
		states[player] = st
		owners[player] = c
		c.model:SetAttribute("QiMax", SpellConfig.Qi.max)
	end
	return st
end

local function syncQi(c: Combatant, st: SpellLogic.State)
	c.model:SetAttribute("Qi", math.floor(st.qi))
end

local function enemies(): { Combatant }
	local out = {}
	for _, c in CombatService.All() do
		if c.team == "Enemies" and not c.dead and c.humanoid.Health > 0 then
			table.insert(out, c)
		end
	end
	return out
end

local function inRadius(center: Vector3, radius: number): { Combatant }
	local out = {}
	for _, c in enemies() do
		local d = c.root.Position - center
		if Vector3.new(d.X, 0, d.Z).Magnitude <= radius and math.abs(d.Y) < 16 then
			table.insert(out, c)
		end
	end
	return out
end

local function inCorridor(origin: Vector3, dir: Vector3, length: number, width: number): { Combatant }
	local out = {}
	for _, c in enemies() do
		local p = c.root.Position
		if math.abs(p.Y - origin.Y) < 14 and SpellLogic.InCorridor(origin.X, origin.Z, dir.X, dir.Z, length, width, p.X, p.Z) then
			table.insert(out, c)
		end
	end
	return out
end

local function sanitizeDir(v: Vector3?, fallback: Vector3): Vector3
	if v then
		local flat = Vector3.new(v.X, 0, v.Z)
		if flat.Magnitude > 0.5 and flat.Magnitude < 1.5 then
			return flat.Unit
		end
	end
	local f = Vector3.new(fallback.X, 0, fallback.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.zAxis
end

local function hitAll(player: Player, caster: Combatant, spellId: string, victims: { Combatant }, mult: number?)
	local spell = SpellConfig.Spells[spellId]
	local power = ProgressionService.GetPower(player)
	local stats = CombatService.PlayerStats(player)
	local attack = (1 + (stats.Attack or 0)) * (1 + (stats.ArtPower or 0))
	for _, v in victims do
		local critMult, crit = CombatService.RollCrit(player)
		CombatService.ApplyHit(caster, v, {
			damage = CombatRules.ScaleDamage(spell.damage or 0, power, rng:NextNumber()) * attack * critMult * (mult or 1),
			postureDamage = (spell.posture or 0) * (mult or 1),
			moveId = "spell_" .. spellId,
			knockback = spell.knockback,
			launch = spell.launch,
			crit = crit,
			source = "spell",
			color = spell.color,
		})
	end
end

local function onCast(player: Player, spellId: string, aim: Vector3?, point: Vector3?)
	local c = CombatService.GetByPlayer(player)
	local data = DataService.GetData(player)
	if c == nil or data == nil or c.dead or c.humanoid.Health <= 0 or c.duelId ~= nil then
		return -- (no Qi arts in duels: PvpConfig)
	end
	local now = os.clock()
	local rules = c.rules
	if rules and now < rules.stunnedUntil then
		Net.Server.Fire("CombatEvent", player, { kind = "SpellRejected", spell = spellId, reason = "Stunned" })
		return
	end
	local st = stateFor(player, c)
	local ok, reason = SpellLogic.CanCast(st, data.spellLoadout, data.level, spellId, now, data.skills)
	if not ok then
		Net.Server.Fire("CombatEvent", player, { kind = "SpellRejected", spell = spellId, reason = reason })
		return
	end
	local stats = CombatService.PlayerStats(player)
	local cooldown = SpellLogic.Commit(st, spellId, now, stats.Haste or 0)
	syncQi(c, st)

	local spell = SpellConfig.Spells[spellId]
	local root = c.root
	local origin = root.Position
	local dir = sanitizeDir(aim, root.CFrame.LookVector)
	local range = spell.range or 30
	-- Target point: the client's choice, clamped to range; default straight ahead.
	local target = origin + dir * range * 0.6
	if point and (point - origin).Magnitude < range * 3 then
		local x, z = SpellLogic.ClampPoint(origin.X, origin.Z, point.X, point.Z, range)
		target = Vector3.new(x, point.Y, z)
	end
	local event: { [string]: any } = {
		kind = "Spell",
		spell = spellId,
		sourceId = c.id,
		userId = player.UserId,
		origin = origin,
		dir = dir,
		point = target,
		cooldown = cooldown,
	}

	local function iframes(seconds: number?)
		local r = c.rules
		if r and seconds then
			r.iframeUntil = math.max(r.iframeUntil, now + seconds)
		end
	end
	if spell.kind == "Flurry" then
		-- Flash to the target (the client moves you) and carve everything around it.
		iframes(spell.iframes)
		Net.Server.FireAll("CombatEvent", event)
		task.spawn(function()
			task.wait(0.12)
			for _ = 1, spell.ticks or 10 do
				if c.dead then
					break
				end
				hitAll(player, c, spellId, inRadius(target, spell.radius or 9))
				task.wait(spell.interval or 0.08)
			end
		end)
	elseif spell.kind == "Blink" then
		-- The caster's client moves the character (it owns its physics); the server cuts the path.
		iframes(spell.iframes or 0.3)
		event.point = origin + dir * range
		Net.Server.FireAll("CombatEvent", event)
		hitAll(player, c, spellId, inCorridor(origin, dir, range, spell.width or 5))
	elseif spell.kind == "SlashWave" then
		-- A flying crescent: each enemy in the line is cut when the wave reaches it.
		Net.Server.FireAll("CombatEvent", event)
		for _, v in inCorridor(origin, dir, range, spell.width or 5) do
			local along = math.max(0, (v.root.Position - origin):Dot(dir))
			task.delay(along / (spell.speed or 120), function()
				if not v.dead then
					hitAll(player, c, spellId, { v })
				end
			end)
		end
	elseif spell.kind == "Fissure" then
		Net.Server.FireAll("CombatEvent", event)
		task.delay(spell.delay or 0.25, function()
			hitAll(player, c, spellId, inCorridor(origin, dir, range, spell.width or 5))
		end)
	elseif spell.kind == "Rising" then
		iframes(spell.iframes)
		Net.Server.FireAll("CombatEvent", event)
		hitAll(player, c, spellId, inRadius(origin, spell.radius or 10))
	elseif spell.kind == "Storm" then
		Net.Server.FireAll("CombatEvent", event)
		task.spawn(function()
			for _ = 1, spell.ticks or 5 do
				if c.dead then
					break
				end
				hitAll(player, c, spellId, inRadius(c.root.Position, spell.radius or 12))
				task.wait(spell.interval or 0.3)
			end
		end)
	elseif spell.kind == "Chain" then
		-- Pick up to `count` enemies near you (nearest first, each hop from the last one) and cut
		-- them one after another; the caster's client blinks along the same points.
		iframes(spell.iframes)
		local pool = inRadius(origin, range)
		local order: { Combatant } = {}
		local from = origin
		while #order < (spell.count or 5) and #pool > 0 do
			local bi, bd = 1, math.huge
			for i, v in pool do
				local d = (v.root.Position - from).Magnitude
				if d < bd then
					bi, bd = i, d
				end
			end
			local v = table.remove(pool, bi) :: Combatant
			table.insert(order, v)
			from = v.root.Position
		end
		local points = {}
		for _, v in order do
			table.insert(points, v.root.Position)
		end
		if #points == 0 then
			table.insert(points, origin + dir * math.min(range, 20))
		end
		event.points = points
		Net.Server.FireAll("CombatEvent", event)
		for i, v in order do
			task.delay(i * (spell.interval or 0.16), function()
				if not v.dead and not c.dead then
					hitAll(player, c, spellId, { v })
				end
			end)
		end
	elseif spell.kind == "SkyFall" then
		-- Leap up (client) and crash onto the target point.
		iframes(spell.iframes)
		Net.Server.FireAll("CombatEvent", event)
		task.delay(spell.delay or 0.8, function()
			hitAll(player, c, spellId, inRadius(target, spell.radius or 16))
		end)
	end
end

local function onSetSlot(player: Player, slot: number, spellId: string): (boolean, string?)
	local data = DataService.GetData(player)
	if data == nil then
		return false, "Loading..."
	end
	local ok, err = SpellLogic.SetLoadout(data.spellLoadout, slot, spellId, data.level, data.skills)
	if ok then
		DataService.Changed(player, "spellLoadout")
	end
	return ok, err
end

function SpellService.Init() end

function SpellService.Start()
	Net.Server.On("CastSpell", onCast)
	Net.Server.OnInvoke("SetSpellSlot", onSetSlot)

	-- Qi from fighting: hits you land and perfect parries.
	CombatService.Damaged:Connect(function(target: Combatant, attacker: Combatant?, res)
		if attacker and attacker.player and (res.outcome == "Hit" or res.outcome == "Blocked") then
			local st = stateFor(attacker.player, attacker)
			SpellLogic.AddQi(st, SpellConfig.Qi.onHit)
			syncQi(attacker, st)
		end
		if target.player and res.outcome == "Parried" then
			local st = stateFor(target.player, target)
			SpellLogic.AddQi(st, SpellConfig.Qi.onParry)
			syncQi(target, st)
		end
		-- Vanishing Step (skill): dodging through an attack restores Qi.
		if target.player and res.outcome == "Dodged" then
			local q = CombatService.PlayerStats(target.player).DodgeQi or 0
			if q > 0 then
				local st = stateFor(target.player, target)
				SpellLogic.AddQi(st, q)
				syncQi(target, st)
			end
		end
	end)

	CombatService.Died:Connect(function(target: Combatant, contributions: { [Player]: number })
		if target.team ~= "Enemies" then
			return
		end
		for player in contributions do
			local c = CombatService.GetByPlayer(player)
			if c and not c.dead then
				local st = stateFor(player, c)
				SpellLogic.AddQi(st, SpellConfig.Qi.onKill)
				syncQi(c, st)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		owners[player] = nil
	end)

	-- Regen at 5 Hz.
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		local step = acc
		acc = 0
		for _, player in Players:GetPlayers() do
			local c = CombatService.GetByPlayer(player)
			if c and not c.dead then
				local st = stateFor(player, c)
				if st.qi < SpellConfig.Qi.max then
					SpellLogic.Regen(st, step, CombatService.PlayerStats(player).QiRegen or 0)
					syncQi(c, st)
				elseif c.model:GetAttribute("Qi") == nil then
					syncQi(c, st)
				end
			end
		end
	end)
end

return SpellService
