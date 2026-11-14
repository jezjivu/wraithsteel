-- Minimal fake Roblox instance tree + test runner used by tools/run_tests.py.
-- Only supports what pure modules need: script.Parent chains, child lookup, require(),
-- game:GetService(name), task.spawn/defer. Anything touching real engine APIs is not testable here.

local Node = {}
local nodeMethods = {}

local function newNode(name, parent)
	local n = setmetatable({ __name = name, __parent = parent, __children = {} }, Node)
	if parent then
		rawget(parent, "__children")[name] = n
	end
	return n
end

Node.__index = function(self, key)
	if key == "Name" then
		return rawget(self, "__name")
	elseif key == "Parent" then
		return rawget(self, "__parent")
	elseif key == "ClassName" then
		return if rawget(self, "__loader") then "ModuleScript" else "Folder"
	end
	local m = nodeMethods[key]
	if m then
		return m
	end
	local child = rawget(self, "__children")[key]
	if child == nil then
		error("fake instance: " .. tostring(key) .. " is not a valid member of " .. rawget(self, "__name"), 2)
	end
	return child
end

function nodeMethods.FindFirstChild(self, name)
	return rawget(self, "__children")[name]
end
function nodeMethods.WaitForChild(self, name)
	local c = rawget(self, "__children")[name]
	assert(c, "WaitForChild would hang: " .. name)
	return c
end
function nodeMethods.GetChildren(self)
	local out = {}
	for _, c in rawget(self, "__children") do
		table.insert(out, c)
	end
	table.sort(out, function(a, b)
		return a.Name < b.Name
	end)
	return out
end
function nodeMethods.IsA(self, class)
	return self.ClassName == class
end
function nodeMethods.GetService(self, name)
	return nodeMethods.WaitForChild(self, name)
end
function nodeMethods.GetFullName(self)
	local p = rawget(self, "__parent")
	if p and rawget(p, "__parent") then
		return nodeMethods.GetFullName(p) .. "." .. rawget(self, "__name")
	end
	return rawget(self, "__name")
end

local GAME = newNode("game", nil)

local function resolve(path)
	local n = GAME
	for _, part in path do
		n = rawget(n, "__children")[part] or newNode(part, n)
	end
	return n
end

local cache = {}
local loading = {}
local function fakeRequire(node)
	if cache[node] ~= nil then
		return cache[node]
	end
	local loader = rawget(node, "__loader")
	assert(loader, "require: not a ModuleScript: " .. tostring(rawget(node, "__name")))
	assert(not loading[node], "require: cyclic require of " .. nodeMethods.GetFullName(node))
	loading[node] = true
	local result = loader(node, fakeRequire)
	loading[node] = nil
	cache[node] = result
	return result
end

function __node(path)
	resolve(path)
end

function __source(path, fn)
	rawset(resolve(path), "__loader", fn)
end

-- Engine shims -----------------------------------------------------------------------------
game = GAME
warn = function(...)
	print("[warn]", ...)
end
task = {
	spawn = function(f, ...)
		if type(f) == "thread" then
			return coroutine.resume(f, ...)
		end
		local co = coroutine.create(f)
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			error(err, 0)
		end
		return co
	end,
	defer = function(f, ...)
		return task.spawn(f, ...)
	end,
	wait = function()
		error("task.wait is not available in pure tests")
	end,
}

-- Deterministic RNG for tests. Returns floats in [0,1).
function __rng(seed)
	math.randomseed(seed or 1)
	return function()
		return math.random()
	end
end

-- Runner -----------------------------------------------------------------------------------
local specs = {}
function __spec(name, fn)
	table.insert(specs, { name = name, fn = fn })
end

function __run()
	local passed, failed = 0, 0
	for _, spec in specs do
		local cases = spec.fn(GAME, fakeRequire)
		for caseName, case in cases do
			local ok, err = pcall(case)
			if ok then
				passed += 1
			else
				failed += 1
				print(string.format("FAIL %s :: %s\n    %s", spec.name, caseName, tostring(err)))
			end
		end
	end
	print(string.format("%d passed, %d failed", passed, failed))
	if failed > 0 then
		error("tests failed", 0)
	end
end

-- Assertions available to specs as globals.
function expectEq(actual, expected, msg)
	if actual ~= expected then
		error(string.format("%sexpected %s, got %s", if msg then msg .. ": " else "", tostring(expected), tostring(actual)), 2)
	end
end
function expectNear(actual, expected, eps, msg)
	if math.abs(actual - expected) > (eps or 1e-9) then
		error(string.format("%sexpected ~%s, got %s", if msg then msg .. ": " else "", tostring(expected), tostring(actual)), 2)
	end
end
function expectTrue(v, msg)
	if not v then
		error(msg or "expected true", 2)
	end
end
function expectError(fn, msg)
	local ok = pcall(fn)
	if ok then
		error(msg or "expected an error", 2)
	end
end
