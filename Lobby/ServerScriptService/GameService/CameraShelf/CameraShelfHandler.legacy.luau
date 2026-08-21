local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)

-- Cameras are purchased and swapped ONLY on the Lobby by design (Phase 11's
-- read-only-on-Game loadout depends on that staying true -- see
-- docs/Planned.md). Every other self-wiring .legacy.luau Script in this repo
-- is role-gated except this one was; if an IsCameraShelf part were ever
-- placed on the Game place, this would have let a mid-match swap through
-- CameraShelfSwap's real CameraInventory.Give path (the Lobby's own
-- PreferenceSaved branch never applies there, since Game-place players do
-- have a Camera slot).
if not ServerRole.Is("LobbyServer") then
	return
end

local Cooldown = require(ReplicatedStorage.Modules.Shared.Cooldown)
local CameraShelfSwap = require(script.Parent.CameraShelfSwap)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)

local OpenCameraShelf = Remotes.Get("OpenCameraShelf")
local CloseCameraShelf = Remotes.Get("CloseCameraShelf")
local TakeCameraRequest = Remotes.Get("TakeCameraRequest")
local CameraShelfResult = Remotes.Get("CameraShelfResult")

local MAX_INTERACT_DISTANCE = 12 -- studs; generous margin over the ProximityPrompt's own activation range
local requestCooldown = Cooldown.new(0.5)

-- PromptTriggered has no cooldown or distance check of its own -- the prompt
-- normally throttles this, but nothing here re-verifies it server-side, so a
-- modified client re-arming shelfOpenFor at will was one FireClient per
-- trigger with no ceiling.
local promptCooldown = Cooldown.new(0.5)

-- Separate from requestCooldown: the "no open shelf" warn below fires before
-- requestCooldown is ever checked, so a client spamming TakeCameraRequest
-- with no shelf open could log unbounded. Bounds that independently.
local logCooldown = Cooldown.new(2)

-- Tracks which shelf part each player currently has open, so a
-- TakeCameraRequest can be rejected if it didn't come from a legitimately
-- opened prompt, or the player has since walked away from it.
local shelfOpenFor = {}

local function isShelfPart(part: Instance?): boolean
	return part ~= nil and part:GetAttribute("IsCameraShelf") == true
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	local part = prompt.Parent
	if not isShelfPart(part) then
		return
	end

	if not promptCooldown:Check(player.UserId) then
		return
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local tooFar = not rootPart
		or (rootPart.Position - (part :: BasePart).Position).Magnitude > MAX_INTERACT_DISTANCE
	if tooFar then
		return
	end

	shelfOpenFor[player.UserId] = part
	OpenCameraShelf:FireClient(player)
end)

TakeCameraRequest.OnServerEvent:Connect(function(player, cameraId)
	local shelfPart = shelfOpenFor[player.UserId]
	if not shelfPart then
		if logCooldown:Check(player.UserId) then
			warn(player.Name, "sent TakeCameraRequest without an open shelf UI")
		end
		return
	end

	if typeof(cameraId) ~= "string" then
		return
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local tooFar = not rootPart
		or not shelfPart.Parent
		or (rootPart.Position - (shelfPart :: BasePart).Position).Magnitude > MAX_INTERACT_DISTANCE

	if tooFar then
		CameraShelfResult:FireClient(player, {
			success = false,
			reason = "TooFarAway",
			cameraId = cameraId,
		})
		return
	end

	if not requestCooldown:Check(player.UserId) then
		return
	end

	local success, reason = CameraShelfSwap.TakeCamera(player, cameraId)

	CameraShelfResult:FireClient(player, {
		success = success,
		reason = reason,
		cameraId = cameraId,
	})

	if success and reason == "Success" then
		print(player.Name, "took", cameraId, "from the shelf")
		shelfOpenFor[player.UserId] = nil -- close server-side gate after a successful take
	end
end)

CloseCameraShelf.OnServerEvent:Connect(function(player)
	shelfOpenFor[player.UserId] = nil
end)

Players.PlayerRemoving:Connect(function(player)
	shelfOpenFor[player.UserId] = nil
end)
