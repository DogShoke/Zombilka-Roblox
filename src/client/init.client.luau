local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
localPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
localPlayer.CameraMinZoomDistance = 0.5
localPlayer.CameraMaxZoomDistance = 0.5

UserInputService.MouseIconEnabled = GuiService.MenuIsOpen
GuiService.MenuOpened:Connect(function()
	UserInputService.MouseIconEnabled = true
end)
GuiService.MenuClosed:Connect(function()
	UserInputService.MouseIconEnabled = false
end)

local Crosshair = require(script:WaitForChild("Crosshair"))
local PistolController = require(script:WaitForChild("PistolController"))
local AmmoGui = require(script:WaitForChild("AmmoGui"))
local ViewmodelController = require(script:WaitForChild("ViewmodelController"))
local SprintController = require(script:WaitForChild("SprintController"))
local HitFeedback = require(script:WaitForChild("HitFeedback"))

Crosshair.mount()
PistolController.start()
AmmoGui.mount()
SprintController.start()
ViewmodelController.start()
HitFeedback.mount()
