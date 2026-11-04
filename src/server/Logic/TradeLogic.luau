--!strict
-- TradeLogic: pure trade sessions between two profiles.
--   * each side offers up to MaxSpiritsPerSide of its own Spirits (not locked/equipped/away)
--   * any offer change clears both confirmations (no bait-and-switch)
--   * paid-flag rule: Spirits with `paid = true` are only offerable when the session allows
--     paid items (both players' policy allows paid item trading); the flag travels with them
--   * both confirmed -> countdown; Execute re-validates everything at swap time, then moves the
--     Spirits in one synchronous step (receiver gets fresh uids from its own counter)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TradeConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("TradeConfig"))

local SpiritLogic = require(script.Parent.SpiritLogic)

local TradeLogic = {}

export type Side = { userId: number, offer: { string }, confirmed: boolean }

export type Session = {
	a: Side,
	b: Side,
	countdownEndsAt: number?, -- set while both are confirmed
	allowPaid: boolean, -- both players may trade paid items (PolicyService)
	executing: boolean, -- escrow commit in progress: offers are frozen
}

function TradeLogic.New(userA: number, userB: number, allowPaid: boolean?): Session
	return {
		a = { userId = userA, offer = {}, confirmed = false },
		b = { userId = userB, offer = {}, confirmed = false },
		countdownEndsAt = nil,
		allowPaid = allowPaid == true,
		executing = false,
	}
end

function TradeLogic.SideOf(s: Session, userId: number): (Side?, Side?)
	if s.a.userId == userId then
		return s.a, s.b
	elseif s.b.userId == userId then
		return s.b, s.a
	end
	return nil, nil
end

-- Checks that `uids` can be offered from `data`.
function TradeLogic.ValidateOffer(data: SpiritLogic.SpiritData, uids: { string }, allowPaid: boolean?): (boolean, string?)
	if #uids > TradeConfig.MaxSpiritsPerSide then
		return false, "You can offer at most " .. TradeConfig.MaxSpiritsPerSide .. " Spirits"
	end
	local seen = {}
	for _, uid in uids do
		local s = data.spirits[uid]
		if s == nil or seen[uid] then
			return false, "Invalid selection"
		end
		seen[uid] = true
		if s.locked then
			return false, "Locked Spirits cannot be traded"
		end
		if s.paid and not allowPaid then
			return false, "Spirits from paid lanterns cannot be traded on these accounts"
		end
		if SpiritLogic.IsEquipped(data, uid) then
			return false, "Unequip Spirits before trading them"
		end
		if SpiritLogic.IsAway(data, uid) then
			return false, "Spirits on expeditions cannot be traded"
		end
	end
	return true, nil
end

function TradeLogic.SetOffer(s: Session, userId: number, data: SpiritLogic.SpiritData, uids: { string }): (boolean, string?)
	local me = TradeLogic.SideOf(s, userId)
	if me == nil then
		return false, "Not in this trade"
	end
	if s.executing then
		return false, "Trade is being completed"
	end
	local ok, err = TradeLogic.ValidateOffer(data, uids, s.allowPaid)
	if not ok then
		return false, err
	end
	me.offer = table.clone(uids)
	s.a.confirmed = false
	s.b.confirmed = false
	s.countdownEndsAt = nil
	return true, nil
end

function TradeLogic.Confirm(s: Session, userId: number, now: number): boolean
	local me = TradeLogic.SideOf(s, userId)
	if me == nil then
		return false
	end
	me.confirmed = true
	if s.a.confirmed and s.b.confirmed then
		s.countdownEndsAt = now + TradeConfig.ConfirmCountdownSeconds
	end
	return true
end

function TradeLogic.Unconfirm(s: Session, userId: number)
	local me = TradeLogic.SideOf(s, userId)
	if me and not s.executing then
		me.confirmed = false
		s.countdownEndsAt = nil
	end
end

function TradeLogic.Ready(s: Session, now: number): boolean
	return s.a.confirmed and s.b.confirmed and s.countdownEndsAt ~= nil and now >= s.countdownEndsAt
end

-- Re-validates both offers and storage at swap time (no changes).
function TradeLogic.Validate(s: Session, dataA: SpiritLogic.SpiritData, dataB: SpiritLogic.SpiritData): (boolean, string?)
	if #s.a.offer == 0 and #s.b.offer == 0 then
		return false, "Nothing to trade"
	end
	local okA, errA = TradeLogic.ValidateOffer(dataA, s.a.offer, s.allowPaid)
	if not okA then
		return false, errA
	end
	local okB, errB = TradeLogic.ValidateOffer(dataB, s.b.offer, s.allowPaid)
	if not okB then
		return false, errB
	end
	if SpiritLogic.FreeStorage(dataA) + #s.a.offer < #s.b.offer then
		return false, "Spirit storage is full"
	end
	if SpiritLogic.FreeStorage(dataB) + #s.b.offer < #s.a.offer then
		return false, "Spirit storage is full"
	end
	return true, nil
end

-- Swaps the offers in memory (no ledger; TradeService uses TradeLedger instead).
-- All-or-nothing: validates both sides and storage first.
function TradeLogic.Execute(s: Session, dataA: SpiritLogic.SpiritData, dataB: SpiritLogic.SpiritData, now: number): (boolean, string?)
	local ok, err = TradeLogic.Validate(s, dataA, dataB)
	if not ok then
		return false, err
	end
	local fromA, fromB = {}, {}
	for _, uid in s.a.offer do
		table.insert(fromA, dataA.spirits[uid])
		dataA.spirits[uid] = nil
	end
	for _, uid in s.b.offer do
		table.insert(fromB, dataB.spirits[uid])
		dataB.spirits[uid] = nil
	end
	local function receive(data: SpiritLogic.SpiritData, list: { any })
		for _, inst in list do
			local copy = SpiritLogic.Create(data, inst.id, inst.rarity, inst.mutation, now)
			copy.level = inst.level
			copy.xp = inst.xp
			copy.fusedCount = inst.fusedCount
			if inst.paid then
				copy.paid = true
			end
		end
	end
	receive(dataA, fromB)
	receive(dataB, fromA)
	return true, nil
end

return TradeLogic
