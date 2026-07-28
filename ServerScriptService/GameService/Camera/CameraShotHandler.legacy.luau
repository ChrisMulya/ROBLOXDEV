-- Thin remote adapter: validates the shooter and the shot itself, resolves
-- cooldown/settings, delegates the raycast to PhotoCapture, and routes any
-- hit through the Reward System. Reports the outcome (hit/miss + reward)
-- back to the shooter.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local CameraStats = require(ReplicatedStorage.Modules.Camera.CameraStats)
local Cooldown = require(ReplicatedStorage.Modules.Shared.Cooldown)
local PhotoCapture = require(script.Parent.PhotoCapture)
local CaptureGuard = require(ServerScriptService.GameService.Reward.CaptureGuard)
local RewardService = require(ServerScriptService.GameService.Reward.RewardService)

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

	if not CaptureGuard.ValidateShot(player, origin, direction) then
		warn(player.Name, "camera shot failed origin/direction validation")
		return
	end

	local cameraTool = getEquippedCameraTool(player)
	if not cameraTool then
		warn(player.Name, "tried to camera-shoot without holding a camera")
		return
	end

	local cameraId = CameraStats.GetIdFromTool(cameraTool)
	-- Server re-derives quality from actual movement state, so a client can't
	-- just always claim Strong for the bigger payout (see REWARD_SYSTEM.md).
	local resolvedQuality = CaptureGuard.ResolveShotQuality(player, shotType, cameraId)
	local settings = CameraStats.GetShotSettings(cameraId, resolvedQuality)

	if not shotCooldown:Check(player.UserId, settings.Cooldown) then
		return
	end

	local character = player.Character
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }

	local result = PhotoCapture.Fire(origin, direction.Unit, settings.Range, settings.SpreadRadius, raycastParams)

	if not result then
		ShotFeedback:FireClient(player, {
			shotType = resolvedQuality,
			hit = false,
		})
		return
	end

	local rewardContext = {
		player = player,
		subject = result.subject,
		shotQuality = resolvedQuality,
		distanceStuds = result.distanceStuds,
		cameraId = cameraId,
	}

	-- Always routes through the full resolve/validate/calculate/grant
	-- pipeline -- the result always carries a resultCode explaining the
	-- outcome (Awarded, TooFar, WrongShotQuality, OnRepeatCooldown,
	-- UnknownTarget), amounts only present when Awarded. See RewardService.
	local rewardResult = RewardService.AwardFromCapture(player, rewardContext)

	ShotFeedback:FireClient(player, {
		shotType = resolvedQuality,
		hit = true,
		position = result.hitPosition,
		meters = rewardResult.meters,
		bandLabel = rewardResult.bandLabel,
		targetType = rewardResult.targetType,
		resultCode = rewardResult.resultCode,
		amounts = rewardResult.amounts,
		rollMultiplier = rewardResult.rollMultiplier,
	})
end

WeakCameraShot.OnServerEvent:Connect(function(player, origin, direction)
	handleShot(player, "Weak", origin, direction)
end)

StrongCameraShot.OnServerEvent:Connect(function(player, origin, direction)
	handleShot(player, "Strong", origin, direction)
end)
