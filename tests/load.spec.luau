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
			if look.build then
				expectTrue(require(Config.EnemyConfig).Builds[look.build] ~= nil, id .. " build " .. look.build)
			end
		end
	end
end

cases["Every Spirit has a visual"] = function()
	local SpiritConfig = require(Config.SpiritConfig)
	for id, s in SpiritConfig.Spirits do
		expectTrue(s.visual ~= nil and s.visual.size > 0, id)
	end
end

cases["Every animation style named in configs exists"] = function()
	local A = require(Config.AnimationConfig)
	local function check(where, style)
		if style then
			expectTrue(A.Styles[style] ~= nil, where .. " style " .. tostring(style))
		end
	end
	for id, def in require(Config.EnemyConfig).Enemies do
		for aid, atk in def.attacks or {} do
			if not def.creature then
				check(id .. "." .. aid, atk.style)
			end
		end
	end
	for id, def in require(Config.BossConfig).Bosses do
		for mid, mv in def.moves do
			check(id .. "." .. mid, mv.style)
		end
	end
	for moveId, style in A.MoveStyles do
		check(moveId, style)
	end
	for kind, style in A.CastStyles do
		check("cast " .. kind, style)
	end
	for class, stance in A.StanceByClass do
		expectTrue(A.Stances[stance] ~= nil, class .. " stance")
	end
end

return cases
