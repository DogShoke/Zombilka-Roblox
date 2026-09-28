local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local CollisionGroups = require(ReplicatedStorage.Shared:WaitForChild("CollisionGroups"))
local PistolServer = require(script:WaitForChild("PistolServer"))
local ZombieSpawner = require(script:WaitForChild("ZombieSpawner"))
local ProgressionService = require(script:WaitForChild("ProgressionService"))
local CombatService = require(script:WaitForChild("CombatService"))
local TalentAltars = require(script:WaitForChild("TalentAltars"))

for _, group in { CollisionGroups.Players, CollisionGroups.Zombies } do
	if not PhysicsService:IsCollisionGroupRegistered(group) then
		PhysicsService:RegisterCollisionGroup(group)
	end
end
PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Players, CollisionGroups.Default, true)
PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Zombies, CollisionGroups.Default, true)
PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Players, CollisionGroups.Zombies, true)
PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Zombies, CollisionGroups.Zombies, false)
PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Players, CollisionGroups.Players, false)

local firePistol, reloadPistol, combatFeedback = Remotes.initServer()
ProgressionService.start()
CombatService.start(combatFeedback)
TalentAltars.start()
PistolServer.start(firePistol, reloadPistol)
ZombieSpawner.start()
