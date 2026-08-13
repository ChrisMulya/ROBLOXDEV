-- Client-side free-look camera for a placed Portable CCTV: the camera sits AT
-- the lens and the player looks around from there, as if standing inside the
-- camera housing.
--
-- Scriptable, NOT Custom + CameraSubject -- and this is the deliberate
-- opposite of what Spectate does, so read G12 alongside this rather than
-- treating one as a mistake:
--
--   * Spectate FOLLOWS a moving player. Custom is what tracks a subject, and
--     Scriptable there froze the camera in place while the HUD claimed to be
--     watching someone -- the bug G12 records.
--   * A CCTV is an ANCHORED camera and must not move at all. Custom would
--     orbit the lens at the player's zoom distance, showing the housing from
--     outside instead of the view through it, and there is no zoom setting
--     that reliably means "exactly at the subject" for a non-humanoid part.
--     "The engine stops writing CFrame" is precisely the behaviour wanted
--     here: position is fixed, and this module owns rotation outright.
--
-- Everything acquired on entry goes into one Trove, so Exit is a single
-- Clean() and teardown cannot drift from setup -- the same shape
-- CameraSession uses for its own session.
--
-- Placement, ownership, and who may view all stay server-authoritative
-- (CCTVService). This only renders whatever the server hands it over
-- CCTVViewState, and the server can revoke that at any time.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Modules.Shared.Trove)

local CCTVViewController = {}

local RENDER_NAME = "CCTVFreeLook"
-- One past the camera-tilt bind in Playermovementcontroller (Camera + 1), so
-- this writes last and the strafe roll can't lean a bolted-down security
-- camera.
local RENDER_PRIORITY = Enum.RenderPriority.Camera.Value + 2

local LOOK_SENSITIVITY = 0.005 -- radians per pixel of input delta
local PITCH_LIMIT = math.rad(75) -- stops the view flipping over at the poles

local active = false
local currentLens: BasePart? = nil
local yaw, pitch = 0, 0
local touchDelta = Vector2.zero
local sessionTrove = nil

-- Resolved per call, never cached -- Workspace.CurrentCamera is replaced by
-- the engine on respawn/teleport, and a module-level capture goes stale.
local function getCamera(): Camera?
	return Workspace.CurrentCamera
end

local function tryExitCameraSession()
	local ok, CameraSession = pcall(function()
		return require(ReplicatedStorage.Modules.Camera.CameraSession)
	end)
	if ok and CameraSession and CameraSession.Exit then
		pcall(CameraSession.Exit)
	end
end

-- The camera sits INSIDE the housing, so the housing fills the view. Hidden
-- with LocalTransparencyModifier -- a client-only property that does not
-- replicate -- so the camera stays fully visible to everyone else, exactly
-- the way CameraSession dims the held camera tool for its own holder.
local function hideModel(model: Instance, trove)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local original = descendant.LocalTransparencyModifier
			descendant.LocalTransparencyModifier = 1
			trove:Add(function()
				if descendant.Parent then
					descendant.LocalTransparencyModifier = original
				end
			end)
		end
	end
	if model:IsA("BasePart") then
		local original = model.LocalTransparencyModifier
		model.LocalTransparencyModifier = 1
		trove:Add(function()
			if model.Parent then
				model.LocalTransparencyModifier = original
			end
		end)
	end
end

-- Roblox hides the local character's parts for first person, and with a
-- Scriptable camera its TransparencyController may never run again to put
-- them back -- so the player watched their own CCTV feed with their body
-- missing from the shot. Re-asserted per frame rather than once on entry,
-- because whether that controller runs at all under Scriptable is exactly the
-- thing not worth depending on. The equality guard keeps this to zero writes
-- in the steady state.
local function showLocalCharacter()
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	if not character then
		return
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.LocalTransparencyModifier ~= 0 then
			descendant.LocalTransparencyModifier = 0
		end
	end
end

local function render()
	local camera = getCamera()
	local lens = currentLens
	-- The camera being destroyed under us (match cleanup) is a normal exit,
	-- not an error state -- the server will also clear the view, this just
	-- gets there first rather than writing to a dead part for a frame.
	if not camera or not lens or not lens.Parent then
		CCTVViewController.Exit()
		return
	end

	-- Re-asserted every frame, not once on entry. Roblox's own CameraModule
	-- rewrites MouseBehavior from player.CameraMode on its own render step and
	-- stomps a one-shot lock -- the same fight CameraShelfClient already
	-- solves with a render-step bind holding Default. This runs at Camera + 2,
	-- after the engine's step, so this write is the one that lands.
	--
	-- Symptom when it was set only on entry: the FIRST entry into a CCTV had
	-- no look control at all (GetMouseDelta returns zero while unlocked) and
	-- only started working on a later re-entry, once the engine happened to
	-- have settled on LockCenter for its own reasons.
	if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end

	showLocalCharacter()

	local delta = UserInputService:GetMouseDelta() + touchDelta
	touchDelta = Vector2.zero

	yaw -= delta.X * LOOK_SENSITIVITY
	pitch = math.clamp(pitch - delta.Y * LOOK_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)

	-- Rebuilt from the lens position every frame rather than accumulated onto
	-- the previous CFrame: the lens is anchored, so this can never drift, and
	-- a nudged/re-placed camera is followed for free.
	camera.CFrame = CFrame.new(lens.Position)
		* CFrame.Angles(0, yaw, 0)
		* CFrame.Angles(pitch, 0, 0)
end

-- model is the whole placed CCTV (hidden locally so it doesn't block the
-- shot); lens is the part the camera sits at.
function CCTVViewController.Enter(lens: BasePart, model: Instance?)
	local camera = getCamera()
	if not camera then
		return
	end

	-- Re-entering (a different camera, or a re-toggle that raced the exit)
	-- tears the old session down first, so the Trove lifecycle stays strictly
	-- one-in-one-out and no transparency restore is ever skipped.
	if active then
		CCTVViewController.Exit()
	end
	active = true

	local trove = Trove.new()
	sessionTrove = trove
	currentLens = lens

	local localPlayer = Players.LocalPlayer
	local previousCameraType = camera.CameraType
	local previousSubject = camera.CameraSubject
	local previousCameraMode = localPlayer and localPlayer.CameraMode
	local previousMouseBehavior = UserInputService.MouseBehavior
	local previousMouseIcon = UserInputService.MouseIconEnabled

	tryExitCameraSession()

	-- Out of LockFirstPerson for the duration. That mode is what hides the
	-- local character and what makes the engine yaw the body to match camera
	-- rotation -- with the camera now being the CCTV's, both were wrong: the
	-- player couldn't see their own body standing in the shot, and the body
	-- turned to follow wherever the security camera was pointed.
	--
	-- A one-shot write is safe here: FirstPersonCrosshair only sets CameraMode
	-- on CharacterAdded and on a PlayerState change, never per frame, so
	-- nothing re-forces it mid-view and the restore below is not racing it.
	if localPlayer then
		localPlayer.CameraMode = Enum.CameraMode.Classic
		trove:Add(function()
			if localPlayer then
				localPlayer.CameraMode = previousCameraMode or Enum.CameraMode.Classic
			end
		end)
	end

	-- Start pointed where the lens actually faces, so opening a camera shows
	-- the shot it was placed to cover rather than an arbitrary heading.
	local look = lens.CFrame.LookVector
	yaw = math.atan2(-look.X, -look.Z)
	pitch = math.asin(math.clamp(look.Y, -1, 1))

	camera.CameraType = Enum.CameraType.Scriptable
	trove:Add(function()
		local liveCamera = getCamera()
		if not liveCamera then
			return
		end
		liveCamera.CameraType = previousCameraType or Enum.CameraType.Custom
		-- Prefer whatever humanoid exists NOW over the one saved on entry --
		-- dying while viewing destroys the saved one, and restoring a dead
		-- humanoid leaves the camera stuck on nothing.
		local character = Players.LocalPlayer and Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		liveCamera.CameraSubject = humanoid or previousSubject
	end)

	if model then
		hideModel(model, trove)
	end

	-- Locked so the mouse is a look control rather than a pointer -- the same
	-- reasoning as spectate's own lock.
	UserInputService.MouseIconEnabled = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	trove:Add(function()
		UserInputService.MouseBehavior = previousMouseBehavior or Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = previousMouseIcon ~= false
	end)

	touchDelta = Vector2.zero
	trove:Add(UserInputService.TouchMoved:Connect(function(input)
		touchDelta += Vector2.new(input.Delta.X, input.Delta.Y)
	end))

	RunService:BindToRenderStep(RENDER_NAME, RENDER_PRIORITY, render)
	trove:Add(function()
		RunService:UnbindFromRenderStep(RENDER_NAME)
	end)
end

function CCTVViewController.Exit()
	if not active then
		return
	end
	active = false
	currentLens = nil
	touchDelta = Vector2.zero

	if sessionTrove then
		sessionTrove:Clean()
		sessionTrove = nil
	end
end

function CCTVViewController.IsActive(): boolean
	return active
end

return CCTVViewController
