--!strict
-- WorldBossService: timed open-world bosses (WorldBossConfig). Announces a warning, spawns the
-- next boss in the rotation as an open-world BossService encounter (anyone nearby joins,
-- rewards by contribution), despawns it if not defeated in time, then waits for the next slot.
-- Spawn points: Workspace.WorldBossSpawns/<Part> (random pick); falls back to DefaultSpawn.
--
-- API:
--   WorldBossService.NextSpawnAt() -> number   (os.time of the next spawn, or 0 while active)
--   WorldBossService.Active() -> string?        (bossId while a world boss is up)
--   WorldBossService.SpawnNow() -> boolean      (debug: spawn immediately)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local Time = require(Shared:WaitForChild("Time"))
local WorldBossConfig = require(Config:WaitForChild("WorldBossConfig"))
local BossConfig = require(Config:WaitForChild("BossConfig"))

local BossService = require(script.Parent.BossService)

local WorldBossService = { Name = "WorldBossService", Priority = 53 }

local nextSpawnAt = 0
local activeBoss: string? = nil
local rotationIndex = 0

function WorldBossService.NextSpawnAt(): number
	return nextSpawnAt
end

function WorldBossService.Active(): string?
	return activeBoss
end

local function spawnCFrame(): CFrame
	local folder = workspace:FindFirstChild(WorldBossConfig.SpawnFolderName)
	if folder then
		local parts = {}
		for _, p in folder:GetChildren() do
			if p:IsA("BasePart") then
				table.insert(parts, p)
			end
		end
		if #parts > 0 then
			return parts[math.random(1, #parts)].CFrame + Vector3.new(0, 4, 0)
		end
	end
	local d = WorldBossConfig.DefaultSpawn
	return CFrame.new(d[1], d[2], d[3])
end

local function announce(text: string)
	Net.Server.FireAll("Notify", "WorldBoss", text)
end

local function cycle(skipWarning: boolean?)
	rotationIndex = rotationIndex % #WorldBossConfig.Rotation + 1
	local bossId = WorldBossConfig.Rotation[rotationIndex]
	local def = BossConfig.Bosses[bossId]
	if def == nil then
		warn("[WorldBossService] unknown boss in rotation", bossId)
		return
	end
	if not skipWarning then
		announce(string.format("%s stirs in the Wilds... (%s)", def.name, Time.FormatDuration(WorldBossConfig.WarningSeconds)))
		task.wait(WorldBossConfig.WarningSeconds)
	end

	local id = BossService.StartEncounter(bossId, spawnCFrame(), {}, nil, {
		joinRadius = WorldBossConfig.JoinRadius,
		minContribution = WorldBossConfig.MinContribution,
		durationSeconds = WorldBossConfig.DespawnSeconds,
	})
	if id == nil then
		return
	end
	activeBoss = bossId
	nextSpawnAt = 0
	announce(def.name .. " has awakened in the Wilds! Everyone nearby can join the fight.")
	while BossService.IsActive(id) do
		task.wait(2)
	end
	activeBoss = nil
end

-- Spawns the next world boss right away (Studio debug command); no-op while one is active.
function WorldBossService.SpawnNow(): boolean
	if activeBoss then
		return false
	end
	task.spawn(cycle, true)
	return true
end

function WorldBossService.Init() end

function WorldBossService.Start()
	if #WorldBossConfig.Rotation == 0 then
		-- No world bosses: clear spawn points left in older saved worlds.
		local old = workspace:FindFirstChild(WorldBossConfig.SpawnFolderName)
		if old then
			old:Destroy()
		end
		return
	end
	task.spawn(function()
		nextSpawnAt = os.time() + WorldBossConfig.FirstSpawnSeconds
		task.wait(math.max(0, WorldBossConfig.FirstSpawnSeconds - WorldBossConfig.WarningSeconds))
		while true do
			local ok, err = pcall(cycle :: any)
			if not ok then
				warn("[WorldBossService] cycle failed:", err)
				activeBoss = nil
			end
			nextSpawnAt = os.time() + WorldBossConfig.IntervalSeconds
			task.wait(math.max(1, WorldBossConfig.IntervalSeconds - WorldBossConfig.WarningSeconds))
		end
	end)
end

return WorldBossService
