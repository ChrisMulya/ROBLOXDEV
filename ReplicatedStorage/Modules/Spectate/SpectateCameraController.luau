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

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SpectateCameraController = {}

local camera = Workspace.CurrentCamera
local active = false
local previousCameraType: Enum.CameraType? = nil
local previousSubject: Instance? = nil

-- Fixed anchor for the "no valid targets" fallback. Roblox's CameraSubject
-- cannot reliably be cleared to "nothing" -- confirmed live: assigning nil
-- left the camera pinned to the local player's own humanoid (Roblox's
-- default out-of-the-box subject), completely unchanged. A neutral fixed
-- part is the actual free-camera vantage point, matching the plan's own
-- suggested alternative ("a fixed map vantage point").
local freeCameraAnchor: Part? = nil

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

function SpectateCameraController.SetTarget(targetPlayer: Player?)
	if not active then
		previousCameraType = camera.CameraType
		previousSubject = camera.CameraSubject
		tryExitCameraSession()
		active = true
	end

	-- Scriptable, not Custom -- Custom is Roblox's default interactive mode,
	-- and its built-in camera scripts fight for CameraSubject every frame
	-- (resetting it back to the local player) unless the camera is fully
	-- scripted.
	camera.CameraType = Enum.CameraType.Scriptable

	if targetPlayer and targetPlayer.Character then
		local humanoid = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
			return
		end
	end

	camera.CameraSubject = ensureFreeCameraAnchor()
end

function SpectateCameraController.Stop()
	if not active then
		return
	end
	active = false
	camera.CameraType = previousCameraType or Enum.CameraType.Custom
	camera.CameraSubject = previousSubject
	if freeCameraAnchor then
		freeCameraAnchor:Destroy()
		freeCameraAnchor = nil
	end
end

return SpectateCameraController
