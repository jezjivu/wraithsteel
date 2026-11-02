--!strict
-- NeonBuilder: builds Neon Verge, the cyberpunk realm (RealmConfig.Realms.neon), from parts:
-- wet asphalt streets with glowing lane lines, a grid of dark towers striped with neon window
-- bands and holo-signs, Circuit Square with a hologram bell, the Lantern Wire Market, the
-- Mag-Rail Yards (tracks, cargo stacks, a crane), the Skyline Overpass and the Static Spire.
-- All text on signs is original nonsense branding.
--
-- API:
--   NeonBuilder.Build(origin: Vector3, parent: Instance) -> Model

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RealmConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("RealmConfig"))
local K = require(script.Parent:WaitForChild("BuildKit"))

local NeonBuilder = {}

local NEON = {
	Color3.fromRGB(60, 230, 255), -- cyan
	Color3.fromRGB(255, 60, 200), -- magenta
	Color3.fromRGB(255, 190, 60), -- amber
	Color3.fromRGB(120, 255, 120), -- acid green
	Color3.fromRGB(150, 110, 255), -- violet
}
local SIGNS = {
	"KAIRO NOODLE", "VOLT//ARC", "NEURO-BANK", "SYNTH RAMEN 24H", "OMNI ECHO", "LUX TAXI",
	"PAPER MOON HOTEL", "STATIC SHRINE", "BELLWIRE NEWS", "CHROME & SONS", "NINE GATES NET",
	"RUST-FREE LIMBS", "HOLO KOI", "GHOST SIGNAL", "LOTUS DATA", "KESTREL ARMS",
}
local ASPHALT = Color3.fromRGB(26, 26, 32)
local CONCRETE = Color3.fromRGB(58, 58, 66)

function NeonBuilder.Build(origin: Vector3, parent: Instance): Model
	local rng = Random.new(2077)
	local realm = RealmConfig.Realms.neon
	local m = K.model("NeonVerge", parent)
	local function at(x: number, z: number, y: number?): Vector3
		return origin + Vector3.new(x, y or 0, z)
	end
	local half = realm.half

	-- Ground: one big wet-asphalt slab (top at y = 0) and a reflective sheen.
	K.part(m, "Ground", Vector3.new(half * 2 + 60, 4, half * 2 + 60), CFrame.new(at(0, 0, -2)), ASPHALT, Enum.Material.Asphalt)
	-- Edge walls so nobody walks off the city.
	for _, side in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local len = half * 2 + 60
		local size = if side[1] ~= 0 then Vector3.new(6, 60, len) else Vector3.new(len, 60, 6)
		K.part(m, "CityWall", size, CFrame.new(at(side[1] * (half + 30), side[2] * (half + 30), 30)), Color3.fromRGB(18, 18, 24), Enum.Material.Metal)
	end

	-- Avenues: north-south main avenue, east-west cross avenue.
	local avenues = {
		{ from = { 0, 90 }, to = { 0, -330 }, width = 26 },
		{ from = { -320, 40 }, to = { 320, 40 }, width = 22 },
		{ from = { -320, -150 }, to = { 320, -150 }, width = 18 },
	}
	local streets = K.model("Streets", m)
	for _, av in avenues do
		local a, b = at(av.from[1], av.from[2]), at(av.to[1], av.to[2])
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt(mid, b)
		K.part(streets, "Road", Vector3.new(av.width, 0.2, len), cf * CFrame.new(0, 0.1, 0), Color3.fromRGB(34, 34, 42), Enum.Material.Asphalt)
		for _, s in { -1, 1 } do
			K.part(streets, "Sidewalk", Vector3.new(6, 0.6, len), cf * CFrame.new(s * (av.width / 2 + 3), 0.3, 0), CONCRETE, Enum.Material.Concrete)
		end
		-- Glowing lane dashes.
		for d = -len / 2 + 6, len / 2 - 6, 14 do
			K.decor(streets, "Lane", Vector3.new(0.5, 0.05, 6), cf * CFrame.new(0, 0.23, d), NEON[1], Enum.Material.Neon)
		end
		-- Street lamps every 40 studs on both sides.
		for d = -len / 2 + 20, len / 2 - 20, 40 do
			for _, s in { -1, 1 } do
				local base = (cf * CFrame.new(s * (av.width / 2 + 5), 0.6, d)).Position
				K.column(streets, "LampPost", 11, 0.5, base, Color3.fromRGB(40, 40, 48), Enum.Material.Metal)
				local lamp = K.decor(streets, "Lamp", Vector3.new(2.4, 0.4, 0.8), CFrame.new(base + Vector3.new(-s * 1, 11, 0)), NEON[(math.floor(d) % 2) + 1], Enum.Material.Neon)
				if math.floor(d / 40) % 2 == 0 then
					K.light(lamp, lamp.Color, 22, 1.2)
				end
			end
		end
	end

	-- Puddles (glassy, reflect the neon).
	for _ = 1, 40 do
		local x, z = rng:NextNumber(-half, half), rng:NextNumber(-half, half)
		local s = rng:NextNumber(4, 10)
		local p = K.decor(streets, "Puddle", Vector3.new(0.05, s, s * rng:NextNumber(0.5, 1)), CFrame.new(at(x, z, 0.26)) * CFrame.Angles(0, rng:NextNumber(0, 6), math.rad(90)), Color3.fromRGB(30, 40, 60), Enum.Material.Glass, Enum.PartType.Cylinder)
		p.Reflectance = 0.5
		p.Transparency = 0.3
	end

	-- Keep-out zones for buildings: areas + avenues.
	local function blocked(x: number, z: number, margin: number): boolean
		for _, a in realm.areas do
			if (Vector2.new(x, z) - Vector2.new(a.center[1], a.center[2])).Magnitude < a.radius + margin then
				return true
			end
		end
		if math.abs(x) < 13 + margin + 9 and z < 100 and z > -340 then
			return true
		end
		if math.abs(z - 40) < 11 + margin + 9 or math.abs(z + 150) < 9 + margin + 9 then
			return true
		end
		return false
	end

	-- Towers.
	local towers = K.model("Towers", m)
	local signIndex = 0
	for gx = -300, 300, 44 do
		for gz = -320, 320, 44 do
			local x, z = gx + rng:NextNumber(-6, 6), gz + rng:NextNumber(-6, 6)
			local w, d = rng:NextNumber(20, 32), rng:NextNumber(20, 32)
			if not blocked(x, z, math.max(w, d) / 2) and rng:NextNumber() < 0.85 then
				local h = rng:NextNumber(30, 150)
				local body = Color3.fromRGB(28 + rng:NextInteger(0, 18), 28 + rng:NextInteger(0, 14), 38 + rng:NextInteger(0, 18))
				local tower = K.model("Tower", towers)
				K.part(tower, "Body", Vector3.new(w, h, d), CFrame.new(at(x, z, h / 2)), body, if rng:NextNumber() < 0.5 then Enum.Material.Metal else Enum.Material.Concrete)
				-- Neon window bands on the faces toward the streets.
				local neon = NEON[rng:NextInteger(1, #NEON)]
				for y = 8, h - 6, rng:NextNumber(9, 16) do
					for _, face in { { 0, d / 2 + 0.15 }, { w / 2 + 0.15, 0 }, { -w / 2 - 0.15, 0 }, { 0, -d / 2 - 0.15 } } do
						if rng:NextNumber() < 0.55 then
							local size = if face[1] == 0 then Vector3.new(w * 0.8, 0.6, 0.2) else Vector3.new(0.2, 0.6, d * 0.8)
							local band = K.decor(tower, "WindowBand", size, CFrame.new(at(x + face[1], z + face[2], y)), neon, Enum.Material.Neon)
							band.Transparency = 0.15
						end
					end
				end
				-- Rooftop: antenna with a red blinker, sometimes a billboard.
				K.column(tower, "Antenna", rng:NextNumber(6, 18), 0.4, at(x + w * 0.2, z, h), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
				local blink = K.decor(tower, "Blinker", Vector3.new(0.8, 0.8, 0.8), CFrame.new(at(x + w * 0.2, z, h + 18)), Color3.fromRGB(255, 40, 40), Enum.Material.Neon, Enum.PartType.Ball)
				blink:SetAttribute("Blink", true)
				if rng:NextNumber() < 0.45 then
					signIndex += 1
					local text = SIGNS[(signIndex - 1) % #SIGNS + 1]
					local vertical = rng:NextNumber() < 0.5
					local sc = NEON[rng:NextInteger(1, #NEON)]
					local size = if vertical then Vector3.new(4, math.min(h * 0.6, 40), 0.6) else Vector3.new(math.min(w, 26), 6, 0.6)
					local y = if vertical then h * 0.55 else h + 4
					local board = K.decor(tower, "HoloSign", size, CFrame.new(at(x, z + d / 2 + 1, y)), Color3.fromRGB(10, 10, 16), Enum.Material.SmoothPlastic)
					K.sign(board, if vertical then string.gsub(text, " ", "\n") else text, sc, Enum.Font.Arcade)
					local frame = K.decor(tower, "SignFrame", size + Vector3.new(0.6, 0.6, -0.2), board.CFrame, sc, Enum.Material.Neon)
					frame.Transparency = 0.5
				end
			end
		end
	end

	-- Circuit Square: plaza, neon ring, hologram bell, benches, vending machines.
	do
		local sq = K.model("CircuitSquare", m)
		local c = at(0, 0)
		K.disc(sq, "Plaza", 96, 0.4, c + Vector3.new(0, 0.4, 0), Color3.fromRGB(48, 48, 58), Enum.Material.DiamondPlate)
		local ring = K.disc(sq, "PlazaRing", 100, 0.3, c + Vector3.new(0, 0.3, 0), NEON[1], Enum.Material.Neon)
		ring.CanCollide = false
		-- Hologram bell: stacked translucent neon rings.
		for i = 0, 7 do
			local r = 10 - math.abs(i - 3) * 1.2
			local holo = K.decor(sq, "HoloBell", Vector3.new(0.4, r * 2, r * 2), CFrame.new(c + Vector3.new(0, 10 + i * 2.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), NEON[1], Enum.Material.ForceField, Enum.PartType.Cylinder)
			holo.Transparency = 0.2
		end
		local base = K.disc(sq, "HoloBase", 14, 1.4, c + Vector3.new(0, 1.8, 0), Color3.fromRGB(30, 30, 40), Enum.Material.Metal)
		K.light(base, NEON[1], 40, 2)
		for i = 0, 5 do
			local a = math.rad(i * 60 + 30)
			local p = c + Vector3.new(math.cos(a) * 34, 0, math.sin(a) * 34)
			local vend = K.part(sq, "Vending", Vector3.new(4, 7, 3), CFrame.lookAt(p + Vector3.new(0, 3.9, 0), c + Vector3.new(0, 3.9, 0)), Color3.fromRGB(40, 40, 52), Enum.Material.Metal)
			local front = K.decor(sq, "VendFront", Vector3.new(3.2, 5, 0.2), vend.CFrame * CFrame.new(0, 0.5, -1.55), NEON[(i % #NEON) + 1], Enum.Material.Neon)
			front.Transparency = 0.25
		end
	end

	-- Lantern Wire Market: stalls with colored awnings, strings of neon lanterns.
	do
		local mk = K.model("LanternWireMarket", m)
		local c = realm.areas[2].center
		for row = -1, 1, 2 do
			for i = -3, 3 do
				local x, z = c[1] + i * 13, c[2] + row * 18
				local face = if row < 0 then 0 else 180
				local cf = CFrame.new(at(x, z)) * CFrame.Angles(0, math.rad(face), 0)
				K.part(mk, "Counter", Vector3.new(10, 3.4, 3), cf * CFrame.new(0, 1.7, 0), Color3.fromRGB(70, 60, 55), Enum.Material.Metal)
				for _, sx in { -4.6, 4.6 } do
					K.part(mk, "StallPole", Vector3.new(0.4, 9, 0.4), cf * CFrame.new(sx, 4.5, 2), Color3.fromRGB(50, 50, 60), Enum.Material.Metal)
				end
				local aw = NEON[(i + 3) % #NEON + 1]
				K.part(mk, "Awning", Vector3.new(11, 0.4, 6), cf * CFrame.new(0, 9, 0.5) * CFrame.Angles(math.rad(-12), 0, 0), aw:Lerp(Color3.new(0, 0, 0), 0.45), Enum.Material.Fabric)
				local strip = K.decor(mk, "AwningGlow", Vector3.new(11, 0.2, 0.2), cf * CFrame.new(0, 8.4, -2.4), aw, Enum.Material.Neon)
				if i % 2 == 0 then
					K.light(strip, aw, 16, 1)
				end
				local label = K.decor(mk, "StallSign", Vector3.new(8, 1.6, 0.3), cf * CFrame.new(0, 6.6, -1.6), Color3.fromRGB(15, 15, 20))
				K.sign(label, SIGNS[(i + row + 20) % #SIGNS + 1], aw, Enum.Font.Arcade, { Enum.NormalId.Front })
			end
		end
		-- Lantern strings across the alley.
		for i = -4, 4 do
			for j = -2, 2 do
				local p = at(c[1] + i * 10, c[2] + j * 3, 12 + math.sin(i + j) * 0.6)
				local lantern = K.decor(mk, "WireLantern", Vector3.new(1.2, 1.6, 1.2), CFrame.new(p), if (i + j) % 2 == 0 then Color3.fromRGB(255, 70, 70) else NEON[1], Enum.Material.Neon, Enum.PartType.Ball)
				lantern.Transparency = 0.1
			end
		end
	end

	-- Mag-Rail Yards: tracks, cargo containers, a gantry crane.
	do
		local ry = K.model("MagRailYards", m)
		local c = realm.areas[3].center
		for t = -2, 2 do
			local z = c[2] + t * 9
			for _, s in { -1.6, 1.6 } do
				K.part(ry, "Rail", Vector3.new(130, 0.5, 0.4), CFrame.new(at(c[1], z + s, 0.45)), Color3.fromRGB(120, 120, 130), Enum.Material.Metal)
			end
			for x = -62, 62, 4 do
				K.part(ry, "Sleeper", Vector3.new(1, 0.3, 4.4), CFrame.new(at(c[1] + x, z, 0.2)), Color3.fromRGB(50, 40, 35), Enum.Material.Wood)
			end
			local glow = K.decor(ry, "MagStrip", Vector3.new(130, 0.1, 0.6), CFrame.new(at(c[1], z, 0.5)), NEON[5], Enum.Material.Neon)
			glow.Transparency = 0.3
		end
		local cargo = { Color3.fromRGB(170, 60, 40), Color3.fromRGB(40, 90, 150), Color3.fromRGB(200, 150, 40), Color3.fromRGB(60, 120, 70) }
		for i = 1, 14 do
			local x = c[1] + rng:NextNumber(-55, 55)
			local z = c[2] + (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(28, 48)
			local stack = rng:NextInteger(1, 3)
			local yaw = if rng:NextNumber() < 0.5 then 0 else 90
			for s = 0, stack - 1 do
				K.part(ry, "Container", Vector3.new(16, 7, 7), CFrame.new(at(x, z, 3.5 + s * 7)) * CFrame.Angles(0, math.rad(yaw), 0), cargo[rng:NextInteger(1, #cargo)], Enum.Material.CorrodedMetal)
			end
		end
		-- Gantry crane.
		for _, s in { -1, 1 } do
			K.part(ry, "CraneLeg", Vector3.new(2, 40, 2), CFrame.new(at(c[1] - 20, c[2] + s * 26, 20)), Color3.fromRGB(220, 170, 30), Enum.Material.Metal)
			K.part(ry, "CraneLeg", Vector3.new(2, 40, 2), CFrame.new(at(c[1] + 20, c[2] + s * 26, 20)), Color3.fromRGB(220, 170, 30), Enum.Material.Metal)
		end
		K.part(ry, "CraneBeam", Vector3.new(44, 3, 56), CFrame.new(at(c[1], c[2], 41.5)), Color3.fromRGB(200, 150, 30), Enum.Material.Metal)
		local hook = K.decor(ry, "CraneLight", Vector3.new(3, 1, 3), CFrame.new(at(c[1], c[2], 39)), NEON[3], Enum.Material.Neon)
		K.light(hook, NEON[3], 40, 1.5)
	end

	-- Skyline Overpass: elevated road with ramps and neon rails.
	do
		local ov = K.model("SkylineOverpass", m)
		local c = realm.areas[4].center
		local H = 14
		K.part(ov, "Deck", Vector3.new(80, 1.2, 14), CFrame.new(at(c[1], c[2], H)), CONCRETE, Enum.Material.Concrete)
		for _, s in { -1, 1 } do
			K.decor(ov, "Rail", Vector3.new(80, 0.3, 0.3), CFrame.new(at(c[1], c[2] + s * 7, H + 2.2)), NEON[2], Enum.Material.Neon)
			K.part(ov, "Barrier", Vector3.new(80, 2.2, 0.5), CFrame.new(at(c[1], c[2] + s * 7, H + 1.6)), Color3.fromRGB(70, 70, 80), Enum.Material.Metal)
			-- Ramps down at both ends.
			local rampLen = math.sqrt(H * H + 36 * 36)
			local angle = math.atan2(H, 36)
			K.part(ov, "Ramp", Vector3.new(rampLen, 1.2, 14), CFrame.new(at(c[1] + s * (40 + 18), c[2], H / 2)) * CFrame.Angles(0, 0, -s * angle), CONCRETE, Enum.Material.Concrete)
		end
		for x = -30, 30, 20 do
			K.part(ov, "Pillar", Vector3.new(3, H, 3), CFrame.new(at(c[1] + x, c[2], H / 2)), Color3.fromRGB(50, 50, 60), Enum.Material.Concrete)
		end
	end

	-- Static Spire: a colossal tower behind the boss gate, with a beacon.
	do
		local sp = K.model("StaticSpire", m)
		local c = realm.areas[5].center
		local base = at(c[1], c[2] - 40)
		K.part(sp, "SpireBase", Vector3.new(50, 30, 50), CFrame.new(base + Vector3.new(0, 15, 0)), Color3.fromRGB(30, 30, 40), Enum.Material.Metal)
		K.part(sp, "SpireShaft", Vector3.new(26, 260, 26), CFrame.new(base + Vector3.new(0, 160, 0)), Color3.fromRGB(24, 24, 34), Enum.Material.Metal)
		for y = 40, 280, 24 do
			local band = K.decor(sp, "SpireBand", Vector3.new(27, 1, 27), CFrame.new(base + Vector3.new(0, y, 0)), NEON[2], Enum.Material.Neon)
			band.Transparency = 0.2
		end
		local beacon = K.decor(sp, "Beacon", Vector3.new(8, 8, 8), CFrame.new(base + Vector3.new(0, 296, 0)), NEON[2], Enum.Material.Neon, Enum.PartType.Ball)
		K.light(beacon, NEON[2], 60, 3)
		-- Gate arch in front of the arena pad.
		local g = at(c[1], c[2] + 10)
		for _, s in { -1, 1 } do
			K.part(sp, "GatePillar", Vector3.new(3, 22, 3), CFrame.new(g + Vector3.new(s * 12, 11, 0)), Color3.fromRGB(40, 40, 50), Enum.Material.Metal)
		end
		local lintel = K.part(sp, "GateLintel", Vector3.new(30, 2.5, 3), CFrame.new(g + Vector3.new(0, 23, 0)), Color3.fromRGB(40, 40, 50), Enum.Material.Metal)
		local plate = K.decor(sp, "GateSign", Vector3.new(16, 2, 0.3), lintel.CFrame * CFrame.new(0, 0, -1.7), Color3.fromRGB(10, 10, 15))
		K.sign(plate, "STATIC SPIRE // AUTHORIZED ONLY", NEON[2], Enum.Font.Arcade)
	end

	return m
end

return NeonBuilder
