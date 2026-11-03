#!/usr/bin/env python3
"""Headless server boot smoke test (no Studio): bundles the Rojo tree with tests/engine_mock,
tools/ui_mock and tools/server_mock, loads every Service like Bootstrap does, runs Init and
Start, lets two fake players join, runs N scheduler ticks and prints every error.
This is NOT a Roblox playtest - it catches boot-time crashes (bad requires, nil indexing,
missing config keys) before anyone opens Studio.

Usage: python3 tools/smoke_server.py path/to/luau [ticks]
"""
import pathlib
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from run_tests import build_bundle  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUAU = sys.argv[1] if len(sys.argv) > 1 else "luau"
TICKS = int(sys.argv[2]) if len(sys.argv) > 2 else 20

SPEC = """
local cases = {}
cases["boot"] = function()
	__serverSetup()
	local SSS = game:GetService("ServerScriptService")
	local Net = require(game:GetService("ReplicatedStorage").Shared.Net)
	Net.Server.Init()
	local list = {}
	for _, module in SSS.Services:GetChildren() do
		local ok, svc = pcall(require, module)
		if ok and type(svc) == "table" then
			svc.Name = svc.Name or module.Name
			table.insert(list, svc)
		else
			print("[smoke] LOAD FAIL " .. tostring(module.Name) .. ": " .. tostring(svc))
		end
	end
	table.sort(list, function(a, b)
		local pa, pb = a.Priority or 100, b.Priority or 100
		if pa == pb then return a.Name < b.Name end
		return pa < pb
	end)
	for _, s in list do
		if s.Init then
			local ok, err = pcall(s.Init)
			if not ok then print("[smoke] INIT FAIL " .. s.Name .. ": " .. tostring(err)) end
		end
	end
	for _, s in list do
		if s.Start then
			task.spawn(function()
				local ok, err = pcall(s.Start)
				if not ok then print("[smoke] START FAIL " .. s.Name .. ": " .. tostring(err)) end
			end)
		end
	end
	print("[smoke] booted " .. #list .. " services")
	__joinPlayer(101, "Kaito")
	__joinPlayer(102, "Mirelle")
	for _ = 1, __TICKS__ do
		__tick()
	end
	local DataService = require(SSS.Services.DataService)
	for _, pl in __allPlayers do
		local d = DataService.GetData(pl)
		print(string.format("[smoke] player %s profile %s (v%s, ember %s, chips %s)", pl.Name, if d then "loaded" else "MISSING", tostring(d and d.dataVersion), tostring(d and d.ember), tostring(d and d.chips)))
	end
	local CombatService = require(SSS.Services.CombatService)
	local n = 0
	for _ in CombatService.All and CombatService.All() or {} do
		n += 1
	end
	print("[smoke] combatants registered: " .. n)
	-- Mini playtest: call real remote handlers as the players (server validation included).
	local remotes = game:GetService("ReplicatedStorage").Remotes
	local function call(player, name, ...)
		local r = remotes:FindFirstChild(name)
		if r == nil or r.OnServerInvoke == nil then
			print("[smoke] action " .. name .. ": NO HANDLER")
			return nil
		end
		local res = table.pack(pcall(r.OnServerInvoke, player, ...))
		local parts = {}
		for i = 2, math.min(res.n, 3) do
			local v = res[i]
			table.insert(parts, if type(v) == "table" then "{table}" else tostring(v))
		end
		print(string.format("[smoke] action %-16s -> %s", name, if res[1] then table.concat(parts, ", ") else "ERROR " .. tostring(res[2])))
		return res[2], res[3]
	end
	local kaito, mirelle = __allPlayers[1], __allPlayers[2]
	call(kaito, "GetLanternOdds", "paper_lantern")
	local opened = call(kaito, "OpenLantern", "paper_lantern", 1)
	if type(opened) == "table" and opened[1] then
		print("[smoke]   hatched " .. tostring(opened[1].spirit) .. " " .. tostring(opened[1].rarity) .. " uid " .. tostring(opened[1].uid))
		call(kaito, "EquipSpirit", opened[1].uid)
	end
	call(kaito, "ClaimDaily")
	call(kaito, "DiceState")
	call(kaito, "DiceBet", "Low", 5)
	call(kaito, "DiceBet", "Triple", 999)
	call(kaito, "DiceExchange", 10)
	local nm = call(kaito, "GetNightMarket")
	if type(nm) == "table" then
		call(kaito, "BuyNightMarket", 1, nm.window)
	end
	call(kaito, "PartyRequest", "invite", mirelle.UserId)
	for partyId = 1, 3 do -- invites are keyed by party id (the panel reads them from PartyEvent)
		if call(mirelle, "PartyRequest", "accept", partyId) then
			break
		end
	end
	local PartyService = require(SSS.Services.PartyService)
	print("[smoke] party size seen by Kaito: " .. #PartyService.GetParty(kaito))
	call(kaito, "TradeRequest", mirelle.UserId)
	call(kaito, "RaidRequest", "create", "sunken_bell_vigil")
	call(kaito, "TravelWaystone", "keep_road")
	call(kaito, "BuyWeapon", "dao_rustcutter")
	call(kaito, "LearnSkill", "keen_edge")
	call(kaito, "GetStoreInfo")
	local d = DataService.GetData(kaito)
	print(string.format("[smoke] after: ember %s, chips %s, spirits %d, equipped %d", tostring(d.ember), tostring(d.chips), (function() local n = 0 for _ in d.spirits do n += 1 end return n end)(), #d.equippedSpirits))
	local errs = __smokeErrors()
	local seen = {}
	for _, e in errs do
		local head = string.match(e, "^[^\\n]*") or e
		if not seen[head] then
			seen[head] = true
			print("[smoke] THREAD ERROR " .. e)
		end
	end
	print("[smoke] done, " .. #errs .. " thread errors")
end
return cases
"""


def main():
    bundle = build_bundle([("smoke", SPEC.replace("__TICKS__", str(TICKS)))], preludes=("tests/engine_mock.luau", "tools/ui_mock.luau", "tools/server_mock.luau"))
    out = ROOT / "build" / "smoke.bundle.luau"
    out.parent.mkdir(exist_ok=True)
    out.write_text(bundle)
    res = subprocess.run([LUAU, str(out)], capture_output=True, text=True, timeout=600)
    for line in (res.stdout + res.stderr).splitlines():
        if line.startswith("[smoke]") or line.startswith("[warn]") or "FAIL" in line or "error" in line.lower():
            print(line)


if __name__ == "__main__":
    main()
