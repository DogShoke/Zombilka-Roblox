local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local SprintController = {}
local player = Players.LocalPlayer
local NORMAL_SPEED = 16
local SPRINT_SPEED = 24
local started = false
local sprinting = false
local humanoid
local diedConnection

local function setSprinting(value)
	sprinting = value and humanoid ~= nil and humanoid.Health > 0 and not GuiService.MenuIsOpen
	if humanoid and humanoid.Health > 0 then
		humanoid.WalkSpeed = if sprinting then SPRINT_SPEED else NORMAL_SPEED
	end
end

local function onCharacterAdded(character)
	if diedConnection then
		diedConnection:Disconnect()
		diedConnection = nil
	end
	sprinting = false
	humanoid = nil
	local newHumanoid = character:WaitForChild("Humanoid", 5)
	if player.Character ~= character or not newHumanoid or not newHumanoid:IsA("Humanoid") then
		return
	end
	humanoid = newHumanoid
	newHumanoid.WalkSpeed = NORMAL_SPEED
	diedConnection = newHumanoid.Died:Connect(function()
		if humanoid == newHumanoid then
			setSprinting(false)
			newHumanoid.WalkSpeed = NORMAL_SPEED
			humanoid = nil
		end
	end)
end

function SprintController.start()
	if started then return end
	started = true
	player.CharacterAdded:Connect(onCharacterAdded)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.KeyCode == Enum.KeyCode.LeftShift and not gameProcessed then
			setSprinting(true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			setSprinting(false)
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		setSprinting(false)
	end)
	GuiService.MenuOpened:Connect(function()
		setSprinting(false)
	end)
	if player.Character then onCharacterAdded(player.Character) end
end

function SprintController.isSprinting(): boolean
	return sprinting
end

return SprintController
