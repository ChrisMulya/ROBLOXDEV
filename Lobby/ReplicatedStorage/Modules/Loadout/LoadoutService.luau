-- Facade for "what camera should this player be given". Deliberately just an
-- attribute read today -- a later phase puts a DataStore behind this exact
-- signature so camera choice survives a teleport (and a plain rejoin, which
-- it doesn't today either -- CurrentCamera is an attribute, never persisted).
-- StartGame.giveStarterCamera routes through this instead of reading
-- CurrentCamera directly, so swapping the backend later touches one file.
--
-- Deliberately does NOT read TeleportData for this -- it's client-routed,
-- and a camera is a purchase-backed capability grant, so a forged cameraId
-- would be a free upgrade. The Lobby is the only writer of CurrentCamera
-- (CameraInventory.Give / CameraShelfSwap); this module only ever reads it.

local LoadoutService = {}

-- Matches CameraInventory.DefaultCameraId. Duplicated rather than required
-- to avoid a ReplicatedStorage module depending on a ServerScriptService one.
local DEFAULT_CAMERA_ID = "Camera1"

function LoadoutService.GetCameraId(player: Player): string
	return player:GetAttribute("CurrentCamera") or DEFAULT_CAMERA_ID
end

return LoadoutService
