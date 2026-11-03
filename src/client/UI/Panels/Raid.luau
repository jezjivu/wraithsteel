--!strict
-- Raid panel: open a raid lobby, join one nearby, launch (leader). Up to 8 players.
-- TODO(Studio/Agent D): raid gate prop in the hub and real panel art.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RaidConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("RaidConfig"))

local UI = script.Parent.Parent
local Kit = require(UI:WaitForChild("Kit"))
local PanelTypes = require(UI:WaitForChild("PanelTypes"))
local RaidController = require(UI.Parent:WaitForChild("Controllers"):WaitForChild("RaidController"))

local C = Kit.Colors

local Panel: PanelTypes.Panel = {
	Title = "Raids",
	WatchKeys = { "level", "chapter", "raidClears" },
	Changed = RaidController.Changed,
	Render = function(body, ctx)
		local st = RaidController.State
		local function act(op: string, arg: string?)
			local ok, msg = RaidController.Request(op, arg)
			if msg then
				ctx.notify(msg, not ok)
			end
		end
		if st.raidServer then
			Kit.Label(body, "You are inside a raid. Hold the line!", { bold = true })
			return
		end
		local mine = st.mine
		if mine then
			local def = RaidConfig.Raids[mine.raidId]
			Kit.Label(body, (def and def.name or mine.raidId) .. string.format("  (%d/%d)", #mine.members, RaidConfig.RaidSize), { bold = true })
			Kit.Label(body, table.concat(mine.members, ", "), { size = 13, color = C.Muted, wrap = true })
			local row = Kit.Row(body, 48)
			if mine.isLeader and not mine.launching then
				Kit.Button(row, "Begin raid", C.Accent, function()
					act("launch")
				end, 150)
			end
			if not mine.launching then
				Kit.Button(row, "Leave", C.Steel, function()
					act("leave")
				end, 110)
			else
				Kit.Label(row, "The raid gate is opening...", { color = C.Gold, width = 260 })
			end
			return
		end
		Kit.Label(body, "Raids are fought by up to 8 blades in their own realm. Open a lobby, or stand near a leader and join theirs.", { size = 13, color = C.Muted, wrap = true })
		for i, raidId in RaidConfig.RaidOrder do
			local def = RaidConfig.Raids[raidId]
			local row = Kit.Row(body, 64, i % 2 == 0)
			local stack = Kit.Stack(row)
			Kit.Label(stack, def.name, { bold = true })
			Kit.Label(stack, string.format("%s  Level %d+, %d-%d players", def.description, def.minLevel, def.minPlayers, RaidConfig.RaidSize), { size = 13, color = C.Muted })
			Kit.Button(row, "Open lobby", C.Blue, function()
				act("create", raidId)
			end, 140)
		end
		for i, l in st.lobbies or {} do
			local def = RaidConfig.Raids[l.raidId]
			local row = Kit.Row(body, 48, i % 2 == 1)
			Kit.Label(row, string.format("%s - led by %s (%d/%d)", def and def.name or l.raidId, l.leaderName, l.count, RaidConfig.RaidSize), { width = 360 })
			if not l.launching then
				Kit.Button(row, "Join", C.Good, function()
					act("join", l.id)
				end, 100)
			end
		end
	end,
}

return Panel
