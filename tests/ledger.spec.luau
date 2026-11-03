-- Tests for the trade escrow ledger (Logic/TradeLedger) and the paid-flag trade rule.
local Logic = game:GetService("ServerScriptService").Logic
local TradeLogic = require(Logic.TradeLogic)
local TradeLedger = require(Logic.TradeLedger)
local SpiritLogic = require(Logic.SpiritLogic)
local ProfileTemplate = require(Logic.ProfileTemplate)
local Migrations = require(Logic.Migrations)
local LanternOdds = require(game:GetService("ReplicatedStorage").Shared.LanternOdds)

local cases = {}

-- In-memory store. `failOn(key, n)` makes the next n updates of keys starting with `key` fail;
-- `lose(key)` makes an update apply but report failure (lost answer).
local function newStore()
	local mem = {}
	local fail = {}
	local lost = {}
	local store = {}
	store.mem = mem
	function store.failOn(prefix, n)
		fail[prefix] = n
	end
	function store.lose(prefix)
		lost[prefix] = true
	end
	local function matches(tbl, key)
		for prefix, v in tbl do
			if string.sub(key, 1, #prefix) == prefix and v then
				return prefix
			end
		end
		return nil
	end
	store.update = function(key, fn)
		local f = matches(fail, key)
		if f then
			fail[f] -= 1
			if fail[f] <= 0 then
				fail[f] = nil
			end
			return false, "injected failure"
		end
		local new = fn(mem[key] and table.clone(mem[key]))
		if new ~= nil then
			mem[key] = new
		end
		local l = matches(lost, key)
		if l then
			lost[l] = nil
			return false, "answer lost"
		end
		return true, mem[key]
	end
	store.get = function(key)
		return true, mem[key] and table.clone(mem[key])
	end
	return store
end

local function setup()
	local a, b = ProfileTemplate.New(), ProfileTemplate.New()
	local sa = SpiritLogic.Create(a, "brass_carp", "Rare", "Gilded", 0)
	sa.level = 7
	local sb = SpiritLogic.Create(b, "reed_fox", "Uncommon", "None", 0)
	sb.paid = true
	return a, b, sa, sb
end

local function speciesOf(data)
	local out = {}
	for _, inst in data.spirits do
		table.insert(out, inst.id)
	end
	table.sort(out)
	return table.concat(out, ",")
end

cases["Ledger: commit then apply both sides once (idempotent)"] = function()
	local a, b, sa, sb = setup()
	local store = newStore()
	local rec = TradeLedger.BuildRecord("T1", 1, a, { sa.uid }, 2, b, { sb.uid }, 100)
	expectEq(TradeLedger.Commit(store, rec), "committed")
	expectEq(store.mem["t_T1"].status, "committed")
	expectTrue(table.find(store.mem["u_1"], "T1") ~= nil and table.find(store.mem["u_2"], "T1") ~= nil)
	expectTrue(TradeLedger.Apply(a, rec, 1, 100))
	expectTrue(TradeLedger.Apply(b, rec, 2, 100))
	expectEq(speciesOf(a), "reed_fox")
	expectEq(speciesOf(b), "brass_carp")
	-- second apply does nothing
	expectTrue(not TradeLedger.Apply(a, rec, 1, 101))
	expectEq(SpiritLogic.Count(a), 1)
	-- the paid flag and level travel with the Spirit
	for _, inst in a.spirits do
		expectEq(inst.paid, true)
	end
	for _, inst in b.spirits do
		expectEq(inst.level, 7)
	end
end

cases["Ledger: crash before B saved -> B recovers on next load, A untouched"] = function()
	local a, b, sa, sb = setup()
	local store = newStore()
	local bBefore = table.clone(b.spirits)
	local rec = TradeLedger.BuildRecord("T2", 1, a, { sa.uid }, 2, b, { sb.uid }, 100)
	expectEq(TradeLedger.Commit(store, rec), "committed")
	TradeLedger.Apply(a, rec, 1, 100) -- A applied (and saved); B's server dies
	-- B reloads from its pre-trade save
	local b2 = ProfileTemplate.New()
	b2.spirits = bBefore
	b2.nextUid = b.nextUid
	local applied, settled = TradeLedger.Recover(store, b2, 2, 200)
	expectEq(#applied, 1)
	expectEq(#settled, 1)
	expectEq(speciesOf(b2), "brass_carp")
	-- A loading again does not double-apply
	local appliedA, settledA = TradeLedger.Recover(store, a, 1, 200)
	expectEq(#appliedA, 0)
	expectEq(#settledA, 1)
	expectEq(speciesOf(a), "reed_fox")
	-- after pruning the index is empty
	expectTrue(TradeLedger.Prune(store, 2, settled))
	expectEq(#store.mem["u_2"], 0)
end

cases["Ledger: failures before commit abort and change nothing"] = function()
	local a, b, sa, sb = setup()
	-- record write fails every retry
	local store = newStore()
	store.failOn("t_", 99)
	local rec = TradeLedger.BuildRecord("T3", 1, a, { sa.uid }, 2, b, { sb.uid }, 100)
	expectEq(TradeLedger.Commit(store, rec), "aborted")
	-- index write for B fails every retry -> record marked aborted
	local store2 = newStore()
	store2.failOn("u_2", 99)
	local rec2 = TradeLedger.BuildRecord("T4", 1, a, { sa.uid }, 2, b, { sb.uid }, 100)
	expectEq(TradeLedger.Commit(store2, rec2), "aborted")
	expectEq(store2.mem["t_T4"].status, "aborted")
	-- A's index holds the aborted id: Recover drops it without applying
	local applied, settled = TradeLedger.Recover(store2, a, 1, 200)
	expectEq(#applied, 0)
	expectEq(settled[1], "T4")
	expectEq(speciesOf(a), "brass_carp")
	-- a transient failure is retried and still commits
	local store3 = newStore()
	store3.failOn("u_1", 1)
	local rec3 = TradeLedger.BuildRecord("T5", 1, a, { sa.uid }, 2, b, { sb.uid }, 100)
	expectEq(TradeLedger.Commit(store3, rec3), "committed")
end

cases["Ledger: lost commit answer resolves to the stored truth"] = function()
	local a, b, sa, sb = setup()
	local store = newStore()
	store.lose("t_T6") -- first update of the record applies but reports failure ...
	local rec = TradeLedger.BuildRecord("T6", 1, a, { sa.uid }, 2, b, { sb.uid }, 100)
	-- ... the pending write is retried and succeeds, commit goes through
	expectEq(TradeLedger.Commit(store, rec), "committed")
	-- now lose the commit answer itself: the follow-up abort attempt reads "committed"
	local store2 = newStore()
	local rec2 = TradeLedger.BuildRecord("T7", 1, a, { sa.uid }, 2, b, { sb.uid }, 100)
	local realUpdate = store2.update
	local calls = 0
	store2.update = function(key, fn)
		if key == "t_T7" then
			calls += 1
			if calls == 2 then -- the pending -> committed transition
				realUpdate(key, fn)
				return false, "answer lost"
			end
		end
		return realUpdate(key, fn)
	end
	expectEq(TradeLedger.Commit(store2, rec2), "committed")
	-- if the store is unreachable after that, the outcome is unknown (caller kicks both)
	local store3 = newStore()
	local rec3 = TradeLedger.BuildRecord("T8", 1, a, { sa.uid }, 2, b, { sb.uid }, 100)
	local real3 = store3.update
	local n = 0
	store3.update = function(key, fn)
		if key == "t_T8" then
			n += 1
			if n >= 2 then
				return false, "down"
			end
		end
		return real3(key, fn)
	end
	expectEq(TradeLedger.Commit(store3, rec3), "unknown")
	-- on rejoin Recover aborts the still-pending record; nothing is applied
	local applied = TradeLedger.Recover(newStoreFrom(store3), a, 1, 300)
	expectEq(#applied, 0)
	expectEq(speciesOf(a), "brass_carp")
end

-- A store that shares `other`'s memory but works again (the outage ended).
function newStoreFrom(other)
	local s = newStore()
	for k, v in other.mem do
		s.mem[k] = v
	end
	return s
end

cases["Ledger: a party reloading mid-commit aborts the trade (no dupe)"] = function()
	local a, b, sa, sb = setup()
	local store = newStore()
	local rec = TradeLedger.BuildRecord("T9", 1, a, { sa.uid }, 2, b, { sb.uid }, 100)
	-- simulate: record + indexes written, then B loads elsewhere before the commit step
	local real = store.update
	local hooked = false
	store.update = function(key, fn)
		if key == "t_T9" and store.mem["u_2"] and not hooked then
			hooked = true
			TradeLedger.Recover({ update = real, get = store.get }, b, 2, 150)
		end
		return real(key, fn)
	end
	expectEq(TradeLedger.Commit(store, rec), "aborted")
	expectEq(speciesOf(b), "reed_fox")
end

cases["Trade: paid-flag rule"] = function()
	local a, b, sa, sb = setup() -- sb is paid
	local s = TradeLogic.New(1, 2, false)
	expectTrue(TradeLogic.SetOffer(s, 1, a, { sa.uid }))
	expectEq(select(2, TradeLogic.SetOffer(s, 2, b, { sb.uid })), "Spirits from paid lanterns cannot be traded on these accounts")
	local s2 = TradeLogic.New(1, 2, true)
	expectTrue(TradeLogic.SetOffer(s2, 2, b, { sb.uid }))
	-- offers are frozen while the escrow commit runs
	s2.executing = true
	expectEq(select(2, TradeLogic.SetOffer(s2, 2, b, {})), "Trade is being completed")
end

cases["Fusion: a paid input makes the result paid"] = function()
	local d = ProfileTemplate.New()
	d.ember = 1e6
	local uids = {}
	for i = 1, 3 do
		local inst = SpiritLogic.Create(d, "lantern_moth", "Common", "None", 0)
		inst.paid = i == 2
		table.insert(uids, inst.uid)
	end
	local plan, err = SpiritLogic.PlanFusion(d, uids)
	expectTrue(plan ~= nil, err)
	local out = SpiritLogic.ApplyFusion(d, plan, 0)
	expectEq(out.paid, true)
end

cases["Lanterns: Ember and Jade lanterns count as paid (both sold for Robux)"] = function()
	expectTrue(LanternOdds.IsPurchasableCurrency("Jade"))
	expectTrue(LanternOdds.IsPurchasableCurrency("Ember"))
	expectTrue(not LanternOdds.IsPurchasableCurrency("Nothing"))
	expectTrue(LanternOdds.IsPaid("paper_lantern"))
	expectTrue(LanternOdds.IsPaid("jade_lantern"))
	expectTrue(LanternOdds.IsPaid("no_such_lantern"))
end

cases["Migration v12 adds trade ledger fields"] = function()
	local d = ProfileTemplate.New()
	d.tradesApplied = nil
	d.tradeOrder = nil
	d.dataVersion = 11
	Migrations.Run(d)
	expectEq(type(d.tradesApplied), "table")
	expectEq(type(d.tradeOrder), "table")
end

return cases
