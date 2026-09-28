local Definitions = {}

Definitions.Rarities = {
	Blue = { Name = "Rare", Color = Color3.fromRGB(50, 160, 255) },
	Purple = { Name = "Epic", Color = Color3.fromRGB(185, 75, 255) },
	Red = { Name = "Mythic", Color = Color3.fromRGB(255, 60, 60) },
	Gold = { Name = "Legendary", Color = Color3.fromRGB(255, 205, 65) },
}

Definitions.Order = {
	"Sharpshooter", "QuickHands", "ExtendedMagazine", "Vitality",
	"ArcDischarge", "StaticShock", "ConductiveTarget", "TeslaCascade",
	"APCore", "LargeCaliber", "CombatReload", "Deadeye",
}

Definitions.ById = {
	Sharpshooter = {
		Id = "Sharpshooter", DisplayName = "Sharpshooter", Category = "Neutral", Patron = "Neutral",
		MaxTier = "Purple", Upgradeable = true,
		Tiers = {
			Blue = { Description = "+25% headshot damage", Values = { HeadshotBonus = 0.25 } },
			Purple = { Description = "+45% headshot damage", Values = { HeadshotBonus = 0.45 } },
		},
	},
	QuickHands = {
		Id = "QuickHands", DisplayName = "Quick Hands", Category = "Neutral", Patron = "Neutral",
		MaxTier = "Purple", Upgradeable = true,
		Tiers = {
			Blue = { Description = "Reload 20% faster", Values = { ReloadReduction = 0.20 } },
			Purple = { Description = "Reload 35% faster", Values = { ReloadReduction = 0.35 } },
		},
	},
	ExtendedMagazine = {
		Id = "ExtendedMagazine", DisplayName = "Extended Magazine", Category = "Neutral", Patron = "Neutral",
		MaxTier = "Purple", Upgradeable = true,
		Tiers = {
			Blue = { Description = "+4 magazine capacity", Values = { MagazineBonus = 4 } },
			Purple = { Description = "+8 magazine capacity", Values = { MagazineBonus = 8 } },
		},
	},
	Vitality = {
		Id = "Vitality", DisplayName = "Vitality", Category = "Neutral", Patron = "Neutral",
		MaxTier = "Purple", Upgradeable = true,
		Tiers = {
			Blue = { Description = "+20 maximum health", Values = { MaxHealthBonus = 20 } },
			Purple = { Description = "+40 maximum health", Values = { MaxHealthBonus = 40 } },
		},
	},
	ArcDischarge = {
		Id = "ArcDischarge", DisplayName = "Arc Discharge", Category = "Professor Volta", Patron = "Professor Volta",
		MaxTier = "Purple", Upgradeable = true,
		Tiers = {
			Blue = { Description = "Headshots chain to 1 zombie for 20 damage", Values = { ChainCount = 1, ChainDamage = 20 } },
			Purple = { Description = "Headshots chain to 2 zombies for 25 damage", Values = { ChainCount = 2, ChainDamage = 25 } },
		},
	},
	StaticShock = {
		Id = "StaticShock", DisplayName = "Static Shock", Category = "Professor Volta", Patron = "Professor Volta",
		MaxTier = "Purple", Upgradeable = true,
		Tiers = {
			Blue = { Description = "20% headshot stun for 1 second", Values = { ShockChance = 0.20, ShockDuration = 1.0 } },
			Purple = { Description = "35% headshot stun for 1.5 seconds", Values = { ShockChance = 0.35, ShockDuration = 1.5 } },
		},
	},
	ConductiveTarget = {
		Id = "ConductiveTarget", DisplayName = "Conductive Target", Category = "Professor Volta", Patron = "Professor Volta",
		MaxTier = "Purple", Upgradeable = false,
		Tiers = {
			Purple = { Description = "Shocked zombies take 25% more damage", Values = { ShockedDamageBonus = 0.25 } },
		},
	},
	TeslaCascade = {
		Id = "TeslaCascade", DisplayName = "Tesla Cascade", Category = "Professor Volta", Patron = "Professor Volta",
		MaxTier = "Red", Upgradeable = false,
		Prerequisites = { RequiredTalents = { "ArcDischarge" }, AdditionalVoltaBoon = true },
		Tiers = {
			Red = { Description = "Arc lightning jumps to 3 additional zombies", Values = { AdditionalChains = 3 } },
		},
	},
	APCore = {
		Id = "APCore", DisplayName = "AP Core", Category = "Sergeant Bravo", Patron = "Sergeant Bravo",
		MaxTier = "Purple", Upgradeable = true,
		Tiers = {
			Blue = { Description = "Bullets pierce 1 additional zombie", Values = { PiercingCount = 1 } },
			Purple = { Description = "Bullets pierce 2 additional zombies", Values = { PiercingCount = 2 } },
		},
	},
	LargeCaliber = {
		Id = "LargeCaliber", DisplayName = "Large Caliber", Category = "Sergeant Bravo", Patron = "Sergeant Bravo",
		MaxTier = "Purple", Upgradeable = true,
		Tiers = {
			Blue = { Description = "+20% base pistol damage", Values = { BaseDamageBonus = 0.20 } },
			Purple = { Description = "+35% base pistol damage", Values = { BaseDamageBonus = 0.35 } },
		},
	},
	CombatReload = {
		Id = "CombatReload", DisplayName = "Combat Reload", Category = "Sergeant Bravo", Patron = "Sergeant Bravo",
		MaxTier = "Purple", Upgradeable = true,
		Tiers = {
			Blue = { Description = "Headshot kills speed up the next reload by 30%", Values = { NextReloadReduction = 0.30 } },
			Purple = { Description = "Headshot kills speed up the next reload by 50%", Values = { NextReloadReduction = 0.50 } },
		},
	},
	Deadeye = {
		Id = "Deadeye", DisplayName = "Deadeye", Category = "Sergeant Bravo", Patron = "Sergeant Bravo",
		MaxTier = "Red", Upgradeable = false,
		Tiers = {
			Red = { Description = "Consecutive headshots add 10% damage, up to 50%", Values = { StreakBonus = 0.10, MaximumStreak = 5 } },
		},
	},
}

return Definitions
