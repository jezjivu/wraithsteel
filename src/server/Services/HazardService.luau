--!strict
-- HazardService: boss attacks that are not sword swings, simulated on the server.
--   * Projectile: flies in a straight line; hits the first player it reaches. Guard/deflect
--     works on it. A DEFLECTABLE projectile that you perfectly deflect flies back at its
--     owner and hits for big damage + posture.
--   * Wave: a shockwave ring expanding along the ground - jump over it (perilous Sweep).
--   * Rain: marked circles erupt after a delay - get out (perilous Grasp: dash i-frames work).
-- Clients only draw them (CombatEvent kinds HazardProjectile / HazardEnd / HazardWave /
-- HazardRain); every hit is decided here with server positions.
--
-- API:
--   HazardService.Projectile(owner, from, dir, spec)
--   HazardService.Wave(owner, origin, spec)
--   HazardService.Rain(owner, points, spec)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local CombatService = require(script.Parent.CombatService)

type Combatant = CombatService.Combatant

local HazardService = { Name = "HazardService", Priority = 26 }

export type ProjectileSpec = {
	speed: number,
	radius: number, -- hit radius (studs, added to a body radius)
	range: number,
	damage: number,
	posture: number,
	color: { number },
	size: number?, -- visual size
	deflectable: boolean?, -- perfect deflect sends it back
	reflectDamage: number?,
	reflectPosture: number?,
	moveId: string,
}

export type WaveSpec = { speed: number, maxRadius: number, band: number, damage: number, posture: number, color: { number }, moveId: string }
export type RainSpec = { radius: number, delay: number, damage: number, posture: number, color: { number }, moveId: string }

type Projectile = {
	id: number,
	owner: Combatant,
	pos: Vector3,
	vel: Vector3,
	travelled: number,
	spec: ProjectileSpec,
	reflected: boolean,
	reflector: Combatant?,
}

local BODY_RADIUS = 2.5
local projectiles: { [number]: Projectile } = {}
local nextId = 0

local function fire(payload: { [string]: any })
	Net.Server.FireAll("CombatEvent", payload)
end

local function spawnProjectile(owner: Combatant, from: Vector3, dir: Vector3, spec: ProjectileSpec, reflected: boolean, reflector: Combatant?)
	nextId += 1
	local unit = if dir.Magnitude > 1e-3 then dir.Unit else Vector3.zAxis
	local p: Projectile = {
		id = nextId,
		owner = owner,
		pos = from,
		vel = unit * spec.speed,
		travelled = 0,
		spec = spec,
		reflected = reflected,
		reflector = reflector,
	}
	projectiles[p.id] = p
	fire({
		kind = "HazardProjectile",
		id = p.id,
		from = from,
		velocity = p.vel,
		range = spec.range,
		color = spec.color,
		size = spec.size or 2,
		deflectable = spec.deflectable == true,
		reflected = reflected,
	})
end

function HazardService.Projectile(owner: Combatant, from: Vector3, dir: Vector3, spec: ProjectileSpec)
	spawnProjectile(owner, from, dir, spec, false, nil)
end

local function endProjectile(p: Projectile, at: Vector3, how: string)
	projectiles[p.id] = nil
	fire({ kind = "HazardEnd", id = p.id, pos = at, how = how, color = p.spec.color })
end

local function stepProjectiles(dt: number)
	for _, p in projectiles do
		local step = p.vel * dt
		local from = p.pos
		p.pos += step
		p.travelled += step.Magnitude
		if p.reflected then
			-- Flying back at the owner.
			local o = p.owner
			if o.dead then
				endProjectile(p, p.pos, "Fizzle")
				continue
			end
			local toOwner = o.root.Position - p.pos
			-- Gentle homing so a returned orb always lands.
			p.vel = p.vel:Lerp(toOwner.Unit * p.vel.Magnitude, math.min(1, dt * 6))
			if toOwner.Magnitude <= p.spec.radius + BODY_RADIUS * 2 then
				endProjectile(p, p.pos, "Impact")
				local reflector = p.reflector
				CombatService.ApplyHit(reflector, o, {
					damage = p.spec.reflectDamage or p.spec.damage * 3,
					postureDamage = p.spec.reflectPosture or p.spec.posture * 3,
					moveId = "reflect_" .. p.spec.moveId,
					knockback = 20,
					source = "reflect",
					color = p.spec.color,
				})
			elseif p.travelled > p.spec.range * 2 then
				endProjectile(p, p.pos, "Fizzle")
			end
			continue
		end
		-- Hit the first player along the segment.
		local hit: Combatant? = nil
		for _, player in Players:GetPlayers() do
			local pc = CombatService.GetByPlayer(player)
			if pc and not pc.dead then
				local rp = pc.root.Position
				-- Distance from the body to the segment travelled this frame.
				local ab = p.pos - from
				local t = if ab.Magnitude > 1e-4 then math.clamp((rp - from):Dot(ab) / ab:Dot(ab), 0, 1) else 0
				local closest = from + ab * t
				if (rp - closest).Magnitude <= p.spec.radius + BODY_RADIUS then
					hit = pc
					break
				end
			end
		end
		if hit then
			local res = CombatService.ApplyHit(p.owner, hit, {
				damage = p.spec.damage,
				postureDamage = p.spec.posture,
				moveId = p.spec.moveId,
				knockback = 14,
				ranged = true,
				color = p.spec.color,
			})
			if res and res.outcome == "Parried" and p.spec.deflectable then
				-- Perfect deflect: the orb goes back where it came from.
				endProjectile(p, p.pos, "Reflected")
				spawnProjectile(p.owner, hit.root.Position + Vector3.new(0, 1, 0), p.owner.root.Position - hit.root.Position, {
					speed = p.spec.speed * 1.7,
					radius = p.spec.radius,
					range = p.spec.range,
					damage = p.spec.damage,
					posture = p.spec.posture,
					color = { 255, 240, 200 },
					size = p.spec.size,
					reflectDamage = p.spec.reflectDamage,
					reflectPosture = p.spec.reflectPosture,
					moveId = p.spec.moveId,
				}, true, hit)
				fire({ kind = "Returned", targetId = hit.id })
			elseif res and (res.outcome == "Parried" or res.outcome == "Blocked") then
				endProjectile(p, p.pos, "Blocked")
			elseif res and res.outcome == "Dodged" then
				-- Dodged through: it keeps flying.
				continue
			else
				endProjectile(p, p.pos, "Impact")
			end
		elseif p.travelled >= p.spec.range then
			endProjectile(p, p.pos, "Fizzle")
		end
	end
end

function HazardService.Wave(owner: Combatant, origin: Vector3, spec: WaveSpec)
	fire({ kind = "HazardWave", origin = origin, speed = spec.speed, maxRadius = spec.maxRadius, color = spec.color })
	local hitSet: { [Combatant]: boolean } = {}
	local start = os.clock()
	task.spawn(function()
		while true do
			local r = (os.clock() - start) * spec.speed
			if r > spec.maxRadius or owner.dead then
				break
			end
			for _, player in Players:GetPlayers() do
				local pc = CombatService.GetByPlayer(player)
				if pc and not pc.dead and not hitSet[pc] then
					local d = pc.root.Position - origin
					local flat = Vector3.new(d.X, 0, d.Z).Magnitude
					if math.abs(flat - r) <= spec.band and math.abs(d.Y) < 12 then
						hitSet[pc] = true
						CombatService.ApplyHit(owner, pc, {
							damage = spec.damage,
							postureDamage = spec.posture,
							perilous = true,
							perilousKind = "Sweep",
							moveId = spec.moveId,
							knockback = 24,
							launch = 10,
							ranged = true,
							color = spec.color,
						})
					end
				end
			end
			task.wait(0.03)
		end
	end)
end

function HazardService.Rain(owner: Combatant, points: { Vector3 }, spec: RainSpec)
	fire({ kind = "HazardRain", points = points, radius = spec.radius, delay = spec.delay, color = spec.color })
	task.delay(spec.delay, function()
		if owner.dead then
			return
		end
		local hitSet: { [Combatant]: boolean } = {}
		for _, at in points do
			for _, player in Players:GetPlayers() do
				local pc = CombatService.GetByPlayer(player)
				if pc and not pc.dead and not hitSet[pc] then
					local d = pc.root.Position - at
					if Vector3.new(d.X, 0, d.Z).Magnitude <= spec.radius and math.abs(d.Y) < 10 then
						hitSet[pc] = true
						CombatService.ApplyHit(owner, pc, {
							damage = spec.damage,
							postureDamage = spec.posture,
							perilous = true,
							perilousKind = "Grasp",
							moveId = spec.moveId,
							launch = 30,
							ranged = true,
							color = spec.color,
						})
					end
				end
			end
		end
	end)
end

function HazardService.Init() end

function HazardService.Start()
	RunService.Heartbeat:Connect(function(dt)
		if next(projectiles) then
			local ok, err = pcall(stepProjectiles :: any, dt)
			if not ok then
				warn("[HazardService]", err)
			end
		end
	end)
end

return HazardService
