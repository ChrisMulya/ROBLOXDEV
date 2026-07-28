-- Single owner of "give this player a camera Tool". Previously duplicated
-- (template lookup, clone, rename, CurrentCamera attribute) between
-- StartGame.giveStarterCamera and CameraShelfSwap.TakeCamera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraInventory = {}

local CAMERA_TEMPLATES_FOLDER = ReplicatedStorage.Assets.Tool.Camera
local CAMERA_SLOT_NAME = "Camera"

CameraInventory.DefaultCameraId = "Camera1"

-- Returns the player's Camera slot Tool and the container holding it (their
-- Backpack, or their Character if it's currently equipped), or (nil, nil) if
-- they have no Camera slot at all.
--
-- Returns the container itself rather than an "inCharacter" boolean on
-- purpose: the boolean version was set whenever the Character was *searched*,
-- not when the slot was *found* there, so a player with no slot anywhere got
-- back "not found, but it's in the Character" -- and Give then parented their
-- brand-new starter camera straight into the Character, force-equipping it.
-- A returned container can't drift out of sync with the slot it came from.
function CameraInventory.FindSlot(player: Player): (Tool?, Instance?)
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character

	local slot = backpack and backpack:FindFirstChild(CAMERA_SLOT_NAME)
	if slot then
		return slot, backpack
	end

	slot = character and character:FindFirstChild(CAMERA_SLOT_NAME)
	if slot then
		return slot, character
	end

	return nil, nil
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

	-- Replacing an existing slot keeps the new camera wherever the old one
	-- was, so swapping while holding a camera leaves the new one held. With
	-- no existing slot (first-time player) it goes to the Backpack unequipped.
	local slot, container = CameraInventory.FindSlot(player)
	local parent = container or player:FindFirstChild("Backpack")
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
	-- container is guaranteed non-nil past this guard -- FindSlot only returns
	-- a slot together with the container it was found in.
	local slot, container = CameraInventory.FindSlot(player)
	if not slot or slot:GetAttribute("IsEmpty") then
		return
	end

	slot:Destroy()

	local placeholder = Instance.new("Tool")
	placeholder.Name = CAMERA_SLOT_NAME
	placeholder:SetAttribute("IsEmpty", true)
	placeholder.Parent = container
end

return CameraInventory
