local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Definitions = require(ReplicatedStorage.Shared.TalentDefinitions)
local TalentConfig = require(ReplicatedStorage.Shared.TalentConfig)
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local TalentService = require(script.Parent:WaitForChild("TalentService"))

local TalentAltars = {}
local started = false
local altars = {}
local choicesByPlayer = {}
local activePlayer
local warnedExhausted = false

local function label(parent, name, position, height, size, bold)
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = name
	textLabel.BackgroundTransparency = 1
	textLabel.Position = UDim2.fromOffset(8, position)
	textLabel.Size = UDim2.new(1, -16, 0, height)
	textLabel.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	textLabel.TextSize = size
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextWrapped = true
	textLabel.TextXAlignment = Enum.TextXAlignment.Center
	textLabel.Parent = parent
	return textLabel
end

local function render()
	local current = activePlayer and choicesByPlayer[activePlayer]
	for index, altar in altars do
		local choice = current and current[index]
		local definition = choice and Definitions.ById[choice.Id]
		local tierData = definition and definition.Tiers[choice.Tier]
		local rarity = choice and Definitions.Rarities[choice.Tier]
		altar.Prompt.Enabled = choice ~= nil
		altar.Part:SetAttribute("TalentId", choice and choice.Id or "")
		altar.Part:SetAttribute("TalentTier", choice and choice.Tier or "")
		altar.NameLabel.Text = definition and definition.DisplayName or "TALENT ALTAR"
		altar.RarityLabel.Text = rarity and (choice.Tier .. " • " .. rarity.Name) or "Awaiting level"
		altar.RarityLabel.TextColor3 = rarity and rarity.Color or Color3.fromRGB(180, 180, 180)
		altar.CategoryLabel.Text = definition and definition.Category or ""
		altar.DescriptionLabel.Text = tierData and tierData.Description or ""
		altar.Stroke.Color = rarity and rarity.Color or Color3.fromRGB(100, 100, 100)
	end
end

local function chooseActivePlayer()
	if activePlayer and activePlayer.Parent == Players
		and ProgressionService.getState(activePlayer)
		and ProgressionService.getState(activePlayer).PendingTalentChoices > 0
		and choicesByPlayer[activePlayer] then
		render()
		return
	end
	activePlayer = nil
	for _, player in Players:GetPlayers() do
		local state = ProgressionService.getState(player)
		if state and state.PendingTalentChoices > 0 then
			if not choicesByPlayer[player] then
				choicesByPlayer[player] = TalentService.rollChoices(player)
			end
			if choicesByPlayer[player] then
				activePlayer = player
				break
			end
		end
	end
	if not activePlayer and not warnedExhausted then
		for _, player in Players:GetPlayers() do
			local state = ProgressionService.getState(player)
			if state and state.PendingTalentChoices > 0 then
				warnedExhausted = true
				warn("[TalentAltars] Fewer than three unique talents remain in the prototype pool")
				break
			end
		end
	end
	render()
end

function TalentAltars.refresh(player)
	local state = ProgressionService.getState(player)
	if not state or state.PendingTalentChoices <= 0 then
		choicesByPlayer[player] = nil
	else
		choicesByPlayer[player] = choicesByPlayer[player] or TalentService.rollChoices(player)
	end
	chooseActivePlayer()
end

local function choose(player, index)
	if player ~= activePlayer then return end
	local state = ProgressionService.getState(player)
	local choices = choicesByPlayer[player]
	local choice = choices and choices[index]
	local altar = altars[index]
	if not state or state.PendingTalentChoices <= 0 or not choice or not altar
		or altar.Part:GetAttribute("TalentId") ~= choice.Id
		or altar.Part:GetAttribute("TalentTier") ~= choice.Tier then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not character:IsDescendantOf(workspace) or not humanoid or humanoid.Health <= 0 then
		return
	end
	if not root or not root:IsA("BasePart")
		or (root.Position - altar.Part.Position).Magnitude > altar.Prompt.MaxActivationDistance + 2 then
		return
	end
	if not TalentService.grant(player, choice.Id, choice.Tier) then return end
	ProgressionService.consumeChoice(player)
	choicesByPlayer[player] = nil
	activePlayer = nil
	TalentAltars.refresh(player)
end

function TalentAltars.start()
	if started then return end
	started = true
	local folder = Instance.new("Folder")
	folder.Name = "TalentAltars"
	folder.Parent = workspace
	for index, position in TalentConfig.AltarPositions do
		local part = Instance.new("Part")
		part.Name = "TalentAltar" .. index
		part.Anchored = true
		part.Size = Vector3.new(4, 4, 4)
		part.Position = position
		part.Material = Enum.Material.Slate
		part.Color = Color3.fromRGB(43, 43, 52)
		part.Parent = folder
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Choose Talent"
		prompt.ObjectText = "Talent Altar"
		prompt.HoldDuration = 0.6
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 10
		prompt.Enabled = false
		prompt.Parent = part
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "TalentDisplay"
		billboard.Adornee = part
		billboard.Size = UDim2.fromOffset(230, 122)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 60
		billboard.Parent = part
		local background = Instance.new("Frame")
		background.Size = UDim2.fromScale(1, 1)
		background.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
		background.BackgroundTransparency = 0.15
		background.Parent = billboard
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = background
		local nameLabel = label(background, "TalentName", 4, 28, 17, true)
		local rarityLabel = label(background, "Rarity", 32, 20, 14, true)
		local categoryLabel = label(background, "Category", 53, 20, 13, false)
		local descriptionLabel = label(background, "Description", 74, 44, 12, false)
		altars[index] = {
			Part = part, Prompt = prompt, Stroke = stroke, NameLabel = nameLabel,
			RarityLabel = rarityLabel, CategoryLabel = categoryLabel,
			DescriptionLabel = descriptionLabel,
		}
		prompt.Triggered:Connect(function(player)
			choose(player, index)
		end)
	end
	ProgressionService.setChoicesChangedCallback(TalentAltars.refresh)
	Players.PlayerRemoving:Connect(function(player)
		choicesByPlayer[player] = nil
		if activePlayer == player then activePlayer = nil end
		chooseActivePlayer()
	end)
	render()
end

return TalentAltars
