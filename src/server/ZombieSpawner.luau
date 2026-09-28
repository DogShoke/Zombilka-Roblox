local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local HordeConfig = require(ReplicatedStorage.Shared.HordeConfig)
local Zombie = require(script.Parent:WaitForChild("Zombie"))

local ZombieSpawner = {}
local running = false
local aliveCount = 0
local hordeStartTime = nil

local function livingPlayerRoots()
	local roots = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and character:IsDescendantOf(workspace) then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local root = character:FindFirstChild("HumanoidRootPart")
			if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
				table.insert(roots, root)
			end
		end
	end
	return roots
end

local function livingZombieRoots()
	local roots = {}
	for _, model in CollectionService:GetTagged("Zombie") do
		if model:IsA("Model") and model:IsDescendantOf(workspace)
			and model:GetAttribute("IsDead") ~= true then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart")
			if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
				table.insert(roots, root)
			end
		end
	end
	return roots
end

local function chooseSpawnPoint(playerRoots, zombieRoots)
	local playerPosition = playerRoots[1].Position
	for _ = 1, HordeConfig.MaxSpawnAttempts do
		local angle = math.random() * math.pi * 2
		local radius = HordeConfig.MinSpawnRadius
			+ math.random() * (HordeConfig.MaxSpawnRadius - HordeConfig.MinSpawnRadius)
		local candidate = Vector3.new(
			playerPosition.X + radius * math.cos(angle),
			3,
			playerPosition.Z + radius * math.sin(angle)
		)
		if math.abs(candidate.X) < HordeConfig.ArenaRadiusLimit
			and math.abs(candidate.Z) < HordeConfig.ArenaRadiusLimit then
			local separated = true
			for _, root in playerRoots do
				if (candidate - root.Position).Magnitude < HordeConfig.MinPlayerSpawnDistance then
					separated = false
					break
				end
			end
			if separated then
				for _, root in zombieRoots do
					if (candidate - root.Position).Magnitude < HordeConfig.MinZombieSeparation then
						separated = false
						break
					end
				end
			end
			if separated then
				return candidate
			end
		end
	end
	return nil
end

local function currentDifficulty()
	local elapsedTime = if hordeStartTime then (os.clock() - hordeStartTime) else 0
	local step = math.floor(elapsedTime / HordeConfig.DifficultyStepSeconds)
	local currentMaxAlive = math.clamp(
		HordeConfig.InitialMaxAlive + (step * HordeConfig.MaxAliveIncreasePerStep),
		HordeConfig.InitialMaxAlive,
		HordeConfig.MaximumMaxAlive
	)
	local currentSpawnInterval = math.clamp(
		HordeConfig.InitialSpawnInterval - (step * HordeConfig.SpawnIntervalDecreasePerStep),
		HordeConfig.MinimumSpawnInterval,
		HordeConfig.InitialSpawnInterval
	)
	return currentMaxAlive, currentSpawnInterval
end

function ZombieSpawner.start()
	if running then
		return
	end
	running = true
	task.spawn(function()
		local nextSpawnTime = nil
		while running do
			local roots = livingPlayerRoots()
			if #roots == 0 then
				task.wait(1)
			else
				local now = os.clock()
				if not hordeStartTime then
					hordeStartTime = now
					nextSpawnTime = now
				end
				local currentMaxAlive, currentSpawnInterval = currentDifficulty()
				if aliveCount < currentMaxAlive and now >= nextSpawnTime then
					local spawnPosition = chooseSpawnPoint(roots, livingZombieRoots())
					if spawnPosition then
						local counted = false
						local died = false
						local success, zombieModel = pcall(function()
							return Zombie.spawn(spawnPosition, function()
								died = true
								if counted then
									aliveCount = math.max(0, aliveCount - 1)
								end
							end)
						end)
						local validModel = success and typeof(zombieModel) == "Instance"
							and zombieModel:IsA("Model") and zombieModel.Parent == workspace
						local humanoid = validModel and zombieModel:FindFirstChildOfClass("Humanoid")
						if humanoid and humanoid.Health > 0 and not died
							and zombieModel:GetAttribute("IsDead") ~= true then
							aliveCount += 1
							counted = true
						else
							warn("[ZombieSpawner] Failed to spawn zombie:", zombieModel)
						end
						nextSpawnTime = now + currentSpawnInterval
					end
				end
				task.wait(0.2)
			end
		end
	end)
end

return ZombieSpawner
