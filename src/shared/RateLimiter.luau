--!strict
-- RateLimiter: per-key token bucket. Pure (clock injected) so it is unit-testable.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { tokens: number, last: number }

export type RateLimiter = typeof(setmetatable(
	{} :: { burst: number, perSecond: number, clock: () -> number, buckets: { [any]: Bucket } },
	RateLimiter
))

-- burst: max tokens stored; perSecond: refill rate.
function RateLimiter.new(burst: number, perSecond: number, clock: (() -> number)?): RateLimiter
	return setmetatable({
		burst = burst,
		perSecond = perSecond,
		clock = clock or os.clock,
		buckets = {},
	}, RateLimiter)
end

function RateLimiter.Allow(self: RateLimiter, key: any, cost: number?): boolean
	local now = self.clock()
	local c = cost or 1
	local b = self.buckets[key]
	if b == nil then
		b = { tokens = self.burst, last = now }
		self.buckets[key] = b
	else
		b.tokens = math.min(self.burst, b.tokens + (now - b.last) * self.perSecond)
		b.last = now
	end
	if b.tokens >= c then
		b.tokens -= c
		return true
	end
	return false
end

function RateLimiter.Remove(self: RateLimiter, key: any)
	self.buckets[key] = nil
end

return RateLimiter
