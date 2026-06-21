--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local SharedFolder = ReplicatedStorage:WaitForChild("LWS_Shared")
local Events = SharedFolder:WaitForChild("Events")
local Bridge = Events:WaitForChild("LWS_Bridge") :: RemoteEvent

local function CreateVisualTracer(origin: Vector3, target: Vector3)
	local p = Instance.new("Part")
	p.Size = Vector3.new(0.1, 0.1, (target - origin).Magnitude)
	p.CFrame = CFrame.new(origin:Lerp(target, 0.5), target)
	p.Anchored = true
	p.CanCollide = false
	p.Transparency = 1
	p.Parent = workspace
	game:GetService("Debris"):AddItem(p, 0.05)
end

Bridge.OnServerEvent:Connect(function(player: Player, clientDirection: any, weaponName: any)
	if typeof(clientDirection) ~= "Vector3" or typeof(weaponName) ~= "string" then 
		return 
	end

	local character = player.Character
	if not character or not character.PrimaryPart then return end

	local tool = character:FindFirstChild(weaponName) or player.Backpack:FindFirstChild(weaponName) or ReplicatedStorage:FindFirstChild("LWS_HiddenStorage"):FindFirstChild(weaponName)
	if not tool then return end

	local settingsModule = tool:FindFirstChild("Settings")
	if not settingsModule then return end

	local settings = require(settingsModule)

	local maxBounces = settings.MaxBounce or 3
	local angleLimit = settings.RicochetAngleLimit or 45
	local baseDamage = settings.Damage or 20
	local ricochetEnabled = settings.RicochetEnabled

	local currentFilter = table.create(maxBounces + 2)
	table.insert(currentFilter, character)

	local bounces = 0
	-- БЕЗОПАСНО И НАДЕЖНО: Пуля летит от головы персонажа, а не из спрятанного в реплике AimPart
	local head = character:FindFirstChild("Head") :: BasePart
	local origin = if head then head.Position else character.PrimaryPart.Position

	local dir: Vector3 = clientDirection :: Vector3
	local direction = dir.Unit * 1000 

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	while origin and direction and bounces <= maxBounces do
		raycastParams.FilterDescendantsInstances = currentFilter
		local raycastResult = workspace:Raycast(origin, direction, raycastParams)

		if raycastResult then
			local hitPart = raycastResult.Instance
			local hitPosition = raycastResult.Position
			local normal = raycastResult.Normal

			CreateVisualTracer(origin, hitPosition)

			local hitModel = hitPart:FindFirstAncestorOfClass("Model")
			if hitModel then
				local humanoid = hitModel:FindFirstChildOfClass("Humanoid")
				if humanoid and hitModel ~= character then
					local damage = baseDamage
					if hitPart.Name == "Head" then
						damage *= settings.HeadshotMultiplier
					end
					humanoid:TakeDamage(damage)
					break 
				end
			end

			if ricochetEnabled == false then
				break
			end

			local incomingVector = direction.Unit
			local dotProduct = incomingVector:Dot(normal)
			local angle = math.acos(math.abs(dotProduct)) * (180 / math.pi)

			if angle <= angleLimit then
				local reflectVector = incomingVector - 2 * dotProduct * normal
				origin = hitPosition + (reflectVector * 0.05) 
				direction = reflectVector * 1000
				bounces += 1
				table.insert(currentFilter, hitPart)
			else
				break 
			end
		else
			CreateVisualTracer(origin, origin + direction)
			break
		end
	end
end)
