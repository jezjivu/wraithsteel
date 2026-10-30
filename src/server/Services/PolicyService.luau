--!strict
-- PolicyService: caches Roblox PolicyService:GetPolicyInfoForPlayerAsync per player.
-- On failure we assume the MOST restrictive policy (paid random items restricted, no paid
-- trading) until a retry succeeds. Every paid random item and trade checks this server-side.
--
-- API:
--   PolicyService.Get(player) -> Policy
--   PolicyService.CanBuyPaidRandomItems(player) -> boolean
--   PolicyService.CanTradePaidItems(player) -> boolean
--   PolicyService.WaitFor(player, timeout?) -> Policy

local Players = game:GetService("Players")
local RobloxPolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

export type Policy = {
	loaded: boolean,
	arePaidRandomItemsRestricted: boolean,
	isPaidItemTradingAllowed: boolean,
	isSubjectToChinaPolicies: boolean,
	allowedExternalLinkReferences: { string },
}

local RESTRICTIVE: Policy = table.freeze({
	loaded = false,
	arePaidRandomItemsRestricted = true,
	isPaidItemTradingAllowed = false,
	isSubjectToChinaPolicies = true,
	allowedExternalLinkReferences = {},
})

local RETRIES = 4

local PolicyService = { Name = "PolicyService", Priority = 1 }

local cache: { [Player]: Policy } = {}

local function fetch(player: Player)
	for attempt = 1, RETRIES do
		local ok, info = pcall(RobloxPolicyService.GetPolicyInfoForPlayerAsync, RobloxPolicyService, player)
		if ok and type(info) == "table" then
			local policy: Policy = {
				loaded = true,
				arePaidRandomItemsRestricted = info.ArePaidRandomItemsRestricted == true,
				isPaidItemTradingAllowed = info.IsPaidItemTradingAllowed == true,
				isSubjectToChinaPolicies = info.IsSubjectToChinaPolicies == true,
				allowedExternalLinkReferences = info.AllowedExternalLinkReferences or {},
			}
			if player.Parent == Players then
				cache[player] = policy
				-- Client uses these only to hide UI; the server re-checks every action.
				Net.Server.Fire("PolicyFlags", player, {
					paidRandomItemsRestricted = policy.arePaidRandomItemsRestricted,
					paidItemTradingAllowed = policy.isPaidItemTradingAllowed,
				})
			end
			return
		end
		task.wait(2 ^ attempt)
		if player.Parent ~= Players then
			return
		end
	end
	warn("[PolicyService] could not load policy for", player.UserId, "- staying restrictive")
end

function PolicyService.Get(player: Player): Policy
	return cache[player] or RESTRICTIVE
end

function PolicyService.WaitFor(player: Player, timeout: number?): Policy
	local deadline = os.clock() + (timeout or 5)
	while cache[player] == nil and os.clock() < deadline and player.Parent == Players do
		task.wait(0.1)
	end
	return PolicyService.Get(player)
end

function PolicyService.CanBuyPaidRandomItems(player: Player): boolean
	return not PolicyService.Get(player).arePaidRandomItemsRestricted
end

function PolicyService.CanTradePaidItems(player: Player): boolean
	return PolicyService.Get(player).isPaidItemTradingAllowed
end

function PolicyService.Init() end

function PolicyService.Start()
	Players.PlayerAdded:Connect(function(player)
		fetch(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		cache[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(fetch, player)
	end
end

return PolicyService
