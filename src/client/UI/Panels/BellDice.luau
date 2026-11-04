--!strict
-- Bell Dice panel: the shared chance table. Shows the exact odds, payouts and expected return
-- of every bet BEFORE any bet button, the live round, who else is betting, and the chip
-- exchange. Fortune Chips are free (daily + time played) and can never be bought.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DiceConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("DiceConfig"))

local UI = script.Parent.Parent
local Kit = require(UI:WaitForChild("Kit"))
local PanelTypes = require(UI:WaitForChild("PanelTypes"))
local Controllers = UI.Parent:WaitForChild("Controllers")
local DataController = require(Controllers:WaitForChild("DataController"))
local DiceController = require(Controllers:WaitForChild("DiceController"))

local C = Kit.Colors
local STAKES = { 1, 5, 10, 25 }
local stake = 5

local function die(parent: Instance, value: number?, glow: boolean)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(52, 52)
	f.BackgroundColor3 = if glow then C.Gold else C.Raised
	f.BackgroundTransparency = if glow then 0.75 else 0.1
	f.BorderSizePixel = 0
	f.Parent = parent
	Kit.Corner(f, 10)
	Kit.Stroke(f, if glow then C.Gold else C.Line, if glow then 0.2 else 0.7, if glow then 1.5 else 1)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Kit.TitleFont
	l.TextSize = 26
	l.TextColor3 = if value then C.Text else C.Faint
	l.Text = if value then tostring(value) else "?"
	l.Parent = f
end

local Panel: PanelTypes.Panel = {
	Title = "Bell Dice",
	WatchKeys = { "chips", "chipsExchanged" },
	Changed = DiceController.Changed,
	Render = function(body, ctx)
		local st = DiceController.State
		if DiceController.Odds() == nil then
			st = DiceController.Refresh()
		end
		if not st.allowed then
			Kit.Empty(body, "Bell Dice is not available on this account.")
			return
		end
		local chips = DataController.Get("chips") or 0

		-- Round header: chips, countdown, the dice.
		local head = Kit.Row(body, 76)
		local info = Kit.Stack(head, -200)
		local timer = Kit.Label(info, DiceController.PhaseText(st), { font = Kit.TitleFont, size = 20 })
		DiceController.TimerLabel = timer
		local chipsRow = Kit.Strip(info, 24)
		Kit.Chip(chipsRow, chips .. " Fortune Chips", C.Gold, true)
		Kit.Chip(chipsRow, "Round " .. tostring(st.round or 1), C.Muted)
		local shown = if st.phase ~= "Betting" then st.dice else (st.history and st.history[1])
		local triple = shown ~= nil and shown[1] == shown[2] and shown[2] == shown[3]
		for i = 1, 3 do
			die(head, if st.phase == "Rolling" then nil else (shown and shown[i]), triple and st.phase == "Result")
		end

		-- Odds first, then the bet buttons.
		Kit.Section(body, "Odds and payouts", "exact, three dice")
		local odds = DiceController.Odds() or {}
		for _, o in odds do
			local def = DiceConfig.Bets[o.id]
			local t = st.tables and st.tables[o.id] or { players = 0, chips = 0 }
			local row = Kit.Row(body, 64)
			local s = Kit.Stack(row, -170)
			Kit.Label(s, string.format("%s  <font color=\"#%s\">pays %d:1</font>", def.label, C.Gold:ToHex(), o.payout), { bold = true, size = 16 })
			Kit.Label(s, string.format("%s  ·  win chance %.2f%%  ·  returns %.2f%% on average", def.description, o.percent, o.returnPercent), { size = 13, color = C.Muted })
			Kit.Label(s, string.format("%d at the table on this  ·  %d chips", t.players, t.chips), { size = 12, color = C.Faint })
			Kit.Button(row, "Bet " .. stake, if st.phase == "Betting" then C.Gold else C.Row, function()
				local ok, msg = DiceController.Bet(o.id, stake)
				if not ok then
					ctx.notify(msg or "Could not bet", true)
				end
			end, 140)
		end
		local stakeRow = Kit.Strip(body, 36)
		Kit.Label(stakeRow, "Stake per click", { size = 14, color = C.Muted, width = 120 })
		for _, v in STAKES do
			Kit.Button(stakeRow, tostring(v), if v == stake then C.Accent else C.Row, function()
				stake = v
				ctx.refresh()
			end, 56)
		end
		Kit.Label(stakeRow, string.format("max %d per bet", DiceConfig.MaxStake), { size = 13, color = C.Faint, width = 120 })

		-- Everyone at the table this round.
		Kit.Section(body, "At the table", string.format("%d players", #(st.seated or {})))
		if #(st.seated or {}) == 0 then
			Kit.Label(body, "No bets yet this round.", { size = 14, color = C.Faint })
		end
		for _, seat in st.seated or {} do
			local parts = {}
			for _, b in seat.bets do
				table.insert(parts, DiceConfig.Bets[b.bet].label .. " " .. b.stake)
			end
			Kit.KeyValue(body, seat.name, table.concat(parts, "   "), C.Text, C.Gold, 14)
		end
		if st.phase == "Result" and #(st.winners or {}) > 0 then
			Kit.Section(body, "Winners")
			for i, w in st.winners do
				if i <= 5 then
					Kit.KeyValue(body, w.name, "+" .. w.net .. " chips", C.Text, C.Good, 14)
				end
			end
		end

		-- Exchange (capped per day).
		local used = DataController.Get("chipsExchanged") or 0
		Kit.Section(body, "Chip exchange", string.format("%d / %d chips today", used, DiceConfig.DailyExchangeChips))
		local ex = Kit.Strip(body, 40)
		for _, n in { 10, 50 } do
			Kit.Button(ex, string.format("%d chips -> %d Ember", n, n * DiceConfig.EmberPerChip), C.Jade, function()
				local ok, msg = DiceController.Exchange(n)
				ctx.notify(msg or "Try again", not ok)
			end, 210)
		end
		Kit.Label(body, string.format("Fortune Chips are free: %d every day and %d for every %d minutes you play. They can never be bought or traded.", DiceConfig.DailyChips, DiceConfig.PlayChips, DiceConfig.PlayChipSeconds // 60), { size = 13, color = C.Muted, wrap = true })
	end,
}

return Panel
