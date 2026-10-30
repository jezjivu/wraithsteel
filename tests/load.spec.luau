-- Every Config module must load outside Roblox (catches typos/nil indexing in data files).
-- InputConfig is skipped because it needs Roblox Enums.
local Config = game:GetService("ReplicatedStorage").Config

local cases = {}

cases["All Config modules load"] = function()
	local loaded = 0
	for _, module in Config:GetChildren() do
		if module.Name ~= "InputConfig" then
			local ok, err = pcall(require, module)
			expectTrue(ok, module.Name .. ": " .. tostring(err))
			loaded += 1
		end
	end
	expectTrue(loaded >= 18, "expected the full config set, got " .. loaded)
end

cases["Every enemy/boss rig look references a real weapon"] = function()
	local WeaponConfig = require(Config.WeaponConfig)
	for _, cfg in { require(Config.EnemyConfig).Enemies, require(Config.BossConfig).Bosses } do
		for id, def in cfg do
			local look = def.look
			expectTrue(look ~= nil, id .. " needs a look")
			if look.weapon then
				expectTrue(WeaponConfig.Weapons[look.weapon] ~= nil, id .. " weapon " .. look.weapon)
			end
			expectTrue(look.scale > 0, id)
		end
	end
end

cases["Every Spirit has a visual"] = function()
	local SpiritConfig = require(Config.SpiritConfig)
	for id, s in SpiritConfig.Spirits do
		expectTrue(s.visual ~= nil and s.visual.size > 0, id)
	end
end

return cases
