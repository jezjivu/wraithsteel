--!strict
-- CodeConfig: redeemable codes. Server-only (ServerScriptService) so clients cannot read them.
-- Codes are matched case-insensitively. expiresAt is a UTC os.time() or nil for no expiry.
-- Rewards never include paid random items.

export type CodeDef = {
	reward: { ember: number?, jade: number?, xp: number?, lantern: string? },
	expiresAt: number?,
	minLevel: number?,
}

local CodeConfig = {}

CodeConfig.Codes = {
	NINEGATES = { reward = { ember = 500, lantern = "paper_lantern" } },
	FIRSTBELL = { reward = { ember = 250, jade = 10 }, minLevel = 5 },
} :: { [string]: CodeDef }

return CodeConfig
