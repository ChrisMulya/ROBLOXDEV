-- Resolves ReplicatedStorage.Remotes once so scripts don't repeat
-- WaitForChild boilerplate for every remote they use.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local Remotes = {}

function Remotes.Get(name: string): RemoteEvent
	return remotesFolder:WaitForChild(name)
end

return Remotes
