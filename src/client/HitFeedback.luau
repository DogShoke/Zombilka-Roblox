local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HitFeedback = {}
local mounted = false

function HitFeedback.mount()
	if mounted then return end
	mounted = true
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "HitFeedbackGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 11
	gui.Parent = playerGui
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0.5, 15)
	label.Size = UDim2.fromOffset(140, 30)
	label.BackgroundTransparency = 1
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.Text = ""
	label.Parent = gui
	local token = 0
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CombatFeedback")
	remote.OnClientEvent:Connect(function(kind)
		if kind ~= "Hit" and kind ~= "Headshot" then return end
		token += 1
		local current = token
		label.Text = if kind == "Headshot" then "HEADSHOT" else "HIT"
		label.TextColor3 = if kind == "Headshot" then Color3.fromRGB(255, 95, 70) else Color3.new(1, 1, 1)
		task.delay(0.35, function()
			if token == current then label.Text = "" end
		end)
	end)
end

return HitFeedback
