#!/usr/bin/env python3
"""Headless client boot smoke (no Studio): loads every StarterPlayerScripts/Controllers module the
way ClientBootstrap does (Init for all, then Start for all, ordered by Priority), under
tests/engine_mock + tools/ui_mock + tools/ui_fixture, with a fake character, then runs the
scheduler for a few seconds. Reports module load / Init / Start failures and thread errors.
NOT a Roblox playtest: a clean run means "no obvious boot-time crashes".

Usage: python3 tools/smoke_client.py path/to/luau [seconds]
"""
import pathlib
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from run_tests import build_bundle  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUAU = sys.argv[1] if len(sys.argv) > 1 else "luau"
SECONDS = float(sys.argv[2]) if len(sys.argv) > 2 else 3

SPEC = """
local cases = {}
cases["client boot"] = function()
	__require = require
	__asyncSignals = true
	local errors = {}
	function __onThreadError(co, err)
		table.insert(errors, tostring(err))
	end
	-- cooperative scheduler (same idea as tools/server_mock.luau)
	local waiting, delayed = {}, {}
	local function resume(co, ...)
		if coroutine.status(co) ~= "suspended" then return end
		local ok, err = coroutine.resume(co, ...)
		if not ok then __onThreadError(co, err) end
	end
	task.spawn = function(f, ...)
		local co = if type(f) == "thread" then f else coroutine.create(f)
		resume(co, ...)
		return co
	end
	task.defer = task.spawn
	task.wait = function(t)
		if coroutine.isyieldable() then
			table.insert(waiting, { co = coroutine.running(), due = os.clock() + (t or 1 / 30) })
			coroutine.yield()
		end
		return t or 1 / 30
	end
	task.delay = function(t, f, ...)
		table.insert(delayed, { f = f, args = table.pack(...), due = os.clock() + (t or 0) })
	end
	local function step()
		local now = os.clock()
		local rs = game:GetService("RunService")
		rs.RenderStepped:Fire(1 / 60)
		rs.Heartbeat:Fire(1 / 60)
		local w = waiting
		waiting = {}
		for _, x in w do
			if x.due <= now then resume(x.co) else table.insert(waiting, x) end
		end
		local d = delayed
		delayed = {}
		for _, x in d do
			if x.due <= now then task.spawn(x.f, table.unpack(x.args, 1, x.args.n)) else table.insert(delayed, x) end
		end
	end
	__client()
	-- a character for the controllers that read one
	local player = game:GetService("Players").LocalPlayer
	local ch = Instance.new("Model")
	ch.Name = "Wanderer"
	local hum = Instance.new("Humanoid")
	hum.Name = "Humanoid"
	hum.MaxHealth, hum.Health = 100, 100
	hum.Parent = ch
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = CFrame.new(0, 5, 0)
	root.Parent = ch
	ch.PrimaryPart = root
	ch.Parent = workspace
	player.Character = ch
	local Controllers = game.StarterPlayer.StarterPlayerScripts.Controllers
	local list = {}
	for _, module in Controllers:GetChildren() do
		local ok, c = pcall(__require, module)
		if ok and type(c) == "table" then
			c.Name = c.Name or module.Name
			table.insert(list, c)
		else
			print("[client] LOAD FAIL " .. tostring(module.Name) .. ": " .. tostring(c))
		end
	end
	table.sort(list, function(a, b)
		local pa, pb = a.Priority or 100, b.Priority or 100
		if pa == pb then return a.Name < b.Name end
		return pa < pb
	end)
	for _, c in list do
		if c.Init and c.Name ~= "DataController" then
			local ok, err = pcall(c.Init)
			if not ok then print("[client] INIT FAIL " .. c.Name .. ": " .. tostring(err)) end
		end
	end
	for _, c in list do
		if c.Start then
			task.spawn(function()
				local ok, err = pcall(c.Start)
				if not ok then print("[client] START FAIL " .. c.Name .. ": " .. tostring(err)) end
			end)
		end
	end
	print("[client] booted " .. #list .. " controllers")
	local stop = os.clock() + __SECONDS__
	while os.clock() < stop do
		step()
	end
	player.CharacterAdded:Fire(ch)
	local stop2 = os.clock() + 1
	while os.clock() < stop2 do
		step()
	end
	local seen = {}
	for _, e in errors do
		local head = string.match(e, "^[^\\n]*") or e
		if not seen[head] then
			seen[head] = true
			print("[client] THREAD ERROR " .. head)
		end
	end
	print("[client] done, " .. #errors .. " thread errors")
end
return cases
"""


def main():
    spec = SPEC.replace("__SECONDS__", str(SECONDS))
    bundle = build_bundle([("client", spec)], preludes=("tests/engine_mock.luau", "tools/ui_mock.luau", "tools/ui_fixture.luau"))
    out = ROOT / "build" / "smoke_client.bundle.luau"
    out.parent.mkdir(exist_ok=True)
    out.write_text(bundle)
    res = subprocess.run([LUAU, str(out)], capture_output=True, text=True, timeout=300)
    for line in (res.stdout + res.stderr).splitlines():
        if line.startswith("[client]") or line.startswith("[warn]") or "FAIL" in line or ".luau:" in line or line.startswith("    "):
            print(line)


if __name__ == "__main__":
    main()
