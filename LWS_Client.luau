local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Shared = ReplicatedStorage:WaitForChild("LWS_Shared")
local Bridge = Shared:WaitForChild("Events"):WaitForChild("LWS_Bridge")
local ShellHandler = require(Shared:WaitForChild("ShellHandler"))
local GlobalSettings = require(Shared:WaitForChild("LWS_Settings"))

local CurrentWeapon = nil
local CurrentConfig = nil

local LastShot = 0
local IsFiring = false
local IsReloading = false
local IsAiming = false 
local IsEquipping = false

local ConsecutiveShots = 0
local LastShotTime = 0

local ReloadStartTime = 0
local ReloadDuration = 2

local HiddenStorage = Instance.new("Folder", ReplicatedStorage)
HiddenStorage.Name = "LWS_HiddenStorage"

local ViewmodelModel = nil
local FakeWeapon = nil

local HipfireOffset = CFrame.new(0.45, -0.75, -1.6) 
local CurrentWeaponOffset = HipfireOffset
local CurrentShakeOffset = CFrame.new()

local BobbingTick = 0
local CurrentBobbingOffset = CFrame.new()
local CurrentSprintOffset = CFrame.new()

local AmmoStorage = {}

ShellHandler.Init()

local function EaseQuadOut(t) return t * (2 - t) end
local function EaseQuadIn(t) return t * t end

local function ApplyRecoil(intensity)
	local upKick = intensity or 2
	if IsAiming then upKick = upKick * 0.7 end 
	local sideKick = math.random(-10, 10) * (upKick / 10)

	local camTweenInfo = TweenInfo.new(0.04, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(Camera, camTweenInfo, {
		CFrame = Camera.CFrame * CFrame.Angles(math.rad(upKick), math.rad(sideKick), 0)
	}):Play()

	local targetShake = CFrame.new(sideKick * 0.01, -upKick * 0.01, upKick * 0.08) * CFrame.Angles(math.rad(upKick * 12), math.rad(sideKick * 3), math.rad(sideKick * -2))

	task.spawn(function()
		local p1 = 0
		local kickConnection
		kickConnection = RunService.RenderStepped:Connect(function(dt)
			p1 = math.min(p1 + dt / 0.02, 1)
			CurrentShakeOffset = CFrame.new():Lerp(targetShake, p1)
			if p1 >= 1 then
				kickConnection:Disconnect()
				local p2 = 0
				local returnConnection
				returnConnection = RunService.RenderStepped:Connect(function(dt2)
					p2 = math.min(p2 + dt2 / 0.12, 1)
					CurrentShakeOffset = targetShake:Lerp(CFrame.new(), p2)
					if p2 >= 1 then returnConnection:Disconnect() end
				end)
			end
		end)
	end)
end

local function PlayWeaponSound(id, parent)
	if not id or id == "" then return end

	local success, sound = pcall(function()
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Parent = parent
		return s
	end)

	if success and sound then
		sound:Play()
		game:GetService("Debris"):AddItem(sound, 2)
	else
		warn("Не удалось загрузить звук " .. tostring(id))
	end
end


local function CleanViewmodel()
	if CurrentWeapon and CurrentWeapon.Parent == HiddenStorage then
		local Character = Player.Character
		if Character then CurrentWeapon.Parent = Character end
	end
	if ViewmodelModel then
		ViewmodelModel:Destroy()
		ViewmodelModel = nil
		FakeWeapon = nil
	end
	IsAiming = false 
	IsReloading = false
	Camera.FieldOfView = 70 
end

local function StripPhysics(instance)
	for _, obj in pairs(instance:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.CanCollide = false
			obj.CanQuery = false
			obj.CanTouch = false
			obj.CastShadow = false
			obj.Massless = true
			obj.Anchored = true
		elseif obj:IsA("JointInstance") or obj:IsA("Constraint") then
			obj:Destroy()
		end
	end
end

local function CreateViewmodel(weapon)
	CleanViewmodel()
	local Character = Player.Character
	if not Character then return end

	ViewmodelModel = Instance.new("Model")
	ViewmodelModel.Name = "LWS_Viewmodel"

	local vHumanoid = Instance.new("Humanoid", ViewmodelModel)
	vHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local skinColor = Color3.fromRGB(225, 172, 150)
	local bodyColors = Character:FindFirstChildWhichIsA("BodyColors")
	if bodyColors then skinColor = bodyColors.RightArmColor3 end

	local rArm = Instance.new("Part")
	rArm.Name = "Right Arm" 
	rArm.Size = Vector3.new(0.45, 1.4, 0.45)
	rArm.Color = skinColor
	rArm.Material = Enum.Material.SmoothPlastic
	rArm.Parent = ViewmodelModel

	local lArm = Instance.new("Part")
	lArm.Name = "Left Arm"
	lArm.Size = Vector3.new(0.45, 1.4, 0.45)
	lArm.Color = skinColor
	lArm.Material = Enum.Material.SmoothPlastic
	lArm.Parent = ViewmodelModel

	local shirt = Character:FindFirstChildWhichIsA("Shirt")
	if shirt then shirt:Clone().Parent = ViewmodelModel end

	FakeWeapon = weapon:Clone()
	local settingsMod = FakeWeapon:FindFirstChild("Settings")
	if settingsMod then settingsMod:Destroy() end
	FakeWeapon.Parent = ViewmodelModel

	StripPhysics(ViewmodelModel)
	ViewmodelModel.Parent = Camera
	weapon.Parent = HiddenStorage
end

local function Reload()
	if IsReloading or not CurrentWeapon or not CurrentConfig then return end
	local currentAmmo = AmmoStorage[CurrentWeapon] or CurrentConfig.MaxAmmo
	if currentAmmo == CurrentConfig.MaxAmmo then return end

	IsReloading = true
	IsFiring = false
	IsAiming = false 
	ConsecutiveShots = 0

	ReloadDuration = CurrentConfig.ReloadTime or 2
	ReloadStartTime = tick()

	local Muzzle = FakeWeapon and FakeWeapon:FindFirstChild("Handle")
	if Muzzle and CurrentConfig.Sounds and CurrentConfig.Sounds.Reload then
		PlayWeaponSound(CurrentConfig.Sounds.Reload, Muzzle)
	end

	task.wait(ReloadDuration)
	if CurrentWeapon and CurrentWeapon.Parent == HiddenStorage then 
		AmmoStorage[CurrentWeapon] = CurrentConfig.MaxAmmo 
	end
	IsReloading = false
end

local function Fire()
	if not CurrentWeapon or not CurrentConfig or IsReloading or not FakeWeapon then return end
	local Character = Player.Character
	local Humanoid = Character and Character:FindFirstChildWhichIsA("Humanoid")
	if not Character or not Humanoid then return end

	local rate = CurrentConfig.FireRate or 0.1
	if tick() - LastShot < rate then return end
	LastShot = tick()

	if AmmoStorage[CurrentWeapon] == nil then
		AmmoStorage[CurrentWeapon] = CurrentConfig.MaxAmmo
	end

	local Muzzle = FakeWeapon:FindFirstChild("Handle")
	if not Muzzle then return end

	if AmmoStorage[CurrentWeapon] <= 0 then
		if CurrentConfig.Sounds and CurrentConfig.Sounds.Empty then
			PlayWeaponSound(CurrentConfig.Sounds.Empty, Muzzle)
		end
		IsFiring = false
		return
	end

	if tick() - LastShotTime < (rate * 2.5) then
		ConsecutiveShots = ConsecutiveShots + 1
	else
		ConsecutiveShots = 1
	end
	LastShotTime = tick()

	local currentSpread = CurrentConfig.BaseSpread or 0.5
	if IsAiming then currentSpread = currentSpread * (CurrentConfig.AimSpreadMultiplier or 0.5) end
	if Humanoid.MoveDirection.Magnitude > 0 then currentSpread = currentSpread + (CurrentConfig.MovementSpreadBonus or 1.0) end
	if ConsecutiveShots > 3 then currentSpread = currentSpread + ((ConsecutiveShots - 3) * (CurrentConfig.ContinuousFirePenalty or 0.2)) end

	local randomX = math.rad(math.random(-100, 100) / 100 * currentSpread)
	local randomY = math.rad(math.random(-100, 100) / 100 * currentSpread)

	local screenCenter = Camera.ViewportSize / 2
	local unitRay = Camera:ViewportPointToRay(screenCenter.X, screenCenter.Y)
	local spreadDirection = (CFrame.new(Vector3.new(), unitRay.Direction) * CFrame.Angles(randomX, randomY, 0)).LookVector

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {Character, Camera, HiddenStorage}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local raycastResult = Workspace:Raycast(unitRay.Origin, spreadDirection * 1000, raycastParams)
	local targetPos = if raycastResult then raycastResult.Position else unitRay.Origin + spreadDirection * 1000

	local fMuzzle = Muzzle:FindFirstChild("MuzzlePoint") or Muzzle
	local flash = Instance.new("PointLight")
	flash.Color = Color3.fromRGB(255, 210, 130)
	flash.Brightness = 6 
	flash.Range = 12
	flash.Parent = fMuzzle
	game:GetService("Debris"):AddItem(flash, 0.04)

	AmmoStorage[CurrentWeapon] = AmmoStorage[CurrentWeapon] - 1
	ApplyRecoil(CurrentConfig.CameraRecoil)

	if CurrentConfig.Sounds and CurrentConfig.Sounds.Fire then
		PlayWeaponSound(CurrentConfig.Sounds.Fire, Muzzle)
	end

	local ShellPoint = FakeWeapon:FindFirstChild("ShellPart")
	if ShellPoint and GlobalSettings.ShellsEnabled then
		local sSound = CurrentConfig.Sounds and CurrentConfig.Sounds.ShellSound
		ShellHandler.Eject(ShellPoint, sSound)
	end

	Bridge:FireServer(spreadDirection, CurrentWeapon.Name)
end

task.spawn(function()
	while true do
		if IsFiring and CurrentConfig then 
			Fire() 
			if CurrentConfig.WeaponType == "Pistol" then IsFiring = false end
			task.wait(CurrentConfig.FireRate)
		else
			task.wait(0.05)
		end
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if not CurrentWeapon or not CurrentConfig or not FakeWeapon then return end
	local Character = Player.Character
	local Humanoid = Character and Character:FindFirstChildWhichIsA("Humanoid")
	if not Humanoid then return end

	for _, part in pairs(Character:GetChildren()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.LocalTransparencyModifier = 1
		end
	end

	local speed = Humanoid.MoveDirection.Magnitude
	if speed > 0 and not IsReloading then
		local bobSpeedMultiplier = IsAiming and 0.3 or 0.8
		local bobIntensityMultiplier = IsAiming and 0.2 or 1

		BobbingTick = BobbingTick + (dt * Humanoid.WalkSpeed * 0.8 * bobSpeedMultiplier)
		local bobX = math.sin(BobbingTick) * 0.04 * bobIntensityMultiplier
		local bobY = math.cos(BobbingTick * 2) * 0.02 * bobIntensityMultiplier
		CurrentBobbingOffset = CurrentBobbingOffset:Lerp(CFrame.new(bobX, bobY, 0) * CFrame.Angles(bobY * 0.5, bobX * 0.5, bobX), 0.2)

		if not IsAiming then
			CurrentSprintOffset = CurrentSprintOffset:Lerp(CFrame.new(-0.1, -0.2, 0.2) * CFrame.Angles(math.rad(-10), math.rad(-15), math.rad(-10)), 0.1)
		else
			CurrentSprintOffset = CurrentSprintOffset:Lerp(CFrame.new(), 0.1)
		end
	else
		CurrentBobbingOffset = CurrentBobbingOffset:Lerp(CFrame.new(), 0.1)
		CurrentSprintOffset = CurrentSprintOffset:Lerp(CFrame.new(), 0.1)
	end

	local fakeHandle = FakeWeapon.Handle
	local fakeAimPart = FakeWeapon:FindFirstChild("AimPart")

	local reloadWeaponOffset = CFrame.new()
	local leftArmReloadOffset = CFrame.new()

	if IsReloading then
		local rawProgress = math.clamp((tick() - ReloadStartTime) / ReloadDuration, 0, 1)
		local smoothProgress = EaseQuadOut(rawProgress)

		local startOffset = CFrame.new()
		local targetOffset = CFrame.new(0.08, 0.05, 0.15) * CFrame.Angles(math.rad(-8), math.rad(22), math.rad(12))

		if rawProgress < 0.25 then
			local p = EaseQuadOut(rawProgress / 0.25)
			reloadWeaponOffset = startOffset:Lerp(targetOffset, p)
		elseif rawProgress > 0.8 then 
			local p = EaseQuadIn((rawProgress - 0.8) / 0.2)
			reloadWeaponOffset = targetOffset:Lerp(startOffset, p)
		else
			reloadWeaponOffset = targetOffset
		end

		if rawProgress < 0.45 then
			local p = EaseQuadIn(rawProgress / 0.45)
			leftArmReloadOffset = CFrame.new(-0.6, -0.9, 0.4) * CFrame.Angles(math.rad(-35), math.rad(-35), math.rad(-10)):Lerp(CFrame.new(), 1 - p)
		elseif rawProgress >= 0.45 and rawProgress <= 0.75 then
			local p = EaseQuadOut((rawProgress - 0.45) / 0.3)
			leftArmReloadOffset = CFrame.new(-0.6, -0.9, 0.4):Lerp(CFrame.new(0.12, 0.08, -0.15) * CFrame.Angles(math.rad(15), math.rad(-15), 0), p)
		else
			local p = EaseQuadOut((rawProgress - 0.75) / 0.25)
			leftArmReloadOffset = CFrame.new(0.12, 0.08, -0.15):Lerp(CFrame.new(), p)
		end
	end

	local targetOffset = HipfireOffset
	if IsAiming and fakeAimPart then
		targetOffset = fakeHandle.CFrame:ToObjectSpace(fakeAimPart.CFrame):Inverse() * CFrame.new(0, 0, -1.2)
	end

	CurrentWeaponOffset = CurrentWeaponOffset:Lerp(targetOffset, 0.25)

	local targetFOV = IsAiming and 50 or 70
	Camera.FieldOfView = math.lerp(Camera.FieldOfView, targetFOV, 0.2)

	local baseCFrame = Camera.CFrame * CurrentWeaponOffset * reloadWeaponOffset * CurrentSprintOffset * CurrentBobbingOffset * CurrentShakeOffset
	fakeHandle.CFrame = baseCFrame

	for _, part in pairs(FakeWeapon:GetChildren()) do
		if part:IsA("BasePart") and part ~= fakeHandle then
			local origPart = CurrentWeapon:FindFirstChild(part.Name)
			if origPart then part.CFrame = fakeHandle.CFrame * CurrentWeapon.Handle.CFrame:ToObjectSpace(origPart.CFrame) end
		end
	end

	local rArmPart = ViewmodelModel:FindFirstChild("Right Arm")
	if rArmPart then
		rArmPart.CFrame = fakeHandle.CFrame * (IsAiming and CFrame.new(0.15, -0.45, 0.5) or CFrame.new(0.25, -0.4, 0.4)) * CFrame.Angles(math.rad(-30), math.rad(-10), math.rad(5)) 
	end

	local lArmPart = ViewmodelModel:FindFirstChild("Left Arm")
	if lArmPart then
		lArmPart.CFrame = fakeHandle.CFrame * leftArmReloadOffset * (IsAiming and CFrame.new(-0.15, -0.45, 0.3) or CFrame.new(-0.25, -0.45, -0.1)) * CFrame.Angles(math.rad(-45), math.rad(25), math.rad(-15)) 
	end
end)

local function OnWeaponEquipped(tool)
	if IsEquipping then return end
	IsEquipping = true

	local SettingsModule = tool:FindFirstChild("Settings")
	if not SettingsModule then 
		IsEquipping = false
		return 
	end

	local success, config = pcall(function() return require(SettingsModule) end)
	if success and config and config.IsLWS then
		CurrentWeapon = tool
		CurrentConfig = config

		if Player.CameraMode ~= Enum.CameraMode.LockFirstPerson then
			Player.CameraMode = Enum.CameraMode.LockFirstPerson
		end

		CreateViewmodel(tool)
	end
	IsEquipping = false
end

local function OnWeaponUnequipped()
	CleanViewmodel()
	CurrentWeapon = nil
	CurrentConfig = nil

	if Player.CameraMode ~= Enum.CameraMode.Classic then
		Player.CameraMode = Enum.CameraMode.Classic
	end
end

Player.CharacterAdded:Connect(function(char)
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then OnWeaponEquipped(child) end
	end)
	char.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and child == CurrentWeapon then OnWeaponUnequipped() end
	end)
end)

if Player.Character then
	local char = Player.Character
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then OnWeaponEquipped(child) end
	end)
	char.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and child == CurrentWeapon then OnWeaponUnequipped() end
	end)
	local currentTool = char:FindFirstChildWhichIsA("Tool")
	if currentTool then OnWeaponEquipped(currentTool) end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then 
		IsFiring = true 
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		IsAiming = true 
	elseif input.KeyCode == Enum.KeyCode.R then
		Reload()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then 
		IsFiring = false 
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		IsAiming = false 
	end
end)
