-- Content added with the UI pass: raid boss Kurozuma, Tidewater Spirits + lantern.
local RS = game:GetService("ReplicatedStorage")
local BossConfig = require(RS.Config.BossConfig)
local SpiritConfig = require(RS.Config.SpiritConfig)
local LanternConfig = require(RS.Config.LanternConfig)
local RaidConfig = require(RS.Config.RaidConfig)
local HubConfig = require(RS.Config.HubConfig)
local LanternOdds = require(RS.Shared.LanternOdds)

local cases = {}

cases["Bosses: every phase move exists, thresholds descend"] = function()
	for id, def in BossConfig.Bosses do
		local last = 2
		for _, phase in def.phases do
			expectTrue(phase.hpThreshold < last, id .. " thresholds descend")
			last = phase.hpThreshold
			for _, m in phase.moves do
				expectTrue(def.moves[m] ~= nil, id .. " phase move " .. m)
			end
		end
	end
end

cases["Raid: Kurozuma is a Raid boss and the raid uses it"] = function()
	local k = BossConfig.Bosses.kurozuma
	expectTrue(k ~= nil)
	expectEq(k.kind, "Raid")
	expectEq(RaidConfig.Raids.sunken_bell_vigil.bossId, "kurozuma")
	expectTrue(#k.phases == 3)
end

cases["Tidewater: Spirits have abilities, lantern odds are exact and shown at the shrine"] = function()
	for _, id in { "drift_jelly", "ledger_crab", "salt_kite", "bellwater_koi", "deep_toll_eel" } do
		local s = SpiritConfig.Spirits[id]
		expectTrue(s ~= nil, id)
		expectTrue(SpiritConfig.Abilities[s.ability] ~= nil, id .. " ability")
		for stat in s.stats do
			expectTrue(SpiritConfig.StatInfo[stat] ~= nil, id .. " stat " .. stat)
		end
	end
	local sheet = LanternOdds.Sheet("tidewater_lantern", 1, 0)
	local total = 0
	for _, r in sheet.spirits do
		total += r.percent
	end
	expectNear(total, 100, 1e-6)
	expectTrue(sheet.pity ~= nil and sheet.pityOdds ~= nil)
	expectTrue(table.find(HubConfig.ShrineLanterns, "tidewater_lantern") ~= nil)
	expectTrue(LanternOdds.IsPaid("tidewater_lantern"), "Ember is sold for Robux -> paid randomness")
	expectEq(LanternConfig.Lanterns.tidewater_lantern.chapter, 1)
end

return cases
