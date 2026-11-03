--!strict
-- Bootstrap: the only server Script. Loads every ModuleScript in ServerScriptService.Services,
-- orders them by `Priority` (lower first, then by Name), calls Init() on all of them in order
-- (no yielding, no cross-service calls that need other services started), then Start() in the
-- same order. Each Start runs in its own thread so one yielding/erroring service cannot block
-- or break the rest.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

type Service = {
	Name: string,
	Priority: number?,
	Init: (() -> ())?,
	Start: (() -> ())?,
}

-- Remotes must exist before any client WaitForChild()s them.
Net.Server.Init()

local servicesFolder = script.Parent:WaitForChild("Services")
local services: { Service } = {}

for _, module in servicesFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" then
			result.Name = result.Name or module.Name
			table.insert(services, result :: Service)
		else
			warn("[Bootstrap] failed to load", module.Name, result)
		end
	end
end

table.sort(services, function(a, b)
	local pa, pb = a.Priority or 100, b.Priority or 100
	if pa == pb then
		return a.Name < b.Name
	end
	return pa < pb
end)

for _, service in services do
	if service.Init then
		local t0 = os.clock()
		local ok, err = pcall(service.Init :: any)
		if not ok then
			warn("[Bootstrap] Init failed:", service.Name, err)
		elseif os.clock() - t0 > 0.1 then
			warn("[Bootstrap] Init slow (>0.1s):", service.Name)
		end
	end
end

for _, service in services do
	if service.Start then
		task.spawn(function()
			local ok, err = pcall(service.Start :: any)
			if not ok then
				warn("[Bootstrap] Start failed:", service.Name, err)
			end
		end)
	end
end

print(string.format("[Bootstrap] %d services started", #services))
