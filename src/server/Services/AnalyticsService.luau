--!strict
-- AnalyticsService: thin, failure-proof wrapper over Roblox AnalyticsService.
-- Funnel helper logs each onboarding step at most once per profile (stored in funnelSteps).
--
-- API:
--   AnalyticsService.Onboarding(player, step, stepName)   once per profile, in order
--   AnalyticsService.Funnel(player, funnelName, sessionId, step, stepName)
--   AnalyticsService.Economy(player, flow: "Source"|"Sink", currency, amount, balance, txType, sku)
--   AnalyticsService.Custom(player, eventName, value?)

local RobloxAnalytics = game:GetService("AnalyticsService")

local DataService = require(script.Parent.DataService)

local AnalyticsService = { Name = "AnalyticsService", Priority = 2 }

-- Onboarding steps (guide §11 retention funnel). Keep names stable for dashboards.
AnalyticsService.OnboardingSteps = {
	"Joined",
	"FirstEnemyDefeated",
	"FirstParry",
	"FirstLanternOpened",
	"FirstSpiritEquipped",
	"KagehisaDefeated",
	"Chapter1Entered",
}

local function safe(fn: () -> ())
	local ok, err = pcall(fn :: any)
	if not ok then
		warn("[AnalyticsService]", err)
	end
end

function AnalyticsService.Onboarding(player: Player, stepName: string)
	local step = table.find(AnalyticsService.OnboardingSteps, stepName)
	if step == nil then
		warn("[AnalyticsService] unknown onboarding step", stepName)
		return
	end
	local data = DataService.GetData(player)
	if data == nil or data.funnelSteps["Onboarding:" .. stepName] then
		return
	end
	data.funnelSteps["Onboarding:" .. stepName] = true
	safe(function()
		RobloxAnalytics:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
end

function AnalyticsService.Funnel(player: Player, funnelName: string, sessionId: string?, step: number, stepName: string)
	safe(function()
		RobloxAnalytics:LogFunnelStepEvent(player, funnelName, sessionId, step, stepName)
	end)
end

function AnalyticsService.Economy(
	player: Player,
	flow: "Source" | "Sink",
	currency: string,
	amount: number,
	balance: number,
	transactionType: string,
	sku: string?
)
	if amount <= 0 then
		return
	end
	safe(function()
		RobloxAnalytics:LogEconomyEvent(
			player,
			if flow == "Source" then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink,
			currency,
			amount,
			balance,
			transactionType,
			sku
		)
	end)
end

function AnalyticsService.Custom(player: Player, eventName: string, value: number?)
	safe(function()
		RobloxAnalytics:LogCustomEvent(player, eventName, value or 1)
	end)
end

function AnalyticsService.Init() end

function AnalyticsService.Start()
	DataService.ProfileLoaded:Connect(function(player)
		AnalyticsService.Onboarding(player, "Joined")
	end)
end

return AnalyticsService
