--!strict
-- TradeLock: tiny shared registry of players whose Spirits are frozen while a trade's escrow
-- record is being written (DataStore calls yield). Every Spirit-changing request checks
-- `TradeLock.IsLocked(userId)` and refuses. No engine APIs, so it lives with the pure logic.

local TradeLock = {}

local locked: { [number]: boolean? } = {}

TradeLock.Message = "Finishing a trade, try again in a moment"

function TradeLock.Set(userId: number, on: boolean)
	locked[userId] = if on then true else nil
end

function TradeLock.IsLocked(userId: number): boolean
	return locked[userId] == true
end

return TradeLock
