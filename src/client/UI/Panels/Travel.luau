--!strict
-- Travel panel (rest at a waystone, or from the menu): fast travel between attuned waystones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local UI = script.Parent.Parent
local Kit = require(UI:WaitForChild("Kit"))
local PanelTypes = require(UI:WaitForChild("PanelTypes"))
local DataController = require(UI.Parent:WaitForChild("Controllers"):WaitForChild("DataController"))

local C = Kit.Colors

local REALM_NAMES = { japan = "Ashen Valley", neon = "Neon Verge", greek = "Aeloria" }

local Panel: PanelTypes.Panel = {
	Title = "Waystones",
	WatchKeys = { "waystones", "respawnWaystone" },
	Render = function(body, ctx)
		local attuned = DataController.Get("waystones") or {}
		local respawn = DataController.Get("respawnWaystone") or "hub"
		Kit.Label(body, "Rest at a waystone to heal, refill your flask and set your respawn point. Attuned waystones can be travelled to (not during a fight).", { size = 13, color = C.Muted, wrap = true })
		local dir = ReplicatedStorage:FindFirstChild("WaystoneDirectory")
		if dir == nil then
			Kit.Label(body, "Waystones are still being placed...", { color = C.Muted })
			return
		end
		local list = dir:GetChildren()
		local REALM_ORDER = { japan = 1, neon = 2, greek = 3 }
		table.sort(list, function(a, b)
			local ra = REALM_ORDER[tostring(a:GetAttribute("Realm"))] or 9
			local rb = REALM_ORDER[tostring(b:GetAttribute("Realm"))] or 9
			if ra ~= rb then
				return ra < rb
			end
			return (tonumber(a:GetAttribute("Order")) or 0) < (tonumber(b:GetAttribute("Order")) or 0)
		end)
		local lastRealm = nil
		for i, entry in list do
			local realm = tostring(entry:GetAttribute("Realm") or "japan")
			if realm ~= lastRealm then
				lastRealm = realm
				Kit.Label(body, REALM_NAMES[realm] or realm, { bold = true, color = C.Gold })
			end
			local id = entry.Name
			local open = attuned[id] == true
			local row = Kit.Row(body, 44, i % 2 == 0)
			local name = tostring(entry:GetAttribute("DisplayName") or id)
			Kit.Label(row, (if id == respawn then "★ " else "") .. name, { bold = open, color = if open then C.Text else C.Muted, width = 300 })
			if open then
				Kit.Button(row, "Travel", C.Blue, function()
					local ok, err = Net.Client.Invoke("TravelWaystone", id)
					if ok then
						ctx.close()
					else
						ctx.notify(err or "Can't travel now", true)
					end
				end, 100)
			else
				Kit.Label(row, "not attuned", { size = 12, color = C.Muted, width = 120 })
			end
		end
	end,
}

return Panel
