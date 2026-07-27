-- Single owner of "give this player a camera Tool". Previously duplicated
-- (template lookup, clone, rename, CurrentCamera attribute) between
-- StartGame.giveStarterCamera and CameraShelfSwap.TakeCamera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraInventory = {}

local CAMERA_TEMPLATES_FOLDER = ReplicatedStorage.Assets.Tool.Camera
local CAMERA_SLOT_NAME = "Camera"

CameraInventory.DefaultCameraId = "Camera1"

-- Returns the player's Camera slot Tool (in Backpack or, if currently
-- equipped, Character) and whether it was found in the Character.
function CameraInventory.FindSlot(player: Player): (Tool?, boolean)
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character

	local slot = backpack and backpack:FindFirstChild(CAMERA_SLOT_NAME)
	local inCharacter = false

	if not slot and character then
		slot = character:FindFirstChild(CAMERA_SLOT_NAME)
		inCharacter = true
	end

	return slot, inCharacter
end

function CameraInventory.GetCurrentId(player: Player): string?
	return player:GetAttribute("CurrentCamera")
end

-- Destroys whatever currently sits in the player's Camera slot (empty
-- placeholder OR a different camera) and replaces it with cameraId.
-- Returns ok, code.
function CameraInventory.Give(player: Player, cameraId: string): (boolean, string)
	local template = CAMERA_TEMPLATES_FOLDER:FindFirstChild(cameraId)
	if not template then
		warn("CameraInventory: no camera template for CameraId:", cameraId)
		return false, "InvalidCamera"
	end

	local slot, inCharacter = CameraInventory.FindSlot(player)
	local parent = if inCharacter then player.Character else player:FindFirstChild("Backpack")
	if not parent then
		return false, "NoBackpack"
	end

	if slot then
		slot:Destroy()
	end

	local newTool = template:Clone()
	newTool.Name = CAMERA_SLOT_NAME
	newTool.Parent = parent

	player:SetAttribute("CurrentCamera", cameraId)
	return true, "Success"
end

function CameraInventory.ClearSlot(player: Player)
	local slot, inCharacter = CameraInventory.FindSlot(player)
	if not slot or slot:GetAttribute("IsEmpty") then
		return
	end

	local parent = if inCharacter then player.Character else player:FindFirstChild("Backpack")
	if not parent then
		return
	end

	slot:Destroy()

	local placeholder = Instance.new("Tool")
	placeholder.Name = CAMERA_SLOT_NAME
	placeholder:SetAttribute("IsEmpty", true)
	placeholder.Parent = parent
end

return CameraInventory
