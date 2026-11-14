--!strict
-- Migrations: upgrades saved profiles to EconomyConfig.DataVersion.
-- Rules: never delete a migration; each migration takes data at version N-1 and returns it at N.
-- Add a new one by bumping EconomyConfig.DataVersion and appending Steps[newVersion].

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EconomyConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("EconomyConfig"))
local SpellConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SpellConfig"))

local Migrations = {}

Migrations.Steps = {
	-- v0 -> v1: profiles saved before dataVersion existed (pre-release test data).
	[1] = function(data: { [string]: any })
		data.receipts = data.receipts or {}
		data.receiptOrder = data.receiptOrder or {}
		if type(data.equippedSpirits) ~= "table" then
			data.equippedSpirits = {}
		end
	end,
	-- v1 -> v2: fighting styles.
	[2] = function(data: { [string]: any })
		if type(data.fightingStyle) ~= "string" then
			data.fightingStyle = "river"
		end
	end,
	-- v2 -> v3: Qi arts (spell slots).
	[3] = function(data: { [string]: any })
		if type(data.spellLoadout) ~= "table" then
			data.spellLoadout = table.clone(SpellConfig.DefaultLoadout)
		end
	end,
	-- v3 -> v4: waystones (rest / respawn / fast travel).
	[4] = function(data: { [string]: any })
		if type(data.waystones) ~= "table" then
			data.waystones = { hub = true }
		end
		if type(data.respawnWaystone) ~= "string" then
			data.respawnWaystone = "hub"
		end
		if type(data.saga) ~= "table" then
			data.saga = { quest = 1, step = 1, progress = 0, started = false }
		end
	end,
	-- v4 -> v5: the first boss was remade (rust_tiger -> kagehisa); keep earned unlocks.
	[5] = function(data: { [string]: any })
		local d = data.bossesDefeated
		if type(d) == "table" and d.rust_tiger then
			d.kagehisa = (d.kagehisa or 0) + d.rust_tiger
			d.rust_tiger = nil
		end
		local q = data.quests
		if type(q) == "table" and q.s_prologue_tiger then
			q.s_prologue_kagehisa = q.s_prologue_tiger
			q.s_prologue_tiger = nil
		end
	end,
	-- v5 -> v6: the first boss was remade again (bell_oni -> kagehisa).
	[6] = function(data: { [string]: any })
		local d = data.bossesDefeated
		if type(d) == "table" and d.bell_oni then
			d.kagehisa = (d.kagehisa or 0) + d.bell_oni
			d.bell_oni = nil
		end
		local q = data.quests
		if type(q) == "table" and q.s_prologue_oni then
			q.s_prologue_kagehisa = q.s_prologue_oni
			q.s_prologue_oni = nil
		end
	end,
	-- v6 -> v7: the first boss is Kagehisa now (bell_engine -> kagehisa); arts were reworked.
	[7] = function(data: { [string]: any })
		local d = data.bossesDefeated
		if type(d) == "table" and d.bell_engine then
			d.kagehisa = (d.kagehisa or 0) + d.bell_engine
			d.bell_engine = nil
		end
		local q = data.quests
		if type(q) == "table" and q.s_prologue_engine then
			q.s_prologue_kagehisa = q.s_prologue_engine
			q.s_prologue_engine = nil
		end
		data.spellLoadout = { "thousand_cuts", "ghost_step", "crescent_wave" }
	end,
	-- v7 -> v8: the skill tree (points come from your level, so nothing else to convert).
	[8] = function(data: { [string]: any })
		if type(data.skills) ~= "table" then
			data.skills = {}
		end
	end,
	-- v8 -> v9: shortcut gates and Ashen Relics.
	[9] = function(data: { [string]: any })
		data.shortcuts = if type(data.shortcuts) == "table" then data.shortcuts else {}
		data.relics = if type(data.relics) == "table" then data.relics else {}
	end,
	-- v9 -> v10: Ember dropped on death.
	[10] = function(data: { [string]: any })
		if type(data.lostEmber) ~= "table" then
			data.lostEmber = { amount = 0, x = 0, y = 0, z = 0 }
		end
	end,
	-- v10 -> v11: the Ashen Valley bosses were deleted; forget them.
	[11] = function(data: { [string]: any })
		local d = data.bossesDefeated
		if type(d) == "table" then
			for _, id in { "sable_crane", "hollow_abbot", "twin_cinder_sisters", "rustwood_matriarch", "gatekeeper_of_rust", "hollow_carillon", "kagehisa", "bell_engine", "bell_oni", "rust_tiger" } do
				d[id] = nil
			end
		end
	end,
} :: { [number]: (data: { [string]: any }) -> () }

-- Returns true if data was migrated. Errors if data is from a NEWER version (a newer server
-- wrote it); DataService must then kick the player rather than risk overwriting newer data.
function Migrations.Run(data: { [string]: any }): boolean
	local from = data.dataVersion or 0
	local target = EconomyConfig.DataVersion
	if from > target then
		error(string.format("profile dataVersion %d is newer than server %d", from, target))
	end
	if from == target then
		return false
	end
	for v = from + 1, target do
		local step = Migrations.Steps[v]
		assert(step, "missing migration step " .. v)
		step(data)
		data.dataVersion = v
	end
	return true
end

return Migrations
