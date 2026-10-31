--!strict
-- InputController: maps keyboard/mouse, gamepad and touch input to combat actions
-- (InputConfig.Bindings) via ContextActionService. Emits ActionPressed(action); it never talks
-- to the server itself (CombatController does).
--
-- API:
--   InputController.ActionPressed: Signal(action: string)
--   InputController.SetEnabled(enabled)   -- disable during dialogue/menus

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared:WaitForChild("Signal"))
local InputConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("InputConfig"))

local InputController = {
	Name = "InputController",
	Priority = 10,
	ActionPressed = Signal.new(),
	ActionReleased = Signal.new(), -- (action) on key/button release (hold-to-guard)
}

local enabled = true
local BIND_PREFIX = "Wraithsteel_"

local function handler(actionName: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		-- Releases always go through (a guard must never stay stuck up).
		InputController.ActionReleased:Fire(string.sub(actionName, #BIND_PREFIX + 1))
		return Enum.ContextActionResult.Pass
	end
	if not enabled then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		InputController.ActionPressed:Fire(string.sub(actionName, #BIND_PREFIX + 1))
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

function InputController.SetEnabled(value: boolean)
	enabled = value
end

function InputController.Init() end

function InputController.Start()
	for action, binding in InputConfig.Bindings do
		ContextActionService:BindAction(BIND_PREFIX .. action, handler, binding.touchButton, table.unpack(binding.inputs))
		if binding.touchButton then
			ContextActionService:SetTitle(BIND_PREFIX .. action, binding.title)
			-- TODO(Studio/Agent D): SetPosition/SetImage for touch buttons once the HUD layout exists.
		end
	end
end

return InputController
