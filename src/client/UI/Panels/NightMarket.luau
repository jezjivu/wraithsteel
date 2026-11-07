--!strict
-- Night Market panel: four fixed-price items that rotate every 10 minutes (same on every server).
-- Nothing here is random: each card says exactly what you get.
-- TODO(Studio/Agent D): real stall art, item icons (Spirit viewports already exist in Kit).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local FormatNumber = require(Shared:WaitForChild("FormatNumber"))
local Time = require(Shared:WaitForChild("Time"))
local NightMarketConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("NightMarketConfig"))

local UI = script.Parent.Parent
local Kit = require(UI:WaitForChild("Kit"))
local PanelTypes = require(UI:WaitForChild("PanelTypes"))

local C = Kit.Colors

local Panel: PanelTypes.Panel = {
	Title = "Night Market",
	WatchKeys = { "nightMarket", "ember", "jade", "chapter" },
	Render = function(body, ctx)
		local info = Net.Client.Invoke("GetNightMarket")
		if type(info) ~= "table" then
			Kit.Label(body, "The market is setting up...", { color = C.Muted })
			return
		end
		local left = math.max(0, info.endsAt - Time.Now())
		Kit.Label(body, "New stock in " .. Time.FormatDuration(left) .. " - the same stalls on every server.", { color = C.Muted, wrap = true })
		for i, entry in info.stock do
			local def = NightMarketConfig.Items[entry.itemId]
			if def then
				local row = Kit.Row(body, 64, i % 2 == 0)
				local stack = Kit.Stack(row)
				Kit.Label(stack, def.name, { bold = true })
				Kit.Label(stack, def.description .. string.format("  (%d/%d bought)", entry.bought, def.limit), { size = 13, color = C.Muted })
				local soldOut = entry.bought >= def.limit
				local label = if soldOut then "Sold out" else FormatNumber.Commas(def.price) .. " " .. def.currency
				Kit.Button(row, label, if soldOut then C.Steel elseif def.currency == "Jade" then C.Jade else C.Gold, function()
					if soldOut then
						return
					end
					local ok, msg = Net.Client.Invoke("BuyNightMarket", entry.slot, info.window)
					ctx.notify(msg or "Try again", not ok)
					ctx.refresh()
				end, 160)
			end
		end
	end,
}

return Panel
