--!strict
-- Expeditions panel: send idle Spirits on timed routes, claim when they return.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local Time = require(Shared:WaitForChild("Time"))
local FormatNumber = require(Shared:WaitForChild("FormatNumber"))
local ExpeditionConfig = require(Config:WaitForChild("ExpeditionConfig"))
local SpiritConfig = require(Config:WaitForChild("SpiritConfig"))

local UI = script.Parent.Parent
local Kit = require(UI:WaitForChild("Kit"))
local PanelTypes = require(UI:WaitForChild("PanelTypes"))
local DataController = require(UI.Parent:WaitForChild("Controllers"):WaitForChild("DataController"))

local C = Kit.Colors

-- Strongest Spirits that are neither equipped nor already away.
local function bestIdle(count: number): { string }
	local spirits = DataController.Get("spirits") or {}
	local equipped = DataController.Get("equippedSpirits") or {}
	local away = {}
	for _, e in DataController.Get("expeditions") or {} do
		for _, uid in e.spiritUids do
			away[uid] = true
		end
	end
	local list = {}
	for uid, s in spirits do
		if not away[uid] and table.find(equipped, uid) == nil then
			table.insert(list, { uid = uid, power = SpiritConfig.PowerOf(s.id, s.rarity, s.mutation, s.level) })
		end
	end
	table.sort(list, function(a, b)
		return a.power > b.power
	end)
	local out = {}
	for i = 1, math.min(count, #list) do
		table.insert(out, list[i].uid)
	end
	return out
end

local function routeIds(): { string }
	local ids = {}
	for id in ExpeditionConfig.Routes do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return ExpeditionConfig.Routes[a].durationSeconds < ExpeditionConfig.Routes[b].durationSeconds
	end)
	return ids
end

local Panel: PanelTypes.Panel = {
	Title = "Expedition Board",
	WatchKeys = { "expeditions", "spirits", "equippedSpirits", "chapter" },
	Render = function(body, ctx)
		local exps = DataController.Get("expeditions") or {}
		local chapter = DataController.Get("chapter") or 0
		Kit.Label(body, "Send Spirits that are not equipped. They earn Ember and Spirit XP while you play or rest.", { size = 14, color = C.Muted, wrap = true })
		local slots = table.clone(ExpeditionConfig.SlotIds)
		table.insert(slots, ExpeditionConfig.ExtraSlotWithPass)
		for i, slotId in slots do
			local e = exps[slotId]
			local eligible = {}
			for _, routeId in routeIds() do
				if ExpeditionConfig.Routes[routeId].chapter <= chapter then
					table.insert(eligible, routeId)
				end
			end
			local row = Kit.Row(body, 64, i % 2 == 0)
			local info = Kit.Stack(row, if e then -150 else -(#eligible * 150 + 10))
			local slotName = if slotId == ExpeditionConfig.ExtraSlotWithPass then "Slot 3 (Long Road pass)" else "Slot " .. i
			if e then
				local route = ExpeditionConfig.Routes[e.id]
				local left = e.endsAt - os.time()
				Kit.Label(info, slotName .. ": " .. (if route then route.name else e.id), { bold = true })
				Kit.Label(info, string.format("%d Spirits · %s", #e.spiritUids, if left > 0 then "returns in " .. Time.FormatDuration(left) else "back home!"), { size = 13, color = C.Muted })
				Kit.Button(row, if left > 0 then "Exploring..." else "Claim", if left > 0 then C.Row else C.Good, function()
					local result, err = Net.Client.Invoke("ClaimExpedition", slotId)
					if result then
						ctx.notify(string.format("+%s Ember, +%d Spirit XP", FormatNumber.Short(result.ember), result.spiritXp))
					else
						ctx.notify(err or "Not yet", true)
					end
				end, 130)
			else
				Kit.Label(info, slotName .. ": free", { bold = true })
				Kit.Label(info, "Pick a route to send your best idle Spirits.", { size = 12, color = C.Muted, wrap = true })
				for _, routeId in eligible do
					local route = ExpeditionConfig.Routes[routeId]
					do
						local b = Kit.Button(row, route.name .. "\n" .. Time.FormatDuration(route.durationSeconds), C.Blue, function()
							local uids = bestIdle(route.maxSpirits)
							if #uids == 0 then
								ctx.notify("No idle Spirits. Unequip some first.", true)
								return
							end
							local ok, err = Net.Client.Invoke("StartExpedition", slotId, routeId, uids)
							ctx.notify(if ok then "Expedition started!" else err or "Could not start", not ok)
						end, 140)
						b.Size = UDim2.fromOffset(140, 44)
						b.TextSize = 13
					end
				end
			end
		end
	end,
}

return Panel
