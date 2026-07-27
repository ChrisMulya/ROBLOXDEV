-- Thin remote adapter: validates the shooter, resolves cooldown/settings,
-- delegates the actual raycast to PhotoCapture, and reports the outcome
-- (hit or miss) back to the shooter.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CameraStats = require(ReplicatedStorage.Modules.Camera.CameraStats)
local Cooldown = require(ReplicatedStorage.Modules.Shared.Cooldown)
local Units = require(ReplicatedStorage.Modules.Shared.Units)
local PhotoCapture = require(script.Parent.PhotoCapture)

local WeakCameraShot = ReplicatedStorage.Remotes:WaitForChild("WeakCameraShot")
local StrongCameraShot = ReplicatedStorage.Remotes:WaitForChild("StrongCameraShot")
local ShotFeedback = ReplicatedStorage.Remotes:WaitForChild("ShotFeedback")

-- Window varies per camera + shot type, so Check() is called with an
-- explicit override each time rather than a fixed window at construction.
local shotCooldown = Cooldown.new()

-- Server always resolves cameraId from the server-observed equipped tool's
-- attribute, never a client-declared identity.
local function getEquippedCameraTool(player)
	local character = player.Character
	if not character then return nil end

	local tool = character:FindFirstChildOfClass("Tool")
	if tool and tool:GetAttribute("IsCameraTool") == true then
		return tool
	end
	return nil
end

local function handleShot(player, shotType, origin, direction)
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end

	local cameraTool = getEquippedCameraTool(player)
	if not cameraTool then
		warn(player.Name, "tried to camera-shoot without holding a camera")
		return
	end

	local cameraId = CameraStats.GetIdFromTool(cameraTool)
	local settings = CameraStats.GetShotSettings(cameraId, shotType)

	if not shotCooldown:Check(player.UserId, settings.Cooldown) then
		return
	end

	local character = player.Character
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }

	local result = PhotoCapture.Fire(origin, direction.Unit, settings.Range, settings.SpreadRadius, raycastParams)

	if result then
		local distanceMeters = Units.StudsToMeters(result.distanceStuds)
		print(string.format("%s took a %s shot from %.1fm away", player.Name, string.lower(shotType), distanceMeters))

		ShotFeedback:FireClient(player, {
			shotType = shotType,
			hit = true,
			distanceMeters = distanceMeters,
			position = result.hitPosition,
		})
	else
		ShotFeedback:FireClient(player, {
			shotType = shotType,
			hit = false,
		})
	end
end

WeakCameraShot.OnServerEvent:Connect(function(player, origin, direction)
	handleShot(player, "Weak", origin, direction)
end)

StrongCameraShot.OnServerEvent:Connect(function(player, origin, direction)
	handleShot(player, "Strong", origin, direction)
end)
