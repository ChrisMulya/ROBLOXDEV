-- Orchestrates one camera "in-camera" session: resolves the tool's stats,
-- shows the viewfinder, applies Lighting effects, hides other GUIs, locks
-- CameraMode, hides the mouse icon, and dims the tool -- all registered into
-- one Trove as they're acquired, so Exit() is a single Clean() call and
-- teardown can never drift from setup.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Modules.Shared.Trove)
local CameraState = require(ReplicatedStorage.Modules.Camera.CameraState)
local CameraEffects = require(ReplicatedStorage.Modules.Camera.CameraEffects)
local CameraViewfinder = require(ReplicatedStorage.Modules.Camera.CameraViewfinder)
local CameraStats = require(ReplicatedStorage.Modules.Camera.CameraStats)
local FlashSignal = require(ReplicatedStorage.Modules.Flash.FlashSignal)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)

local WeakCameraShot = Remotes.Get("WeakCameraShot")
local StrongCameraShot = Remotes.Get("StrongCameraShot")
local CameraSessionChanged = Remotes.Get("CameraSessionChanged")

local player = Players.LocalPlayer

local CameraSession = {}

local sessionTrove = nil
local originalCameraMode = nil
local activeCameraId = nil

-- True from the moment the shutter is pressed until the two-stage flash
-- sequence finishes. While set, the session is LOCKED: Capture ignores repeat
-- presses and Toggle refuses to exit, so the sequence always plays through
-- rather than being cut in half by a second click. Forced exits (unequip,
-- spectate, death) still work -- they call Exit directly, which clears this.
local capturing = false

-- Per-frame watcher that runs only for the length of one exposure. Held at
-- module scope (not captured in Capture's closure) so Exit can kill it on a
-- forced teardown without needing a handle passed to it.
local exposureConnection: RBXScriptConnection? = nil

local function stopExposureWatch()
	if exposureConnection then
		exposureConnection:Disconnect()
		exposureConnection = nil
	end
end

local function setToolLocalTransparency(tool, transparency)
	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = transparency
		end
	end
end

-- Hides every other enabled ScreenGui and restores each one's PRIOR Enabled
-- state on exit (not a blanket re-enable), so a GUI that was legitimately
-- disabled before entering the camera stays disabled after leaving it.
--
-- Two exemptions, both required for the camera to be usable on touch devices:
--   - ScreenGuis carrying a KeepDuringCamera=true attribute (the viewfinder
--     itself, and CameraTouchHud) -- same attribute-tag convention as
--     IsCameraTool/IsMonster/IsCameraShelf elsewhere in this project.
--   - "TouchGui" by name: Roblox's own touch controls (joystick, jump). It's
--     engine-owned and gets recreated on control-scheme changes, so it can't
--     reliably carry our attribute. Hiding it previously also broke camera
--     look on touch devices -- CameraModule/CameraInput reads
--     TouchGui.TouchControlFrame and early-outs when TouchGui is disabled.
local function hideOtherGuis(trove)
	local playerGui = player:WaitForChild("PlayerGui")
	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui")
			and gui.Name ~= "CameraViewfinderGui"
			and gui.Name ~= "TouchGui"
			and not gui:GetAttribute("KeepDuringCamera")
			and gui.Enabled
		then
			gui.Enabled = false
			trove:Add(function()
				if gui and gui.Parent then
					gui.Enabled = true
				end
			end)
		end
	end
end

function CameraSession.IsActive(): boolean
	return CameraState.Get()
end

function CameraSession.Enter(tool: Tool)
	if CameraState.Get() then return end

	local cameraId = CameraStats.GetIdFromTool(tool)
	activeCameraId = cameraId
	local effectsSettings = CameraStats.GetEffectsSettings(cameraId)
	local blurSettings = CameraStats.GetBlurSettings(cameraId)
	local movementSettings = CameraStats.GetMovementSettings(cameraId)
	local colorGrade = CameraStats.GetColorGradeSettings(cameraId)
	local viewfinderSettings = CameraStats.GetViewfinderSettings(cameraId)

	sessionTrove = Trove.new()

	CameraViewfinder.Show(effectsSettings, viewfinderSettings)
	sessionTrove:Add(function()
		CameraViewfinder.Hide()
	end)

	-- Green reticle while the player is holding still, i.e. while a shot taken
	-- now would qualify Strong. Driven off CameraState rather than recomputing
	-- stability here: CameraClient's per-frame loop already owns that number,
	-- and a second implementation of the same rule is exactly what the
	-- stamina split had to undo. OnStableChanged only fires on a CHANGE, so
	-- the current value is seeded once here.
	CameraViewfinder.SetStable(CameraState.GetStable())
	sessionTrove:Add(CameraState.OnStableChanged(function(isStable: boolean)
		CameraViewfinder.SetStable(isStable)
	end))

	hideOtherGuis(sessionTrove)

	originalCameraMode = player.CameraMode
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	sessionTrove:Add(function()
		player.CameraMode = originalCameraMode or Enum.CameraMode.Classic
	end)

	UserInputService.MouseIconEnabled = false
	sessionTrove:Add(function()
		UserInputService.MouseIconEnabled = true
	end)

	CameraEffects.Apply(colorGrade, blurSettings)
	sessionTrove:Add(function()
		CameraEffects.Clear()
	end)

	setToolLocalTransparency(tool, 1)
	sessionTrove:Add(tool.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = 1
		end
	end))
	sessionTrove:Add(function()
		if tool and tool.Parent then
			setToolLocalTransparency(tool, 0)
		end
	end)

	CameraState.SetMovementSettings(movementSettings)
	-- Scope-in FOV. Applied by PlayerMovementController's Heartbeat (the one
	-- writer of Camera.FieldOfView), not here -- see CameraState.GetFOV.
	CameraState.SetZoomSettings(CameraStats.GetZoomSettings(cameraId))
	sessionTrove:Add(function()
		CameraState.SetZoomSettings(nil)
	end)
	CameraState.SetInCamera(true)

	-- Lets the server refuse actions that shouldn't interrupt an active
	-- session (e.g. the shelf swapping out an equipped, active camera).
	CameraSessionChanged:FireServer(true)
end

-- "Scope button" semantics: enters if not active, exits if active. Shared by
-- both the desktop right-click binding and the mobile Open/Close touch
-- button so the two input paths can never drift into different behavior.
function CameraSession.Toggle(tool: Tool)
	-- Locked mid-capture: scoping out here would strand the second flash and
	-- leave `capturing` set on a session that no longer exists.
	if capturing then
		return
	end
	if CameraState.Get() then
		CameraSession.Exit()
	else
		CameraSession.Enter(tool)
	end
end

function CameraSession.Exit()
	if not CameraState.Get() then return end

	-- A FORCED exit part-way through the sequence (unequip/spectate/death)
	-- lands here with `capturing` still set, meaning a flash is being HELD
	-- solid and the beat that would have cleared it is never going to run --
	-- that is a fully white screen for the rest of the session. Cut it here.
	--
	-- The normal end-of-sequence path clears `capturing` BEFORE calling Exit
	-- precisely so it skips this and its fade is left alone.
	if capturing then
		capturing = false
		stopExposureWatch()
		CameraViewfinder.SetProcessing(false)
		FlashSignal:Fire({ cameraId = activeCameraId, mode = "off" })
	end

	CameraState.SetInCamera(false)
	CameraState.SetMovementSettings(nil)

	if sessionTrove then
		sessionTrove:Clean()
		sessionTrove = nil
	end

	CameraSessionChanged:FireServer(false)
end

-- speed: studs/sec, the root part's current AssemblyLinearVelocity magnitude.
-- Drives both the world blur and the viewfinder's reticle ghost-ring.
function CameraSession.UpdateBlur(speed: number)
	if not CameraState.Get() then return end

	CameraEffects.UpdateFromSpeed(speed)
	CameraViewfinder.SetBlurAlpha(CameraEffects.GetBlurAlpha())
end

-- Two-stage capture. The session stays open and LOCKED for the whole
-- sequence (see `capturing`) rather than exiting on the shutter press as it
-- used to, so the player watches the exposure play out from the viewfinder.
--
-- The shot is resolved and sent at the END of the sequence, not on the press.
-- Two reasons, and they reinforce each other:
--
--   * Semantics. Sequence.CameraProcess is an EXPOSURE: holding the shot open
--     is the whole point, so what the photo captures is where the camera is
--     pointing when the exposure completes, and moving during it degrades the
--     result. Sampling the aim on the press would make the exposure window
--     decorative.
--   * CaptureGuard. The server rejects outright (not downgrades) any shot
--     whose origin is more than MAX_ORIGIN_DEVIATION_STUDS (10) from the
--     player's head when the remote lands. A press-time origin sent ~1.4s
--     later can exceed that -- in-camera walk speed is up to 8.5 studs/sec
--     (Camera2), so ~11.8 studs of drift is reachable -- and a moving player
--     would silently get NO photo where the whole point is that they get a
--     weak one.
--
-- movedDuringExposure is the exposure verdict: any frame where CameraState
-- reports unstable, anywhere from the press to the final beat, forces Weak.
-- It only ever downgrades -- a shot that was already Weak stays Weak.
function CameraSession.Capture()
	if not CameraState.Get() then return end
	if capturing then return end
	capturing = true

	local flashSettings = CameraStats.GetFlashSettings(activeCameraId)
	local sequence = flashSettings.Sequence
	local capturedCameraId = activeCameraId

	-- Seeded from the press so a shot begun while already moving is Weak even
	-- if the player stops dead for the rest of the exposure.
	local movedDuringExposure = not CameraState.GetStable()

	-- Light/flash placement follows the camera every beat rather than being
	-- pinned to the press position -- it is a light in the world attached to
	-- the player, so it should travel with them if they move.
	local function fireFlash(fields)
		local camera = workspace.CurrentCamera
		fields.cameraId = capturedCameraId
		fields.origin = camera.CFrame.Position
		fields.direction = camera.CFrame.LookVector
		FlashSignal:Fire(fields)
	end

	local function resolveAndSendShot()
		local camera = workspace.CurrentCamera
		local origin = camera.CFrame.Position
		local direction = camera.CFrame.LookVector

		-- CameraState.GetStable() is re-checked here as well as across the
		-- window: the final frame counts too.
		local stable = CameraState.GetStable() and not movedDuringExposure
		if stable then
			StrongCameraShot:FireServer(origin, direction)
		else
			WeakCameraShot:FireServer(origin, direction)
		end
	end

	-- No Sequence block authored for this camera: fall back to the old
	-- single-flash-then-exit behaviour rather than guessing timings.
	if not sequence then
		resolveAndSendShot()
		fireFlash({ withSound = true })
		capturing = false
		CameraSession.Exit()
		return
	end

	-- Yellow reticle for the whole exposure -- the "hold still" cue. Spans
	-- exactly the window in which moving forces the shot to Weak, so it stops
	-- when the verdict is locked in, not when the light goes out.
	CameraViewfinder.SetProcessing(true)

	-- Watches the whole exposure. Disconnected on the final beat and by Exit,
	-- so a forced exit (unequip/spectate/death) can't leak it.
	stopExposureWatch()
	exposureConnection = RunService.Heartbeat:Connect(function()
		if not CameraState.GetStable() then
			movedDuringExposure = true
		end
	end)

	-- Every step re-checks `capturing`, which a forced Exit clears. Without
	-- that, an unequip/spectate/death part-way through would leave the
	-- remaining beats firing into a closed session -- and, worse, could strand
	-- the light/screen ON forever if the "off" beat never ran. Exit fires its
	-- own "off" for exactly that reason.
	--
	-- screen = false: beat one is the CAMERA LIGHT, world only. The player's
	-- view is not whited out until the actual shutter on beat three.
	fireFlash({
		mode = "solid",
		screen = false,
		brightnessScale = sequence.CameraProcessBrightness,
	}) -- t = 0

	task.delay(sequence.CameraProcess, function()
		if not capturing then
			return
		end
		fireFlash({ mode = "off" }) -- t = CameraProcess

		task.delay(sequence.Gap, function()
			if not capturing then
				return
			end
			fireFlash({ mode = "solid" }) -- t = CameraProcess + Gap -- shutter

			task.delay(sequence.SecondHold, function()
				if not capturing then
					return
				end
				-- Last beat: exposure ends, so the verdict is final. Resolve
				-- and send the shot, then fade + sound + exit together.
				-- Cleared BEFORE Exit so Exit doesn't also fire an "off" and
				-- cut this fade short.
				capturing = false
				stopExposureWatch()
				CameraViewfinder.SetProcessing(false)
				resolveAndSendShot()
				fireFlash({
					mode = "fade",
					fadeDuration = sequence.SecondFade,
					withSound = true,
				})
				CameraSession.Exit()
			end)
		end)
	end)
end

return CameraSession
