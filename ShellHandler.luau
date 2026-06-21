local ShellHandler = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local Shared = ReplicatedStorage:WaitForChild("LWS_Shared")
local Settings = require(Shared:WaitForChild("LWS_Settings"))
local PoolFolder = Shared:FindFirstChild("ShellPool") or Instance.new("Folder", Shared)
PoolFolder.Name = "ShellPool"
local ShellTemplate = Shared:WaitForChild("Shell")
local Pool = {}
local CurrentIndex = 1
local MAX_SHELLS = Settings.MaxShells
local LIFE_TIME = Settings.ShellLifeTime
local ShellTimers = {} 
local ProjectilesFolder = Workspace:FindFirstChild("LWS_Projectiles") or Instance.new("Folder", Workspace)
ProjectilesFolder.Name = "LWS_Projectiles"
function ShellHandler.Init()
	if #Pool > 0 then return end
	for i = 1, MAX_SHELLS do
		local shell = ShellTemplate:Clone()
		shell.Transparency = 1
		shell.Anchored = true
		shell.CanCollide = false
		shell.Parent = PoolFolder
		table.insert(Pool, shell)
	end
end
function ShellHandler.Eject(muzzlePart, shellSoundId)
	if not Settings.ShellsEnabled then return end
	local shell = Pool[CurrentIndex]
	if not shell then return end
	local myFlightId = HttpService:GenerateGUID(false)
	ShellTimers[shell] = myFlightId
	shell.Anchored = false
	shell.Transparency = 0
	shell.CanCollide = true
	shell.CFrame = muzzlePart.CFrame * CFrame.Angles(0, math.rad(90), 0)
	shell.Parent = ProjectilesFolder
	if shellSoundId then
		local sound = Instance.new("Sound")
		sound.SoundId = shellSoundId
		sound.Volume = 0.5
		sound.Parent = shell
		sound:Play()
		game:GetService("Debris"):AddItem(sound, 1)
	end
	shell.AssemblyLinearVelocity = muzzlePart.CFrame.RightVector * 15 + muzzlePart.CFrame.UpVector * 5
	shell.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
	task.delay(LIFE_TIME, function()
		if ShellTimers[shell] == myFlightId then
			shell.Transparency = 1
			shell.Anchored = true
			shell.CanCollide = false
			shell.Parent = PoolFolder
		end
	end)
	CurrentIndex = (CurrentIndex % MAX_SHELLS) + 1
end
return ShellHandler
