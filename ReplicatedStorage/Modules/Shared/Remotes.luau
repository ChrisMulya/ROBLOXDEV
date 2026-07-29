-- Single provisioning + lookup path for every RemoteEvent in the game.
-- Previously 25 call sites did their own `ReplicatedStorage.Remotes:WaitForChild(name)`,
-- six of them indexing `.Remotes` raw (no WaitForChild on the folder itself) --
-- a hard client error if that folder hadn't replicated yet. Remotes.Get always
-- waits for both the folder and the remote, so that failure mode is gone.
--
-- Remotes.Init() (server-only, called once from Bootstrap) creates whatever's
-- missing from ALL_NAMES. FindFirstChild wins over creation, so a
-- Studio-placed remote is never touched or duplicated.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

-- Every RemoteEvent the game uses. Add a new one here and Init() provisions it.
Remotes.ALL_NAMES = {
	"OpenCameraShelf",
	"CloseCameraShelf",
	"CameraShelfResult",
	"TakeCameraRequest",
	"WeakCameraShot",
	"StrongCameraShot",
	"ShotFeedback",
	"CameraSessionChanged",
	"ObjectiveStateSync",
	"ShowCurrencyUI",
	"HideCurrencyUI",
	"OpenShop",
	"BuyItem",
	"PurchaseResult",
}

function Remotes.Get(name: string): RemoteEvent
	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
	return remotesFolder:WaitForChild(name)
end

-- Server-only. Idempotent -- safe to call more than once, and safe alongside
-- remotes hand-placed in Studio under the same names.
function Remotes.Init()
	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = ReplicatedStorage
	end

	for _, name in ipairs(Remotes.ALL_NAMES) do
		if not remotesFolder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = remotesFolder
		end
	end
end

return Remotes
