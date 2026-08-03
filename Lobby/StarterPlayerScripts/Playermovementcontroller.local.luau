-- PlayerMovementController
-- Place in: StarterPlayer.StarterPlayerScripts (runs as a LocalScript)
--
-- Owns horizontal movement via a LinearVelocity constraint: snappy accel on
-- input, slower decay on release for the slide-to-stop feel. Sprint (hold
-- Shift) raises the target top speed, drains stamina, and pulls in FOV.
-- Also applies a small smoothed camera roll while strafing left/right.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStats = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PlayerStats"))
local PlayerRuntimeStats = require(ReplicatedStorage.Modules.PlayerRuntimeStats)
local CameraState = require(ReplicatedStorage.Modules.Camera.CameraState)
local CAMERA_SPEED_MULTIPLIER = 0.7


local player = Players.LocalPlayer

local isSprinting = false
local currentVelocity = Vector3.zero
local currentFOV = PlayerStats.BaseFOV
local currentTilt = 0
local activeHumanoid: Humanoid? = nil

local function setupCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart

	-- Let our LinearVelocity own X/Z entirely; don't fight the engine's own
	-- WalkSpeed-driven movement. Vertical motion (gravity, jumping) stays
	-- fully engine-governed -- we just lower how high a jump goes.
	humanoid.WalkSpeed = 0
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = PlayerStats.JumpHeight

	local attachment = Instance.new("Attachment")
	attachment.Name = "MovementAttachment"
	attachment.Parent = rootPart

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "MovementDrive"
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	-- Y max force = 0: gravity/jumping stay fully governed by the engine,
	-- we only ever drive X/Z.
	linearVelocity.MaxAxesForce = Vector3.new(PlayerStats.MaxAxisForce, 0, PlayerStats.MaxAxisForce)
	linearVelocity.VectorVelocity = Vector3.zero
	linearVelocity.Parent = rootPart

	isSprinting = false
	currentVelocity = Vector3.zero
	currentFOV = PlayerStats.BaseFOV
	currentTilt = 0
	activeHumanoid = humanoid
	-- Previously nothing reset Stamina on respawn -- die while exhausted,
	-- respawn exhausted, forever.
	PlayerRuntimeStats.Set("Stamina", PlayerStats.MaxStamina)
	local startCamera = workspace.CurrentCamera
	if startCamera then
		startCamera.FieldOfView = PlayerStats.BaseFOV
	end

	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if not character.Parent or humanoid.Health <= 0 then
			connection:Disconnect()
			activeHumanoid = nil
			return
		end

		-- MoveDirection is computed by Roblox's default control scripts from
		-- WASD + camera orientation -- we read it, we don't override it.
		local moveDir = humanoid.MoveDirection
		local isMoving = moveDir.Magnitude > 0.01

		-- Stamina drain/regen + auto-drop out of sprint at 0 stamina.
		if isSprinting then
			if isMoving then
				PlayerRuntimeStats.Add("Stamina", -PlayerStats.StaminaDrainRate * dt, PlayerStats.MaxStamina)
			end
			if (PlayerRuntimeStats.Get("Stamina") or 0) <= 0 then
				isSprinting = false
			end
		else
			PlayerRuntimeStats.Add("Stamina", PlayerStats.StaminaRegenRate * dt, PlayerStats.MaxStamina)
		end

		local topSpeed = isSprinting and PlayerStats.SprintSpeed or PlayerStats.WalkSpeed
		topSpeed *= CameraState.GetWalkSpeedMultiplier()
		
		local targetVelocity = Vector3.new(moveDir.X, 0, moveDir.Z) * topSpeed

		-- Snappy accel while input is held, slow decay after release
		-- (the "slippery stop" feel) -- frame-rate independent smoothing.
		local rate = isMoving and PlayerStats.AccelRate or PlayerStats.DecelRate
		local alpha = 1 - math.exp(-rate * dt)
		currentVelocity = currentVelocity:Lerp(targetVelocity, alpha)
		linearVelocity.VectorVelocity = currentVelocity

		-- Face camera yaw so strafing/aiming reads correctly in first person.
		local camera = workspace.CurrentCamera
		if camera then
			local look = camera.CFrame.LookVector
			local flatLook = Vector3.new(look.X, 0, look.Z)
			if flatLook.Magnitude > 0.001 then
				rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + flatLook)
			end

			-- FOV kick while sprinting -- same frame-rate independent smoothing
			-- as the velocity lerp, so it eases in/out rather than snapping.
			local targetFOV = isSprinting and PlayerStats.SprintFOV or PlayerStats.BaseFOV
			local fovAlpha = 1 - math.exp(-PlayerStats.FOVChangeRate * dt)
			currentFOV += (targetFOV - currentFOV) * fovAlpha
			camera.FieldOfView = currentFOV
		end
	end)
end

-- === Sprint input ===
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		if (PlayerRuntimeStats.Get("Stamina") or 0) >= PlayerStats.MinStaminaToSprint then
			isSprinting = true
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, _gameProcessed)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		isSprinting = false
	end
end)

if player.Character then
	setupCharacter(player.Character)
end
player.CharacterAdded:Connect(setupCharacter)

-- === Camera tilt on strafe ===
-- Roblox's default camera scripts recompute Camera.CFrame every frame on
-- RenderStepped at Enum.RenderPriority.Camera. We bind just after that
-- priority so our roll is layered on top of a fresh (untilted) CFrame each
-- frame instead of fighting or accumulating with the default camera.
RunService:BindToRenderStep("PlayerCameraTilt", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local camera = workspace.CurrentCamera
	if not camera or not activeHumanoid then return end

	local moveDir = activeHumanoid.MoveDirection
	-- How much of the movement is sideways relative to where the camera is
	-- facing: +1 = fully strafing right, -1 = fully strafing left.
	local strafe = camera.CFrame.RightVector:Dot(moveDir)

	local targetTilt = -strafe * PlayerStats.MaxCameraTilt
	local alpha = 1 - math.exp(-PlayerStats.CameraTiltRate * dt)
	currentTilt += (targetTilt - currentTilt) * alpha

	if math.abs(currentTilt) > 0.01 then
		camera.CFrame = camera.CFrame * CFrame.Angles(0, 0, math.rad(currentTilt))
	end
end)