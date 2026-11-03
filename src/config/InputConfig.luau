--!strict
-- InputConfig: default bindings for every combat action (keyboard/mouse, gamepad, touch).
-- InputController binds these through ContextActionService. Owner: Agent B.

export type Binding = { inputs: { any }, touchButton: boolean, title: string }

local InputConfig = {}

-- Each action lists every input that triggers it. Touch buttons are created by
-- ContextActionService when `touchButton` is true; their layout is a Studio/UI task.
InputConfig.Bindings = {
	LightAttack = { inputs = { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2 }, touchButton = true, title = "Strike" },
	HeavyAttack = { inputs = { Enum.KeyCode.R, Enum.KeyCode.ButtonR1 }, touchButton = true, title = "Heavy" },
	Parry = { inputs = { Enum.KeyCode.F, Enum.KeyCode.ButtonL1 }, touchButton = true, title = "Parry" },
	Dodge = { inputs = { Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl, Enum.KeyCode.ButtonB }, touchButton = true, title = "Dodge" },
	Skill1 = { inputs = { Enum.KeyCode.One, Enum.KeyCode.ButtonX }, touchButton = true, title = "Skill 1" },
	Skill2 = { inputs = { Enum.KeyCode.Two, Enum.KeyCode.ButtonY }, touchButton = true, title = "Skill 2" },
	Ultimate = { inputs = { Enum.KeyCode.G, Enum.KeyCode.ButtonL2 }, touchButton = true, title = "Ultimate" },
	Flask = { inputs = { Enum.KeyCode.Q, Enum.KeyCode.ButtonSelect }, touchButton = true, title = "Flask" },
	SpiritCall = { inputs = { Enum.KeyCode.T, Enum.KeyCode.DPadUp }, touchButton = true, title = "Burst" },
	-- Shadow Kunai (KunaiController).
	Kunai = { inputs = { Enum.KeyCode.B }, touchButton = true, title = "Kunai" },
	-- Grappling hook (MovementController / GrappleController; not a combat action).
	Grapple = { inputs = { Enum.KeyCode.V }, touchButton = true, title = "Hook" }, -- gamepad: every button is taken; touch gets a button
	-- Qi arts (SpellController handles these; CombatController ignores them).
	Spell1 = { inputs = { Enum.KeyCode.Z, Enum.KeyCode.DPadLeft }, touchButton = true, title = "Art 1" },
	Spell2 = { inputs = { Enum.KeyCode.X, Enum.KeyCode.DPadRight }, touchButton = true, title = "Art 2" },
	Spell3 = { inputs = { Enum.KeyCode.C, Enum.KeyCode.DPadDown }, touchButton = true, title = "Art 3" },
} :: { [string]: Binding }

-- Client-side input buffer: a press during a move is remembered this long and re-sent when
-- the move ends (makes combos feel responsive while the server stays authoritative).
InputConfig.BufferSeconds = 0.25

return InputConfig
