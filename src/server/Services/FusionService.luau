--!strict
-- FusionService: deterministic Spirit fusion (rules in Logic/SpiritLogic.PlanFusion).
-- No randomness is involved, so there is nothing to disclose; the UI can preview the exact
-- result by calling SpiritLogic rules mirrored in its own preview text.
--
-- API:
--   FusionService.Fuse(player, uids) -> (SpiritInstance?, reason?)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local SpiritLogic = require(script.Parent.Parent:WaitForChild("Logic"):WaitForChild("SpiritLogic"))
local TradeLock = require(script.Parent.Parent:WaitForChild("Logic"):WaitForChild("TradeLock"))
local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local QuestService = require(script.Parent.QuestService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local FusionService = { Name = "FusionService", Priority = 22 }

function FusionService.Fuse(player: Player, uids: { string }): (any, string?)
	if TradeLock.IsLocked(player.UserId) then
		return nil, TradeLock.Message
	end
	local data = DataService.GetData(player)
	if data == nil then
		return nil, "Loading..."
	end
	local plan, err = SpiritLogic.PlanFusion(data :: any, uids)
	if plan == nil then
		return nil, err
	end
	local inst = SpiritLogic.ApplyFusion(data :: any, plan, os.time())
	DataService.Changed(player, "spirits", "ember")
	ProgressionService.RefreshPower(player)
	QuestService.Increment(player, "Fusions", 1)
	AnalyticsService.Economy(player, "Sink", "Ember", plan.cost, data.ember, "Gameplay", "Fusion:" .. plan.toRarity)
	return inst, nil
end

function FusionService.Init() end

function FusionService.Start()
	Net.Server.OnInvoke("FuseSpirits", FusionService.Fuse)
end

return FusionService
