--!strict
-- WeaponLogic: pure purchase rules for the Weapon Smith (fixed prices, chapter gating).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Config")
local WeaponConfig = require(Config:WaitForChild("WeaponConfig"))
local ChapterConfig = require(Config:WaitForChild("ChapterConfig"))

local WeaponLogic = {}

export type WeaponData = {
	weapons: { [string]: boolean },
	chapter: number,
	ember: number,
	jade: number,
}

function WeaponLogic.CanBuy(data: WeaponData, weaponId: string): (boolean, string?)
	local def = WeaponConfig.Weapons[weaponId]
	if def == nil then
		return false, "Unknown weapon"
	end
	if data.weapons[weaponId] then
		return false, "You already own this weapon"
	end
	if data.chapter < def.unlockChapter then
		local chapter = ChapterConfig.Chapters[def.unlockChapter]
		return false, "Unlocks in " .. (if chapter then chapter.name else "a later chapter")
	end
	local balance = if def.currency == "Jade" then data.jade else data.ember
	if balance < def.price then
		return false, "Not enough " .. def.currency
	end
	return true, nil
end

return WeaponLogic
