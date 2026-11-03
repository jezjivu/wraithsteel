--!strict
-- ExpeditionLogic: pure rules for sending idle Spirits on timed expeditions (no randomness).
--   Start: route unlocked, slot valid and free, 1..maxSpirits distinct owned Spirits that are not
--          equipped and not already away.
--   Claim: only once os.time() >= endsAt; grants Ember (from the Spirits' Power at start) and
--          Spirit XP; frees the slot. Spirits released/fused meanwhile cannot happen (IsAway).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Config")
local ExpeditionConfig = require(Config:WaitForChild("ExpeditionConfig"))
local SpiritConfig = require(Config:WaitForChild("SpiritConfig"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local SpiritLogic = require(script.Parent.SpiritLogic)

local ExpeditionLogic = {}

export type ExpeditionData = SpiritLogic.SpiritData & { chapter: number }

local function slots(data: ExpeditionData): { [string]: Types.ExpeditionState }
	local exps = data.expeditions
	assert(exps, "profile has no expeditions table")
	return exps
end

-- Route id is stored inside the state's `id` field.
function ExpeditionLogic.SlotIds(hasPass: boolean): { string }
	local ids = table.clone(ExpeditionConfig.SlotIds)
	if hasPass then
		table.insert(ids, ExpeditionConfig.ExtraSlotWithPass)
	end
	return ids
end

function ExpeditionLogic.Start(
	data: ExpeditionData,
	slotId: string,
	routeId: string,
	uids: { string },
	now: number,
	hasPass: boolean
): (boolean, string?)
	local route = ExpeditionConfig.Routes[routeId]
	if route == nil then
		return false, "Unknown route"
	end
	if data.chapter < route.chapter then
		return false, "Route not unlocked yet"
	end
	if table.find(ExpeditionLogic.SlotIds(hasPass), slotId) == nil then
		return false, "Slot not available"
	end
	local exps = slots(data)
	if exps[slotId] then
		return false, "Slot is busy"
	end
	if #uids == 0 or #uids > route.maxSpirits then
		return false, string.format("Send 1 to %d Spirits", route.maxSpirits)
	end
	local seen = {}
	for _, uid in uids do
		if data.spirits[uid] == nil or seen[uid] then
			return false, "Invalid selection"
		end
		seen[uid] = true
		if SpiritLogic.IsEquipped(data, uid) then
			return false, "Unequip Spirits before sending them"
		end
		if SpiritLogic.IsAway(data, uid) then
			return false, "A Spirit is already away"
		end
	end
	exps[slotId] = {
		id = routeId,
		spiritUids = table.clone(uids),
		startedAt = now,
		endsAt = now + route.durationSeconds,
	}
	return true, nil
end

export type ClaimResult = { ember: number, spiritXp: number, levelUps: number }

function ExpeditionLogic.Claim(data: ExpeditionData, slotId: string, now: number): (ClaimResult?, string?)
	local exps = slots(data)
	local e = exps[slotId]
	if e == nil then
		return nil, "Nothing to claim"
	end
	if now < e.endsAt then
		return nil, "Still exploring"
	end
	local route = ExpeditionConfig.Routes[e.id]
	exps[slotId] = nil
	if route == nil then
		return { ember = 0, spiritXp = 0, levelUps = 0 }, nil
	end
	local hours = route.durationSeconds / 3600
	local power = 0
	local xp = math.floor(route.spiritXpPerHour * hours)
	local levelUps = 0
	for _, uid in e.spiritUids do
		local s = data.spirits[uid]
		if s then
			power += SpiritConfig.PowerOf(s.id, s.rarity, s.mutation, s.level)
			levelUps += SpiritLogic.AddXp(s, xp)
		end
	end
	local ember = math.floor(power * route.emberPerPowerHour * hours)
	data.ember += ember
	return { ember = ember, spiritXp = xp, levelUps = levelUps }, nil
end

return ExpeditionLogic
