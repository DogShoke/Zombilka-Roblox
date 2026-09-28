local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local PistolServer = require(script:WaitForChild("PistolServer"))
local ZombieSpawner = require(script:WaitForChild("ZombieSpawner"))

local firePistol, reloadPistol = Remotes.initServer()
PistolServer.start(firePistol, reloadPistol)
ZombieSpawner.start()
