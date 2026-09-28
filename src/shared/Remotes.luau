local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

function Remotes.initServer()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end

	local firePistol = folder:FindFirstChild("FirePistol")
	if not firePistol then
		firePistol = Instance.new("RemoteEvent")
		firePistol.Name = "FirePistol"
		firePistol.Parent = folder
	end

	local reloadPistol = folder:FindFirstChild("ReloadPistol")
	if not reloadPistol then
		reloadPistol = Instance.new("RemoteEvent")
		reloadPistol.Name = "ReloadPistol"
		reloadPistol.Parent = folder
	end

	return firePistol, reloadPistol
end

function Remotes.getClient()
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	return folder:WaitForChild("FirePistol"), folder:WaitForChild("ReloadPistol")
end

return Remotes
