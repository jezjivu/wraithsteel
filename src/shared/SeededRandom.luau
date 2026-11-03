--!strict
-- SeededRandom: tiny deterministic PRNG (mulberry32) using only 32-bit integer math, so the
-- same seed gives the same sequence on every server, every client and in tests. Use it for
-- GLOBAL schedules (Night Market stock, rotations). Never for paid rolls (those use the
-- server's Random via Shared/Odds).

local SeededRandom = {}
SeededRandom.__index = SeededRandom

export type Rng = typeof(setmetatable({} :: { state: number }, SeededRandom))

-- 32-bit multiply modulo 2^32 without losing precision in doubles.
local function imul(a: number, b: number): number
	local aHi, aLo = bit32.rshift(a, 16), bit32.band(a, 0xFFFF)
	local bHi, bLo = bit32.rshift(b, 16), bit32.band(b, 0xFFFF)
	local lo = aLo * bLo
	local mid = bit32.band(aHi * bLo + aLo * bHi, 0xFFFF)
	return (lo + bit32.lshift(mid, 16)) % 4294967296
end

function SeededRandom.new(seed: number): Rng
	return setmetatable({ state = math.floor(seed) % 4294967296 }, SeededRandom)
end

-- Next 32-bit unsigned integer.
function SeededRandom.NextUInt(self: Rng): number
	self.state = (self.state + 0x6D2B79F5) % 4294967296
	local t = self.state
	t = imul(bit32.bxor(t, bit32.rshift(t, 15)), bit32.bor(t, 1))
	t = bit32.bxor(t, (t + imul(bit32.bxor(t, bit32.rshift(t, 7)), bit32.bor(t, 61))) % 4294967296)
	return bit32.bxor(t, bit32.rshift(t, 14))
end

-- Float in [0, 1).
function SeededRandom.Next(self: Rng): number
	return self:NextUInt() / 4294967296
end

-- Integer in [lo, hi].
function SeededRandom.Range(self: Rng, lo: number, hi: number): number
	return lo + math.floor(self:Next() * (hi - lo + 1))
end

-- Mixes several integers into one 32-bit seed.
function SeededRandom.Hash(...: number): number
	local h = 0x811C9DC5
	for _, v in { ... } do
		local x = math.floor(v) % 4294967296
		for _ = 1, 4 do
			h = imul(bit32.bxor(h, bit32.band(x, 0xFF)), 0x01000193)
			x = bit32.rshift(x, 8)
		end
	end
	return h
end

return SeededRandom
