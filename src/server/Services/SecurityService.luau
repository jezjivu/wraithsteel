--!strict
-- SecurityService: anti-exploit telemetry (rules in Logic/ExploitScore, numbers in
-- ServerConfig/SecurityConfig).
--   * every Net.Rejected (rate limit / bad arguments) adds to the player's decaying score
--   * HumanoidRootPart is sampled; sustained impossible speed adds to the score (no rubber-band)
--   * crossing FlagScore: one "SecurityFlag" analytics event + an Output warning per session
--   * crossing KickScore: kick (only sustained garbage traffic gets there)
--
-- API:
--   SecurityService.Report(player, reason)     add an event from any service (e.g. "speed")
--   SecurityService.Score(player) -> number

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local ServerRoot = script.Parent.Parent
local ExploitScore = require(ServerRoot:WaitForChild("Logic"):WaitForChild("ExploitScore"))
local SecurityConfig = require(ServerRoot:WaitForChild("ServerConfig"):WaitForChild("SecurityConfig"))
local AnalyticsService = require(script.Parent.AnalyticsService)

local SecurityService = { Name = "SecurityService", Priority = 7 }

local states: { [Player]: ExploitScore.State } = {}
local moves: { [Player]: ExploitScore.MoveState } = {}

function SecurityService.Score(player: Player): number
	local st = states[player]
	return if st then ExploitScore.Decayed(st, os.clock()) else 0
end

function SecurityService.Report(player: Player, reason: string, detail: string?)
	if player.Parent ~= Players then
		return
	end
	local st = states[player]
	if st == nil then
		st = ExploitScore.New(os.clock())
		states[player] = st
	end
	local verdict = ExploitScore.Add(st, reason, os.clock())
	if verdict == "flag" then
		warn(string.format("[SecurityService] flagged %s (%d): score %.0f, last %s %s", player.Name, player.UserId, st.score, reason, detail or ""))
		AnalyticsService.Custom(player, "SecurityFlag", math.floor(st.score))
	elseif verdict == "kick" then
		warn(string.format("[SecurityService] kicking %s (%d): score %.0f", player.Name, player.UserId, st.score))
		AnalyticsService.Custom(player, "SecurityKick", math.floor(st.score))
		player:Kick(SecurityConfig.KickMessage)
	end
end

local function sampleMovement()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			local p = root.Position
			local nextState, violation = ExploitScore.Move(moves[player], p.X, p.Y, p.Z, now)
			moves[player] = nextState
			if violation then
				nextState.fast = 0 -- one report per sustained burst
				SecurityService.Report(player, "speed", string.format("at %.0f,%.0f,%.0f", p.X, p.Y, p.Z))
			end
		else
			moves[player] = nil -- dead/respawning: the next spawn starts a fresh track
		end
	end
end

function SecurityService.Init() end

function SecurityService.Start()
	Net.Rejected:Connect(function(player: Player, remote: string, reason: string)
		SecurityService.Report(player, reason, remote)
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		moves[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(SecurityConfig.MoveSampleSeconds)
			sampleMovement()
		end
	end)
end

return SecurityService
