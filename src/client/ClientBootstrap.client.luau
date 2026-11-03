--!strict
-- ClientBootstrap: the only client LocalScript. Loads every ModuleScript in
-- StarterPlayerScripts.Controllers, orders by Priority then Name, calls Init() then Start().
-- Mirrors the server Bootstrap so both sides follow one pattern.

type Controller = {
	Name: string,
	Priority: number?,
	Init: (() -> ())?,
	Start: (() -> ())?,
}

local controllersFolder = script.Parent:WaitForChild("Controllers")
local controllers: { Controller } = {}

for _, module in controllersFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" then
			result.Name = result.Name or module.Name
			table.insert(controllers, result :: Controller)
		else
			warn("[ClientBootstrap] failed to load", module.Name, result)
		end
	end
end

table.sort(controllers, function(a, b)
	local pa, pb = a.Priority or 100, b.Priority or 100
	if pa == pb then
		return a.Name < b.Name
	end
	return pa < pb
end)

for _, c in controllers do
	if c.Init then
		local ok, err = pcall(c.Init :: any)
		if not ok then
			warn("[ClientBootstrap] Init failed:", c.Name, err)
		end
	end
end

for _, c in controllers do
	if c.Start then
		task.spawn(function()
			local ok, err = pcall(c.Start :: any)
			if not ok then
				warn("[ClientBootstrap] Start failed:", c.Name, err)
			end
		end)
	end
end
