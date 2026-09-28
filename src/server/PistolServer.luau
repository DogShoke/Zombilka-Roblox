local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PistolConfig = require(ReplicatedStorage.Shared.PistolConfig)

local PistolServer = {}
local lastShotTimes = {}
local reloadTokens = {}
local initializedPlayers = {}

local function livingCharacter(player)
	local character = player.Character
	if not character or not character:IsDescendantOf(workspace) then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local head = character:FindFirstChild("Head")
	if not humanoid or humanoid.Health <= 0 or not head or not head:IsA("BasePart") then
		return nil
	end
	return character, humanoid, head
end

local function validDirection(direction)
	if typeof(direction) ~= "Vector3" then
		return false
	end
	for _, component in { direction.X, direction.Y, direction.Z } do
		if component ~= component or math.abs(component) == math.huge then
			return false
		end
	end
	local magnitude = direction.Magnitude
	return magnitude >= 0.5 and magnitude <= 1.5
end

local function resetAmmo(player)
	reloadTokens[player] = (reloadTokens[player] or 0) + 1
	lastShotTimes[player] = nil
	player:SetAttribute("PistolMagazine", PistolConfig.MagazineSize)
	player:SetAttribute("PistolReloading", false)
end

local function setupPlayer(player)
	if initializedPlayers[player] then
		return
	end
	initializedPlayers[player] = true
	local function onCharacterAdded(character)
		resetAmmo(player)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			if player.Character == character then
				reloadTokens[player] = (reloadTokens[player] or 0) + 1
				player:SetAttribute("PistolReloading", false)
			end
		end)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

local function onFire(player, aimDirection)
	if player.Parent ~= Players then
		return
	end
	local character, _, head = livingCharacter(player)
	if not character or player:GetAttribute("PistolReloading") == true then
		return
	end
	local magazine = player:GetAttribute("PistolMagazine")
	if typeof(magazine) ~= "number" or magazine <= 0 then
		return
	end
	local now = os.clock()
	local lastShotTime = lastShotTimes[player]
	if lastShotTime and now - lastShotTime < PistolConfig.FireRate then
		return
	end
	if not validDirection(aimDirection) then
		return
	end

	lastShotTimes[player] = now
	player:SetAttribute("PistolMagazine", magazine - 1)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local result = workspace:Raycast(head.Position, aimDirection.Unit * PistolConfig.Range, params)
	if not result then
		return
	end

	local model = result.Instance:FindFirstAncestorOfClass("Model")
	if not model or model:GetAttribute("IsZombie") ~= true or model:GetAttribute("IsDead") == true then
		return
	end
	local zombieHumanoid = model:FindFirstChildOfClass("Humanoid")
	if zombieHumanoid and zombieHumanoid.Health > 0 then
		zombieHumanoid:TakeDamage(PistolConfig.Damage)
	end
end

local function onReload(player)
	if player.Parent ~= Players then
		return
	end
	local character = livingCharacter(player)
	if not character or player:GetAttribute("PistolReloading") == true then
		return
	end
	local magazine = player:GetAttribute("PistolMagazine")
	if typeof(magazine) ~= "number" or magazine >= PistolConfig.MagazineSize then
		return
	end

	local token = (reloadTokens[player] or 0) + 1
	reloadTokens[player] = token
	player:SetAttribute("PistolReloading", true)
	task.delay(PistolConfig.ReloadDuration, function()
		if player.Parent ~= Players or player.Character ~= character or reloadTokens[player] ~= token then
			return
		end
		if not livingCharacter(player) then
			player:SetAttribute("PistolReloading", false)
			return
		end
		player:SetAttribute("PistolMagazine", PistolConfig.MagazineSize)
		player:SetAttribute("PistolReloading", false)
	end)
end

function PistolServer.start(firePistol, reloadPistol)
	firePistol.OnServerEvent:Connect(onFire)
	reloadPistol.OnServerEvent:Connect(onReload)
	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(function(player)
		lastShotTimes[player] = nil
		reloadTokens[player] = nil
		initializedPlayers[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
end

return PistolServer
