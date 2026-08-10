-- Camera transitions only, driven entirely by server-assigned targets.
-- Must restore CameraType/CameraSubject on every exit path, and must
-- coordinate with the existing camera system: CameraSession is the single
-- most connected node in the graph (per GRAPH_REPORT), so entering spectate
-- must force-exit any active camera session rather than fight it for
-- control.
--
-- CameraSession isn't migrated to this place yet (see MAINHANDOFF's
-- content-migration gap) -- the exit call is wrapped in pcall so this
-- controller degrades gracefully today and does the right thing once that
-- migration lands, with no further edit here.
--
-- Spectating is CameraType.Custom + CameraSubject, NOT Scriptable. Scriptable
-- means "no engine camera logic at all": the engine stops writing CFrame and
-- ignores CameraSubject entirely, so the camera freezes wherever it happened
-- to be and never follows the target. Custom is what actually follows a
-- subject. The cost is that Roblox's own camera scripts reassign CameraSubject
-- back to the local humanoid on respawn -- handled by the guard below rather
-- than by giving up engine camera control.
--
-- Mouse lock: verified live that entering spectate leaves MouseBehavior
-- stuck at LockCenter even though FirstPersonCrosshair already dropped
-- CameraMode to Classic for Dead/Spectating -- Roblox's own camera script
-- keeps re-forcing the lock here independent of CameraMode, driven by
-- CameraType.Custom + a Humanoid CameraSubject. Same fix as
-- MatchReceiptController: a one-shot MouseBehavior = Default doesn't stick,
-- so this fights it back every frame for as long as spectating is active,
-- and stops fighting (not force-relocks) on Stop().

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local SpectateCameraController = {}

local active = false
local previousCameraType: Enum.CameraType? = nil
local previousSubject: Instance? = nil

local currentTarget: Player? = nil
local desiredSubject: Instance? = nil
local subjectGuard: RBXScriptConnection? = nil
local targetSpawnConnection: RBXScriptConnection? = nil
local applyingSubject = false

-- Fixed anchor for the "no valid targets" fallback. Roblox's CameraSubject
-- cannot reliably be cleared to "nothing" -- confirmed live: assigning nil
-- left the camera pinned to the local player's own humanoid (Roblox's
-- default out-of-the-box subject), completely unchanged. A neutral fixed
-- part is the actual free-camera vantage point, matching the plan's own
-- suggested alternative ("a fixed map vantage point").
local freeCameraAnchor: Part? = nil

-- Resolved per call, never cached: Workspace.CurrentCamera is replaced by the
-- engine (respawn, place teleport), and a module-level capture taken at
-- require time goes stale -- every write then lands on a camera that is no
-- longer the one being rendered.
local function getCamera(): Camera?
	return Workspace.CurrentCamera
end

local function ensureFreeCameraAnchor(): Part
	if freeCameraAnchor and freeCameraAnchor.Parent then
		return freeCameraAnchor
	end
	local part = Instance.new("Part")
	part.Name = "SpectateFreeCameraAnchor"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.Position = Vector3.new(0, 20, 0)
	part.Parent = Workspace
	freeCameraAnchor = part
	return part
end

local function tryExitCameraSession()
	local ok, CameraSession = pcall(function()
		return require(ReplicatedStorage.Modules.Camera.CameraSession)
	end)
	if ok and CameraSession and CameraSession.Exit then
		pcall(CameraSession.Exit)
	end
end

local mouseUnlocked = false

local function unlockSpectateMouse()
	if mouseUnlocked then
		return
	end
	mouseUnlocked = true
	UserInputService.MouseIconEnabled = true
	RunService:BindToRenderStep("SpectateMouseUnlock", Enum.RenderPriority.Camera.Value + 1, function()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end)
end

local function relockSpectateMouse()
	if not mouseUnlocked then
		return
	end
	mouseUnlocked = false
	RunService:UnbindFromRenderStep("SpectateMouseUnlock")
	-- Deliberately does not force MouseBehavior/MouseIconEnabled back: if the
	-- local player respawned into Alive, CameraMode returns to LockFirstPerson
	-- (FirstPersonCrosshair) and its own RenderStepped loop reclaims both the
	-- moment Roblox's camera script settles MouseBehavior back to LockCenter.
end

local function resolveSubject(targetPlayer: Player?): Instance
	if targetPlayer and targetPlayer.Character then
		local humanoid = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return humanoid
		end
	end
	return ensureFreeCameraAnchor()
end

local function applySubject()
	local camera = getCamera()
	if not camera or not desiredSubject then
		return
	end
	if camera.CameraSubject == desiredSubject then
		return
	end
	applyingSubject = true
	camera.CameraSubject = desiredSubject
	applyingSubject = false
end

-- Roblox's default camera scripts reassign CameraSubject to the local player's
-- humanoid whenever the local character respawns. Without this, spectate
-- silently snaps back to your own corpse mid-session.
local function ensureSubjectGuard()
	if subjectGuard then
		return
	end
	local camera = getCamera()
	if not camera then
		return
	end
	subjectGuard = camera:GetPropertyChangedSignal("CameraSubject"):Connect(function()
		if active and not applyingSubject then
			applySubject()
		end
	end)
end

function SpectateCameraController.SetTarget(targetPlayer: Player?)
	local camera = getCamera()
	if not camera then
		return
	end

	if not active then
		previousCameraType = camera.CameraType
		previousSubject = camera.CameraSubject
		tryExitCameraSession()
		active = true
		unlockSpectateMouse()
	end

	camera.CameraType = Enum.CameraType.Custom

	if targetSpawnConnection then
		targetSpawnConnection:Disconnect()
		targetSpawnConnection = nil
	end
	currentTarget = targetPlayer

	-- The target dying and respawning replaces their Humanoid, which would
	-- leave us following a destroyed one.
	if targetPlayer then
		targetSpawnConnection = targetPlayer.CharacterAdded:Connect(function()
			if active and currentTarget == targetPlayer then
				desiredSubject = resolveSubject(targetPlayer)
				applySubject()
			end
		end)
	end

	desiredSubject = resolveSubject(targetPlayer)
	applySubject()
	ensureSubjectGuard()
end

function SpectateCameraController.Stop()
	if not active then
		return
	end
	active = false
	relockSpectateMouse()

	if subjectGuard then
		subjectGuard:Disconnect()
		subjectGuard = nil
	end
	if targetSpawnConnection then
		targetSpawnConnection:Disconnect()
		targetSpawnConnection = nil
	end
	currentTarget = nil
	desiredSubject = nil

	local camera = getCamera()
	if camera then
		camera.CameraType = previousCameraType or Enum.CameraType.Custom
		-- Prefer the humanoid we have NOW over the one saved on entry: the
		-- local player respawning during spectate (the normal way a spectate
		-- session ends) destroys the saved one, and restoring a destroyed
		-- humanoid leaves the camera stuck on nothing.
		local character = Players.LocalPlayer and Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		camera.CameraSubject = humanoid or previousSubject
	end

	if freeCameraAnchor then
		freeCameraAnchor:Destroy()
		freeCameraAnchor = nil
	end
end

return SpectateCameraController
