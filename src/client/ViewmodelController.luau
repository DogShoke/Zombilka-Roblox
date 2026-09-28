local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent:WaitForChild("ViewmodelConfig"))
local SprintController = require(script.Parent:WaitForChild("SprintController"))

local ViewmodelController = {}
local player = Players.LocalPlayer
local started = false
local generation = 0
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

local keptParts = {
	HumanoidRootPart = true,
	LowerTorso = true,
	UpperTorso = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
}

local requiredJoints = {
	Root = { "HumanoidRootPart", "LowerTorso" },
	Waist = { "LowerTorso", "UpperTorso" },
	RightShoulder = { "UpperTorso", "RightUpperArm" },
	RightElbow = { "RightUpperArm", "RightLowerArm" },
	RightWrist = { "RightLowerArm", "RightHand" },
	LeftShoulder = { "UpperTorso", "LeftUpperArm" },
	LeftElbow = { "LeftUpperArm", "LeftLowerArm" },
	LeftWrist = { "LeftLowerArm", "LeftHand" },
}

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
	for _, track in tracks do
		pcall(function()
			track:Stop(0)
		end)
	end
	tracks = {}
	if viewmodel then
		viewmodel:Destroy()
	end
	viewmodel = nil
	viewmodelRoot = nil
	recoilOffset = CFrame.identity
	currentBobOffset = CFrame.identity
	bobCycle = 0
end

local function isCurrent(forCharacter, token)
	return generation == token and character == forCharacter and player.Character == forCharacter
end

local function cosmeticPart(part, anchored)
	part.Anchored = anchored
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	part.LocalTransparencyModifier = 0
end

local function cloneCharacter(forCharacter)
	local originalArchivable = forCharacter.Archivable
	forCharacter.Archivable = true
	local success, clone = pcall(function()
		return forCharacter:Clone()
	end)
	forCharacter.Archivable = originalArchivable
	if not success or not clone then
		return nil
	end
	clone.Name = "Viewmodel"
	return clone
end

local function prepareCharacterClone(clone)
	local parts = {}
	for name in keptParts do
		local part = clone:FindFirstChild(name)
		if not part or not part:IsA("BasePart") then
			return nil
		end
		parts[name] = part
	end
	for name, endpoints in requiredJoints do
		local joint = clone:FindFirstChild(name, true)
		if joint and joint:IsA("AnimationConstraint") then
			local attachment0 = joint.Attachment0
			local attachment1 = joint.Attachment1
			if not attachment0 or not attachment1
				or attachment0.Parent ~= parts[endpoints[1]]
				or attachment1.Parent ~= parts[endpoints[2]] then
				return nil
			end
			local motor = Instance.new("Motor6D")
			motor.Name = name
			motor.Part0 = parts[endpoints[1]]
			motor.Part1 = parts[endpoints[2]]
			motor.C0 = attachment0.CFrame
			motor.C1 = attachment1.CFrame
			motor.Parent = parts[endpoints[1]]
		end
	end

	for _, descendant in clone:GetDescendants() do
		if descendant.Parent then
			if descendant:IsA("Accessory") or descendant:IsA("Tool")
				or descendant:IsA("Humanoid") or descendant:IsA("Script")
				or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript")
				or descendant:IsA("AnimationController")
				or descendant:IsA("Sound") or descendant:IsA("BillboardGui")
				or descendant:IsA("SurfaceGui") or descendant:IsA("ForceField")
				or descendant:IsA("Highlight") or descendant:IsA("Constraint")
				or descendant:IsA("AnimationConstraint") then
				descendant:Destroy()
			elseif descendant:IsA("BasePart") then
				if not keptParts[descendant.Name] or descendant.Parent ~= clone then
					descendant:Destroy()
				else
					cosmeticPart(descendant, descendant == parts.HumanoidRootPart)
					if descendant == parts.HumanoidRootPart or descendant == parts.LowerTorso
						or descendant == parts.UpperTorso then
						descendant.Transparency = 1
					end
				end
			end
		end
	end

	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("Motor6D") then
			local expected = requiredJoints[descendant.Name]
			if not expected or descendant.Part0 ~= parts[expected[1]]
				or descendant.Part1 ~= parts[expected[2]] then
				descendant:Destroy()
			end
		elseif descendant:IsA("Decal") or descendant:IsA("Texture")
			or descendant:IsA("SurfaceAppearance") then
			local parent = descendant.Parent
			if parent == parts.HumanoidRootPart or parent == parts.LowerTorso
				or parent == parts.UpperTorso then
				descendant:Destroy()
			end
		end
	end
	for name, endpoints in requiredJoints do
		local joint = clone:FindFirstChild(name, true)
		if not joint or not joint:IsA("Motor6D") or joint.Part0 ~= parts[endpoints[1]]
			or joint.Part1 ~= parts[endpoints[2]] then
			return nil
		end
	end

	clone.PrimaryPart = parts.HumanoidRootPart
	local controller = Instance.new("AnimationController")
	controller.Name = "AnimationController"
	controller.Parent = clone
	local animator = Instance.new("Animator")
	animator.Parent = controller
	return parts, controller, animator
end

local function preparePistol(template, rightHand)
	local pistol = template:Clone()
	if not pistol or not pistol:IsA("Model") then
		if pistol then pistol:Destroy() end
		return nil
	end
	pistol.Name = "Pistol"
	local handle = pistol:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		pistol:Destroy()
		return nil
	end
	for _, descendant in pistol:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript")
			or descendant:IsA("ModuleScript") or descendant:IsA("RemoteEvent")
			or descendant:IsA("RemoteFunction") or descendant:IsA("Sound") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			cosmeticPart(descendant, false)
		end
	end
	for _, name in { "Bolt", "Magazine", "Pistol" } do
		local joint = handle:FindFirstChild(name)
		if not joint or not joint:IsA("Motor6D") then
			pistol:Destroy()
			return nil
		end
		local part = joint.Part1
		if joint.Part0 ~= handle
			or not part or not part:IsA("BasePart") or part.Name ~= name
			or not part:IsDescendantOf(pistol) then
			pistol:Destroy()
			return nil
		end
	end
	pistol.PrimaryPart = handle
	pistol:PivotTo(rightHand.CFrame * Config.RightGripC0 * Config.RightGripC1:Inverse() * handle.PivotOffset)
	local rightGrip = Instance.new("Motor6D")
	rightGrip.Name = "RightGrip"
	rightGrip.Part0 = rightHand
	rightGrip.Part1 = handle
	rightGrip.C0 = Config.RightGripC0
	rightGrip.C1 = Config.RightGripC1
	rightGrip.Parent = rightHand
	return pistol
end

local function loadTrack(animator, controller, name, id, priority, looped)
	if typeof(id) ~= "string" or id == "" then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.Name = "Pistol" .. name
	animation.AnimationId = id
	animation.Parent = controller
	local success, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not success or not track then
		animation:Destroy()
		warn("[Viewmodel] Could not load Pistol" .. name .. " animation")
		return nil
	end
	track.Priority = priority
	track.Looped = looped
	return track
end

local function buildViewmodel(forCharacter, token)
	local assets = ReplicatedStorage:WaitForChild("Assets", 5)
	local pistolTemplate = assets and assets:WaitForChild("Pistol", 5)
	if not isCurrent(forCharacter, token) then return end
	if not pistolTemplate then
		warnOnce("Pistol asset is missing")
		return
	end
	local clone = cloneCharacter(forCharacter)
	if not clone then
		warnOnce("Could not clone the loaded character")
		return
	end
	viewmodel = clone
	local parts, controller, animator = prepareCharacterClone(clone)
	if not parts then
		destroyViewmodel()
		warnOnce("The character is missing the required R15 arm joints")
		return
	end
	local pistol = preparePistol(pistolTemplate, parts.RightHand)
	if not pistol then
		destroyViewmodel()
		warnOnce("Pistol Handle or internal Motor6D joints are missing")
		return
	end
	pistol.Parent = clone
	local camera = workspace.CurrentCamera
	if not camera or not isCurrent(forCharacter, token) then
		destroyViewmodel()
		return
	end
	local existing = camera:FindFirstChild("Viewmodel")
	if existing then existing:Destroy() end
	clone.Parent = camera
	viewmodelRoot = parts.HumanoidRootPart
	viewmodelRoot.CFrame = camera.CFrame * Config.CameraOffset
	tracks.Idle = loadTrack(animator, controller, "Idle", Config.AnimationIds.Idle, Enum.AnimationPriority.Idle, true)
	tracks.Fire = loadTrack(animator, controller, "Fire", Config.AnimationIds.Fire, Enum.AnimationPriority.Action, false)
	tracks.Reload = loadTrack(animator, controller, "Reload", Config.AnimationIds.Reload, Enum.AnimationPriority.Action, false)
	if tracks.Idle then
		pcall(function() tracks.Idle:Play(0.1) end)
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
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		warnOnce("A loaded R15 character is required")
		return
	end
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
	for _, name in { "HumanoidRootPart", "LowerTorso", "UpperTorso", "RightHand", "LeftHand" } do
		if not newCharacter:WaitForChild(name, 5) or not isCurrent(newCharacter, token) then
			return
		end
	end
	local deadline = os.clock() + 5
	while isCurrent(newCharacter, token) and humanoid.Health > 0
		and not player:HasAppearanceLoaded() and os.clock() < deadline do
		task.wait(0.1)
	end
	if not isCurrent(newCharacter, token) or humanoid.Health <= 0 then return end
	while not workspace.CurrentCamera and isCurrent(newCharacter, token) do
		workspace:GetPropertyChangedSignal("CurrentCamera"):Wait()
	end
	if not isCurrent(newCharacter, token) then return end
	local success, failure = pcall(buildViewmodel, newCharacter, token)
	if not success then
		destroyViewmodel()
		warnOnce("Could not build the cosmetic viewmodel: " .. tostring(failure))
	end
end

function ViewmodelController.start()
	if started then return end
	started = true
	player.CharacterAdded:Connect(onCharacterAdded)
	player:GetAttributeChangedSignal("PistolReloading"):Connect(function()
		if player:GetAttribute("PistolReloading") == true and tracks.Reload then
			pcall(function() tracks.Reload:Play(0.05) end)
		end
	end)
	RunService:BindToRenderStep("ZombilkaViewmodel", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = workspace.CurrentCamera
		if camera and viewmodel and viewmodelRoot then
			if viewmodel.Parent ~= camera then
				local existing = camera:FindFirstChild("Viewmodel")
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
			currentBobOffset = currentBobOffset:Lerp(targetBob, math.clamp(dt * Config.BobSmoothingSpeed, 0, 1))
			viewmodelRoot.CFrame = camera.CFrame * Config.CameraOffset * currentBobOffset * recoilOffset
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
	if viewmodel then
		recoilOffset = Config.RecoilKick
		if tracks.Fire then
			pcall(function() tracks.Fire:Play(0.05) end)
		end
	end
end

return ViewmodelController
