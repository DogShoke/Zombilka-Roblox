local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent:WaitForChild("ViewmodelConfig"))
local SprintController = require(script.Parent:WaitForChild("SprintController"))
local PistolConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PistolConfig"))

local ViewmodelController = {}
local player = Players.LocalPlayer
local started = false
local generation = 0
local reloadToken = 0
local character
local viewmodel
local viewmodelRoot
local tracks = {}
local humanoidDiedConnection
local descendantAddedConnection
local recoilOffset = CFrame.identity
local currentBobOffset = CFrame.identity
local bobCycle = 0
local warned = false
local playReload

local function warnOnce(message)
	if not warned then
		warned = true
		warn("[Viewmodel] " .. message)
	end
end

local function hideCharacterPart(instance)
	if instance:IsA("BasePart") then
		instance.LocalTransparencyModifier = 1
	end
end

local function destroyViewmodel()
	reloadToken += 1
	for _, track in tracks do
		pcall(function() track:Stop(0) end)
	end
	tracks = {}
	if viewmodel then viewmodel:Destroy() end
	viewmodel = nil
	viewmodelRoot = nil
	recoilOffset = CFrame.identity
	currentBobOffset = CFrame.identity
	bobCycle = 0
end

local function isCurrent(forCharacter, token)
	return generation == token and character == forCharacter and player.Character == forCharacter
end

local function loadTrack(animator, controller, name, id, priority, looped)
	if typeof(id) ~= "string" or id == "" then return nil end
	local animation = Instance.new("Animation")
	animation.Name = name
	animation.AnimationId = id
	animation.Parent = controller
	local success, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not success or not track then
		animation:Destroy()
		warnOnce("Could not load " .. name .. " animation")
		return nil
	end
	track.Priority = priority
	track.Looped = looped
	return track
end

local function prepareRig(clone)
	local root = clone:FindFirstChild("RootPart")
	local arms = clone:FindFirstChild("ArmModel")
	local glock = clone:FindFirstChild("Glock19")
	local controller = clone:FindFirstChildOfClass("AnimationController")
	if not root or not root:IsA("BasePart")
		or not arms or not arms:IsA("MeshPart")
		or not glock or not glock:IsA("MeshPart")
		or not controller then
		return nil
	end
	local armJoint = arms:FindFirstChild("ArmModelMotor6D")
	local glockJoint = glock:FindFirstChild("Glock19Motor6D")
	if not armJoint or not armJoint:IsA("Motor6D") or armJoint.Part0 ~= root or armJoint.Part1 ~= arms
		or not glockJoint or not glockJoint:IsA("Motor6D") or glockJoint.Part0 ~= root or glockJoint.Part1 ~= glock then
		return nil
	end
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = descendant == root
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CastShadow = false
			descendant.Massless = true
			descendant.LocalTransparencyModifier = 0
		end
	end
	root.Transparency = 1
	clone.PrimaryPart = root
	local animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end
	return root, controller, animator
end

local function buildViewmodel(forCharacter, token)
	local assets = ReplicatedStorage:WaitForChild("Assets", 5)
	local template = assets and assets:WaitForChild("FpsGlock", 5)
	if not isCurrent(forCharacter, token) then return end
	if not template or not template:IsA("Model") then
		warnOnce("ReplicatedStorage.Assets.FpsGlock is missing or is not a Model")
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		warnOnce("CurrentCamera is unavailable")
		return
	end
	local clone = template:Clone()
	if not clone then
		warnOnce("Could not clone FpsGlock")
		return
	end
	clone.Name = "FpsViewmodel"
	local root, controller, animator = prepareRig(clone)
	if not root then
		clone:Destroy()
		warnOnce("FpsGlock is missing its root, meshes, Motor6D joints, or AnimationController")
		return
	end
	if not isCurrent(forCharacter, token) then
		clone:Destroy()
		return
	end
	for _, name in { "FpsViewmodel", "Viewmodel" } do
		local existing = camera:FindFirstChild(name)
		if existing then existing:Destroy() end
	end
	clone.Parent = camera
	viewmodel = clone
	viewmodelRoot = root
	root.CFrame = camera.CFrame * Config.CameraOffset
	clone:PivotTo(root.CFrame)
	local idleTrack = loadTrack(animator, controller, "Idle", Config.AnimationIds.Idle, Enum.AnimationPriority.Idle, true)
	local shootTrack = loadTrack(animator, controller, "Shoot", Config.AnimationIds.Shoot, Enum.AnimationPriority.Action, false)
	local reloadTrack = loadTrack(animator, controller, "Reload", Config.AnimationIds.Reload, Enum.AnimationPriority.Action, false)
	if not isCurrent(forCharacter, token) or viewmodel ~= clone then
		if viewmodel == clone then destroyViewmodel() end
		return
	end
	tracks.Idle = idleTrack
	tracks.Shoot = shootTrack
	tracks.Reload = reloadTrack
	if tracks.Idle then
		local success = pcall(function() tracks.Idle:Play(0.1) end)
		if not success then warnOnce("Could not play Idle animation") end
	end
	if player:GetAttribute("PistolReloading") == true then
		playReload()
	end
end

playReload = function()
	local track = tracks.Reload
	if not track or not viewmodel then return end
	reloadToken += 1
	local token = reloadToken
	local success = pcall(function()
		if track.IsPlaying then track:Stop(0) end
		local speed = if track.Length > 0 then track.Length / PistolConfig.ReloadDuration else 1
		track:Play(0.05, 1, speed)
	end)
	if not success then
		warnOnce("Could not play Reload animation")
		return
	end
	if track.Length <= 0 then
		task.spawn(function()
			local deadline = os.clock() + PistolConfig.ReloadDuration
			while reloadToken == token and track.IsPlaying and track.Length <= 0 and os.clock() < deadline do
				task.wait()
			end
			if reloadToken == token and track.IsPlaying and track.Length > 0 then
				pcall(function()
					track:AdjustSpeed(track.Length / PistolConfig.ReloadDuration)
				end)
			end
		end)
	end
end

local function onCharacterAdded(newCharacter)
	generation += 1
	local token = generation
	if humanoidDiedConnection then humanoidDiedConnection:Disconnect() end
	if descendantAddedConnection then descendantAddedConnection:Disconnect() end
	destroyViewmodel()
	character = newCharacter
	local humanoid = newCharacter:WaitForChild("Humanoid", 5)
	if not isCurrent(newCharacter, token) then return end
	if not humanoid or not humanoid:IsA("Humanoid") or humanoid.Health <= 0 then return end
	for _, descendant in newCharacter:GetDescendants() do
		hideCharacterPart(descendant)
	end
	descendantAddedConnection = newCharacter.DescendantAdded:Connect(hideCharacterPart)
	humanoidDiedConnection = humanoid.Died:Connect(function()
		if isCurrent(newCharacter, token) then
			generation += 1
			destroyViewmodel()
			if descendantAddedConnection then descendantAddedConnection:Disconnect() end
		end
	end)
	local deadline = os.clock() + 5
	while not workspace.CurrentCamera and isCurrent(newCharacter, token) and os.clock() < deadline do
		task.wait()
	end
	if not isCurrent(newCharacter, token) or humanoid.Health <= 0 then return end
	local success, failure = pcall(buildViewmodel, newCharacter, token)
	if not success then
		destroyViewmodel()
		warnOnce("Could not build FpsGlock viewmodel: " .. tostring(failure))
	end
end

function ViewmodelController.start()
	if started then return end
	started = true
	player.CharacterAdded:Connect(onCharacterAdded)
	player:GetAttributeChangedSignal("PistolReloading"):Connect(function()
		if player:GetAttribute("PistolReloading") == true then playReload() end
	end)
	RunService:BindToRenderStep("ZombilkaViewmodel", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = workspace.CurrentCamera
		if camera and viewmodel and viewmodelRoot then
			if viewmodel.Parent ~= camera then
				local existing = camera:FindFirstChild("FpsViewmodel")
				if existing and existing ~= viewmodel then existing:Destroy() end
				viewmodel.Parent = camera
			end
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local velocity = if root then Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude else 0
			local isMoving = velocity > 1.5 and humanoid ~= nil and humanoid.Health > 0
				and humanoid.MoveDirection.Magnitude > 0.1
			local isSprinting = isMoving and SprintController.isSprinting()
			local targetBob = CFrame.identity
			if isMoving then
				local frequency = if isSprinting then Config.SprintBobFrequency else Config.WalkBobFrequency
				local horizontal = if isSprinting then Config.SprintBobHorizontal else Config.WalkBobHorizontal
				local vertical = if isSprinting then Config.SprintBobVertical else Config.WalkBobVertical
				bobCycle += dt * frequency
				targetBob = CFrame.new(math.sin(bobCycle) * horizontal, math.cos(bobCycle * 2) * vertical, 0)
					* CFrame.Angles(0, 0, math.sin(bobCycle) * horizontal * 0.4)
				if isSprinting then targetBob *= Config.SprintLowerOffset end
			end
			local targetCFrame = camera.CFrame * currentBobOffset * recoilOffset * Config.CameraOffset
			viewmodelRoot.CFrame = targetCFrame
			viewmodel:PivotTo(targetCFrame)
			recoilOffset = recoilOffset:Lerp(CFrame.identity, math.clamp(dt * Config.RecoilRecoverySpeed, 0, 1))
		end
		if character then
			for _, descendant in character:GetDescendants() do
				hideCharacterPart(descendant)
			end
		end
	end)
	if player.Character then onCharacterAdded(player.Character) end
end

function ViewmodelController.playFireFeedback()
	if not viewmodel then return end
	recoilOffset = Config.RecoilKick
	local track = tracks.Shoot
	if track then
		local success = pcall(function()
			if track.IsPlaying then track:Stop(0) end
			track:Play(0.03)
		end)
		if not success then warnOnce("Could not play Shoot animation") end
	end
end

return ViewmodelController
