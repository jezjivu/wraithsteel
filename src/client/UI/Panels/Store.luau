--!strict
-- Store panel (Jade Merchant / menu): game passes and developer products.
-- Prices come from Roblox (GetStoreInfo). No off-platform links. Items without a real id yet
-- show "Coming soon".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local UI = script.Parent.Parent
local Kit = require(UI:WaitForChild("Kit"))
local PanelTypes = require(UI:WaitForChild("PanelTypes"))

local C = Kit.Colors

local function sortedKeys(t: { [string]: any }): { string }
	local keys = {}
	for k in t do
		table.insert(keys, k)
	end
	table.sort(keys)
	return keys
end

local Panel: PanelTypes.Panel = {
	Title = "Jade Merchant",
	WatchKeys = { "giftedPasses", "jade" },
	Render = function(body, ctx)
		local info = Net.Client.Invoke("GetStoreInfo")
		if info == nil then
			Kit.Label(body, "The merchant is busy. Try again.", { color = C.Bad })
			return
		end
		if info.testMode then
			Kit.Label(body, "STUDIO TEST MODE - every purchase here is free and simulated (only in Studio). Passes last for this session.", { bold = true, size = 13, color = C.Good, wrap = true })
		end
		Kit.Label(body, "Game Passes", { bold = true, color = C.Gold })
		for i, key in sortedKeys(info.passes) do
			local p = info.passes[key]
			local row = Kit.Row(body, 60, i % 2 == 0)
			local st = Kit.Stack(row)
			Kit.Label(st, p.name, { bold = true })
			Kit.Label(st, p.description, { size = 13, color = C.Muted, wrap = true })
			if p.owned then
				Kit.Button(row, "Owned", C.Good, function() end, 130)
			elseif not p.available then
				Kit.Button(row, "Coming soon", C.Row, function() end, 130)
			else
				Kit.Button(row, if p.price then "R$ " .. p.price else "Buy", C.Jade, function()
					Net.Client.Fire("PromptPass", key)
				end, 130)
			end
		end
		Kit.Label(body, "Levels, Ember, Jade & Boosts", { bold = true, color = C.Gold })
		Kit.Label(body, "Jade can buy weapons and Jade Lanterns. Lantern odds are always shown before you open one.", { size = 13, color = C.Muted, wrap = true })
		local i = 0
		for _, key in sortedKeys(info.products) do
			local p = info.products[key]
			if p.kind ~= "GiftPass" then
				i += 1
				local row = Kit.Row(body, 52, i % 2 == 0)
				local st = Kit.Stack(row)
				Kit.Label(st, p.name, { bold = true })
				local desc = if p.kind == "Jade" then (p.amount or 0) .. " Jade"
					elseif p.kind == "Ember" then (p.amount or 0) .. " Ember"
					elseif p.kind == "Levels" then "+" .. (p.amount or 0) .. " level" .. (if (p.amount or 0) > 1 then "s" else "")
					elseif p.kind == "Bundle" and p.bundle then string.format("%d Jade + %d Ember + %d levels", p.bundle.jade or 0, p.bundle.ember or 0, p.bundle.levels or 0)
					else "Temporary boost"
				Kit.Label(st, desc, { size = 13, color = C.Muted })
				Kit.Button(row, if not p.available then "Coming soon" elseif p.price then "R$ " .. p.price else "Buy", if p.available then C.Jade else C.Row, function()
					if p.available then
						Net.Client.Fire("PromptProduct", key)
					end
				end, 130)
			end
		end
		local _ = ctx
	end,
}

return Panel
