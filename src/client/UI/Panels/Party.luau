--!strict
-- Party panel: invite players in this server, accept invites, leave, kick (leader).

local Players = game:GetService("Players")

local UI = script.Parent.Parent
local Kit = require(UI:WaitForChild("Kit"))
local PanelTypes = require(UI:WaitForChild("PanelTypes"))
local PartyController = require(UI.Parent:WaitForChild("Controllers"):WaitForChild("PartyController"))

local C = Kit.Colors

local Panel: PanelTypes.Panel = {
	Title = "Party",
	WatchKeys = {},
	Changed = PartyController.Changed,
	Render = function(body, ctx)
		local st = PartyController.State
		local me = Players.LocalPlayer.UserId
		local isLeader = st.leader == me

		local function act(action: string, arg: number?)
			local ok, msg = PartyController.Request(action, arg)
			if msg then
				ctx.notify(msg, not ok)
			end
		end

		Kit.Label(body, "Party up to 4 players: +5% Ember per extra member, shared kill rewards nearby, and you fight bosses together.", { size = 13, color = C.Muted, wrap = true })

		for _, inv in st.invites do
			local row = Kit.Row(body, 50)
			Kit.Label(row, inv.leaderName .. " invited you", { bold = true, width = 260 })
			Kit.Button(row, "Accept", C.Good, function()
				act("accept", inv.partyId)
			end, 100)
			Kit.Button(row, "Decline", C.Bad, function()
				act("decline", inv.partyId)
			end, 100)
		end

		Kit.Section(body, if st.inParty then "Your party" else "You are solo")
		local inParty: { [number]: boolean } = {}
		for i, m in st.members do
			inParty[m.userId] = true
			local row = Kit.Row(body, 46, i % 2 == 0)
			Kit.Label(row, m.name .. (if m.userId == st.leader then "  (leader)" else "") .. (if m.userId == me then "  - you" else ""), { width = 300 })
			if isLeader and m.userId ~= me then
				Kit.Button(row, "Kick", C.Bad, function()
					act("kick", m.userId)
				end, 90)
			end
		end
		if st.inParty then
			local row = Kit.Row(body, 46)
			Kit.Button(row, "Leave party", C.Bad, function()
				act("leave")
			end, 150)
		end

		Kit.Section(body, "Players in this server")
		local any = false
		for i, p in Players:GetPlayers() do
			if p ~= Players.LocalPlayer and not inParty[p.UserId] then
				any = true
				local row = Kit.Row(body, 46, i % 2 == 0)
				Kit.Label(row, p.DisplayName, { width = 300 })
				if isLeader or not st.inParty then
					Kit.Button(row, "Invite", C.Blue, function()
						act("invite", p.UserId)
					end, 100)
				end
			end
		end
		if not any then
			Kit.Label(body, "Nobody else is here yet.", { color = C.Muted })
		end
	end,
}

return Panel
