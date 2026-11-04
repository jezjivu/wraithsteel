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
	-- Combat + duel playtest with simple characters.
	print("[smoke] --- combat & duel ---")
	local CombatSvc = require(SSS.Services.CombatService)
	__giveCharacter(kaito, Vector3.new(0, 5, 150))
	__giveCharacter(mirelle, Vector3.new(0, 5, 154))
	__advance(0.3)
	local ca, cb = CombatSvc.GetByPlayer(kaito), CombatSvc.GetByPlayer(mirelle)
	print(string.format("[smoke] combatants: kaito %s, mirelle %s", tostring(ca ~= nil), tostring(cb ~= nil)))
	if ca and cb then
		local combat = remotes:FindFirstChild("CombatAction")
		local seq = 0
		local function swing(player, action, aimAt)
			seq += 100
			local aim = nil
			if aimAt then
				local d = aimAt - CombatSvc.GetByPlayer(player).root.Position
				aim = Vector3.new(d.X, 0, d.Z).Unit
			end
			combat.OnServerEvent:Fire(player, { action = action, seq = seq, aim = aim })
		end
		local before = cb.humanoid.Health
		swing(kaito, "LightAttack", cb.root.Position)
		__advance(0.4)
		print(string.format("[smoke] open world: friendly hit changed health %s -> %s (must not change)", tostring(before), tostring(cb.humanoid.Health)))
		call(kaito, "DuelRequest", "challenge", mirelle.UserId)
		call(mirelle, "DuelRequest", "accept", kaito.UserId)
		local function report(tag)
			print(string.format("[smoke] %s: kaito hp %.0f/%.0f duel %s at %.0f,%.0f | mirelle hp %.0f/%.0f duel %s", tag,
				ca.humanoid.Health, ca.humanoid.MaxHealth, tostring(ca.duelId), ca.root.Position.X, ca.root.Position.Z,
				cb.humanoid.Health, cb.humanoid.MaxHealth, tostring(cb.duelId)))
		end
		report("duel start")
		__advance(3.3)
		-- step in: put Kaito 4 studs in front of Mirelle, facing her
		local mp = cb.root.Position
		ca.root.CFrame = CFrame.lookAt(mp + Vector3.new(0, 0, 4), mp)
		local h0 = cb.humanoid.Health
		swing(kaito, "LightAttack", mp)
		__advance(0.5)
		print(string.format("[smoke] duel light hit: mirelle %.1f -> %.1f", h0, cb.humanoid.Health))
		-- a lethal blow ends the round instead of killing
		CombatSvc.ApplyHit(ca, cb, { damage = 99999, postureDamage = 0, moveId = "jian_light_1" })
		__advance(0.3)
		report("after lethal blow (round 1)")
		print("[smoke] mirelle dead? " .. tostring(cb.dead) .. ", InDuel " .. tostring(mirelle:GetAttribute("InDuel")))
		__advance(3.5) -- between rounds + countdown
		report("round 2 countdown/fight")
		__advance(3.2)
		CombatSvc.ApplyHit(ca, cb, { damage = 99999, postureDamage = 0, moveId = "jian_light_1" })
		__advance(0.3)
		report("after lethal blow (round 2)")
		__advance(4.5) -- result screen, then home
		report("after the duel")
		local dk = DataService.GetData(kaito)
		local dm = DataService.GetData(mirelle)
		print(string.format("[smoke] record: kaito %d-%d (ember %d), mirelle %d-%d (ember %d)", dk.pvpWins, dk.pvpLosses, dk.ember, dm.pvpWins, dm.pvpLosses, dm.ember))
		-- styles: Ember Fang heat from landed hits on an enemy
		dk.level = 20
		call(kaito, "SetFightingStyle", "ember")
		print("[smoke] style now " .. tostring(dk.fightingStyle))
		local enemy
		for _, c in CombatSvc.All() do
			if c.kind == "Enemy" and not c.dead then
				enemy = c
				break
			end
		end
		if enemy then
			ca.styleId = "ember"
			ca.styleState = nil
			ca.styleState = require(game:GetService("ReplicatedStorage").Shared.StyleLogic).New()
			for _ = 1, 3 do
				CombatSvc.ApplyHit(ca, enemy, { damage = 1, postureDamage = 0, moveId = "jian_light_1" })
			end
			print("[smoke] ember heat after 3 landed hits: " .. tostring(ca.model:GetAttribute("StyleStacks")))
			CombatSvc.ApplyHit(enemy, ca, { damage = 1, postureDamage = 0, moveId = "x" })
			print("[smoke] ember heat after being hit: " .. tostring(ca.model:GetAttribute("StyleStacks")))
			cb.styleId = "river"
			cb.styleState = require(game:GetService("ReplicatedStorage").Shared.StyleLogic).New()
			cb.rules.parryUntil = os.clock() + 5
			CombatSvc.ApplyHit(enemy, cb, { damage = 10, postureDamage = 10, moveId = "x" })
			print("[smoke] river flow after a perfect deflect: " .. tostring(cb.model:GetAttribute("StyleStacks")))
		end
	end
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
