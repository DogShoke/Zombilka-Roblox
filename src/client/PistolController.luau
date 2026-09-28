local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local PistolConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PistolConfig"))
local Remotes = require(ReplicatedStorage.Shared:WaitForChild("Remotes"))
local ViewmodelController = require(script.Parent:WaitForChild("ViewmodelController"))

local PistolController = {}
local started = false

function PistolController.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local firePistol, reloadPistol = Remotes.getClient()
	local mouseDown = false
	local lastShotTime = nil
	local lastReloadRequestTime = nil

	local function requestReload()
		local now = os.clock()
		if lastReloadRequestTime and now - lastReloadRequestTime < 0.5 then
			return
		end
		lastReloadRequestTime = now
		reloadPistol:FireServer()
	end

	player.CharacterAdded:Connect(function()
		mouseDown = false
		lastShotTime = nil
		lastReloadRequestTime = nil
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if mouseDown then
				return
			end
			mouseDown = true
			if gameProcessed then
				return
			end
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0
				or player:GetAttribute("PistolReloading") == true then
				return
			end
			local magazine = player:GetAttribute("PistolMagazine")
			if magazine == 0 then
				requestReload()
				return
			elseif not magazine or magazine < 0 then
				return
			end
			local now = os.clock()
			if lastShotTime and now - lastShotTime < PistolConfig.FireRate then
				return
			end
			local camera = workspace.CurrentCamera
			if not camera then
				return
			end
			lastShotTime = now
			firePistol:FireServer(camera.CFrame.LookVector)
			ViewmodelController.playFireFeedback()
		elseif input.KeyCode == Enum.KeyCode.R and not gameProcessed then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0
				and player:GetAttribute("PistolReloading") ~= true
				and (player:GetAttribute("PistolMagazine") or PistolConfig.MagazineSize) < PistolConfig.MagazineSize then
				requestReload()
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			mouseDown = false
		end
	end)
end

return PistolController
