--!strict
-- TradeLedger: crash-safe escrow for Spirit trades (pure; the DataStore is passed in).
--
-- Problem: a trade changes two profiles that ProfileStore saves separately. A crash between
-- the two saves could duplicate or lose a Spirit.
--
-- Solution: before either profile changes, the server writes ONE escrow record (both sides,
-- full Spirit snapshots) to a ledger DataStore and indexes it under both userIds. The record
-- moves pending -> committed in a single atomic UpdateAsync. Each profile then applies its
-- side (remove what it gave + add what it received) in one synchronous step and remembers the
-- trade id in `tradesApplied`. So each profile is always self-consistent: it has applied the
-- whole trade or none of it. If a server dies before a profile saved its side, the next time
-- that player loads, `Recover` re-applies the committed record from the ledger (idempotent).
--
-- Commit protocol (Commit):
--   1. record[id] = pending                (if this fails: abort, nothing happened)
--   2. index[userA] += id, index[userB] += id
--                                          (fails: mark aborted, abort)
--   3. record[id]: pending -> committed    (atomic. Fails: try pending -> aborted. If THAT
--                                          answer is also unknown the outcome is "unknown":
--                                          the caller must kick both players without touching
--                                          their profiles; Recover settles it on rejoin.)
-- Only "committed" records are ever applied. Recover (profile load) aborts any record still
-- "pending": if a party is loading elsewhere, the committing server lost them, and because the
-- pending -> committed/aborted step is atomic, exactly one of the two outcomes wins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TradeConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("TradeConfig"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local SpiritLogic = require(script.Parent.SpiritLogic)

type SpiritInstance = Types.SpiritInstance

local TradeLedger = {}

export type SideRecord = { userId: number, give: { SpiritInstance } }

export type Record = {
	id: string,
	at: number,
	status: "pending" | "committed" | "aborted",
	a: SideRecord,
	b: SideRecord,
}

-- Minimal key-value store. `update` must be atomic per key (DataStore UpdateAsync) and return
-- (true, newValue) or (false, errorMessage). Returning nil from `fn` means "no change".
export type Store = {
	update: (key: string, fn: (old: any) -> any) -> (boolean, any),
	get: (key: string) -> (boolean, any),
}

-- Profile fields this module touches.
export type LedgerData = SpiritLogic.SpiritData & {
	tradesApplied: { [string]: number },
	tradeOrder: { string },
}

export type CommitResult = "committed" | "aborted" | "unknown"

function TradeLedger.RecordKey(id: string): string
	return "t_" .. id
end

function TradeLedger.IndexKey(userId: number): string
	return "u_" .. tostring(userId)
end

local function snapshot(inst: SpiritInstance): SpiritInstance
	return table.clone(inst)
end

-- Builds the escrow record from a validated session (call TradeLogic.Validate first).
function TradeLedger.BuildRecord(
	id: string,
	userA: number,
	dataA: SpiritLogic.SpiritData,
	offerA: { string },
	userB: number,
	dataB: SpiritLogic.SpiritData,
	offerB: { string },
	now: number
): Record
	local function side(userId: number, data: SpiritLogic.SpiritData, offer: { string }): SideRecord
		local give = {}
		for _, uid in offer do
			local inst = data.spirits[uid]
			assert(inst, "TradeLedger.BuildRecord: missing spirit " .. uid)
			table.insert(give, snapshot(inst))
		end
		return { userId = userId, give = give }
	end
	return {
		id = id,
		at = now,
		status = "pending",
		a = side(userA, dataA, offerA),
		b = side(userB, dataB, offerB),
	}
end

-- Returns (mySide, theirSide) of a record for userId.
function TradeLedger.Sides(record: Record, userId: number): (SideRecord?, SideRecord?)
	if record.a.userId == userId then
		return record.a, record.b
	elseif record.b.userId == userId then
		return record.b, record.a
	end
	return nil, nil
end

local function remember(data: LedgerData, id: string, now: number)
	data.tradesApplied[id] = now
	table.insert(data.tradeOrder, id)
	while #data.tradeOrder > TradeConfig.LedgerHistoryLimit do
		local old = table.remove(data.tradeOrder, 1)
		if old then
			data.tradesApplied[old] = nil
		end
	end
end

-- Applies userId's side of a committed record to their profile data. Idempotent: returns
-- false if the trade was already applied (or the record is not committed / not theirs).
function TradeLedger.Apply(data: LedgerData, record: Record, userId: number, now: number): (boolean, string?)
	if record.status ~= "committed" then
		return false, "not committed"
	end
	if data.tradesApplied[record.id] then
		return false, "already applied"
	end
	local mine, theirs = TradeLedger.Sides(record, userId)
	if mine == nil or theirs == nil then
		return false, "not a party"
	end
	for _, inst in mine.give do
		if data.spirits[inst.uid] then
			data.spirits[inst.uid] = nil
			local eq = table.find(data.equippedSpirits, inst.uid)
			if eq then
				table.remove(data.equippedSpirits, eq)
			end
		end
	end
	for _, inst in theirs.give do
		local copy = SpiritLogic.Create(data, inst.id, inst.rarity, inst.mutation, now)
		copy.level = inst.level
		copy.xp = inst.xp
		copy.fusedCount = inst.fusedCount
		if inst.paid then
			copy.paid = true
		end
	end
	remember(data, record.id, now)
	return true, nil
end

local function addToIndex(store: Store, userId: number, id: string): boolean
	local ok = store.update(TradeLedger.IndexKey(userId), function(old)
		local list = if type(old) == "table" then old else {}
		if table.find(list, id) == nil then
			table.insert(list, id)
		end
		return list
	end)
	return ok
end

local function transition(store: Store, id: string, from: string, to: string): (boolean, string?)
	local ok, value = store.update(TradeLedger.RecordKey(id), function(old)
		if type(old) ~= "table" then
			return nil
		end
		if old.status == from then
			old.status = to
		end
		return old
	end)
	if not ok then
		return false, nil
	end
	return true, if type(value) == "table" then value.status else nil
end

-- Runs the commit protocol. Retries each step `TradeConfig.LedgerRetries` times.
function TradeLedger.Commit(store: Store, record: Record): CommitResult
	local retries = TradeConfig.LedgerRetries
	local function try(fn: () -> boolean): boolean
		for _ = 1, retries do
			if fn() then
				return true
			end
		end
		return false
	end
	local pending = table.clone(record)
	pending.status = "pending"
	if not try(function()
		return (store.update(TradeLedger.RecordKey(record.id), function()
			return pending
		end))
	end) then
		return "aborted" -- nothing was written (or an unindexed pending record nobody applies)
	end
	local indexed = try(function()
		return addToIndex(store, record.a.userId, record.id)
	end) and try(function()
		return addToIndex(store, record.b.userId, record.id)
	end)
	local final: string? = nil
	if indexed then
		try(function()
			local ok, status = transition(store, record.id, "pending", "committed")
			if ok then
				final = status
			end
			return ok
		end)
	end
	if final == nil then
		-- Commit not attempted or answer lost: settle it as aborted if still pending.
		try(function()
			local ok, status = transition(store, record.id, "pending", "aborted")
			if ok then
				final = status
			end
			return ok
		end)
	end
	if final == "committed" then
		record.status = "committed"
		return "committed"
	elseif final == "aborted" then
		record.status = "aborted"
		return "aborted"
	end
	return "unknown"
end

-- Called after a profile loads: applies every committed-but-unapplied trade for this user and
-- returns the applied ids plus the ids that can be dropped from the index (settled).
-- Records still pending are aborted first (see header).
function TradeLedger.Recover(store: Store, data: LedgerData, userId: number, now: number): ({ string }, { string })
	local applied, settled = {}, {}
	local ok, list = store.get(TradeLedger.IndexKey(userId))
	if not ok or type(list) ~= "table" then
		return applied, settled
	end
	for _, id in list do
		local gotRecord, record = store.get(TradeLedger.RecordKey(id))
		if gotRecord then
			if type(record) ~= "table" then
				table.insert(settled, id) -- record never written
			else
				if record.status == "pending" then
					local tok, status = transition(store, id, "pending", "aborted")
					if tok and status then
						record.status = status
					end
				end
				if record.status == "committed" then
					if TradeLedger.Apply(data, record, userId, now) then
						table.insert(applied, id)
					end
					if data.tradesApplied[id] then
						table.insert(settled, id)
					end
				elseif record.status == "aborted" then
					table.insert(settled, id)
				end
			end
		end
	end
	return applied, settled
end

-- Removes settled ids from a user's index (call after the profile containing them saved).
function TradeLedger.Prune(store: Store, userId: number, settled: { string }): boolean
	if #settled == 0 then
		return true
	end
	local ok = store.update(TradeLedger.IndexKey(userId), function(old)
		if type(old) ~= "table" then
			return nil
		end
		local out = {}
		for _, id in old do
			if table.find(settled, id) == nil then
				table.insert(out, id)
			end
		end
		return out
	end)
	return ok
end

return TradeLedger
