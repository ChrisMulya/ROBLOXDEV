local CameraStats = {}

-- Every stat that affects camera feel/behavior lives here, keyed by the
-- camera's CameraId attribute (NOT Tool.Name -- Tool.Name gets overwritten
-- at purchase/shelf-swap time by the slot name "Camera"). Add a new key
-- (e.g. Camera3 = {...}) to create a new camera with zero changes to any
-- other script.

CameraStats.Stats = {
	Camera1 = {
		DisplayName = "Old Reliable",
		Description = "Heavy and slow, but forgiving to aim.",
		ShelfOrder = 1,
		Blur = {
			MinSize = 0,              -- BlurEffect.Size while fully Stable (0 = no blur at all)
			MaxSize = 18,              -- BlurEffect.Size at/above MaxSpeedForFullBlur (max blur cap)
			MaxSpeedForFullBlur = 24,  -- studs/sec — speed at which blur reaches MaxSize; read in CameraEffects.UpdateFromSpeed
			SmoothingFactor = 0.15,    -- 0-1, how much blur steps toward its target each frame (higher = snappier, lower = smoother/laggier); same factor used both building up and clearing blur
		},
		Movement = {
			INCAMERA_WALK_SPEED_MULTIPLIER = 0.5, -- movement speed while InCamera (0.5 = 50% slower)
		},
		Zoom = {
			INCAMERA_FOV = 60,    -- degrees -- camera FieldOfView while InCamera (PlayerStats.BaseFOV is 70, so this reads as a zoom in)
			FOV_CHANGE_RATE = 12, -- higher = snappier scope-in; PlayerStats.FOVChangeRate (8) is the out-of-camera rate
		},
		Stability = {
			MoveThreshold = 0.05,     -- Humanoid.MoveDirection.Magnitude above this counts as moving
			VelocityThreshold = 0.5,  -- studs/sec of root part velocity above this counts as moving
		},
		Shots = {
			Weak = {
				Range = 350,        -- studs — max raycast distance for a Weak (moving) shot; read server-side in PhotoCapture
				Cooldown = 0.5,     -- seconds — minimum time between accepted Weak shots per player (anti-spam)
				SpreadRadius = 0.015, -- tangent of the aim cone's half-angle (coneHalfAngle = atan(2 * SpreadRadius) in PhotoCapture); larger = more forgiving aim, smaller = more precise
			},
			Strong = {
				Range = 350,        -- studs — max raycast distance for a Strong (stable) shot; longer range rewards standing still
				Cooldown = 0.5,     -- seconds — minimum time between accepted Strong shots per player (anti-spam)
				SpreadRadius = 0.015, -- tangent of the aim cone's half-angle (coneHalfAngle = atan(2 * SpreadRadius) in PhotoCapture); larger = more forgiving aim, smaller = more precise
			},
		},
		ColorGrade = {
			Brightness = -0.05,   -- slightly darker, old-sensor feel
			Contrast = 0.15,      -- punchier contrast, less washed out
			Saturation = -0.35,   -- desaturated, faded-film look
			TintColor = Color3.fromRGB(255, 235, 200), -- warm amber cast
		},
		Effects = {
			Grain = {
				FlickerMin = 0.75, -- most opaque the grain frame ever gets (lower = noisier)
				FlickerMax = 0.9,  -- most transparent the grain frame ever gets
			},
			Scanlines = {
				LineHeight = 3,       -- pixel height of each scanline
				LineSpacing = 5,      -- pixel gap between scanlines
				Transparency = 0.85,  -- closer to 1 = subtler, closer to 0 = heavy CRT look
			},
			Vignette = {
				Transparency = 0.4,  -- darkest point of the vignette edge fade
				SizeScale = 0.35,    -- fraction of screen height each top/bottom strip covers
			},
		},
		Viewfinder = {
			RecLabel = "● REC",
			SettingsLabel = "AUTO  1/125  f/2.8",
		},
		Flash = {
			Enabled = true,
			Color = Color3.fromRGB(255, 255, 245),
			Duration = 0.4,          -- seconds -- the DEFAULT flash length, used by any flash that isn't part of a capture sequence; Sequence below overrides it per-flash during a capture
			ScreenIntensity = 1.0,   -- 0-1, peak opacity of the full-screen fade; 0 disables it without removing the renderer
			LightBrightness = 3,     -- PointLight.Brightness at flash peak
			LightRange = 40,         -- studs -- doubles as the future monster-detection radius
			LightAngle = 90,         -- degrees -- reserved for a future SpotLight/viewing-angle check
			-- Two-stage capture, played by CameraSession.Capture. Both stages
			-- are HELD SOLID, not faded -- only the very last beat eases out.
			-- Cumulative timeline from the shutter press:
			--   0.000  CAMERA LIGHT on -- world light only, NO screen flash
			--   1.000  light off, hard cut (+CameraProcess)
			--   1.300  FLASH on -- world light AND screen (+Gap)
			--   1.383  flash fades, shutter sound, shot resolved, session
			--          exits (+SecondHold). The fade outlives the session by
			--          design; the flash GUI is independent of the viewfinder.
			--
			-- CameraProcess doubles as the exposure window: the player must
			-- hold still from the press until the session ends, or the shot is
			-- forced to Weak. See CameraSession.Capture.
			Sequence = {
				CameraProcess = 0.5,  -- seconds -- the camera light / exposure window
				Gap = 0.3,          -- seconds of darkness between light and flash
				SecondHold = 0.083, -- seconds -- flash held solid before it fades
				SecondFade = 0.2,   -- seconds -- the flash's ease-out
				-- Scales LightBrightness for the CameraProcess beat only, so the
				-- pre-shutter light reads as the camera warming up rather than
				-- competing with the shutter itself. The shutter beat always
				-- fires at full LightBrightness.
				CameraProcessBrightness = 0.5,
			},
		},
	},

	Camera2 = {
		DisplayName = "Quickdraw",
		Description = "Lighter and faster, tighter aim window.",
		ShelfOrder = 2,
		Blur = {
			MinSize = 0,
			MaxSize = 14,              -- slightly less max blur — steadier "hardware"
			MaxSpeedForFullBlur = 24,
			SmoothingFactor = 0.15,
		},
		Movement = {
			INCAMERA_WALK_SPEED_MULTIPLIER = 0.85, -- only 15% slower, lighter camera
		},
		Zoom = {
			INCAMERA_FOV = 60,
			FOV_CHANGE_RATE = 16, -- snappier scope than Camera1, matching its lighter feel
		},
		Stability = {
			MoveThreshold = 0.05,
			VelocityThreshold = 0.5,
		},
		Shots = {
			Weak = { Range = 350, Cooldown = 0.4, SpreadRadius = 0.02 },
			Strong = { Range = 350, Cooldown = 0.4, SpreadRadius = 0.02 },
		},
		ColorGrade = {
			Brightness = 0,
			Contrast = 0.05,
			Saturation = -0.1,          -- much less desaturated — modern sensor look
			TintColor = Color3.fromRGB(255, 255, 255), -- no tint
		},
		Effects = {
			Grain = { FlickerMin = 0.92, FlickerMax = 0.97 }, -- barely-there grain
			Scanlines = { LineHeight = 2, LineSpacing = 6, Transparency = 0.97 }, -- nearly invisible
			Vignette = { Transparency = 0.2, SizeScale = 0.2 },
		},
		Viewfinder = {
			RecLabel = "● REC",
			SettingsLabel = "4K  1/500  f/1.8",
		},
		Flash = {
			Enabled = true,
			Color = Color3.fromRGB(255, 255, 255),
			Duration = 0.3,
			ScreenIntensity = 0.85,
			LightBrightness = 8,
			LightRange = 50,
			LightAngle = 90,
			Sequence = {
				CameraProcess = 1,
				Gap = 0.3,
				SecondHold = 0.083,
				SecondFade = 0.2,
				CameraProcessBrightness = 0.5,
			},
		},
	},
}


-- Falls back to Camera1's stats only if a cameraId has no matching entry
-- at all (e.g. a typo, or a new camera added without stats yet).
CameraStats.Default = CameraStats.Stats.Camera1
local DEFAULT_ID = "Camera1"

local warnedMissingIds = {}

function CameraStats.GetStats(cameraId)
	local stats = CameraStats.Stats[cameraId]
	if stats then
		return stats
	end

	-- cameraId can legitimately be nil (e.g. a flash context with no camera
	-- tool behind it) -- warnedMissingIds[nil] = true would throw "table
	-- index is nil" instead of falling back, so nil gets its own key.
	local warnKey = cameraId or "<nil>"
	if not warnedMissingIds[warnKey] then
		warnedMissingIds[warnKey] = true
		warn(("CameraStats: no entry for CameraId '%s' — falling back to %s"):format(tostring(cameraId), DEFAULT_ID))
	end

	return CameraStats.Default
end

function CameraStats.GetBlurSettings(cameraId)
	return CameraStats.GetStats(cameraId).Blur
end

function CameraStats.GetMovementSettings(cameraId)
	return CameraStats.GetStats(cameraId).Movement
end

-- Nil-guarded like GetFlashSettings rather than raw-indexed like the others:
-- a camera entry authored before the Zoom block existed would otherwise
-- return nil and silently disable scope-in for that camera only.
function CameraStats.GetZoomSettings(cameraId)
	return CameraStats.GetStats(cameraId).Zoom or CameraStats.Default.Zoom
end

function CameraStats.GetStabilitySettings(cameraId)
	return CameraStats.GetStats(cameraId).Stability
end

function CameraStats.GetShotSettings(cameraId, shotType)
	return CameraStats.GetStats(cameraId).Shots[shotType]
end

function CameraStats.GetColorGradeSettings(cameraId)
	return CameraStats.GetStats(cameraId).ColorGrade
end

function CameraStats.GetEffectsSettings(cameraId)
	return CameraStats.GetStats(cameraId).Effects
end

function CameraStats.GetViewfinderSettings(cameraId)
	return CameraStats.GetStats(cameraId).Viewfinder
end

-- Falls back to Default's Flash block if this cameraId's entry predates the
-- Flash system (unlike the other accessors, which don't nil-guard missing
-- sections -- this one deliberately does).
function CameraStats.GetFlashSettings(cameraId)
	return CameraStats.GetStats(cameraId).Flash or CameraStats.Default.Flash
end

-- Single source of truth for resolving a camera Tool's identity. Always use
-- this instead of Tool.Name, which gets overwritten to "Camera" at
-- purchase/shelf-swap time.
function CameraStats.GetIdFromTool(tool: Tool): string
	return tool:GetAttribute("CameraId") or DEFAULT_ID
end

-- Camera ids sorted by ShelfOrder, for deterministic shelf UI ordering
-- (pairs() iteration order is not guaranteed and previously produced a
-- randomly-ordered shelf list every session).
function CameraStats.GetOrderedIds(): { string }
	local ids = {}
	for id in pairs(CameraStats.Stats) do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		local orderA = CameraStats.Stats[a].ShelfOrder or math.huge
		local orderB = CameraStats.Stats[b].ShelfOrder or math.huge
		if orderA == orderB then
			return a < b
		end
		return orderA < orderB
	end)
	return ids
end

return CameraStats
