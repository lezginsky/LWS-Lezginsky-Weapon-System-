local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("LWS_Shared")
local Bridge = Shared.Events:WaitForChild("LWS_Bridge")
local GlobalSettings = require(Shared:WaitForChild("LWS_Settings"))

local ServerWeaponData = {
	["Glock"] = { Damage = 25, HeadshotMultiplier = 2, MaxRange = 500 },
	["AK47"] = { Damage = 35, HeadshotMultiplier = 2.5, MaxRange = 1000 }
}

local function CheckAndDamage(hitPart, weaponConfig)
	local humanoid = hitPart.Parent:FindFirstChild("Humanoid") or hitPart.Parent.Parent:FindFirstChild("Humanoid")
	if humanoid and humanoid.Health > 0 then
		local finalDamage = weaponConfig.Damage * GlobalSettings.GlobalDamageMultiplier
		if hitPart.Name == "Head" then
			finalDamage = finalDamage * (weaponConfig.HeadshotMultiplier or GlobalSettings.HeadshotMultiplier)
		end
		humanoid:TakeDamage(finalDamage)
		return true
	end
	return false
end

Bridge.OnServerEvent:Connect(function(player, targetPosition, weaponName)
	local character = player.Character
	if not character or not weaponName then return end

	local weaponConfig = ServerWeaponData[weaponName]
	if not weaponConfig then return end 

	local tool = character:FindFirstChildWhichIsA("Tool")
	if not tool or tool.Name ~= weaponName then return end

	local muzzle = tool:FindFirstChild("Handle")
	if not muzzle then return end

	local distance = (targetPosition - muzzle.Position).Magnitude
	if distance > (weaponConfig.MaxRange or 1000) then return end

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {character}
	params.FilterType = Enum.RaycastFilterType.Exclude

	local origin = muzzle.Position
	local direction = (targetPosition - muzzle.Position).Unit * (weaponConfig.MaxRange or 1000)

	local ricochetCount = 0
	local maxRicochets = GlobalSettings.MaxRicochets or 1

	while origin and direction do
		local result = workspace:Raycast(origin, direction, params)

		if result then
			local hitPart = result.Instance

			local hitHuman = CheckAndDamage(hitPart, weaponConfig)

			if hitHuman then break end 

			if GlobalSettings.RicochetEnabled and ricochetCount < maxRicochets then
				ricochetCount = ricochetCount + 1

				local normal = result.Normal
				local incomingVector = direction.Unit

				local dotProduct = incomingVector:Dot(normal) 
				local angle = math.acos(math.abs(dotProduct)) * (180 / math.pi) 

				if angle <= (GlobalSettings.RicochetAngleLimit or 45) then
					local reflectVector = incomingVector - 2 * dotProduct * normal

					origin = result.Position + (normal * 0.05)
					direction = reflectVector * (weaponConfig.MaxRange - (result.Position - muzzle.Position).Magnitude) 

					local currentFilter = params.FilterDescendantsInstances
					table.insert(currentFilter, hitPart)
					params.FilterDescendantsInstances = currentFilter
				else
					break
				end
			else
				break
			end
		else
			break
		end
	end
end)
