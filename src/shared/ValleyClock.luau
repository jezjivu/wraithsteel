--!strict
-- ValleyClock: the Ashen Valley's time of day, the same on server and every client (derived from
-- workspace:GetServerTimeNow() and LightingConfig.DayNight).
--   ValleyClock.Hour() -> 0..24
--   ValleyClock.IsNight() -> boolean

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LightingConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("LightingConfig"))

local ValleyClock = {}

function ValleyClock.HourAt(serverTime: number): number
	local D = LightingConfig.DayNight
	return ((serverTime / (D.cycleMinutes * 60)) * 24 + D.startHour) % 24
end

function ValleyClock.Hour(): number
	return ValleyClock.HourAt(workspace:GetServerTimeNow())
end

function ValleyClock.IsNightAt(hour: number): boolean
	local D = LightingConfig.DayNight
	return hour >= D.nightFrom or hour < D.nightTo
end

function ValleyClock.IsNight(): boolean
	return LightingConfig.DayNight.enabled and ValleyClock.IsNightAt(ValleyClock.Hour())
end

return ValleyClock
