--!strict
-- NetValidate: pure argument checking for remotes declared in NetSchema.
-- Server rejects any call whose args do not match; extra args are rejected too.

local NetValidate = {}

local MAX_SHORT = 64
local MAX_LONG = 512
local MAX_LIST = 64

local function isFiniteNumber(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local checkers: { [string]: (any) -> boolean } = {
	string = function(v)
		return type(v) == "string" and #v <= MAX_SHORT and utf8.len(v) ~= nil
	end,
	longstring = function(v)
		return type(v) == "string" and #v <= MAX_LONG and utf8.len(v) ~= nil
	end,
	number = isFiniteNumber,
	integer = function(v)
		return isFiniteNumber(v) and math.floor(v) == v and math.abs(v) < 2 ^ 53
	end,
	boolean = function(v)
		return type(v) == "boolean"
	end,
	table = function(v)
		return type(v) == "table" and getmetatable(v) == nil
	end,
	Vector3 = function(v)
		return typeof(v) == "Vector3" and isFiniteNumber(v.X) and isFiniteNumber(v.Y) and isFiniteNumber(v.Z)
	end,
	uidList = function(v)
		if type(v) ~= "table" or getmetatable(v) ~= nil then
			return false
		end
		local n = #v
		if n > MAX_LIST then
			return false
		end
		local count = 0
		for k, item in v do
			count += 1
			if type(k) ~= "number" or type(item) ~= "string" or #item > MAX_SHORT then
				return false
			end
		end
		return count == n
	end,
	any = function(_v)
		return true
	end,
}

-- Returns true if `args` (packed, with .n) match `spec`.
function NetValidate.Check(spec: { string }, args: { n: number, [number]: any }): (boolean, string?)
	if args.n > #spec then
		return false, "too many args"
	end
	for i, typeName in spec do
		local optional = string.sub(typeName, -1) == "?"
		local base = if optional then string.sub(typeName, 1, -2) else typeName
		local v = args[i]
		if v == nil then
			if not optional then
				return false, "missing arg " .. i
			end
		else
			local checker = checkers[base]
			if checker == nil then
				return false, "unknown type " .. base
			end
			if not checker(v) then
				return false, "bad arg " .. i .. " (" .. base .. ")"
			end
		end
	end
	return true, nil
end

NetValidate.IsFiniteNumber = isFiniteNumber

return NetValidate
