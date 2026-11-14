-- Tests for TradeLogic: offers, confirmation reset, countdown, atomic swap, validation.
local Logic = game:GetService("ServerScriptService").Logic
local TradeLogic = require(Logic.TradeLogic)
local SpiritLogic = require(Logic.SpiritLogic)
local ProfileTemplate = require(Logic.ProfileTemplate)
local TradeConfig = require(game:GetService("ReplicatedStorage").Config.TradeConfig)

local cases = {}

local function setup()
	local a, b = ProfileTemplate.New(), ProfileTemplate.New()
	local sa = SpiritLogic.Create(a, "brass_carp", "Rare", "Gilded", 0)
	sa.level = 9
	local sb = SpiritLogic.Create(b, "reed_fox", "Uncommon", "None", 0)
	return a, b, sa, sb
end

cases["Trade: offer change resets confirmations; countdown then swap"] = function()
	local a, b, sa, sb = setup()
	local s = TradeLogic.New(1, 2)
	expectTrue(TradeLogic.SetOffer(s, 1, a, { sa.uid }))
	expectTrue(TradeLogic.SetOffer(s, 2, b, { sb.uid }))
	TradeLogic.Confirm(s, 1, 0)
	expectEq(s.countdownEndsAt, nil)
	TradeLogic.Confirm(s, 2, 0)
	expectEq(s.countdownEndsAt, TradeConfig.ConfirmCountdownSeconds)
	expectTrue(not TradeLogic.Ready(s, 1))
	-- B changes their offer during the countdown: everything resets.
	TradeLogic.SetOffer(s, 2, b, {})
	expectTrue(not s.a.confirmed and not s.b.confirmed and s.countdownEndsAt == nil)
	TradeLogic.SetOffer(s, 2, b, { sb.uid })
	TradeLogic.Confirm(s, 1, 10)
	TradeLogic.Confirm(s, 2, 10)
	expectTrue(TradeLogic.Ready(s, 10 + TradeConfig.ConfirmCountdownSeconds))
	expectTrue(TradeLogic.Execute(s, a, b, 20))
	expectEq(SpiritLogic.Count(a), 1)
	expectEq(SpiritLogic.Count(b), 1)
	local gotB
	for _, inst in b.spirits do
		gotB = inst
	end
	expectEq(gotB.id, "brass_carp")
	expectEq(gotB.mutation, "Gilded")
	expectEq(gotB.level, 9)
	expectEq(a.spirits[sa.uid], nil)
end

cases["Trade: locked, equipped, away and foreign spirits are rejected"] = function()
	local a, b, sa, sb = setup()
	local s = TradeLogic.New(1, 2)
	sa.locked = true
	expectEq(select(2, TradeLogic.SetOffer(s, 1, a, { sa.uid })), "Locked Spirits cannot be traded")
	sa.locked = false
	SpiritLogic.Equip(a, sa.uid, 0)
	expectEq(select(2, TradeLogic.SetOffer(s, 1, a, { sa.uid })), "Unequip Spirits before trading them")
	SpiritLogic.Unequip(a, sa.uid)
	expectEq(select(2, TradeLogic.SetOffer(s, 1, a, { "s999" })), "Invalid selection")
	expectEq(select(2, TradeLogic.SetOffer(s, 3, a, {})), "Not in this trade")
end

cases["Trade: execute re-validates (spirit equipped after confirming) and is all-or-nothing"] = function()
	local a, b, sa, sb = setup()
	local s = TradeLogic.New(1, 2)
	TradeLogic.SetOffer(s, 1, a, { sa.uid })
	TradeLogic.SetOffer(s, 2, b, { sb.uid })
	SpiritLogic.Equip(a, sa.uid, 0)
	local ok = TradeLogic.Execute(s, a, b, 0)
	expectTrue(not ok)
	expectTrue(a.spirits[sa.uid] ~= nil and b.spirits[sb.uid] ~= nil)
	-- full storage on the receiving side blocks the trade
	SpiritLogic.Unequip(a, sa.uid)
	b.spiritStorage = 1
	TradeLogic.SetOffer(s, 2, b, {})
	expectEq(select(2, TradeLogic.Execute(s, a, b, 0)), "Spirit storage is full")
	expectEq(SpiritLogic.Count(a), 1)
end

return cases
