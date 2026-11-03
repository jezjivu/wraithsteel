-- Tests for Shared/SeededRandom and the Night Market (global deterministic stock).
local RS = game:GetService("ReplicatedStorage")
local SeededRandom = require(RS.Shared.SeededRandom)
local NightMarketLogic = require(RS.Shared.NightMarketLogic)
local NightMarketConfig = require(RS.Config.NightMarketConfig)
local SpiritConfig = require(RS.Config.SpiritConfig)
local EconomyConfig = require(RS.Config.EconomyConfig)

local cases = {}

cases["SeededRandom: matches the mulberry32 reference sequence"] = function()
	-- reference values from the canonical JavaScript mulberry32
	local r = SeededRandom.new(1)
	expectEq(r:NextUInt(), 2693262067)
	expectEq(r:NextUInt(), 11749833)
	expectEq(r:NextUInt(), 2265367787)
	local r2 = SeededRandom.new(4294967295)
	expectEq(r2:NextUInt(), 3850105811)
	-- floats stay in [0, 1) and ranges are inclusive
	local r3 = SeededRandom.new(7)
	local seenLo, seenHi = false, false
	for _ = 1, 2000 do
		local f = r3:Next()
		expectTrue(f >= 0 and f < 1)
		local n = r3:Range(1, 4)
		expectTrue(n >= 1 and n <= 4)
		seenLo = seenLo or n == 1
		seenHi = seenHi or n == 4
	end
	expectTrue(seenLo and seenHi)
	expectEq(SeededRandom.Hash(1, 2), SeededRandom.Hash(1, 2))
	expectTrue(SeededRandom.Hash(1, 2) ~= SeededRandom.Hash(2, 1))
end

cases["NightMarket: window math uses os.time() // WindowSeconds"] = function()
	local w = NightMarketConfig.WindowSeconds
	expectEq(w, 600)
	expectEq(NightMarketLogic.Window(0), 0)
	expectEq(NightMarketLogic.Window(599), 0)
	expectEq(NightMarketLogic.Window(600), 1)
	expectEq(NightMarketLogic.WindowEndsAt(NightMarketLogic.Window(1234)), 1800)
end

cases["NightMarket: stock is deterministic, distinct and rotates"] = function()
	local differs = 0
	local counts = {}
	for window = 1000, 1400 do
		local a = NightMarketLogic.Stock(window)
		local b = NightMarketLogic.Stock(window)
		expectEq(#a, NightMarketConfig.SlotCount)
		local seen = {}
		for i, e in a do
			expectEq(e.itemId, b[i].itemId, "same window -> same stock")
			expectEq(e.slot, i)
			expectTrue(not seen[e.itemId], "items are distinct")
			seen[e.itemId] = true
			counts[e.itemId] = (counts[e.itemId] or 0) + 1
		end
		local nextStock = NightMarketLogic.Stock(window + 1)
		for i, e in a do
			if nextStock[i].itemId ~= e.itemId then
				differs += 1
				break
			end
		end
	end
	expectTrue(differs > 300, "stock changes between most windows")
	for _, id in NightMarketConfig.ItemOrder do
		expectTrue((counts[id] or 0) > 0, id .. " appears in the rotation")
	end
end

cases["NightMarket: purchase rules (window, limit, chapter, counters reset)"] = function()
	local window = 5000
	local stock = NightMarketLogic.Stock(window)
	local st = NightMarketLogic.Fresh(nil, window)
	local itemId = NightMarketLogic.CanBuy(st, window, window, 1, 5)
	expectEq(itemId, stock[1].itemId)
	expectEq(select(2, NightMarketLogic.CanBuy(st, window, window - 1, 1, 5)), "The market has new stock - take another look")
	expectEq(select(2, NightMarketLogic.CanBuy(st, window, window, 99, 5)), "Unknown item")
	st.bought[stock[1].itemId] = NightMarketConfig.Items[stock[1].itemId].limit
	expectEq(select(2, NightMarketLogic.CanBuy(st, window, window, 1, 5)), "Sold out for you - new stock soon")
	-- new window -> counters reset
	local st2 = NightMarketLogic.Fresh(st, window + 1)
	expectEq(next(st2.bought), nil)
	expectEq(NightMarketLogic.Fresh(st2, window + 1), st2)
	-- chapter gate
	for w = 1, 500 do
		for _, e in NightMarketLogic.Stock(w) do
			local def = NightMarketConfig.Items[e.itemId]
			if def.chapter > 0 then
				local fresh = NightMarketLogic.Fresh(nil, w)
				expectEq(select(2, NightMarketLogic.CanBuy(fresh, w, w, e.slot, def.chapter - 1)), "Reach Chapter " .. def.chapter .. " first")
				return
			end
		end
	end
	error("no chapter-gated item found in 500 windows")
end

cases["NightMarket: config is valid and sells nothing random"] = function()
	local ordered = {}
	for _, id in NightMarketConfig.ItemOrder do
		ordered[id] = true
		expectTrue(NightMarketConfig.Items[id] ~= nil, id)
	end
	for id, def in NightMarketConfig.Items do
		expectTrue(ordered[id], id .. " must be in ItemOrder")
		expectTrue(def.price > 0 and def.limit > 0 and def.weight > 0, id)
		expectTrue(def.currency == "Ember" or def.currency == "Jade", id)
		if def.kind == "Spirit" then
			local s = def.spirit
			expectTrue(s ~= nil, id)
			local sp = SpiritConfig.Spirits[s.id]
			expectTrue(sp ~= nil, id .. " spirit exists")
			expectEq(s.rarity, sp.rarity, id .. " rarity matches the species")
			expectTrue(SpiritConfig.Mutations[s.mutation] ~= nil, id .. " mutation")
			expectTrue(def.chapter >= sp.chapter, id .. " not sold before its chapter")
		elseif def.kind == "Boost" then
			local known = false
			for _, cat in EconomyConfig.Multipliers do
				known = known or cat[def.boostId] ~= nil
			end
			expectTrue(known, id .. " boost id exists in EconomyConfig.Multipliers")
			expectTrue((def.seconds or 0) > 0, id)
		elseif def.kind == "Ember" then
			expectTrue((def.amount or 0) > 0, id)
		else
			error(id .. ": unknown kind " .. tostring(def.kind))
		end
	end
end

return cases
