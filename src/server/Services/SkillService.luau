--!strict
-- SkillService: the skill tree (SkillConfig / Shared/SkillLogic). Points come from your level;
-- learning a rank or resetting is validated here, then combat stats refresh right away.
--
-- API:
--   SkillService.Learn(player, skillId) -> (ok, message)
--   SkillService.Reset(player) -> (ok, message)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local SkillLogic = require(Shared:WaitForChild("SkillLogic"))
local SkillConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SkillConfig"))
local SpellConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SpellConfig"))

local DataService = require(script.Parent.DataService)
local CombatService = require(script.Parent.CombatService)

local SkillService = { Name = "SkillService", Priority = 35 }

local function skillsOf(data: any): { [string]: number }
	if type(data.skills) ~= "table" then
		data.skills = {}
	end
	return data.skills
end

-- Arts tied to skills you no longer have leave your art slots.
local function pruneArts(player: Player, data: any)
	local changed = false
	for i, id in data.spellLoadout do
		if id ~= "" and SpellConfig.Spells[id] and not SkillLogic.HasArt(data.skills, id) then
			data.spellLoadout[i] = ""
			changed = true
		end
	end
	if changed then
		DataService.Changed(player, "spellLoadout")
	end
end

function SkillService.Learn(player: Player, skillId: string): (boolean, string)
	local data = DataService.GetData(player)
	if data == nil then
		return false, "Loading..."
	end
	local skills = skillsOf(data)
	local ok, err = SkillLogic.Learn(skills, data.level, skillId)
	if not ok then
		return false, err or "Can't learn that"
	end
	DataService.Changed(player, "skills")
	CombatService.RefreshStats(player)
	local def = SkillConfig.Skills[skillId]
	if def.art then
		-- Drop a freshly learned art into an empty slot.
		for i = 1, SpellConfig.Slots do
			if (data.spellLoadout[i] or "") == "" then
				data.spellLoadout[i] = def.art
				DataService.Changed(player, "spellLoadout")
				break
			end
		end
		return true, "New art learned: " .. def.name .. " (set it in Arts)"
	end
	return true, string.format("%s %d/%d", def.name, skills[skillId], def.maxRank)
end

function SkillService.Reset(player: Player): (boolean, string)
	local data = DataService.GetData(player)
	if data == nil then
		return false, "Loading..."
	end
	local refunded = SkillLogic.Spent(skillsOf(data))
	if refunded == 0 then
		return false, "No skills to reset"
	end
	data.skills = {}
	DataService.Changed(player, "skills")
	pruneArts(player, data)
	CombatService.RefreshStats(player)
	return true, refunded .. " skill points returned"
end

function SkillService.Init() end

function SkillService.Start()
	Net.Server.OnInvoke("LearnSkill", SkillService.Learn)
	Net.Server.OnInvoke("ResetSkills", SkillService.Reset)
	local function clean(player: Player)
		local data = DataService.GetData(player)
		if data then
			SkillLogic.Sanitize(skillsOf(data))
			-- Over-spent (config changed): start the tree over rather than keep illegal ranks.
			if SkillLogic.Available(data.level, data.skills) < 0 then
				data.skills = {}
			end
			pruneArts(player, data)
		end
	end
	DataService.ProfileLoaded:Connect(clean)
	for _, p in Players:GetPlayers() do
		clean(p)
	end
end

return SkillService
