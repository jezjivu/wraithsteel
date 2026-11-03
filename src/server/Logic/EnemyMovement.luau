--!strict
-- EnemyMovement: pure spacing rules for enemy AI (EnemyService turns them into MoveTo calls).
-- Works on plain numbers (x, z) so it is testable without the engine.
--
--   * Ring slots: enemies waiting for an attack token around the same player spread evenly
--     on a ring (one slot each) that slowly drifts, instead of all orbiting the same spot.
--   * Separation: allies closer than `radius` push each other apart (no stacking/clipping).
--   * Step back: after an attack, an enemy sometimes backs off to its ring before the next one,
--     which gives the player a readable rhythm (attack -> reset -> attack).
--   * Pack spacing: spawn points for a group keep `gap` studs between members.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("EnemyConfig"))

local EnemyMovement = {}

local TAU = math.pi * 2

-- Index of `id` among `ids` after sorting (stable slot order for everyone attacking a target).
function EnemyMovement.SlotIndex(id: string, ids: { string }): (number, number)
	local sorted = table.clone(ids)
	table.sort(sorted)
	local index = table.find(sorted, id) or 1
	return index, #sorted
end

-- Ring point for slot `index` of `count` around (tx, tz) at `range`. `phase` drifts over time;
-- `bias` is the angle from the target toward the enemy's own side so slots start near it.
function EnemyMovement.RingPoint(tx: number, tz: number, index: number, count: number, range: number, phase: number, bias: number): (number, number)
	local n = math.max(1, count)
	local spread = math.min(TAU / n, math.rad(EnemyConfig.Movement.maxSlotDegrees))
	-- Slots fan out around the bias direction (centered), so a pair flanks rather than circles.
	local angle = bias + phase + (index - (n + 1) / 2) * spread
	return tx + math.cos(angle) * range, tz + math.sin(angle) * range
end

-- Push (dx, dz) away from neighbours closer than `radius`. `others` = { {x, z}, ... }.
function EnemyMovement.Separation(x: number, z: number, others: { { number } }, radius: number): (number, number)
	local px, pz = 0, 0
	for _, o in others do
		local dx, dz = x - o[1], z - o[2]
		local d = math.sqrt(dx * dx + dz * dz)
		if d < radius then
			if d < 1e-3 then
				-- exactly on top of each other: push along a fixed axis
				dx, dz, d = 1, 0, 1
			end
			local strength = (radius - d) / radius
			px += dx / d * strength * radius
			pz += dz / d * strength * radius
		end
	end
	return px, pz
end

-- Where to stand when stepping back from (tx, tz) after an attack.
function EnemyMovement.StepBack(x: number, z: number, tx: number, tz: number, range: number): (number, number)
	local dx, dz = x - tx, z - tz
	local d = math.sqrt(dx * dx + dz * dz)
	if d < 1e-3 then
		dx, dz, d = 0, 1, 1
	end
	local back = range + EnemyConfig.Movement.stepBackExtra
	return tx + dx / d * back, tz + dz / d * back
end

-- Should this enemy back off after the attack it just finished? `roll` in [0, 1).
function EnemyMovement.WantsStepBack(attackers: number, roll: number): boolean
	local M = EnemyConfig.Movement
	-- More likely when others are waiting to attack: they take turns instead of piling in.
	local chance = M.stepBackChance + math.max(0, attackers - 1) * M.stepBackPerAlly
	return roll < math.min(M.stepBackMax, chance)
end

-- Spawn offsets for a pack: each new member at least `gap` from the others (best of `tries`).
-- `rand(lo, hi)` returns a number in [lo, hi].
function EnemyMovement.PackOffset(existing: { { number } }, scatter: number, gap: number, tries: number, rand: (number, number) -> number): (number, number)
	local bestX, bestZ, bestD = 0, 0, -1
	for _ = 1, tries do
		local x, z = rand(-scatter, scatter), rand(-scatter, scatter)
		local nearest = math.huge
		for _, o in existing do
			nearest = math.min(nearest, math.sqrt((x - o[1]) ^ 2 + (z - o[2]) ^ 2))
		end
		if nearest >= gap then
			return x, z
		end
		if nearest > bestD then
			bestX, bestZ, bestD = x, z, nearest
		end
	end
	return bestX, bestZ
end

-- Attack choice weight: against a player who is holding guard, perilous attacks (which a block
-- cannot stop) become likelier, so turtling is answered instead of rewarded.
function EnemyMovement.AttackWeight(weight: number, perilous: boolean, targetGuarding: boolean): number
	if targetGuarding and perilous then
		return weight * EnemyConfig.Movement.antiGuardWeight
	end
	return weight
end

return EnemyMovement
