-- Tests for Logic/EnemyMovement (fight spacing) and the valley's spawn layout / clutter.
local RS = game:GetService("ReplicatedStorage")
local EnemyMovement = require(game:GetService("ServerScriptService").Logic.EnemyMovement)
local EnemyConfig = require(RS.Config.EnemyConfig)
local MapConfig = require(RS.Config.MapConfig)

local cases = {}

local function dist(ax, az, bx, bz)
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

cases["Spawns: ground groups stay far apart, sentries clear of groups"] = function()
	local day = {}
	for _, s in MapConfig.EnemySpawns do
		if not s.night then
			table.insert(day, s)
		end
	end
	for i = 1, #day do
		for j = i + 1, #day do
			local a, b = day[i], day[j]
			local limit = if a.lookout or b.lookout then MapConfig.MinSentryGap else MapConfig.MinSpawnGap
			local d = dist(a.at[1], a.at[2], b.at[1], b.at[2])
			expectTrue(d >= limit, string.format("%s - %s only %.0f studs apart", a.name, b.name, d))
		end
	end
end

cases["Clutter: far fewer torii than before"] = function()
	expectTrue(MapConfig.Clutter.toriiRoadCount <= 6)
	expectTrue(MapConfig.Clutter.gatesPerZone <= 1)
end

cases["Ring slots: distinct, on the ring, symmetric"] = function()
	local range = 10
	for count = 1, 5 do
		local pts = {}
		for i = 1, count do
			local x, z = EnemyMovement.RingPoint(0, 0, i, count, range, 0.3, 0)
			expectNear(dist(x, z, 0, 0), range, 1e-6)
			table.insert(pts, { x, z })
		end
		for i = 1, count do
			for j = i + 1, count do
				expectTrue(dist(pts[i][1], pts[i][2], pts[j][1], pts[j][2]) > 4, "slots must not overlap")
			end
		end
	end
	local a = EnemyMovement.SlotIndex("E2", { "E9", "E2", "E5" })
	expectEq(a, 1)
	local b, n = EnemyMovement.SlotIndex("E9", { "E9", "E2", "E5" })
	expectEq(b, 3)
	expectEq(n, 3)
end

cases["Separation pushes stacked allies apart, ignores far ones"] = function()
	local r = EnemyConfig.Movement.separationRadius
	local px, pz = EnemyMovement.Separation(0, 0, { { 2, 0 } }, r)
	expectTrue(px < 0 and math.abs(pz) < 1e-9, "pushed away from the ally")
	local fx, fz = EnemyMovement.Separation(0, 0, { { r + 1, 0 } }, r)
	expectEq(fx, 0)
	expectEq(fz, 0)
	local sx = EnemyMovement.Separation(0, 0, { { 0, 0 } }, r)
	expectTrue(sx ~= 0, "exact overlap still separates")
end

cases["Step back: away from the target, more likely in a crowd"] = function()
	local x, z = EnemyMovement.StepBack(0, 5, 0, 0, 8)
	expectNear(x, 0, 1e-9)
	expectNear(z, 8 + EnemyConfig.Movement.stepBackExtra, 1e-9)
	local M = EnemyConfig.Movement
	local roll = M.stepBackChance + 0.01
	expectTrue(not EnemyMovement.WantsStepBack(1, roll))
	expectTrue(EnemyMovement.WantsStepBack(3, roll))
	expectTrue(not EnemyMovement.WantsStepBack(50, M.stepBackMax + 0.01), "capped")
end

cases["Pack offsets keep members apart when there is room"] = function()
	local rand = __rng(4)
	local function r(lo, hi)
		return lo + (hi - lo) * rand()
	end
	local placed = {}
	for _ = 1, 3 do
		local x, z = EnemyMovement.PackOffset(placed, EnemyConfig.DefaultSpawnScatter, EnemyConfig.Movement.packGap, 40, r)
		for _, o in placed do
			expectTrue(dist(x, z, o[1], o[2]) >= EnemyConfig.Movement.packGap)
		end
		table.insert(placed, { x, z })
	end
end

return cases
