local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraInventory = require(script.Parent.CameraInventory)
local CameraSessionTracker = require(script.Parent.Parent.Camera.CameraSessionTracker)
local LoadoutService = require(ReplicatedStorage.Modules.Loadout.LoadoutService)

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
		LoadoutService.Save(player, cameraId)
		print(player.Name, "has no Camera slot yet -- saved preference:", cameraId)
		return true, "PreferenceSaved"
	end

	-- Already holding this exact camera -- informational, not an error. No
	-- Save() needed: the persisted value already matches, or this player
	-- somehow holds it without ever choosing it here, in which case there's
	-- nothing new worth persisting.
	if not slot:GetAttribute("IsEmpty") and slot:GetAttribute("CameraId") == cameraId then
		return true, "AlreadyHolding"
	end

	local ok, reason = CameraInventory.Give(player, cameraId)
	if ok then
		LoadoutService.Save(player, cameraId)
	end
	return ok, reason
end

function CameraShelfSwap.ClearCameraSlot(player)
	CameraInventory.ClearSlot(player)
end

return CameraShelfSwap
