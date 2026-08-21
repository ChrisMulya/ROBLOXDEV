-- Thin remote adapter: validates the shooter and the shot itself, resolves
-- cooldown/settings, delegates the raycast to PhotoCapture, and routes any
-- hit through the Reward System. Reports the outcome (hit/miss + reward)
-- back to the shooter.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)

-- Photo shots only ever pay out on a Game Server (RewardService fails closed
-- off it anyway) -- refusing to even wire the remotes here means the Lobby
-- never runs the raycast at all, not just never scores it.
if not ServerRole.Is("GameServer") then
	return
end

local CameraStats = require(ReplicatedStorage.Modules.Camera.CameraStats)
local Cooldown = require(ReplicatedStorage.Modules.Shared.Cooldown)
local PhotoCapture = require(script.Parent.PhotoCapture)
local CaptureGuard = require(ServerScriptService.GameService.Reward.CaptureGuard)
local RewardService = require(ServerScriptService.GameService.Reward.RewardService)
local FlashEvents = require(ServerScriptService.GameService.Flash.FlashEvents)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)

local WeakCameraShot = Remotes.Get("WeakCameraShot")
local StrongCameraShot = Remotes.Get("StrongCameraShot")
local ShotFeedback = Remotes.Get("ShotFeedback")

-- Window varies per camera + shot type, so Check() is called with an
-- explicit override each time rather than a fixed window at construction.
local shotCooldown = Cooldown.new()

-- Separate from shotCooldown, which can't gate the two warns below (they fire
-- on paths that never reach a settings-derived cooldown window). Bounds log
-- volume from a client spamming invalid shots -- previously unthrottled.
local logCooldown = Cooldown.new(2)

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
		if logCooldown:Check(player.UserId) then
			warn(player.Name, "camera shot failed origin/direction validation")
		end
		return
	end

	local cameraTool = getEquippedCameraTool(player)
	if not cameraTool then
		if logCooldown:Check(player.UserId) then
			warn(player.Name, "tried to camera-shoot without holding a camera")
		end
		return
	end

	local cameraId = CameraStats.GetIdFromTool(cameraTool)
	-- Server re-derives quality from replicated movement state (MoveDirection/
	-- AssemblyLinearVelocity/HumanoidState). That downgrades an HONEST client
	-- that is actually moving -- it does not defeat a MODIFIED client, which
	-- owns and replicates those same properties and can report stillness while
	-- moving. Accepted risk, same posture as the client-supplied shot origin
	-- (REWARD_SYSTEM.md): bounded by the live 8s per-subject repeat cooldown
	-- (CaptureGuard.CheckRepeatPolicy), not eliminated. A real fix needs a
	-- server-side displacement sample over time, not a single replicated read.
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

	FlashEvents:Fire({
		player = player,
		origin = origin,
		direction = direction,
		cameraId = cameraId,
		shotQuality = resolvedQuality,
		hitPosition = result and result.hitPosition or nil,
		timestamp = os.clock(),
	})

	if not result then
		ShotFeedback:FireClient(player, {
			shotType = resolvedQuality,
			hit = false,
		})
		return
	end

	-- Server-derived distance for RULE GATES (MaxMeters/MinMeters), kept
	-- separate from distanceStuds below on purpose. distanceStuds measures
	-- from the client-reported origin -- an accepted, documented economy
	-- risk (REWARD_SYSTEM.md), bounded to +-10 studs by CaptureGuard, that
	-- only ever shifts a reward BAND by one step. A hard eligibility CUTOFF
	-- is a different kind of exposure: the same 10-stud slack turned a 15m
	-- objective gate into an effective 18.33m. headDistanceStuds is measured
	-- from the server's own Head position, so a rule gate can never be
	-- widened by a spoofed origin.
	local head = character and character:FindFirstChild("Head")
	local headDistanceStuds = head and (head.Position - result.hitPosition).Magnitude

	local rewardContext = {
		player = player,
		subject = result.subject,
		shotQuality = resolvedQuality,
		distanceStuds = result.distanceStuds,
		headDistanceStuds = headDistanceStuds,
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
