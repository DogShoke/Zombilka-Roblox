local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent:WaitForChild("ViewmodelConfig"))

local ViewmodelController = {}
local started = false
local character
local viewmodel
local arms
local pistol
local rightPalm
local humanoidDiedConnection
local descendantAddedConnection
local recoilOffset = CFrame.identity

local function hideCharacterPart(instance)
	if instance:IsA("BasePart") then
		instance.LocalTransparencyModifier = 1
	end
end

local function destroyViewmodel()
	if viewmodel then
		viewmodel:Destroy()
	end
	viewmodel = nil
	arms = nil
	pistol = nil
	rightPalm = nil
	recoilOffset = CFrame.identity
end

local function prepareModel(model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CastShadow = false
			descendant.Massless = true
		end
	end
end

local function buildViewmodel(forCharacter, humanoid)
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local armsTemplate = assets:WaitForChild("Arms")
	local pistolTemplate = assets:WaitForChild("Pistol")
	if character ~= forCharacter or Players.LocalPlayer.Character ~= forCharacter or humanoid.Health <= 0 then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local existing = camera:FindFirstChild("Viewmodel")
	if existing then
		existing:Destroy()
	end

	local armsClone = armsTemplate:Clone()
	local pistolClone = pistolTemplate:Clone()
	if not armsClone:IsA("Model") or not pistolClone:IsA("Model") then
		armsClone:Destroy()
		pistolClone:Destroy()
		warn("[Viewmodel] Arms and Pistol assets must be Models")
		return
	end
	prepareModel(armsClone)
	prepareModel(pistolClone)
	local armsMesh = armsClone:FindFirstChild("armsmesh", true)
	local pistolBody = pistolClone:FindFirstChild("Body")
	local palm = armsClone:FindFirstChild("R_palm", true)
	if not armsMesh or not armsMesh:IsA("BasePart")
		or not pistolBody or not pistolBody:IsA("BasePart")
		or not palm or not palm:IsA("Bone") then
		armsClone:Destroy()
		pistolClone:Destroy()
		warn("[Viewmodel] Expected armsmesh, R_palm Bone, or Pistol.Body is missing")
		return
	end
	local container = Instance.new("Model")
	container.Name = "Viewmodel"
	armsClone.Name = "Arms"
	pistolClone.Name = "Pistol"
	armsClone.PrimaryPart = armsMesh
	pistolClone.PrimaryPart = pistolBody
	armsClone.Parent = container
	pistolClone.Parent = container
	container.Parent = camera

	viewmodel = container
	arms = armsClone
	pistol = pistolClone
	rightPalm = palm
end

local function onCharacterAdded(newCharacter)
	if humanoidDiedConnection then humanoidDiedConnection:Disconnect() end
	if descendantAddedConnection then descendantAddedConnection:Disconnect() end
	destroyViewmodel()
	character = newCharacter
	local humanoid = newCharacter:WaitForChild("Humanoid")
	if Players.LocalPlayer.Character ~= newCharacter or humanoid.Health <= 0 then
		return
	end
	for _, descendant in newCharacter:GetDescendants() do
		hideCharacterPart(descendant)
	end
	descendantAddedConnection = newCharacter.DescendantAdded:Connect(hideCharacterPart)
	humanoidDiedConnection = humanoid.Died:Connect(function()
		if character == newCharacter then
			destroyViewmodel()
		end
	end)
	while not workspace.CurrentCamera do
		workspace:GetPropertyChangedSignal("CurrentCamera"):Wait()
	end
	if Players.LocalPlayer.Character == newCharacter and humanoid.Health > 0 then
		buildViewmodel(newCharacter, humanoid)
	end
end

function ViewmodelController.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(onCharacterAdded)
	RunService:BindToRenderStep("ZombilkaViewmodel", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = workspace.CurrentCamera
		if not camera or not viewmodel or not arms or not pistol or not rightPalm then
			return
		end
		if viewmodel.Parent ~= camera then
			local existing = camera:FindFirstChild("Viewmodel")
			if existing and existing ~= viewmodel then existing:Destroy() end
			viewmodel.Parent = camera
		end
		arms:PivotTo(camera.CFrame * Config.CameraOffset * recoilOffset)
		pistol:PivotTo(rightPalm.TransformedWorldCFrame * Config.PistolOffset)
		recoilOffset = recoilOffset:Lerp(CFrame.identity, math.clamp(dt * Config.RecoilRecoverySpeed, 0, 1))
		if character then
			for _, descendant in character:GetDescendants() do
				hideCharacterPart(descendant)
			end
		end
	end)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

function ViewmodelController.playFireFeedback()
	if viewmodel then
		recoilOffset = Config.RecoilKick
	end
end

return ViewmodelController
