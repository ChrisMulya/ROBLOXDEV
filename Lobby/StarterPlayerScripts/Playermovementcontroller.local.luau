-- PlayerMovementController
-- Place in: StarterPlayer.StarterPlayerScripts (runs as a LocalScript)
--
-- Owns horizontal movement via a LinearVelocity constraint: snappy accel on
-- input, slower decay on release for the slide-to-stop feel. Sprint (hold
-- Shift) raises the target top speed, drains stamina, and pulls in FOV.
-- Also applies a small smoothed camera roll while strafing left/right.
--
-- Sprint and stamina are owned by CharacterMovementService on the server; this
-- script asks for sprint over SprintRequest and renders whatever StaminaSync
-- reports. It does not simulate stamina itself -- one rule, one owner.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStats = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PlayerStats"))
local PlayerRuntimeStats = require(ReplicatedStorage.Modules.PlayerRuntimeStats)
local CameraState = require(ReplicatedStorage.Modules.Camera.CameraState)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local SprintIntent = require(ReplicatedStorage.Modules.Movement.SprintIntent)
local CAMERA_SPEED_MULTIPLIER = 0.7

local sprintRemote = Remotes.Get("SprintRequest")
local staminaRemote = Remotes.Get("StaminaSync")


local player = Players.LocalPlayer

local isSprinting = false
local currentVelocity = Vector3.zero
local currentFOV = PlayerStats.BaseFOV
local currentTilt = 0
local activeHumanoid: Humanoid? = nil

-- Bumped on every setupCharacter entry, captured locally, re-checked after the
-- yields. Same generation-guard shape QueueService uses for its pad countdown.
-- Module state below (activeHumanoid, isSprinting, currentVelocity, ...) is
-- singular, so without this a setup that started for an older character and
-- finished late would overwrite the live one -- leaving movement driving a
-- humanoid that no longer exists.
local setupGeneration = 0

local function setupCharacter(character: Model)
	-- Bounded waits with a bail, the same shape DeathService.bindCharacter
	-- uses. Unbounded WaitForChild here yielded forever whenever the character
	-- was destroyed mid-load -- which sunrise elimination made routine: the
	-- player is killed, deliberately never respawned (MatchStates
	-- .RespawnsOnDeath is false from Playing onward), and then teleported out,
	-- destroying the character while this was still waiting on it. The symptom
	-- was a pair of "Infinite yield possible on HumanoidRootPart" warnings and
	-- a leaked coroutine per match.
	setupGeneration += 1
	local myGeneration = setupGeneration

	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	local rootPart = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not humanoid or not rootPart or not character.Parent then
		return
	end

	-- A newer character started setting up while we were yielding above. That
	-- one owns the module state now; finishing here would hand movement back
	-- to the character the player just stopped being.
	if myGeneration ~= setupGeneration then
		return
	end

	-- Idempotent: this script calls setupCharacter directly for an existing
	-- character AND connects CharacterAdded, so the same model can arrive
	-- twice. Building a second Attachment/LinearVelocity on one root part
	-- would leave two LinearVelocities fighting over the same axes.
	if rootPart:FindFirstChild("MovementAttachment") then
		return
	end

	-- Let our LinearVelocity own X/Z entirely; don't fight the engine's own
	-- WalkSpeed-driven movement. Vertical motion (gravity, jumping) stays
	-- fully engine-governed -- JumpHeight/UseJumpPower are set by
	-- CharacterMovementService on the server (a client write to a Humanoid
	-- property does not replicate, and the server validates motion against
	-- its own copy), so we only touch WalkSpeed, and only locally.
	--
	-- Re-zeroed on change: the server sets a non-zero WalkSpeed as the
	-- validation budget, and that value replicates down to us. Without this
	-- the engine's own control would start driving the character on top of
	-- our LinearVelocity as soon as that replication landed.
	local function zeroLocalWalkSpeed()
		if humanoid.WalkSpeed ~= 0 then
			humanoid.WalkSpeed = 0
		end
	end
	zeroLocalWalkSpeed()
	humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(zeroLocalWalkSpeed)

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
	-- Stamina is not reset here: the server refills it on spawn and pushes the
	-- value down over StaminaSync.

	-- Jump rate limit. The character is simulated on this client, so the state
	-- machine that decides whether a jump happens is here -- this is the half
	-- the player actually feels. CharacterMovementService applies the same
	-- cooldown server-side.
	--
	-- The cooldown runs from LANDING, not from takeoff. Measured from takeoff
	-- it was invisible: a jump's airtime already exceeds JumpCooldown, so the
	-- state re-enabled before touchdown and a held spacebar re-jumped on
	-- contact exactly as if there were no cooldown at all.
	local jumpBlocked = false
	humanoid.StateChanged:Connect(function(_old, new)
		if new == Enum.HumanoidStateType.Jumping then
			if not jumpBlocked then
				jumpBlocked = true
				humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
			end
			return
		end

		-- Landed fires on touchdown, but a jump that ends on a slope or in
		-- water can settle straight into Running/Swimming instead -- treat any
		-- grounded state as the landing, or the block never lifts.
		local grounded = new == Enum.HumanoidStateType.Landed
			or new == Enum.HumanoidStateType.Running
			or new == Enum.HumanoidStateType.RunningNoPhysics
			or new == Enum.HumanoidStateType.Swimming
			or new == Enum.HumanoidStateType.Climbing
		if not jumpBlocked or not grounded then
			return
		end

		-- Cleared here, not in the delay: Landed is immediately followed by
		-- Running, and without this the cooldown would be scheduled twice.
		jumpBlocked = false
		task.delay(PlayerStats.JumpCooldown, function()
			if humanoid.Parent then
				humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			end
		end)
	end)
	local startCamera = workspace.CurrentCamera
	if startCamera then
		startCamera.FieldOfView = PlayerStats.BaseFOV
	end

	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if not character.Parent or humanoid.Health <= 0 then
			connection:Disconnect()
			-- Only surrender the shared state if we still own it. On a
			-- respawn the new character claims activeHumanoid before the old
			-- one's model is destroyed, so an unconditional clear here would
			-- null out the humanoid that just took over and leave the player
			-- unable to move.
			if myGeneration == setupGeneration then
				activeHumanoid = nil
			end
			return
		end

		-- MoveDirection is computed by Roblox's default control scripts from
		-- WASD + camera orientation -- we read it, we don't override it.
		local moveDir = humanoid.MoveDirection
		local isMoving = moveDir.Magnitude > 0.01

		-- Stamina is NOT simulated here. It used to be predicted per-frame and
		-- corrected by StaminaSync, which meant two independent implementations
		-- of the same rule: any disagreement (idle timer, drain gating) showed
		-- up as the server stomping the client's value 5x a second and the bar
		-- appearing frozen. CharacterMovementService owns the number outright;
		-- this only reads it to drop out of sprint when it runs out.
		if isSprinting and (PlayerRuntimeStats.Get("Stamina") or 0) <= 0 then
			isSprinting = false
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
-- Every input device writes SprintIntent; this is the only place that reads it,
-- applies the stamina gate, and talks to the server. Adding a device (touch
-- button, gamepad) means writing intent, not repeating this block.
SprintIntent.Changed:Connect(function(wanted: boolean)
	-- No sprinting while the camera is up. Camera mode deliberately slows
	-- movement (CameraState.GetWalkSpeedMultiplier, applied in the heartbeat
	-- above) and sprinting through that fights the intent of the mode.
	--
	-- UX rule, enforced client-side only, ON PURPOSE. The server-side signal
	-- for this is CameraSessionTracker's InCamera flag, which is
	-- client-reported -- CLAUDE.md forbids backing a server-authoritative
	-- check with it. Consequence, stated plainly: a modified client can still
	-- sprint in camera mode. That is accepted; the WalkSpeed budget still caps
	-- absolute speed.
	if wanted and not CameraState.Get() then
		if (PlayerRuntimeStats.Get("Stamina") or 0) >= PlayerStats.MinStaminaToSprint then
			-- Applied locally so sprint starts on the same frame as the input;
			-- the server grants it independently and its WalkSpeed budget is
			-- what ultimately caps us.
			isSprinting = true
		end
		sprintRemote:FireServer(true)
	else
		isSprinting = false
		sprintRemote:FireServer(false)
	end
end)

-- Opening the camera mid-sprint drops the sprint. Clearing the intent (rather
-- than just the local flag) means a held Shift / still-armed touch button does
-- not silently re-apply on the next Changed fire.
CameraState.OnChanged(function(inCamera: boolean)
	if inCamera and SprintIntent.Get() then
		SprintIntent.Set(false, "CameraMode")
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		SprintIntent.Set(true, "Keyboard")
	end
end)

UserInputService.InputEnded:Connect(function(input, _gameProcessed)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		SprintIntent.Set(false, "Keyboard")
	end
end)


-- Authoritative stamina from CharacterMovementService. The sole writer of the
-- Stamina runtime stat -- the HUD renders this and nothing else. It
-- deliberately carries no sprint flag: a sync already in flight when Shift is
-- pressed would otherwise cancel the sprint we just started.
staminaRemote.OnClientEvent:Connect(function(stamina: number)
	PlayerRuntimeStats.Set("Stamina", stamina)
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