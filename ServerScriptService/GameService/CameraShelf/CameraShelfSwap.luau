local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraInventory = require(script.Parent.CameraInventory)
local CameraSessionTracker = require(script.Parent.Parent.Camera.CameraSessionTracker)

local CameraShelfSwap = {}

local CAMERA_TEMPLATES_FOLDER = ReplicatedStorage.Assets.Tool.Camera

-- Returns: success (bool), reason (string)
function CameraShelfSwap.TakeCamera(player, cameraId)
	if not CAMERA_TEMPLATES_FOLDER:FindFirstChild(cameraId) then
		warn("No camera template found for CameraId:", cameraId)
		return false, "InvalidCamera"
	end

	-- Destroying an equipped, active camera tool out from under a player is
	-- the exact cascade that CameraStateWatcher/CameraClient exists to catch
	-- as a safety net -- refuse it at the source instead.
	if CameraSessionTracker.IsInCamera(player) then
		return false, "InCameraSession"
	end

	local slot = CameraInventory.FindSlot(player)

	-- No Camera slot exists yet (e.g. shelf used before StartGame ever ran).
	-- Nothing to physically swap -- just record the preference so whenever
	-- StartGame DOES run, it hands out the right camera from the start.
	if not slot then
		player:SetAttribute("CurrentCamera", cameraId)
		print(player.Name, "has no Camera slot yet -- saved preference:", cameraId)
		return true, "PreferenceSaved"
	end

	-- Already holding this exact camera -- informational, not an error.
	if not slot:GetAttribute("IsEmpty") and slot:GetAttribute("CameraId") == cameraId then
		return true, "AlreadyHolding"
	end

	return CameraInventory.Give(player, cameraId)
end

function CameraShelfSwap.ClearCameraSlot(player)
	CameraInventory.ClearSlot(player)
end

return CameraShelfSwap
