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
local CCTVViewController = require(ReplicatedStorage.Modules.Item.CCTVViewController)
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

-- Stamped on every SprintRequest and echoed back in StaminaSync, so a verdict
-- can be told apart from a stale sync that was already in flight when the key
-- was pressed. Monotonic for the whole session, never reset per character --
-- the server records whatever id it last saw, so a respawn needs no agreement
-- on where the numbering restarts.
local sprintRequestId = 0

local function requestSprint(wanted: boolean)
	sprintRequestId += 1
	sprintRemote:FireServer(wanted, sprintRequestId)
end

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

		-- Read from the synced runtime values, not the PlayerStats base --
		-- WalkSpeed/SprintSpeed are buffable per-player now (Pills, Adrenaline
		-- Shot), and StaminaSync mirrors the server's effective numbers here
		-- for exactly that reason. Falls back to the PlayerStats base before
		-- the first sync lands.
		local topSpeed = isSprinting
			and (PlayerRuntimeStats.Get("SprintSpeed") or PlayerStats.SprintSpeed)
			or (PlayerRuntimeStats.Get("WalkSpeed") or PlayerStats.WalkSpeed)
		topSpeed *= CameraState.GetWalkSpeedMultiplier()
		
		local targetVelocity = Vector3.new(moveDir.X, 0, moveDir.Z) * topSpeed

		-- Snappy accel while input is held, slow decay after release
		-- (the "slippery stop" feel) -- frame-rate independent smoothing.
		local rate = isMoving and PlayerStats.AccelRate or PlayerStats.DecelRate
		local alpha = 1 - math.exp(-rate * dt)
		currentVelocity = currentVelocity:Lerp(targetVelocity, alpha)
		linearVelocity.VectorVelocity = currentVelocity

		-- Face camera yaw so strafing/aiming reads correctly in first person.
		--
		-- Skipped while a CCTV feed is open: the camera is the security
		-- camera's then, not the player's, so this would spin the body on the
		-- spot to face wherever the CCTV happens to point. Invisible to the
		-- viewer, who is looking through the camera -- but every other player
		-- watches them pirouette.
		local camera = workspace.CurrentCamera
		if camera then
			if not CCTVViewController.IsActive() then
				local look = camera.CFrame.LookVector
				local flatLook = Vector3.new(look.X, 0, look.Z)
				if flatLook.Magnitude > 0.001 then
					rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + flatLook)
				end
			end

			-- FOV kick while sprinting -- same frame-rate independent smoothing
			-- as the velocity lerp, so it eases in/out rather than snapping.
			--
			-- Scope wins over sprint: CameraState.GetFOV() is non-nil only
			-- while InCamera, and sprinting is already blocked in that state
			-- (see the SprintIntent handler below), so the two can't
			-- meaningfully disagree -- this just makes the precedence explicit
			-- rather than relying on that. Kept HERE rather than written from
			-- CameraSession so FieldOfView keeps exactly one writer; two loops
			-- assigning it would fight every frame.
			local scopeFOV = CameraState.GetFOV()
			local targetFOV = scopeFOV or (isSprinting and PlayerStats.SprintFOV or PlayerStats.BaseFOV)
			local fovRate = CameraState.GetFOVChangeRate() or PlayerStats.FOVChangeRate
			local fovAlpha = 1 - math.exp(-fovRate * dt)
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
		requestSprint(true)
	else
		isSprinting = false
		requestSprint(false)
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


-- Authoritative stamina/speed from CharacterMovementService. The sole writer
-- of these runtime stats -- the HUD and this script's own topSpeed read them
-- and nothing else. Payload widened from a bare stamina number to a table
-- (Stamina Sync now doubles as the effective-stat sync, since WalkSpeed/
-- SprintSpeed/MaxStamina are all buffable per-player).
--
-- It now DOES carry the server's sprint verdict, which it deliberately didn't
-- before -- a sync already in flight when Shift is pressed must not cancel the
-- sprint just started. That reason still holds, so the flag is paired with the
-- id of the request it answers and applied under two rules:
--
--   1. Cancel only. A payload can end a sprint, never start one; sprint still
--      begins locally on the input frame.
--   2. Only when it answers our LATEST request. An older id is a verdict about
--      a press we have already moved past, and is ignored.
--
-- Why this exists at all: the heartbeat's `stamina <= 0` test was the only way
-- the client ever dropped out of a sprint it started, and that depends on
-- observing one specific packet -- the server begins regenerating the very next
-- frame, so every later sync reports a positive value. Two clients hit that:
-- one whose exhaustion sync got batched behind a fresher one, and one that
-- tapped Shift while its stamina copy still read above MinStaminaToSprint and
-- the server's had already fallen below it. Both ended up sprinting locally
-- with the server never granting it -- and therefore never draining -- so
-- stamina refilled underneath them and the sprint never ended.
staminaRemote.OnClientEvent:Connect(function(payload: { stamina: number, maxStamina: number, walkSpeed: number, sprintSpeed: number, sprinting: boolean?, requestId: number? })
	PlayerRuntimeStats.Set("Stamina", payload.stamina)
	PlayerRuntimeStats.Set("MaxStamina", payload.maxStamina)
	PlayerRuntimeStats.Set("WalkSpeed", payload.walkSpeed)
	PlayerRuntimeStats.Set("SprintSpeed", payload.sprintSpeed)

	if isSprinting and payload.sprinting == false and payload.requestId == sprintRequestId then
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