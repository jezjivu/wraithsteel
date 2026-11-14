--!strict
-- Time: UTC day keys, durations, and a server-synced clock.

local Time = {}

local DAY = 86400

-- Seconds since epoch. On Roblox uses the synced server clock on both server and client.
function Time.Now(): number
	if workspace ~= nil then
		return workspace:GetServerTimeNow()
	end
	return os.time()
end

-- Integer UTC day number (days since epoch). Daily resets happen at 00:00 UTC.
function Time.DayKey(t: number?): number
	return math.floor((t or Time.Now()) / DAY)
end

function Time.SecondsUntilNextDay(t: number?): number
	local now = t or Time.Now()
	return (Time.DayKey(now) + 1) * DAY - now
end

-- 3725 -> "1h 02m", 65 -> "1m 05s", 9 -> "9s", 90061 -> "1d 1h"
function Time.FormatDuration(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local d = s // DAY
	local h = (s % DAY) // 3600
	local m = (s % 3600) // 60
	local sec = s % 60
	if d > 0 then
		return string.format("%dd %dh", d, h)
	elseif h > 0 then
		return string.format("%dh %02dm", h, m)
	elseif m > 0 then
		return string.format("%dm %02ds", m, sec)
	end
	return string.format("%ds", sec)
end

Time.DAY = DAY

return Time
