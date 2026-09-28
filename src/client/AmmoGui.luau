local Players = game:GetService("Players")

local AmmoGui = {}
local mounted = false

function AmmoGui.mount()
	if mounted then
		return
	end
	mounted = true
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local screenGui = playerGui:FindFirstChild("AmmoGui")
	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "AmmoGui"
		screenGui.ResetOnSpawn = false
		screenGui.IgnoreGuiInset = true
		screenGui.Parent = playerGui
	end

	local label = screenGui:FindFirstChild("AmmoText")
	if not label then
		label = Instance.new("TextLabel")
		label.Name = "AmmoText"
		label.AnchorPoint = Vector2.new(1, 1)
		label.Position = UDim2.new(1, -24, 1, -24)
		label.Size = UDim2.fromOffset(180, 44)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.TextStrokeTransparency = 0
		label.Font = Enum.Font.GothamBold
		label.TextSize = 24
		label.TextXAlignment = Enum.TextXAlignment.Right
		label.Active = false
		label.Selectable = false
		label.Parent = screenGui
	end

	local function update()
		if player:GetAttribute("PistolReloading") == true then
			label.Text = "RELOADING..."
		else
			local magazine = player:GetAttribute("PistolMagazine")
			label.Text = string.format("%d / ∞", magazine or 0)
		end
	end

	for _, name in { "PistolMagazine", "PistolReloading" } do
		player:GetAttributeChangedSignal(name):Connect(update)
	end
	update()
end

return AmmoGui
