local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraShelfGui = require(ReplicatedStorage.Modules.CameraShelf.CameraShelfGui)
local ShelfResultCodes = require(ReplicatedStorage.Modules.CameraShelf.ShelfResultCodes)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local ControlLock = require(ReplicatedStorage.Modules.Shared.ControlLock)

local OpenCameraShelf = Remotes.Get("OpenCameraShelf")
local CloseCameraShelf = Remotes.Get("CloseCameraShelf")
local CameraShelfResult = Remotes.Get("CameraShelfResult")

local player = Players.LocalPlayer

local LOCK_REASON = "CameraShelf"

local shelfGui = nil
local isOpen = false


local function lockMovementAndMouse()
	ControlLock.Acquire(LOCK_REASON)

	UserInputService.MouseIconEnabled = true
	RunService:BindToRenderStep("CameraShelfMouseUnlock", Enum.RenderPriority.Camera.Value + 1, function()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end)
end

local function unlockMovementAndMouse()
	ControlLock.Release(LOCK_REASON)

	RunService:UnbindFromRenderStep("CameraShelfMouseUnlock")
	UserInputService.MouseIconEnabled = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

local function closeShelf()
	-- Idempotency guard, added alongside the ControlLock migration: unlike
	-- the old controls:Enable(), ControlLock.Release warns on a reason that
	-- isn't held, and CameraShelfResult's "Success" branch below used to call
	-- this unconditionally.
	if not isOpen then
		return
	end
	if shelfGui then
		shelfGui.Enabled = false
	end
	isOpen = false
	unlockMovementAndMouse()
	CloseCameraShelf:FireServer()
end

local function openShelf()
	if not shelfGui then
		shelfGui = CameraShelfGui.Build(closeShelf)
	end
	CameraShelfGui.Refresh(shelfGui, player:GetAttribute("CurrentCamera"))
	shelfGui.Enabled = true
	isOpen = true
	lockMovementAndMouse()
end


OpenCameraShelf.OnClientEvent:Connect(openShelf)

-- CurrentCamera is set server-side only (CameraInventory.Give) -- the client
-- just reads the Player attribute instead of keeping its own copy, so there
-- is exactly one source of truth for which camera the player is holding.
CameraShelfResult.OnClientEvent:Connect(function(resultData)
	if not shelfGui then return end

	CameraShelfGui.ShowMessage(shelfGui, ShelfResultCodes.GetMessage(resultData.reason))

	if resultData.success then
		CameraShelfGui.Refresh(shelfGui, player:GetAttribute("CurrentCamera"))
	end

	if resultData.reason == "Success" then
		closeShelf()
	end
end)


-- Death/respawn safety net, mirroring the shop's approach:
-- Died fires immediately on death (don't wait for respawn to clean up),
-- CharacterAdded is a backup net + the point where we re-bind Died for
-- the NEW character, since the old Humanoid's connection dies with it.
local function bindDeathHandler(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		if isOpen then
			closeShelf()
		end
	end)
end

if player.Character then
	bindDeathHandler(player.Character)
end

player.CharacterAdded:Connect(function(newCharacter)
	if isOpen then
		closeShelf()
	end
	bindDeathHandler(newCharacter)
end)
