--!strict
-- KeepBuilder: builds Ironcrow Keep (RealmConfig.Realms.keep), a fortress castle on a
-- mountain of ash. The route climbs from south to north like a castle siege:
--   Cliff Road (banners, burned carts) -> Gatehouse (curtain wall, drum towers, raised
--   portcullis) -> Outer Bailey (Tessai's shrine, stables, well) -> two ways on: the High
--   Ramparts (west wall-walk, archers, the Castellan) or the Chapel of Ash (east) -> Crow Bridge
--   over a chasm -> Inner Keep (courtyard, the tiered keep tower, Ashrei's shrine).
-- Everything is anchored parts + a few terrain fills, placed around `origin` (ground y = 0).
-- TODO(Studio/Agent D): replace this blockout with a sculpted castle; keep the area centers,
-- spawn points and arena pads from RealmConfig.
--
-- API:
--   KeepBuilder.Build(origin: Vector3, parent: Instance) -> Model

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RealmConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("RealmConfig"))
local K = require(script.Parent:WaitForChild("BuildKit"))

local KeepBuilder = {}

local STONE = Color3.fromRGB(120, 114, 108)
local STONE_DARK = Color3.fromRGB(82, 78, 76)
local PLASTER = Color3.fromRGB(226, 220, 206)
local ROOF = Color3.fromRGB(42, 44, 52)
local WOOD = Color3.fromRGB(88, 60, 44)
local LACQUER = Color3.fromRGB(130, 30, 28)
local GOLD = Color3.fromRGB(220, 175, 80)
local EMBER = Color3.fromRGB(255, 140, 70)
local BANNER = Color3.fromRGB(110, 26, 26)

-- Straight wall from a to b (local x/z), with crenellations on top.
local function wall(parent: Instance, a: Vector3, b: Vector3, height: number, thickness: number)
	local flatA, flatB = Vector3.new(a.X, a.Y, a.Z), Vector3.new(b.X, a.Y, b.Z)
	local len = (flatB - flatA).Magnitude
	if len < 1 then
		return
	end
	local mid = (flatA + flatB) / 2
	local cf = CFrame.lookAt(mid, flatB)
	K.part(parent, "Wall", Vector3.new(thickness, height, len), cf * CFrame.new(0, height / 2, 0), STONE, Enum.Material.Cobblestone)
	K.part(parent, "WallCap", Vector3.new(thickness + 1, 1, len), cf * CFrame.new(0, height + 0.5, 0), STONE_DARK, Enum.Material.Slate)
	local n = math.floor(len / 6)
	for i = 0, n - 1 do
		local z = -len / 2 + 3 + i * 6
		for _, x in { -thickness / 2 + 0.6, thickness / 2 - 0.6 } do
			K.part(parent, "Merlon", Vector3.new(1.2, 2.6, 3), cf * CFrame.new(x, height + 2.3, z), STONE, Enum.Material.Cobblestone)
		end
	end
end

-- Round drum tower with a cap ring and a tiled roof.
local function tower(parent: Instance, base: Vector3, diameter: number, height: number)
	local m = K.model("Tower", parent)
	K.column(m, "Drum", height, diameter, base, STONE, Enum.Material.Cobblestone)
	K.column(m, "Ring", 1.2, diameter + 2, base + Vector3.new(0, height, 0), STONE_DARK, Enum.Material.Slate)
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local p = base + Vector3.new(math.cos(a) * diameter / 2, height + 2.4, math.sin(a) * diameter / 2)
		K.part(m, "Merlon", Vector3.new(2, 2.6, 2), CFrame.new(p) * CFrame.Angles(0, -a, 0), STONE, Enum.Material.Cobblestone)
	end
	local slit = K.decor(m, "Slit", Vector3.new(0.4, 4, 1), CFrame.new(base + Vector3.new(0, height * 0.6, diameter / 2 + 0.1)), Color3.fromRGB(20, 18, 18))
	slit.Transparency = 0
end

local function banner(parent: Instance, pos: Vector3, facing: number, h: number)
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(facing), 0)
	K.part(parent, "BannerPole", Vector3.new(0.5, h, 0.5), cf * CFrame.new(0, h / 2, 0), WOOD, Enum.Material.Wood)
	local cloth = K.decor(parent, "Banner", Vector3.new(3, h * 0.45, 0.15), cf * CFrame.new(1.7, h * 0.72, 0), BANNER, Enum.Material.Fabric)
	K.decor(parent, "Crest", Vector3.new(1.2, 1.2, 0.2), cf * CFrame.new(1.7, h * 0.78, -0.1) * CFrame.Angles(0, 0, math.rad(45)), GOLD, Enum.Material.Metal)
	cloth.Transparency = 0
end

local function brazier(parent: Instance, pos: Vector3)
	K.column(parent, "BrazierFoot", 3, 1.2, pos, STONE_DARK, Enum.Material.Slate)
	local bowl = K.part(parent, "Brazier", Vector3.new(1, 3.4, 3.4), CFrame.new(pos + Vector3.new(0, 3.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(50, 44, 40), Enum.Material.Metal, Enum.PartType.Cylinder)
	local f = Instance.new("Fire")
	f.Color = EMBER
	f.SecondaryColor = Color3.fromRGB(255, 220, 150)
	f.Size = 4
	f.Heat = 8
	f.Parent = bowl
	K.light(bowl, EMBER, 22, 1.6)
end

-- One step stair from (x, z0) ground up to `height` going toward -Z, `width` wide.
local function stair(parent: Instance, x: number, z0: number, height: number, width: number, at: (number, number, number?) -> Vector3)
	local steps = math.ceil(height / 1)
	for i = 1, steps do
		local y = math.min(height, i)
		K.part(parent, "Step", Vector3.new(width, y, 2), CFrame.new(at(x, z0 - (i - 1) * 2, y / 2)), STONE_DARK, Enum.Material.Slate)
	end
end

function KeepBuilder.Build(origin: Vector3, parent: Instance): Model
	local rng = Random.new(1212)
	local realm = RealmConfig.Realms.keep
	local m = K.model("IroncrowKeep", parent)
	local function at(x: number, z: number, y: number?): Vector3
		return origin + Vector3.new(x, y or 0, z)
	end
	local half = realm.half
	local T = workspace.Terrain

	-- Terrain: a mountain plateau of ash and rock, a chasm under the Crow Bridge, peaks around.
	pcall(function()
		T:FillBlock(CFrame.new(at(0, 0, -16)), Vector3.new(half * 2, 32, half * 2), Enum.Material.Rock)
		T:FillBlock(CFrame.new(at(0, 0, -1)), Vector3.new(half * 2 - 40, 2, half * 2 - 40), Enum.Material.Ground)
		-- the chasm
		T:FillBlock(CFrame.new(at(0, -150, -20)), Vector3.new(half * 2, 44, 70), Enum.Material.Air)
		T:FillBlock(CFrame.new(at(0, -150, -44)), Vector3.new(half * 2, 6, 70), Enum.Material.Basalt)
		-- paved route
		local path = { { 0, 345 }, { 0, 160 }, { 0, -110 }, { 0, -190 }, { 0, -300 } }
		for i = 1, #path - 1 do
			local a, b = at(path[i][1], path[i][2], -0.5), at(path[i + 1][1], path[i + 1][2], -0.5)
			if not (path[i][2] == -110 and path[i + 1][2] == -190) then
				T:FillBlock(CFrame.lookAt((a + b) / 2, b), Vector3.new(16, 1.5, (b - a).Magnitude), Enum.Material.Cobblestone)
			end
		end
		for _, side in { -1, 1 } do
			local a, b = at(0, 40, -0.5), at(side * 160, -40, -0.5)
			T:FillBlock(CFrame.lookAt((a + b) / 2, b), Vector3.new(12, 1.5, (b - a).Magnitude), Enum.Material.Cobblestone)
		end
		-- peaks around the plateau
		for i = 0, 13 do
			local a = i / 14 * math.pi * 2
			local r = half + rng:NextNumber(10, 60)
			local h = rng:NextNumber(60, 120)
			T:FillBall(at(math.cos(a) * r, math.sin(a) * r, h * 0.3), h, Enum.Material.Rock)
			T:FillBall(at(math.cos(a) * r, math.sin(a) * r, h * 1.05), h * 0.35, Enum.Material.Snow)
		end
	end)

	-- Cliff Road: burned carts, banners, dead trees.
	do
		local road = K.model("CliffRoad", m)
		for i, z in { 320, 290, 260, 230, 200 } do
			banner(road, at(if i % 2 == 0 then 11 else -11, z), if i % 2 == 0 then 180 else 0, 12)
		end
		for _, p in { { -26, 270 }, { 30, 230 } } do
			local cf = CFrame.new(at(p[1], p[2], 1.4)) * CFrame.Angles(0, rng:NextNumber(0, 3), math.rad(12))
			K.part(road, "CartBed", Vector3.new(6, 1, 10), cf, Color3.fromRGB(40, 32, 28), Enum.Material.WoodPlanks)
			K.part(road, "Wheel", Vector3.new(0.6, 4, 4), cf * CFrame.new(3.2, -0.4, 2), Color3.fromRGB(35, 28, 24), Enum.Material.Wood, Enum.PartType.Cylinder)
		end
		for _ = 1, 10 do
			local x = (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(22, 60)
			local z = rng:NextNumber(190, 330)
			local h = rng:NextNumber(8, 14)
			K.part(road, "DeadTree", Vector3.new(1.2, h, 1.2), CFrame.new(at(x, z, h / 2)) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-8, 8))), Color3.fromRGB(45, 38, 34), Enum.Material.Wood)
		end
	end

	-- Gatehouse + curtain wall (south side of the bailey).
	do
		local g = K.model("Gatehouse", m)
		local H = 28
		wall(g, at(-230, 160), at(-12, 160), H, 8)
		wall(g, at(12, 160), at(230, 160), H, 8)
		-- the gate passage
		K.part(g, "GateArch", Vector3.new(24, 8, 10), CFrame.new(at(0, 160, H - 4)), STONE_DARK, Enum.Material.Cobblestone)
		for x = -5, 5 do
			K.decor(g, "PortcullisBar", Vector3.new(0.7, 10, 0.7), CFrame.new(at(x * 2, 158, H - 9)), Color3.fromRGB(55, 55, 60), Enum.Material.Metal)
		end
		for _, x in { -18, 18 } do
			tower(g, at(x, 160), 14, H + 10)
		end
		for _, x in { -230, 230 } do
			tower(g, at(x, 160), 16, H + 6)
		end
		brazier(g, at(-12, 172))
		brazier(g, at(12, 172))
		K.sign(K.decor(g, "GatePlaque", Vector3.new(14, 2.6, 0.4), CFrame.new(at(0, 165.2, H + 2)), Color3.fromRGB(25, 22, 22)), "IRONCROW", GOLD, Enum.Font.Antique)
	end

	-- Side curtain walls enclosing the bailey, and the north wall at the chasm edge.
	do
		local w = K.model("CurtainWalls", m)
		wall(w, at(-230, 160), at(-230, -110), 24, 8)
		wall(w, at(230, 160), at(230, -110), 24, 8)
		wall(w, at(-230, -110), at(-14, -110), 18, 6)
		wall(w, at(14, -110), at(230, -110), 18, 6)
		for _, p in { { -230, 25 }, { 230, 25 }, { -230, -110 }, { 230, -110 } } do
			tower(w, at(p[1], p[2]), 14, 32)
		end
	end

	-- Outer Bailey: stables, well, siege debris, braziers around Tessai's shrine.
	do
		local b = K.model("OuterBailey", m)
		for i = 0, 4 do
			local z = 110 - i * 14
			K.part(b, "StablePost", Vector3.new(1, 9, 1), CFrame.new(at(-150, z, 4.5)), WOOD, Enum.Material.Wood)
			K.part(b, "StablePost", Vector3.new(1, 9, 1), CFrame.new(at(-130, z, 4.5)), WOOD, Enum.Material.Wood)
		end
		K.part(b, "StableRoof", Vector3.new(26, 1, 64), CFrame.new(at(-140, 82, 9.5)) * CFrame.Angles(0, 0, math.rad(8)), ROOF, Enum.Material.Slate)
		K.column(b, "Well", 3, 8, at(90, 90), STONE, Enum.Material.Cobblestone)
		K.part(b, "WellBeam", Vector3.new(9, 0.8, 0.8), CFrame.new(at(90, 90, 7.5)), WOOD, Enum.Material.Wood)
		for _, p in { { -40, 10 }, { 40, 10 }, { -40, -40 }, { 40, -40 } } do
			brazier(b, at(p[1], p[2]))
		end
		for _ = 1, 14 do
			local s = rng:NextNumber(1.5, 4)
			K.part(b, "Rubble", Vector3.new(s, s * 0.6, s), CFrame.new(at(rng:NextNumber(-200, 200), rng:NextNumber(-90, 140), s * 0.3)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0.3), STONE_DARK, Enum.Material.Rock)
		end
	end

	-- High Ramparts (west): a raised wall-walk with stairs up from the bailey.
	do
		local r = K.model("HighRamparts", m)
		local y = 14
		K.part(r, "WallWalk", Vector3.new(16, y, 170), CFrame.new(at(-170, -40, y / 2)), STONE, Enum.Material.Cobblestone)
		for i = 0, 27 do
			K.part(r, "Merlon", Vector3.new(1.2, 2.6, 3), CFrame.new(at(-178.4, 42 - i * 6, y + 1.3)), STONE, Enum.Material.Cobblestone)
		end
		stair(r, -157, 60, y, 10, at) -- flush against the wall-walk's east edge
		tower(r, at(-170, -128), 18, 30)
		for _, z in { 20, -40, -100 } do
			brazier(r, at(-165, z, y))
		end
	end

	-- Chapel of Ash (east): pillared hall, half the roof fallen, an altar with a cracked bell.
	do
		local c = K.model("ChapelOfAsh", m)
		local cx, cz = 160, -40
		K.part(c, "ChapelFloor", Vector3.new(50, 0.6, 76), CFrame.new(at(cx, cz, 0.3)), Color3.fromRGB(70, 64, 60), Enum.Material.Slate)
		for _, s in { -1, 1 } do
			for k = 0, 5 do
				K.column(c, "ChapelPillar", 22, 2.6, at(cx + s * 18, cz - 30 + k * 12, 0.6), LACQUER, Enum.Material.Wood)
			end
			K.part(c, "ChapelWall", Vector3.new(1.5, 22, 76), CFrame.new(at(cx + s * 25, cz, 11)), PLASTER, Enum.Material.Plaster)
		end
		K.part(c, "RoofHalf", Vector3.new(54, 1.2, 38), CFrame.new(at(cx, cz - 19, 23)) * CFrame.Angles(math.rad(-6), 0, 0), ROOF, Enum.Material.Slate)
		K.part(c, "FallenBeam", Vector3.new(2, 2, 40), CFrame.new(at(cx - 6, cz + 18, 4)) * CFrame.Angles(math.rad(14), math.rad(25), 0), Color3.fromRGB(40, 30, 26), Enum.Material.Wood)
		K.part(c, "Altar", Vector3.new(12, 3, 6), CFrame.new(at(cx, cz - 32, 1.5)), STONE_DARK, Enum.Material.Marble)
		local bell = K.part(c, "CrackedBell", Vector3.new(7, 6, 6), CFrame.new(at(cx, cz - 32, 6)), Color3.fromRGB(120, 95, 60), Enum.Material.Metal, Enum.PartType.Ball)
		K.light(bell, EMBER, 26, 1.2)
	end

	-- Crow Bridge: a long stone deck over the chasm, arches below, crow statues on the rails.
	do
		local br = K.model("CrowBridge", m)
		K.part(br, "Deck", Vector3.new(16, 2, 84), CFrame.new(at(0, -150, -1)), STONE, Enum.Material.Cobblestone)
		for _, x in { -8.5, 8.5 } do
			K.part(br, "Rail", Vector3.new(1, 3, 84), CFrame.new(at(x, -150, 1.5)), STONE_DARK, Enum.Material.Slate)
		end
		for _, z in { -128, -150, -172 } do
			K.part(br, "Arch", Vector3.new(14, 36, 6), CFrame.new(at(0, z, -20)), STONE_DARK, Enum.Material.Cobblestone)
		end
		for _, z in { -116, -184 } do
			for _, x in { -8.5, 8.5 } do
				local base = at(x, z, 3)
				K.part(br, "CrowBody", Vector3.new(1.6, 2.6, 2.2), CFrame.new(base + Vector3.new(0, 1.3, 0)), Color3.fromRGB(25, 25, 28), Enum.Material.Basalt)
				K.part(br, "CrowHead", Vector3.new(1.1, 1.1, 1.1), CFrame.new(base + Vector3.new(0, 3, -0.6)), Color3.fromRGB(25, 25, 28), Enum.Material.Basalt)
				K.decor(br, "CrowEye", Vector3.new(0.3, 0.3, 0.3), CFrame.new(base + Vector3.new(0, 3.1, -1.2)), EMBER, Enum.Material.Neon)
			end
		end
	end

	-- Inner Keep: paved courtyard, the tiered keep tower behind Ashrei's shrine.
	do
		local k = K.model("InnerKeep", m)
		K.part(k, "Courtyard", Vector3.new(120, 0.6, 110), CFrame.new(at(0, -265, 0.3)), Color3.fromRGB(96, 90, 86), Enum.Material.Slate)
		wall(k, at(-60, -190), at(-60, -330), 20, 6)
		wall(k, at(60, -190), at(60, -330), 20, 6)
		-- the keep: sloped stone base, three white tiers, dark roofs with gold ridges
		local kz = -360
		K.part(k, "KeepBase", Vector3.new(70, 18, 50), CFrame.new(at(0, kz, 9)), STONE, Enum.Material.Cobblestone)
		local w, y = 58, 18
		for tier = 1, 3 do
			local h = 14 - tier * 2
			K.part(k, "KeepTier", Vector3.new(w, h, w * 0.65), CFrame.new(at(0, kz, y + h / 2)), PLASTER, Enum.Material.Plaster)
			K.part(k, "KeepRoof", Vector3.new(w + 10, 2, w * 0.65 + 10), CFrame.new(at(0, kz, y + h + 1)), ROOF, Enum.Material.Slate)
			K.part(k, "KeepRidge", Vector3.new(w + 10, 0.6, 1.2), CFrame.new(at(0, kz, y + h + 2.2)), GOLD, Enum.Material.Metal)
			for _, s in { -1, 1 } do
				K.decor(k, "Window", Vector3.new(3, 3, 0.4), CFrame.new(at(s * w * 0.25, kz + w * 0.33, y + h / 2)), EMBER, Enum.Material.Neon)
			end
			y += h + 2
			w -= 16
		end
		K.part(k, "Finial", Vector3.new(2, 6, 2), CFrame.new(at(0, kz, y + 3)), GOLD, Enum.Material.Metal)
		for _, p in { { -30, -230 }, { 30, -230 }, { -30, -290 }, { 30, -290 } } do
			brazier(k, at(p[1], p[2]))
		end
		for _, x in { -48, 48 } do
			banner(k, at(x, -320), 180, 16)
		end
	end

	return m
end

return KeepBuilder
