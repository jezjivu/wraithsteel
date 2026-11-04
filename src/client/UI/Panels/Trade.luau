--!strict
-- Trade panel: request trades with nearby players, pick Spirits to offer, confirm.
-- The server re-validates everything; changing an offer clears both confirmations.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpiritConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SpiritConfig"))

local UI = script.Parent.Parent
local Kit = require(UI:WaitForChild("Kit"))
local PanelTypes = require(UI:WaitForChild("PanelTypes"))
local Controllers = UI.Parent:WaitForChild("Controllers")
local TradeController = require(Controllers:WaitForChild("TradeController"))
local DataController = require(Controllers:WaitForChild("DataController"))

local C = Kit.Colors

local function spiritLine(s: { [string]: any }): (string, Color3)
	local def = SpiritConfig.Spirits[s.id]
	local rarity = SpiritConfig.Rarities[s.rarity]
	local mutation = if s.mutation ~= "None" then s.mutation .. " " else ""
	return string.format("%s%s · %s · Lv %d", mutation, if def then def.name else s.id, s.rarity, s.level), Kit.RarityColor(rarity and rarity.color)
end

local Panel: PanelTypes.Panel = {
	Title = "Trade",
	WatchKeys = { "spirits", "equippedSpirits" },
	Changed = TradeController.Changed,
	Render = function(body, ctx)
		local st = TradeController.State
		local function show(ok: boolean, msg: string?)
			if msg then
				ctx.notify(msg, not ok)
			end
		end
		if not st.allowed then
			Kit.Label(body, "Trading is not available for your account.", { color = C.Muted, wrap = true })
			return
		end
		for _, req in st.incoming or {} do
			local row = Kit.Row(body, 48)
			Kit.Label(row, req.name .. " wants to trade", { bold = true, width = 280 })
			Kit.Button(row, "Accept", C.Good, function()
				show(TradeController.Request(req.userId))
			end, 110)
		end

		if st.paidAllowed == false then
			Kit.Label(body, "Spirits from Ember/Jade lanterns cannot be traded on this account; free Spirits can.", { size = 13, color = C.Muted, wrap = true })
		end
		if not st.active then
			Kit.Label(body, "Stand near a player and send a request. Only Spirits can be traded; locked, equipped and expedition Spirits stay home.", { size = 13, color = C.Muted, wrap = true })
			local any = false
			for i, p in Players:GetPlayers() do
				if p ~= Players.LocalPlayer then
					any = true
					local row = Kit.Row(body, 46, i % 2 == 0)
					Kit.Label(row, p.DisplayName, { width = 300 })
					Kit.Button(row, "Request trade", C.Blue, function()
						show(TradeController.Request(p.UserId))
					end, 140)
				end
			end
			if not any then
				Kit.Label(body, "Nobody else is here yet.", { color = C.Muted })
			end
			return
		end

		-- Active session ---------------------------------------------------------------------
		Kit.Label(body, "Trading with " .. st.partnerName, { bold = true, size = 18, color = C.Gold })
		if st.countdown then
			Kit.Label(body, string.format("Both confirmed - swapping in %d seconds...", math.ceil(st.countdown)), { bold = true, color = C.Good })
		end
		Kit.Label(body, "They offer:" .. (if st.theirConfirmed then "  (confirmed)" else ""), { bold = true })
		if #st.theirOffer == 0 then
			Kit.Label(body, "  nothing yet", { color = C.Muted, size = 14 })
		end
		for _, s in st.theirOffer do
			local text, color = spiritLine(s)
			Kit.Label(body, "  " .. text, { color = color, size = 15 })
		end

		local offered: { [string]: boolean } = {}
		local offerList: { string } = {}
		for _, s in st.myOffer do
			offered[s.uid] = true
			table.insert(offerList, s.uid)
		end
		Kit.Label(body, "You offer:" .. (if st.myConfirmed then "  (confirmed)" else "") .. "  - click Spirits below to add/remove", { bold = true })
		local actions = Kit.Row(body, 48)
		Kit.Button(actions, if st.myConfirmed then "Unconfirm" else "Confirm", if st.myConfirmed then C.Row else C.Good, function()
			show(TradeController.Update(if st.myConfirmed then "unconfirm" else "confirm"))
		end, 130)
		Kit.Button(actions, "Cancel trade", C.Bad, function()
			show(TradeController.Update("cancel"))
		end, 130)

		local spirits = DataController.Get("spirits") or {}
		local equipped = DataController.Get("equippedSpirits") or {}
		local i = 0
		for uid, s in spirits do
			if not s.locked and table.find(equipped, uid) == nil then
				i += 1
				local row = Kit.Row(body, 42, i % 2 == 0)
				local text, color = spiritLine({ id = s.id, rarity = s.rarity, mutation = s.mutation, level = s.level })
				Kit.Label(row, text, { color = color, width = 340, size = 15 })
				local isOffered = offered[uid] == true
				Kit.Button(row, if isOffered then "Remove" else "Offer", if isOffered then C.Accent else C.Row, function()
					local list = table.clone(offerList)
					local idx = table.find(list, uid)
					if idx then
						table.remove(list, idx)
					else
						table.insert(list, uid)
					end
					show(TradeController.Update("offer", list))
				end, 100)
			end
		end
	end,
}

return Panel
