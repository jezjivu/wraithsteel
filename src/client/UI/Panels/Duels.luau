--!strict
-- Duels panel (Bonds): challenge a nearby player to a fair duel in the Proving Ring, accept
-- challenges, see your record. Duels: best of three, equal health, no Power or spirit bonuses,
-- no arts/kunai/companions - weapon, style and timing decide. Nobody dies or loses Ember.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PvpConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("PvpConfig"))

local UI = script.Parent.Parent
local Kit = require(UI:WaitForChild("Kit"))
local PanelTypes = require(UI:WaitForChild("PanelTypes"))
local DuelController = require(UI.Parent:WaitForChild("Controllers"):WaitForChild("DuelController"))

local C = Kit.Colors

local Panel: PanelTypes.Panel = {
	Title = "Proving Ring",
	WatchKeys = { "pvpWins", "pvpLosses", "pvpStreak" },
	Changed = DuelController.Changed,
	Render = function(body, ctx)
		local st = DuelController.State
		local function act(op: string, userId: number?)
			local ok, msg = DuelController.Request(op, userId)
			if msg then
				ctx.notify(msg, not ok)
			end
		end
		local rec = Kit.Strip(body, 26)
		Kit.Chip(rec, string.format("%d wins", st.wins or 0), C.Gold, true)
		Kit.Chip(rec, string.format("%d losses", st.losses or 0), C.Muted)
		if (st.streak or 0) > 1 then
			Kit.Chip(rec, string.format("%d win streak", st.streak), C.Accent)
		end
		Kit.Label(body, string.format("Best of three. Both fighters get %d health; levels, Power, Spirits and skills do not count, and arts, kunai and companions stay home. Your weapon, your style and your timing decide. Nobody dies - a lethal blow ends the round.", PvpConfig.Health), { size = 14, color = C.Muted, wrap = true })

		local d = st.duel
		if d then
			Kit.Section(body, "Your duel", "round " .. tostring(d.round))
			Kit.KeyValue(body, "Against " .. tostring(d.opponent), string.format("%d - %d", d.myWins or 0, d.theirWins or 0), C.Text, C.Gold)
			if d.phase ~= "Over" then
				local row = Kit.Strip(body, 40)
				Kit.Button(row, "Yield", C.Bad, function()
					act("forfeit")
				end, 120)
			end
			return
		end

		if #(st.incoming or {}) > 0 then
			Kit.Section(body, "Challenges")
			for _, c in st.incoming do
				local row = Kit.Row(body, 52)
				Kit.Label(row, c.name .. " wants to duel you", { bold = true, width = 320 })
				Kit.Button(row, "Accept", C.Accent, function()
					act("accept", c.userId)
				end, 110)
				Kit.Button(row, "Decline", C.Row, function()
					act("decline", c.userId)
				end, 100)
			end
		end

		Kit.Section(body, "Challenge someone", string.format("within %d studs", PvpConfig.ChallengeRadius))
		local any = false
		for _, p in Players:GetPlayers() do
			if p ~= Players.LocalPlayer then
				any = true
				local row = Kit.Row(body, 48)
				Kit.Label(row, p.DisplayName, { width = 320 })
				Kit.Button(row, "Challenge", C.Gold, function()
					act("challenge", p.UserId)
				end, 130)
			end
		end
		if not any then
			Kit.Empty(body, "Nobody else is here yet", "Invite a friend - the Proving Ring is better with two.")
		end
	end,
}

return Panel
