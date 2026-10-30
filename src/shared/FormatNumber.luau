--!strict
-- FormatNumber: short suffix formatting (1.2K, 3.4M, 5.6B ...) and comma grouping.
-- Values are truncated (never rounded up) so the UI never shows more than the player has.

local FormatNumber = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function truncate(x: number, decimals: number): number
	local m = 10 ^ decimals
	return math.floor(x * m + 1e-9) / m
end

-- Short form: 999 -> "999", 1234 -> "1.2K", 3456789 -> "3.4M", 5.6e9 -> "5.6B".
function FormatNumber.Short(n: number, decimals: number?): string
	if n ~= n then
		return "0"
	end
	if n == math.huge then
		return "∞"
	end
	local d = decimals or 1
	local sign = if n < 0 then "-" else ""
	local a = math.abs(n)
	if a < 1000 then
		return sign .. tostring(math.floor(a))
	end
	local tier = math.min(math.floor(math.log10(a) / 3), #SUFFIXES - 1)
	local scaled = truncate(a / 10 ^ (tier * 3), d)
	-- Truncation can never push 999.99K up to 1000K, but float error on log10 can misplace tier.
	if scaled >= 1000 and tier < #SUFFIXES - 1 then
		tier += 1
		scaled = truncate(a / 10 ^ (tier * 3), d)
	end
	local text = string.format("%." .. d .. "f", scaled)
	if d > 0 then
		text = text:gsub("%.?0+$", "")
	end
	return sign .. text .. SUFFIXES[tier + 1]
end

-- Comma form: 1234567 -> "1,234,567".
function FormatNumber.Commas(n: number): string
	local sign = if n < 0 then "-" else ""
	local s = tostring(math.floor(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return sign .. out
end

-- Percent with up to `decimals` places, trailing zeros trimmed: 12.5 -> "12.5%".
function FormatNumber.Percent(p: number, decimals: number?): string
	local d = decimals or 2
	local text = string.format("%." .. d .. "f", p)
	if d > 0 then
		text = text:gsub("%.?0+$", "")
	end
	return text .. "%"
end

return FormatNumber
