--!strict
-- KunaiService: Shadow Kunai (B). A quick thrown blade: little damage, good posture damage,
-- interrupts flinching enemies and staggers beasts and drones. Charges (CombatConfig.Kunai)
-- refill when you rest at a waystone, respawn, or finish an enemy. Server-authoritative: the
-- client only sends an aim direction; targets come from server positions.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Net = require(Shared:WaitForChild("Net"))
local CombatConfig = require(Config:WaitForChild("CombatConfig"))

local CombatService = require(script.Parent.CombatService)

type Combatant = CombatService.Combatant

local KunaiService = { Name = "KunaiService", Priority = 37 }

local K = CombatConfig.Kunai
local readyAt: { [Player]: number } = {}

local function setCharges(c: Combatant, n: number)
	c.model:SetAttribute("Kunai", math.clamp(n, 0, K.charges))
end

local function charges(c: Combatant): number
	return tonumber(c.model:GetAttribute("Kunai")) or 0
end

-- First enemy along the throw (closest along the line within the corridor).
local function firstInLine(c: Combatant, dir: Vector3): (Combatant?, number)
	local origin = c.root.Position
	local best, bestAlong = nil, math.huge
	for _, e in CombatService.All() do
		if e.team == "Enemies" and not e.dead and e.humanoid.Health > 0 then
			local rel = e.root.Position - origin
			local along = rel:Dot(dir)
			if along > 0 and along <= K.range then
				local side = (rel - dir * along).Magnitude
				if side <= K.width + e.root.Size.X * 0.5 and along < bestAlong then
					best, bestAlong = e, along
				end
			end
		end
	end
	return best, bestAlong
end

local function onThrow(player: Player, aim: Vector3)
	local c = CombatService.GetByPlayer(player)
	if c == nil or c.dead or c.humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	local rules = c.rules
	if (readyAt[player] or 0) > now or (rules and now < rules.stunnedUntil) or charges(c) <= 0 then
		return
	end
	local flat = Vector3.new(aim.X, 0, aim.Z)
	if flat.Magnitude < 0.5 or flat.Magnitude > 1.5 then
		return
	end
	local dir = flat.Unit
	readyAt[player] = now + K.cooldown
	setCharges(c, charges(c) - 1)
	local target, dist = firstInLine(c, dir)
	local from = c.root.Position + Vector3.new(0, 1.5, 0)
	local to = if target then target.root.Position else from + dir * K.range
	Net.Server.FireAll("CombatEvent", { kind = "Kunai", sourceId = c.id, from = from, to = to, hit = target ~= nil })
	if target then
		local t = target
		task.delay(dist / K.speed, function()
			if t.dead or c.dead then
				return
			end
			local creature = t.model:GetAttribute("Creature") ~= nil
			CombatService.ApplyHit(c, t, {
				damage = K.damage,
				postureDamage = K.posture * (if creature then K.creaturePosture else 1),
				moveId = "shadow_kunai",
				source = "kunai",
				knockback = if creature then 10 else 3,
			})
			if creature then
				CombatService.Staggered:Fire(t, 0.8)
			end
		end)
	end
end

function KunaiService.Init() end

function KunaiService.Start()
	Net.Server.On("ThrowKunai", onThrow)
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			-- CombatService registers the character once the profile is ready.
			for _ = 1, 40 do
				task.wait(0.25)
				local c = CombatService.GetByPlayer(player)
				if c and c.model == character then
					setCharges(c, K.charges)
					return
				end
			end
		end)
		local c = CombatService.GetByPlayer(player)
		if c then
			setCharges(c, K.charges)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		readyAt[p] = nil
	end)
	CombatService.Rested:Connect(function(c: Combatant)
		if c.player then
			setCharges(c, K.charges)
		end
	end)
	CombatService.Died:Connect(function(target: Combatant, contributions: { [Player]: number })
		if target.team ~= "Enemies" then
			return
		end
		for player in contributions do
			local c = CombatService.GetByPlayer(player)
			if c and not c.dead then
				setCharges(c, charges(c) + K.refillOnKill)
			end
		end
	end)
end

return KunaiService
