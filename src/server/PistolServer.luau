local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PistolConfig = require(ReplicatedStorage.Shared.PistolConfig)
local CollisionGroups = require(ReplicatedStorage.Shared.CollisionGroups)
local ProgressionConfig = require(ReplicatedStorage.Shared.ProgressionConfig)
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local TalentService = require(script.Parent:WaitForChild("TalentService"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))

local PistolServer = {}
local lastShotTimes = {}
local reloadTokens = {}
local initializedPlayers = {}
local characterPartConnections = {}

local function assignPlayerPart(instance)
	if instance:IsA("BasePart") then
		instance.CollisionGroup = CollisionGroups.Players
	end
end

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
	player:SetAttribute("PistolReloading", false)
	ProgressionService.refreshCombatAttributes(player)
	local state = ProgressionService.getState(player)
	player:SetAttribute("PistolMagazine", PistolConfig.MagazineSize + (state and state.MagazineBonus or 0))
end

local function setupPlayer(player)
	if initializedPlayers[player] then
		return
	end
	initializedPlayers[player] = true
	local function onCharacterAdded(character)
		if characterPartConnections[player] then
			characterPartConnections[player]:Disconnect()
		end
		for _, descendant in character:GetDescendants() do
			assignPlayerPart(descendant)
		end
		characterPartConnections[player] = character.DescendantAdded:Connect(assignPlayerPart)
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

	local state = ProgressionService.getState(player)
	local remainingPierces = state and state.PiercingCount or 0
	local remainingDistance = PistolConfig.Range
	local origin = head.Position
	local direction = aimDirection.Unit
	local excluded = { character }
	local hitZombie = false
	while remainingDistance > 0 do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = excluded
		local result = workspace:Raycast(origin, direction * remainingDistance, params)
		if not result then break end
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		if not model or model:GetAttribute("IsZombie") ~= true or model:GetAttribute("IsDead") == true then
			break
		end
		local context = CombatService.processHit(player, model, result.Instance, result.Position,
			"Pistol", PistolConfig.Damage, not hitZombie)
		if not context then break end
		hitZombie = true
		if remainingPierces <= 0 then break end
		remainingPierces -= 1
		table.insert(excluded, model)
		local advance = (result.Position - origin).Magnitude + 0.1
		remainingDistance -= advance
		origin = result.Position + direction * 0.1
	end
	if not hitZombie then CombatService.onMiss(player) end
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
	local state = ProgressionService.getState(player)
	if not state then return end
	local capacity = PistolConfig.MagazineSize + state.MagazineBonus
	if typeof(magazine) ~= "number" or magazine >= capacity then
		return
	end

	local combatMultiplier = if state.CombatReloadReady then state.CombatReloadMultiplier else 1
	local duration = math.max(ProgressionConfig.MinimumReloadDuration,
		PistolConfig.ReloadDuration * state.ReloadSpeedMultiplier * combatMultiplier)
	local token = (reloadTokens[player] or 0) + 1
	reloadTokens[player] = token
	state.CombatReloadReady = false
	player:SetAttribute("PistolReloadDuration", duration)
	player:SetAttribute("PistolReloading", true)
	TalentService.onReload(player, duration)
	task.delay(duration, function()
		if player.Parent ~= Players or player.Character ~= character or reloadTokens[player] ~= token then
			return
		end
		if not livingCharacter(player) then
			player:SetAttribute("PistolReloading", false)
			ProgressionService.refreshCombatAttributes(player)
			return
		end
		local currentState = ProgressionService.getState(player)
		player:SetAttribute("PistolMagazine", PistolConfig.MagazineSize + (currentState and currentState.MagazineBonus or 0))
		player:SetAttribute("PistolReloading", false)
		ProgressionService.refreshCombatAttributes(player)
	end)
end

function PistolServer.start(firePistol, reloadPistol)
	firePistol.OnServerEvent:Connect(onFire)
	reloadPistol.OnServerEvent:Connect(onReload)
	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(function(player)
		if characterPartConnections[player] then
			characterPartConnections[player]:Disconnect()
			characterPartConnections[player] = nil
		end
		lastShotTimes[player] = nil
		reloadTokens[player] = nil
		initializedPlayers[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
end

return PistolServer
