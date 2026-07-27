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
		Stability = {
			MoveThreshold = 0.05,     -- Humanoid.MoveDirection.Magnitude above this counts as moving
			VelocityThreshold = 0.5,  -- studs/sec of root part velocity above this counts as moving
		},
		Shots = {
			Weak = {
				Range = 100,        -- studs — max raycast distance for a Weak (moving) shot; read server-side in PhotoCapture
				Cooldown = 0.5,     -- seconds — minimum time between accepted Weak shots per player (anti-spam)
				SpreadRadius = 0.015, -- tangent-scale spread width for the 5x5 raycast grid; larger = more forgiving aim, smaller = more precise
			},
			Strong = {
				Range = 150,        -- studs — max raycast distance for a Strong (stable) shot; longer range rewards standing still
				Cooldown = 0.5,     -- seconds — minimum time between accepted Strong shots per player (anti-spam)
				SpreadRadius = 0.015, -- tangent-scale spread width for the 5x5 raycast grid; larger = more forgiving aim, smaller = more precise
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
		Stability = {
			MoveThreshold = 0.05,
			VelocityThreshold = 0.5,
		},
		Shots = {
			Weak = { Range = 130, Cooldown = 0.4, SpreadRadius = 0.02 },
			Strong = { Range = 200, Cooldown = 0.4, SpreadRadius = 0.02 },
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

	if not warnedMissingIds[cameraId] then
		warnedMissingIds[cameraId] = true
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
