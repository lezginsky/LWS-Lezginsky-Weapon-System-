local Settings = {
	IsLWS = true,
	WeaponType = "Pistol", -- "Rifle"/"Pistol"

	Damage = 25,
	FireRate = 0.15,
	BulletColor = Color3.fromRGB(255, 255, 0),
	HeadshotMultiplier = 2,
	CameraRecoil = 1.5,
	MaxAmmo = 12,
	ReloadTime = 2.0,

	BaseSpread = 0.5, 
	AimSpreadMultiplier = 0.4,
	MovementSpreadBonus = 1.2,
	ContinuousFirePenalty = 0.3, 

	Sounds = {
		Fire = "rbxassetid://138346124095367",
		Empty = "rbxassetid://240785604",
		Reload = "rbxassetid://131070677",
		ShellSound = "rbxassetid://325025387"
	}
}

return Settings
