--!strict
-- NightMarketLogic: which items the Night Market sells in a given window, and purchase checks.
-- Pure and deterministic: stock depends only on the window number (global seed
-- `os.time() // NightMarketConfig.WindowSeconds`), so all servers and clients agree.

local Config = script.Parent.Parent:WaitForChild("Config")
local NightMarketConfig = require(Config:WaitForChild("NightMarketConfig"))
local SeededRandom = require(script.Parent.SeededRandom)

local NightMarketLogic = {}

export type Slot = { slot: number, itemId: string }

-- Per-player purchase state for the current window (profile.nightMarket).
export type PlayerState = { window: number, bought: { [string]: number } }

function NightMarketLogic.Window(now: number): number
	return now // NightMarketConfig.WindowSeconds
end

function NightMarketLogic.WindowEndsAt(window: number): number
	return (window + 1) * NightMarketConfig.WindowSeconds
end

-- Weighted pick of SlotCount distinct items for `window`.
function NightMarketLogic.Stock(window: number): { Slot }
	local rng = SeededRandom.new(SeededRandom.Hash(window, NightMarketConfig.SeedSalt))
	local pool = {}
	for _, id in NightMarketConfig.ItemOrder do
		local def = NightMarketConfig.Items[id]
		if def and def.weight > 0 then
			table.insert(pool, { id = id, weight = def.weight })
		end
	end
	local out: { Slot } = {}
	for slot = 1, math.min(NightMarketConfig.SlotCount, #pool) do
		local total = 0
		for _, e in pool do
			total += e.weight
		end
		local r = rng:Next() * total
		local pick = #pool
		for i, e in pool do
			r -= e.weight
			if r < 0 then
				pick = i
				break
			end
		end
		table.insert(out, { slot = slot, itemId = pool[pick].id })
		table.remove(pool, pick)
	end
	return out
end

-- Resets the player's counters when the window changed. Returns the (possibly new) state.
function NightMarketLogic.Fresh(state: PlayerState?, window: number): PlayerState
	if state == nil or state.window ~= window then
		return { window = window, bought = {} }
	end
	return state
end

-- Validates buying `slot` during `window` (the client sends the window it saw, so an item that
-- rotated out while the player clicked is refused instead of buying the new item).
function NightMarketLogic.CanBuy(
	state: PlayerState,
	window: number,
	clientWindow: number,
	slot: number,
	chapter: number
): (string?, string?)
	if clientWindow ~= window then
		return nil, "The market has new stock - take another look"
	end
	local stock = NightMarketLogic.Stock(window)
	local entry = stock[slot]
	if entry == nil then
		return nil, "Unknown item"
	end
	local def = NightMarketConfig.Items[entry.itemId]
	if chapter < def.chapter then
		return nil, "Reach Chapter " .. def.chapter .. " first"
	end
	if (state.bought[entry.itemId] or 0) >= def.limit then
		return nil, "Sold out for you - new stock soon"
	end
	return entry.itemId, nil
end

return NightMarketLogic
