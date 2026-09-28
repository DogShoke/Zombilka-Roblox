local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZombieConfig = require(ReplicatedStorage.Shared.ZombieConfig)
local HordeConfig = require(ReplicatedStorage.Shared.HordeConfig)
local Assets = ReplicatedStorage:WaitForChild("Assets")

local Zombie = {}

local function nearestLivingPlayer(origin)
	local nearestCharacter, nearestHumanoid, nearestRoot
	local nearestDistance = math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and character:IsDescendantOf(workspace) then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local root = character:FindFirstChild("HumanoidRootPart")
			if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
				local distance = (root.Position - origin).Magnitude
				if distance <= nearestDistance then
					nearestCharacter, nearestHumanoid, nearestRoot = character, humanoid, root
					nearestDistance = distance
				end
			end
		end
	end
	return nearestCharacter, nearestHumanoid, nearestRoot, nearestDistance
end

local function createRig(spawnPosition)
	local model = Assets:WaitForChild("Zombie"):Clone()
	model.Name = "Zombie"
	local animations = model:FindFirstChild("Animations")
	if not animations then
		animations = Instance.new("Folder")
		animations.Name = "Animations"
		animations.Parent = model
	end
	local animate = model:FindFirstChild("Animate")
	local animationNumber = 0
	if animate then
		for _, descendant in animate:GetDescendants() do
			if descendant:IsA("Animation") then
				local groupName = descendant.Parent.Name
				if groupName == "idle" and not animations:FindFirstChild("Idle") then
					descendant.Name = "Idle"
				elseif groupName == "walk" and not animations:FindFirstChild("Walk") then
					descendant.Name = "Walk"
				elseif groupName == "run" and not animations:FindFirstChild("Run") then
					descendant.Name = "Run"
				else
					animationNumber += 1
					descendant.Name = "ImportedAnimation" .. animationNumber
				end
				descendant.Parent = animations
			end
		end
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript")
			or descendant:IsA("ModuleScript") or descendant:IsA("AlignOrientation")
			or descendant:IsA("Configuration") then
			if descendant.Parent then descendant:Destroy() end
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = false
		end
	end

	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid then
		model:Destroy()
		return nil
	end
	model.PrimaryPart = root
	root.CanCollide = false
	humanoid.MaxHealth = ZombieConfig.MaxHealth
	humanoid.Health = ZombieConfig.MaxHealth
	humanoid.WalkSpeed = ZombieConfig.WalkSpeed
	humanoid.BreakJointsOnDeath = false
	model:PivotTo(CFrame.new(spawnPosition))
	return model, root, humanoid
end

local function loadLocomotionTrack(animator, animations, name, priority)
	local animation = animations and animations:FindFirstChild(name)
	if not animation or not animation:IsA("Animation") or animation.AnimationId == "" then
		return nil
	end
	local success, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not success then
		return nil
	end
	track.Looped = true
	track.Priority = priority
	return track
end

function Zombie.spawn(spawnPosition, onDiedCallback)
	if typeof(spawnPosition) ~= "Vector3" then
		return nil
	end
	local model, root, humanoid = createRig(spawnPosition)
	if not model then
		return nil
	end
	model:SetAttribute("IsZombie", true)
	model:SetAttribute("IsDead", false)

	local dead = false
	local lastAttackTime = 0
	local idleTrack, walkTrack
	local moving = nil
	local function setMoving(shouldMove)
		if moving == shouldMove then
			return
		end
		moving = shouldMove
		if shouldMove then
			if idleTrack then idleTrack:Stop(0.15) end
			if walkTrack then walkTrack:Play(0.15) end
		else
			if walkTrack then walkTrack:Stop(0.15) end
			if idleTrack then idleTrack:Play(0.15) end
		end
	end
	local function onDeath()
		if dead then
			return
		end
		dead = true
		model:SetAttribute("IsDead", true)
		if idleTrack then idleTrack:Stop(0) end
		if walkTrack then walkTrack:Stop(0) end
		root.Anchored = true
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
			end
		end
		if onDiedCallback then
			onDiedCallback(model)
		end
		task.delay(HordeConfig.CorpseCleanupDelay, function()
			if model.Parent then
				model:Destroy()
			end
		end)
	end
	humanoid.HealthChanged:Connect(function(health)
		if health <= 0 then
			onDeath()
		end
	end)
	humanoid.Died:Connect(onDeath)
	CollectionService:AddTag(model, "Zombie")
	model.Parent = workspace
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local animations = model:FindFirstChild("Animations")
	idleTrack = loadLocomotionTrack(animator, animations, "Idle", Enum.AnimationPriority.Idle)
	walkTrack = loadLocomotionTrack(animator, animations, "Walk", Enum.AnimationPriority.Movement)
		or loadLocomotionTrack(animator, animations, "Run", Enum.AnimationPriority.Movement)
	if not dead then
		setMoving(false)
	end

	task.spawn(function()
		while not dead and humanoid.Health > 0 and model.Parent == workspace do
			local character, targetHumanoid, targetRoot, distance = nearestLivingPlayer(root.Position)
			if character and targetRoot and targetRoot:IsDescendantOf(workspace) then
				if distance > ZombieConfig.AttackRange then
					humanoid:MoveTo(targetRoot.Position)
					setMoving(true)
				else
					humanoid:MoveTo(root.Position)
					setMoving(false)
					local now = os.clock()
					if now - lastAttackTime >= ZombieConfig.AttackCooldown
						and humanoid.Health > 0 and targetHumanoid.Health > 0
						and character:IsDescendantOf(workspace)
						and (targetRoot.Position - root.Position).Magnitude <= ZombieConfig.AttackRange then
						lastAttackTime = now
						targetHumanoid:TakeDamage(ZombieConfig.AttackDamage)
					end
				end
			else
				humanoid:MoveTo(root.Position)
				setMoving(false)
			end
			task.wait(0.2)
		end
	end)

	return model
end

return Zombie
