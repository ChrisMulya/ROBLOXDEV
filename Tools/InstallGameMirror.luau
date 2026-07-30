--[[
	InstallGameMirror -- paste into Roblox Studio's command bar (Edit mode,
	on the Game place, PlaceId 100171816233157) to perform the Phase 7.5
	migration in one shot: creates every Tier 1/2/3 instance from
	~/.claude/plans/before-phase-8-perform-scalable-mochi.md section 3 with
	the exact Source text from disk as of 2026-07-30.

	NOT synced into either place -- "Tools/" is not a Roblox-service-named
	folder (see MAINHANDOFF.md). Meant to be copy-pasted by hand, once.

	Idempotent: existing instances of the wrong class are destroyed and
	recreated; existing instances of the right class just get their Source
	overwritten. Safe to re-run after this file is regenerated to match a
	future disk change -- though nothing currently automates keeping the two
	in sync (see the audit's sync-strategy recommendation: no Rojo yet).

	After running, paste Tools/CheckGameMirror.luau to confirm zero missing.
	This script does NOT place the Workspace spawn point or the tagged
	capture target -- those are manual Studio steps, not code.
]]

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local function folder(parent: Instance, name: string): Folder
	local f = parent:FindFirstChild(name)
	if not f or not f:IsA("Folder") then
		if f then f:Destroy() end
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

local function moduleScript(parent: Instance, name: string, source: string): ModuleScript
	local m = parent:FindFirstChild(name)
	if not m or not m:IsA("ModuleScript") then
		if m then m:Destroy() end
		m = Instance.new("ModuleScript")
		m.Name = name
		m.Parent = parent
	end
	m.Source = source
	return m
end

local function legacyScript(parent: Instance, name: string, source: string): Script
	local s = parent:FindFirstChild(name)
	if not s or not s:IsA("Script") then
		if s then s:Destroy() end
		s = Instance.new("Script")
		s.Name = name
		s.Parent = parent
	end
	s.RunContext = Enum.RunContext.Legacy
	s.Source = source
	return s
end

-- ============================================================ Shared =====

local Modules = folder(RS, "Modules")
local Shared = folder(Modules, "Shared")

moduleScript(Shared, "Units", [====[
-- Stud<->meter conversion. Roblox distances (raycasts, WalkSpeed, MonsterStats
-- radii, etc.) stay in studs everywhere internally -- this only exists for the
-- boundary where a stud distance becomes something a player reads.

local Units = {}

Units.STUDS_PER_METER = 3

function Units.StudsToMeters(studs: number): number
	return studs / Units.STUDS_PER_METER
end

return Units
]====])

-- ============================================================ Reward =====

local Reward = folder(Modules, "Reward")
local Curves = folder(Reward, "Curves")

moduleScript(Reward, "CaptureTargets", [====[
-- The registry of capturable target KINDS. Every capture attribute name
-- (IsMonster, IsObjective, ...) is defined here and nowhere else -- this is
-- what makes adding Boss/RareMonster/SecretObject/QuestObject/etc. a config
-- row instead of a code change, and what makes renaming an attribute (e.g.
-- the old bare CanCapture) a one-file edit.

local CaptureTargets = {}

-- Rules/Payout are consumed by CaptureRules and RewardCalculator
-- respectively; this module only owns identity (Attribute, Priority) and
-- resolution.
CaptureTargets.Types = {
	Monster = {
		Attribute = "IsMonster",
		Priority = 100,
		Rules = {}, -- no gating: always awards, per design decision
		RepeatPolicy = "Unlimited", -- anti-farm seam, currently disabled -- see REWARD_SYSTEM.md
		Payout = {
			Strategy = "Curve",
			UseDistanceMultiplier = true,
		},
	},

	Objective = {
		Attribute = "IsObjective",
		Priority = 200, -- wins over Monster if an instance somehow carries both
		Rules = {
			{ Rule = "RequireShotQuality", Value = "Strong", Code = "WrongShotQuality" },
			{ Rule = "MaxMeters", Value = 15, Code = "TooFar" }, -- inclusive: exactly 15m awards
			-- Checked before objectiveState: an instance tagged IsObjective but
			-- not yet (or no longer) tracked by ObjectiveRegistry used to fall
			-- through with objectiveState == nil, which reads as "not
			-- Available" and reports AlreadyCompleted ("Already Photographed")
			-- for an objective that was never touched. ObjectiveService's
			-- context provider sets objectiveRegistered explicitly either way.
			{ Rule = "RequireContextEquals", Field = "objectiveRegistered", Value = true, Code = "ObjectiveUnavailable" },
			{ Rule = "RequireContextEquals", Field = "objectiveState", Value = "Available", Code = "AlreadyCompleted" },
		},
		RepeatPolicy = "Unlimited",
		Payout = {
			Strategy = "FlatRoll",
			Base = { XP = 1000, Score = 500 },
			Roll = { Min = 0.3, Max = 0.4 },
			UseDistanceMultiplier = false,
		},
	},
}

-- Ordered by Priority (highest first), computed once at module load rather
-- than on every resolve -- pairs() iteration order isn't guaranteed and this
-- table rarely changes.
local orderedTypeNames = {}
for typeName in pairs(CaptureTargets.Types) do
	table.insert(orderedTypeNames, typeName)
end
table.sort(orderedTypeNames, function(a, b)
	return CaptureTargets.Types[a].Priority > CaptureTargets.Types[b].Priority
end)

function CaptureTargets.Get(typeName: string)
	return CaptureTargets.Types[typeName]
end

function CaptureTargets.AttributeFor(typeName: string): string?
	local typeDef = CaptureTargets.Types[typeName]
	return typeDef and typeDef.Attribute
end

-- Returns the type this EXACT instance is tagged as, or nil. Does not walk
-- ancestors -- see Resolve for that. Highest-Priority match wins if an
-- instance carries more than one type's attribute.
function CaptureTargets.TypeOf(instance: Instance): string?
	for _, typeName in ipairs(orderedTypeNames) do
		if instance:GetAttribute(CaptureTargets.Types[typeName].Attribute) then
			return typeName
		end
	end
	return nil
end

function CaptureTargets.IsType(instance: Instance, typeName: string): boolean
	local attribute = CaptureTargets.AttributeFor(typeName)
	return attribute ~= nil and instance:GetAttribute(attribute) == true
end

-- Walks from hitInstance up through its ancestors (stopping at workspace),
-- returning the first Instance carrying a registered type attribute and
-- which type it is, or (nil, nil). Checks hitInstance itself first, so
-- calling Resolve(subject) on an already-resolved subject doubles as a
-- re-verify: it re-checks that exact instance's attribute before falling
-- back to walking further up (which only matters if the tag moved, an edge
-- case handled the same way as the original walk-from-a-raycast-hit case).
function CaptureTargets.Resolve(hitInstance: Instance?): (Instance?, string?)
	local current = hitInstance
	while current and current ~= workspace do
		local typeName = CaptureTargets.TypeOf(current)
		if typeName then
			return current, typeName
		end
		current = current.Parent
	end
	return nil, nil
end

return CaptureTargets
]====])

moduleScript(Reward, "CaptureRules", [====[
-- Composable validation predicates a CaptureTargets type opts into via its
-- Rules list. Rules never know about target types; types never know how a
-- rule is implemented -- adding a new gating condition (time of day, height,
-- quest state) is one Register() call here, not a change to every type that
-- might want it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Units = require(ReplicatedStorage.Modules.Shared.Units)

local CaptureRules = {}

-- [name] = function(context, ruleSpec) -> boolean
-- context: { player, subject, shotQuality, distanceStuds, cameraId, targetType }
-- ruleSpec: the { Rule, Value, Code } entry from a type's Rules list
local predicates = {}

function CaptureRules.Register(name: string, predicate: (any, any) -> boolean)
	predicates[name] = predicate
end

CaptureRules.Register("RequireShotQuality", function(context, ruleSpec)
	return context.shotQuality == ruleSpec.Value
end)

CaptureRules.Register("MaxMeters", function(context, ruleSpec)
	-- Inclusive: exactly the threshold still passes ("distance <= 15m").
	return Units.StudsToMeters(context.distanceStuds) <= ruleSpec.Value
end)

CaptureRules.Register("MinMeters", function(context, ruleSpec)
	return Units.StudsToMeters(context.distanceStuds) >= ruleSpec.Value
end)

-- Generic equality gate against any field a context provider placed on the
-- context (e.g. RewardService's Objective provider adds context.objectiveState).
-- This rule knows nothing about objectives; it just compares a field to a
-- value, which is what lets Feature 4's whole gate be one config row.
CaptureRules.Register("RequireContextEquals", function(context, ruleSpec)
	return context[ruleSpec.Field] == ruleSpec.Value
end)

-- Runs every rule in typeDef.Rules against context in order, stopping at the
-- first failure. Returns true, nil on success, or false, code on failure.
-- An empty/absent Rules list (e.g. Monster) always passes.
function CaptureRules.Check(typeDef, context): (boolean, string?)
	for _, ruleSpec in ipairs(typeDef.Rules or {}) do
		local predicate = predicates[ruleSpec.Rule]
		if not predicate then
			warn(("CaptureRules: unknown rule '%s'"):format(tostring(ruleSpec.Rule)))
			continue
		end
		if not predicate(context, ruleSpec) then
			return false, ruleSpec.Code
		end
	end
	return true, nil
end

return CaptureRules
]====])

moduleScript(Reward, "RewardTypes", [====[
-- What a reward type IS: display name, where it lives, whether it survives
-- EndGame/rejoin. Adding a currency is a row here plus one base curve module
-- -- nothing that awards rewards needs to change.

local RewardTypes = {}

RewardTypes.All = {
	XP = {
		DisplayName = "XP",
		LeaderstatName = "XP",
		Persistent = true,
		ResetOnRunEnd = false,
		BaseCurveName = "XPRewardCurve",
		Round = "nearest",
	},
	Score = {
		DisplayName = "Score",
		LeaderstatName = "Score",
		Persistent = false,
		ResetOnRunEnd = true,
		BaseCurveName = "ScoreRewardCurve",
		Round = "nearest",
	},
}

function RewardTypes.Get(name: string)
	return RewardTypes.All[name]
end

function RewardTypes.Persistent(): { string }
	local names = {}
	for name, def in pairs(RewardTypes.All) do
		if def.Persistent then
			table.insert(names, name)
		end
	end
	return names
end

function RewardTypes.RunScoped(): { string }
	local names = {}
	for name, def in pairs(RewardTypes.All) do
		if def.ResetOnRunEnd then
			table.insert(names, name)
		end
	end
	return names
end

return RewardTypes
]====])

moduleScript(Reward, "RewardModifiers", [====[
-- Registry of optional reward bonuses (combo, streak, event, premium,
-- prestige, camera upgrade, entity rarity...). Ships empty -- the seam exists
-- so a future bonus is one Register() call, not a RewardCalculator edit.
--
-- A modifier is:
--   { Name: string, Stage: "Additive" | "Multiplicative", AppliesTo: string?,
--     Applies(context, rewardType) -> boolean, GetValue(context, rewardType) -> number }
-- Additive values are summed with the base curve before the distance
-- multiplier; Multiplicative values are multiplied in after it.

local RewardModifiers = {}

local registered = {}

function RewardModifiers.Register(modifier)
	table.insert(registered, modifier)
end

-- Returns { { Name, Stage, Value }, ... } for every registered modifier that
-- applies to this context/rewardType.
function RewardModifiers.Collect(context, rewardType: string)
	local applied = {}
	for _, modifier in ipairs(registered) do
		local appliesToThisType = not modifier.AppliesTo or modifier.AppliesTo == rewardType
		if appliesToThisType and modifier.Applies(context, rewardType) then
			table.insert(applied, {
				Name = modifier.Name,
				Stage = modifier.Stage,
				Value = modifier.GetValue(context, rewardType),
			})
		end
	end
	return applied
end

return RewardModifiers
]====])

moduleScript(Reward, "ShotResultCodes", [====[
-- Shared reason codes for a camera shot's outcome, and their player-facing
-- display strings. Mirrors CameraShelf/ShelfResultCodes -- one place the
-- server's returned code and the client's rendered text agree, instead of a
-- bare hardcoded string (the old "No Reward") drifting out of sync with why
-- a shot didn't pay out.

local ShotResultCodes = {}

ShotResultCodes.Messages = {
	TooFar = "Too Far",
	WrongShotQuality = "Needs a Strong Shot",
	OnRepeatCooldown = "Already Photographed",
	UnknownTarget = "Not Capturable",
	AlreadyCompleted = "Already Photographed",
	ObjectiveUnavailable = "Not Available",
	MatchNotScoring = "Match Has Ended",
}

-- "Awarded" has no message here -- the client renders the amounts instead.
-- Any other/unknown code falls back to a generic string rather than nil.
function ShotResultCodes.GetMessage(code: string?): string
	if not code or code == "Awarded" then
		return ""
	end
	return ShotResultCodes.Messages[code] or "No Reward"
end

return ShotResultCodes
]====])

moduleScript(Reward, "RewardCalculator", [====[
-- Pure reward math: CaptureContext -> RewardResult. Contains zero reward
-- values itself -- every number comes from a curve, a target type's Payout
-- config, or a modifier, so a balance change never touches this file.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage.Modules.Shared.Units)
local RewardTypes = require(script.Parent.RewardTypes)
local RewardModifiers = require(script.Parent.RewardModifiers)
local DistanceMultiplierCurve = require(script.Parent.Curves.DistanceMultiplierCurve)
local DistanceBandLabels = require(script.Parent.Curves.DistanceBandLabels)

local BASE_CURVES = {
	XPRewardCurve = require(script.Parent.Curves.XPRewardCurve),
	ScoreRewardCurve = require(script.Parent.Curves.ScoreRewardCurve),
}

local RewardCalculator = {}

-- Shared by every strategy so RewardModifiers behaves identically regardless
-- of how the base amount was produced. extraMultiplier folds in whatever the
-- strategy itself contributes (the distance curve for Curve, the roll for
-- FlatRoll) so modifiers stack on top of it, not instead of it.
local function applyModifiers(context, rewardType: string, base: number, extraMultiplier: number)
	local modifiers = RewardModifiers.Collect(context, rewardType)
	local flat = 0
	local multiplier = extraMultiplier
	for _, applied in ipairs(modifiers) do
		if applied.Stage == "Additive" then
			flat += applied.Value
		elseif applied.Stage == "Multiplicative" then
			multiplier *= applied.Value
		end
	end
	return (base + flat) * multiplier, modifiers
end

-- Original behavior, unchanged: base amount from a per-shot-quality curve,
-- scaled by the distance falloff curve. This is what every monster capture
-- has always used.
local function calculateCurve(context, distanceMultiplier: number)
	local amounts = {}
	local breakdown = {}

	for typeName, typeDef in pairs(RewardTypes.All) do
		local baseCurve = BASE_CURVES[typeDef.BaseCurveName]
		local base = baseCurve:Evaluate(context.shotQuality)

		local amount, modifiers = applyModifiers(context, typeName, base, distanceMultiplier)
		amounts[typeName] = math.round(amount)
		breakdown[typeName] = { Base = base, DistanceMultiplier = distanceMultiplier, Modifiers = modifiers }
	end

	return amounts, breakdown
end

-- Objectives: a fixed base per currency times ONE random roll shared across
-- every currency -- a 0.35 roll means exactly +350 XP and +175 Score off a
-- 1000/500 base. Two independent rolls would break that relationship. No
-- distance multiplier: objectives gate on distance (CaptureRules.MaxMeters)
-- instead of scaling payout by it.
local function calculateFlatRoll(context, payout)
	local rollSpec = payout.Roll
	local roll = rollSpec.Min + math.random() * (rollSpec.Max - rollSpec.Min)
	if rollSpec.Step then
		roll = math.floor(roll / rollSpec.Step + 0.5) * rollSpec.Step
	end

	local amounts = {}
	local breakdown = {}

	for typeName, base in pairs(payout.Base) do
		local amount, modifiers = applyModifiers(context, typeName, base, roll)
		amounts[typeName] = math.round(amount)
		breakdown[typeName] = { Base = base, Roll = roll, Modifiers = modifiers }
	end

	return amounts, breakdown, roll
end

-- meters + band label only, no payout math. For failure-path display (a shot
-- that didn't qualify for a reward) where distance should still be shown.
function RewardCalculator.Describe(distanceStuds: number): (number, string)
	local meters = Units.StudsToMeters(distanceStuds)
	return meters, DistanceBandLabels:Evaluate(meters)
end

-- context: { player, subject, shotQuality, distanceStuds, cameraId }
-- targetTypeDef: a CaptureTargets.Types entry; its Payout table selects the
-- strategy. Omit (nil) to get the original Curve-with-distance-multiplier
-- behavior, preserving every pre-CaptureTargets caller.
-- returns { meters, bandLabel, amounts, breakdown, rollMultiplier? }
function RewardCalculator.Calculate(context, targetTypeDef)
	local meters = Units.StudsToMeters(context.distanceStuds)
	local payout = targetTypeDef and targetTypeDef.Payout
	local useDistanceMultiplier = not payout or payout.UseDistanceMultiplier ~= false
	local distanceMultiplier = if useDistanceMultiplier then DistanceMultiplierCurve:Evaluate(meters) else 1

	local amounts, breakdown, rollMultiplier
	if payout and payout.Strategy == "FlatRoll" then
		amounts, breakdown, rollMultiplier = calculateFlatRoll(context, payout)
	else
		amounts, breakdown = calculateCurve(context, distanceMultiplier)
	end

	return {
		meters = meters,
		bandLabel = DistanceBandLabels:Evaluate(meters),
		amounts = amounts,
		breakdown = breakdown,
		rollMultiplier = rollMultiplier,
	}
end

return RewardCalculator
]====])

moduleScript(Curves, "CurveFactory", [====[
-- Shared :Evaluate(input) contract every reward curve implements. Two curve
-- shapes cover every case so far: a straight key->value lookup (shot quality
-- -> base XP/Score) and a stepped falloff (distance -> multiplier). Adding a
-- third shape later is a new factory function here, not a change to callers.

local CurveFactory = {}

-- entries: { [key]: number }. default: value returned for an unrecognized key.
function CurveFactory.LookupCurve(entries: { [any]: number }, default: number)
	return {
		Evaluate = function(_self, key)
			local value = entries[key]
			if value == nil then
				return default
			end
			return value
		end,
	}
end

-- spec: { StepMeters, StartValue, StepDelta, MinValue }
-- tier = floor(input / StepMeters); value = max(MinValue, StartValue + StepDelta * tier).
-- Upper bound of each step is exclusive: input == StepMeters lands in tier 1,
-- not tier 0 (see REWARD_SYSTEM.md's boundary note).
function CurveFactory.SteppedCurve(spec)
	return {
		Evaluate = function(_self, input: number)
			local tier = math.floor(input / spec.StepMeters)
			return math.max(spec.MinValue, spec.StartValue + spec.StepDelta * tier)
		end,
	}
end

return CurveFactory
]====])

moduleScript(Curves, "DistanceMultiplierCurve", [====[
-- meters -> reward multiplier. The only place the distance falloff shape is
-- defined; RewardCalculator just calls :Evaluate.

local CurveFactory = require(script.Parent.CurveFactory)

return CurveFactory.SteppedCurve({
	StepMeters = 15,
	StartValue = 1.0,
	StepDelta = -0.1,
	MinValue = 0.5,
})
]====])

moduleScript(Curves, "DistanceBandLabels", [====[
-- meters -> display label ("POINT BLANK", "CLOSE", ...). Presentation only --
-- never multiplied into a reward number. Ordered nearest-first; the first
-- band whose Max the distance doesn't exceed wins.

local DistanceBandLabels = {}

local BANDS = {
	{ Max = 15, Label = "POINT BLANK" },
	{ Max = 30, Label = "CLOSE" },
	{ Max = 45, Label = "MID" },
	{ Max = 60, Label = "FAR" },
}
local DEFAULT_LABEL = "DISTANT"

function DistanceBandLabels:Evaluate(meters: number): string
	for _, band in ipairs(BANDS) do
		if meters <= band.Max then
			return band.Label
		end
	end
	return DEFAULT_LABEL
end

return DistanceBandLabels
]====])

moduleScript(Curves, "XPRewardCurve", [====[
-- Shot quality -> base XP, before the distance multiplier and any modifiers.

local CurveFactory = require(script.Parent.CurveFactory)

return CurveFactory.LookupCurve({
	Strong = 1000,
	Weak = 600,
}, 0)
]====])

moduleScript(Curves, "ScoreRewardCurve", [====[
-- Shot quality -> base Score, before the distance multiplier and any modifiers.

local CurveFactory = require(script.Parent.CurveFactory)

return CurveFactory.LookupCurve({
	Strong = 200,
	Weak = 100,
}, 0)
]====])

-- ============================================================ Camera =====

local Camera = folder(Modules, "Camera")

moduleScript(Camera, "CameraStats", [====[
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
		Flash = {
			Enabled = true,
			Color = Color3.fromRGB(255, 255, 245),
			Duration = 0.4,          -- seconds -- shared by both the screen and world-light renderers
			ScreenIntensity = 1.0,   -- 0-1, peak opacity of the full-screen fade; 0 disables it without removing the renderer
			LightBrightness = 6,     -- PointLight.Brightness at flash peak
			LightRange = 40,         -- studs -- doubles as the future monster-detection radius
			LightAngle = 90,         -- degrees -- reserved for a future SpotLight/viewing-angle check
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
		Flash = {
			Enabled = true,
			Color = Color3.fromRGB(255, 255, 255),
			Duration = 0.3,
			ScreenIntensity = 0.85,
			LightBrightness = 8,
			LightRange = 50,
			LightAngle = 90,
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
]====])

moduleScript(Camera, "CameraStability", [====[
-- Pure "is the player moving or airborne" test. Thresholds come from
-- CameraStats.<id>.Stability so a future steadier/shakier camera can differ
-- by data alone.

local CameraStability = {}

-- thresholds: { MoveThreshold, VelocityThreshold }
function CameraStability.IsMoving(humanoid: Humanoid, rootPart: BasePart?, thresholds): boolean
	if humanoid.MoveDirection.Magnitude > thresholds.MoveThreshold then
		return true
	end

	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
		return true
	end

	if rootPart and rootPart.AssemblyLinearVelocity.Magnitude > thresholds.VelocityThreshold then
		return true
	end

	return false
end

return CameraStability
]====])

-- =========================================================== Objective ===

local Objective = folder(Modules, "Objective")

moduleScript(Objective, "ObjectiveStates", [====[
-- The objective state enum, and each state's semantics as data. Nothing in
-- the Objective or Reward systems branches on a state name -- they only ever
-- read IsRewardable/IsVisible, so adding a state is a new row here.
--
-- "Resettable" from the original brief is deliberately NOT a state: modelling
-- it as one allows an illegal combination (an objective both Completed and
-- Resettable) on day one. It is instead a ResetPolicy on the objective TYPE
-- (see ObjectiveTypes), which composes with every state below.

local ObjectiveStates = {}

-- VisualStyle here is an override of the owning type's VisualStyle -- nil
-- means "use whatever ObjectiveTypes says", which is every state's default
-- except the ones that should never be visible at all.
ObjectiveStates.All = {
	Available = { Rewardable = true, Visible = true, VisualStyle = nil },
	Completed = { Rewardable = false, Visible = false, VisualStyle = nil },
	Disabled = { Rewardable = false, Visible = false, VisualStyle = nil },
	Hidden = { Rewardable = false, Visible = false, VisualStyle = nil },
	MissionLocked = { Rewardable = false, Visible = false, VisualStyle = nil },
	EventOnly = { Rewardable = false, Visible = false, VisualStyle = nil },
}

function ObjectiveStates.IsRewardable(state: string): boolean
	local def = ObjectiveStates.All[state]
	return def ~= nil and def.Rewardable
end

function ObjectiveStates.IsVisible(state: string): boolean
	local def = ObjectiveStates.All[state]
	return def ~= nil and def.Visible
end

function ObjectiveStates.IsValid(state: string): boolean
	return ObjectiveStates.All[state] ~= nil
end

return ObjectiveStates
]====])

moduleScript(Objective, "ObjectiveTypes", [====[
-- Per-objective-type configuration, keyed by the ObjectiveType attribute
-- (defaults to "Standard" so plain IsObjective=true instances need no extra
-- authoring). Same registry shape as Reward/CaptureTargets -- adding Rare,
-- SecretCollectible, Mission, Daily, Seasonal, Cooperative, etc. is a new row
-- here, never a code change.

local ObjectiveTypes = {}

-- Ownership: "Player" (each player has independent state; everyone can
--   photograph the same one) or "Shared" (server-global; first completion
--   locks it for everyone).
-- ResetPolicy: "Never" | "OnRunEnd" | "Daily" | "OnEvent". Only "Never" and
--   "OnRunEnd" are wired (see ObjectiveService.Reset / EndGame); "Daily" and
--   "OnEvent" are declared for future use and require ObjectiveStore.
ObjectiveTypes.Types = {
	Standard = {
		Ownership = "Player",
		InitialState = "Available",
		ResetPolicy = "OnRunEnd",
		VisualStyle = "StandardGlow",
	},
	Rare = {
		Ownership = "Player",
		InitialState = "Available",
		ResetPolicy = "Never",
		VisualStyle = "RareGlow",
	},
	Cooperative = {
		Ownership = "Shared",
		InitialState = "Available",
		ResetPolicy = "OnRunEnd",
		VisualStyle = "CoopGlow",
	},
}

ObjectiveTypes.Default = ObjectiveTypes.Types.Standard
local DEFAULT_TYPE_NAME = "Standard"

function ObjectiveTypes.Get(typeName: string)
	return ObjectiveTypes.Types[typeName] or ObjectiveTypes.Default
end

-- Reads the ObjectiveType attribute off an instance, defaulting to Standard.
-- Does not check IsObjective -- that's ObjectiveRegistry's job.
function ObjectiveTypes.TypeOf(instance: Instance): string
	local typeName = instance:GetAttribute("ObjectiveType")
	if typeName and ObjectiveTypes.Types[typeName] then
		return typeName
	end
	return DEFAULT_TYPE_NAME
end

return ObjectiveTypes
]====])

-- ============================================================ Monster ====

local Monster = folder(Modules, "Monster")

moduleScript(Monster, "MonsterStats", [====[
local MonsterStats = {}

-- Every stat that affects monster behavior lives here, keyed by MonsterId then
-- Stage. Stage 1 must be a full table; every later stage is a SPARSE override
-- merged on top of stage 1 (see MonsterStats.Get).

MonsterStats.Stats = {
	GreyCube = {
		[1] = {
			WalkSpeed        = 12,     -- studs/sec
			DetectRadius     = 60,     -- studs -- max distance it will target a player from
			LoseInterestDist = 90,     -- studs -- reserved for future Wandering/Checking states
			PursuitDuration  = 20,     -- secs -- how long it keeps hunting after losing the player
			AttackReach      = 4,      -- studs -- Touched-based hit; this mostly documents intent
			AttackCooldown   = 1,      -- secs -- per-player damage cooldown, prevents multi-hit per frame
			States = { "Chase" },      -- MVP: chase is the whole brain

			-- Chance (0-1) that a requested transition into this state actually
			-- happens. Keeps the state machine from being 100% predictable once
			-- more states exist. At 1.0 it's a no-op.
			TransitionChance = { Chase = 1.0 },
		},
	},
}

-- Merges every stage override from 2 up to `stage` on top of the Stage 1 base,
-- so a stage entry only needs to list what actually changed.
function MonsterStats.Get(monsterId: string, stage: number?)
	local monsterTable = MonsterStats.Stats[monsterId]
	if not monsterTable then
		warn("MonsterStats.Get: unknown monster '" .. tostring(monsterId) .. "'")
		return nil
	end

	local resolvedStage = stage or 1
	local base = monsterTable[1]
	if not base then
		warn("MonsterStats.Get: monster '" .. monsterId .. "' has no Stage 1 base table")
		return nil
	end

	if resolvedStage == 1 then
		return base
	end

	local merged = table.clone(base)
	for s = 2, resolvedStage do
		local override = monsterTable[s]
		if override then
			for key, value in pairs(override) do
				merged[key] = value
			end
		end
	end

	return merged
end

return MonsterStats
]====])

-- ==================================================== GameService tree ===

local GameService = SSS:FindFirstChild("GameService")
assert(GameService, "InstallGameMirror: ServerScriptService.GameService does not exist -- run Phase 1's install first")

-- --- Reward ---

local GSReward = folder(GameService, "Reward")

moduleScript(GSReward, "RewardStore", [====[
-- DataStore wrapper for persistent reward types (currently XP only).
--
-- The central rule: A SESSION IS NOT SAVABLE UNTIL A LOAD HAS DEFINITIVELY
-- COMPLETED. Previously a failed read was indistinguishable from a brand-new
-- player -- both produced zeros, which were then written back over the
-- player's real total on leave. One transient DataStore outage would wipe
-- every online player's progress. Save() now refuses unless the session
-- reached "Ready".

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RewardTypes = require(ReplicatedStorage.Modules.Reward.RewardTypes)

local MAX_ATTEMPTS = 3
local RETRY_BASE_SECONDS = 0.5 -- doubled each retry; a throttled DataStore
                               -- must not be hammered with immediate retries
local AUTOSAVE_INTERVAL = 120

local RewardStore = {}

-- Swappable so failure paths can be exercised deterministically in tests --
-- a real outage can't be waited for, and the Ready gate is exactly what needs
-- coverage. Defaults to the real DataStore.
RewardStore.Backend = DataStoreService:GetDataStore("RewardStore_v1")

-- [userId] = { state: "Loading" | "Ready" | "Failed", baseline: {[type]: number} }
local sessions = {}

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

-- Returns (ok, result). Distinguishing failure from a nil result is the whole
-- point -- GetAsync returns nil for a new key, which must NOT be conflated
-- with "every attempt errored".
local function attempt(fn, ...)
	local args = { ... }
	for tries = 1, MAX_ATTEMPTS do
		local ok, result = pcall(fn, table.unpack(args))
		if ok then
			return true, result
		end
		warn(("RewardStore: DataStore call failed (attempt %d/%d) - %s"):format(tries, MAX_ATTEMPTS, tostring(result)))
		if tries < MAX_ATTEMPTS then
			task.wait(RETRY_BASE_SECONDS * 2 ^ (tries - 1))
		end
	end
	return false, nil
end

local function zeroedBaseline(): { [string]: number }
	local baseline = {}
	for _, typeName in ipairs(RewardTypes.Persistent()) do
		baseline[typeName] = 0
	end
	return baseline
end

-- Resolves the session to Ready (with a trustworthy baseline) or Failed.
-- Returns (baseline, ok). On failure the baseline is all zeros purely so the
-- caller has a shape to work with -- it is NOT trustworthy, and the Failed
-- state means it will never be written back.
function RewardStore.Load(player: Player): ({ [string]: number }, boolean)
	sessions[player.UserId] = { state = "Loading", baseline = nil }

	local ok, data = attempt(function()
		return RewardStore.Backend:GetAsync(keyFor(player))
	end)

	if not ok then
		sessions[player.UserId] = { state = "Failed", baseline = nil }
		warn(("RewardStore: could not load %s -- session will NOT be saved, stored data left untouched"):format(player.Name))
		return zeroedBaseline(), false
	end

	-- ok with nil data is a genuinely new player, not an error.
	local stored = data or {}
	local baseline = {}
	for _, typeName in ipairs(RewardTypes.Persistent()) do
		baseline[typeName] = stored[typeName] or 0
	end

	sessions[player.UserId] = { state = "Ready", baseline = baseline }
	return baseline, true
end

function RewardStore.IsReady(player: Player): boolean
	local session = sessions[player.UserId]
	return session ~= nil and session.state == "Ready"
end

-- values: { [rewardTypeName]: number } -- the persistent totals to store, as
-- read from the player's ledger. Callers are responsible for passing only
-- persistent types (see RewardTypes.Persistent).
--
-- Refuses outright unless the session is Ready. UpdateAsync (not SetAsync) so
-- the write merges into the stored record instead of replacing it wholesale.
function RewardStore.Save(player: Player, values: { [string]: number }?): boolean
	if not RewardStore.IsReady(player) then
		warn(("RewardStore: refusing to save %s -- session never loaded cleanly"):format(player.Name))
		return false
	end

	-- nil means the ledger couldn't produce a complete set of totals; writing
	-- a partial record is exactly the kind of guess this module now refuses.
	if not values then
		warn(("RewardStore: refusing to save %s -- incomplete ledger values"):format(player.Name))
		return false
	end

	local ok = attempt(function()
		RewardStore.Backend:UpdateAsync(keyFor(player), function(stored)
			local merged = stored or {}
			for typeName, amount in pairs(values) do
				merged[typeName] = amount
			end
			return merged
		end)
	end)

	return ok
end

-- Saves every player concurrently. Sequential saves could exceed Roblox's
-- ~30s BindToClose budget once retries/backoff are involved, silently
-- dropping whoever sat at the end of the list.
function RewardStore.SaveAll(getValues: (Player) -> { [string]: number })
	local pending = 0
	local done = Instance.new("BindableEvent")

	for _, player in ipairs(Players:GetPlayers()) do
		pending += 1
		task.spawn(function()
			pcall(function()
				RewardStore.Save(player, getValues(player))
			end)
			pending -= 1
			if pending == 0 then
				done:Fire()
			end
		end)
	end

	if pending > 0 then
		done.Event:Wait()
	end
	done:Destroy()
end

function RewardStore.ClearSession(player: Player)
	sessions[player.UserId] = nil
end

-- Periodic autosave so a server crash doesn't cost a whole session. The Ready
-- gate inside Save applies here too, so Failed sessions stay unwritten.
function RewardStore.StartAutosave(getValues: (Player) -> { [string]: number })
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in ipairs(Players:GetPlayers()) do
				if RewardStore.IsReady(player) then
					task.spawn(function()
						pcall(function()
							RewardStore.Save(player, getValues(player))
						end)
					end)
				end
			end
		end
	end)
end

return RewardStore
]====])

moduleScript(GSReward, "RewardLedger", [====[
-- Owns the actual per-player reward numbers. Creates leaderstat values from
-- RewardTypes, adds/reads through one API, and resets exactly the types
-- RewardTypes marks ResetOnRunEnd -- EndGame never touches a currency by
-- name. Setup/Teardown are called explicitly by PlayerCurrency's
-- PlayerAdded/PlayerRemoving handlers rather than connecting here, so there
-- is one obvious place player lifecycle wiring happens.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RewardTypes = require(ReplicatedStorage.Modules.Reward.RewardTypes)
local RewardStore = require(script.Parent.RewardStore)

local RewardLedger = {}

local function getOrCreateLeaderstats(player: Player): Folder
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	return leaderstats
end

local function getValue(player: Player, rewardType: string): IntValue?
	local typeDef = RewardTypes.Get(rewardType)
	if not typeDef then
		warn(("RewardLedger: unknown reward type '%s'"):format(tostring(rewardType)))
		return nil
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	return leaderstats and leaderstats:FindFirstChild(typeDef.LeaderstatName)
end

-- Creates one IntValue per RewardTypes.All entry at 0, IMMEDIATELY and
-- without yielding, then loads the saved baseline on a separate thread and
-- adds it in when it lands.
--
-- The ordering matters twice over. Creating the values up front means
-- RewardLedger.Add never hits a missing IntValue during the DataStore round
-- trip, so an award earned in that window isn't silently dropped. Adding the
-- baseline (rather than assigning it) means that award survives the load:
-- earn 1000 while Loading, resolve against a stored 5000, end at 6000.
--
-- Idempotent -- safe to call if leaderstats/values already exist.
function RewardLedger.SetupPlayer(player: Player)
	local leaderstats = getOrCreateLeaderstats(player)

	for _, typeDef in pairs(RewardTypes.All) do
		if not leaderstats:FindFirstChild(typeDef.LeaderstatName) then
			local value = Instance.new("IntValue")
			value.Name = typeDef.LeaderstatName
			value.Value = 0
			value.Parent = leaderstats
		end
	end

	task.spawn(function()
		local baseline, ok = RewardStore.Load(player)
		if not ok then
			-- Session is Failed; RewardStore.Save will refuse it, so the
			-- player's stored total stays intact. Nothing to apply here.
			return
		end

		-- Player may have left mid-load.
		if not player.Parent then
			return
		end

		for typeName, amount in pairs(baseline) do
			if amount ~= 0 then
				local value = getValue(player, typeName)
				if value then
					value.Value += amount
				end
			end
		end
	end)
end

function RewardLedger.Add(player: Player, rewardType: string, amount: number): number?
	local value = getValue(player, rewardType)
	if not value then return nil end

	value.Value += amount
	return value.Value
end

function RewardLedger.Get(player: Player, rewardType: string): number?
	local value = getValue(player, rewardType)
	return value and value.Value
end

-- Resets every RewardTypes entry with ResetOnRunEnd = true (currently
-- Score). Persistent types (XP) are untouched.
function RewardLedger.ResetRunScoped(player: Player)
	for _, typeName in ipairs(RewardTypes.RunScoped()) do
		local value = getValue(player, typeName)
		if value then
			value.Value = 0
		end
	end
end

-- { [rewardTypeName]: number } for every persistent type, or nil if any of
-- them is missing. Deliberately no `or 0` fallback: a zero standing in for
-- "we don't know" is what let a failed load overwrite real saved totals.
-- Exported (not a local) because RewardCleanupHook needs this exact
-- nil-safe logic for its Cleanup-time save step, rather than duplicating it.
function RewardLedger.CurrentPersistentValues(player: Player): { [string]: number }?
	local values = {}
	for _, typeName in ipairs(RewardTypes.Persistent()) do
		local amount = RewardLedger.Get(player, typeName)
		if amount == nil then
			warn(("RewardLedger: %s has no '%s' value -- refusing to build save data"):format(player.Name, typeName))
			return nil
		end
		values[typeName] = amount
	end
	return values
end

function RewardLedger.TeardownPlayer(player: Player)
	RewardStore.Save(player, RewardLedger.CurrentPersistentValues(player))
	RewardStore.ClearSession(player)
end

RewardStore.StartAutosave(RewardLedger.CurrentPersistentValues)

game:BindToClose(function()
	RewardStore.SaveAll(RewardLedger.CurrentPersistentValues)
end)

return RewardLedger
]====])

moduleScript(GSReward, "CaptureGuard", [====[
-- Capture-specific anti-exploit validation, kept out of CameraShotHandler so
-- the handler stays a thin adapter. Distance and shot quality drive money,
-- so every check here runs before a reward is ever calculated.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraStats = require(ReplicatedStorage.Modules.Camera.CameraStats)
local CameraStability = require(ReplicatedStorage.Modules.Camera.CameraStability)

local MAX_ORIGIN_DEVIATION_STUDS = 10
local SUBJECT_COOLDOWN_SECONDS = 8

local CaptureGuard = {}

-- [player.UserId] = weak-keyed { [subject Instance]: os.clock() timestamp }.
-- Weak-keyed per-player table so a destroyed subject's entry can be
-- collected instead of leaking forever. Not built on Shared/Cooldown because
-- that module's key is a single flat value, not a (player, subject) pair --
-- Instance:GetDebugId() looked like a fit but requires plugin capability and
-- can't be called from a normal runtime Script.
--
-- Currently unreachable in practice: both shipped CaptureTargets entries set
-- RepeatPolicy = "Unlimited". Kept, not deleted -- re-enabling per-subject
-- farming protection later is a config flip (RepeatPolicy = "Cooldown"), not
-- a re-implementation. See REWARD_SYSTEM.md for the accepted economic
-- tradeoff of shipping this off.
local lastCaptureTime = {}

Players.PlayerRemoving:Connect(function(player)
	lastCaptureTime[player.UserId] = nil
end)

local function isFiniteVector(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z -- NaN ~= itself
		and v.Magnitude < math.huge
end

-- Rejects shots whose client-reported origin is implausibly far from the
-- player's own head -- the cheap version of "don't trust the client's camera
-- position" (CameraSession.Capture sends camera.CFrame.Position unchecked).
-- Does not fully re-derive origin server-side; see REWARD_SYSTEM.md for why
-- that's deferred.
local function validateOrigin(player: Player, origin: Vector3): boolean
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return false
	end

	return (origin - head.Position).Magnitude <= MAX_ORIGIN_DEVIATION_STUDS
end

-- Combined entry point for the parts of validation known before the raycast
-- runs: vector sanity and origin plausibility.
function CaptureGuard.ValidateShot(player: Player, origin: Vector3, direction: Vector3): boolean
	if not isFiniteVector(origin) or not isFiniteVector(direction) then
		return false
	end
	-- direction.Unit is (nan, nan, nan) for a zero vector, which isFiniteVector
	-- already passed (0 < math.huge) -- that NaN then flows into PhotoCapture's
	-- raycast basis, producing 25 NaN raycasts per shot for free.
	if direction.Magnitude == 0 then
		return false
	end
	return validateOrigin(player, origin)
end

-- Re-derives shot quality server-side from the character's actual movement
-- state instead of trusting which remote (Weak/Strong) the client fired. A
-- client claiming Strong while moving is downgraded to Weak, never upgraded.
function CaptureGuard.ResolveShotQuality(player: Player, requestedQuality: string, cameraId: string): string
	if requestedQuality ~= "Strong" then
		return requestedQuality
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return "Weak"
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	local thresholds = CameraStats.GetStabilitySettings(cameraId)
	if CameraStability.IsMoving(humanoid, rootPart, thresholds) then
		return "Weak"
	end

	return "Strong"
end

-- Blocks repeated rewards for the same (player, subject) inside the farm
-- window. Independent of the per-shot rate-limit Cooldown already in
-- CameraShotHandler, which only throttles fire rate, not repetition. Only
-- reached via CheckRepeatPolicy when a type opts into "Cooldown".
local function checkCooldown(player: Player, subject: Instance): boolean
	local now = os.clock()
	local perPlayer = lastCaptureTime[player.UserId]
	if not perPlayer then
		perPlayer = setmetatable({}, { __mode = "k" })
		lastCaptureTime[player.UserId] = perPlayer
	end

	local last = perPlayer[subject]
	if last and now - last < SUBJECT_COOLDOWN_SECONDS then
		return false
	end

	perPlayer[subject] = now
	return true
end

-- Gate for repeated rewards on the same (player, subject), driven by the
-- target type's RepeatPolicy (see CaptureTargets.Types). "Unlimited" always
-- passes; "Cooldown" is the original always-on 8s window, now opt-in per
-- type instead of global. An unrecognized/future policy (e.g. "Diminishing",
-- "Once") fails safe by falling back to Cooldown rather than defaulting open.
function CaptureGuard.CheckRepeatPolicy(player: Player, subject: Instance, typeDef): boolean
	local policy = typeDef and typeDef.RepeatPolicy or "Cooldown"

	if policy == "Unlimited" then
		return true
	elseif policy == "Cooldown" then
		return checkCooldown(player, subject)
	end

	warn(("CaptureGuard: unimplemented RepeatPolicy '%s' -- falling back to Cooldown"):format(tostring(policy)))
	return checkCooldown(player, subject)
end

return CaptureGuard
]====])

moduleScript(GSReward, "RewardService", [====[
-- The single sink every reward source calls through. AwardFromCapture is the
-- capture-shaped convenience wrapper for CameraShotHandler; Grant is the raw
-- entry point future sources (missions, achievements, events) use directly
-- with flat amounts. No remote accepts a reward amount -- this module is
-- only reachable from other server scripts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Signal = require(ReplicatedStorage.Modules.Shared.Signal)
local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MatchStates = require(ReplicatedStorage.Modules.Shared.MatchStates)
local CaptureTargets = require(ReplicatedStorage.Modules.Reward.CaptureTargets)
local CaptureRules = require(ReplicatedStorage.Modules.Reward.CaptureRules)
local RewardCalculator = require(ReplicatedStorage.Modules.Reward.RewardCalculator)
local RewardLedger = require(script.Parent.RewardLedger)
local CaptureGuard = require(script.Parent.CaptureGuard)

-- Lazy: MatchManager is Game-Server-only, and this module is currently
-- required on both places (see MAINHANDOFF's content-migration gap). A
-- top-level require would be inert either way (module scope has no role
-- assert), but resolving it only when actually gating on the Game Server
-- keeps that gap from becoming this file's problem to solve.
local function isScoringActive(): boolean
	if not ServerRole.Is("GameServer") then
		return true
	end
	local MatchManager = require(script.Parent.Parent.Match.MatchManager)
	return MatchStates.IsScoringActive(MatchManager.Get())
end

local RewardService = {}

-- (player: Player, context: table, result: RewardResult) -- fired after a
-- successful Grant from AwardFromCapture. Generic: this module never learns
-- what an objective is. ObjectiveService subscribes to mark completion.
RewardService.Awarded = Signal.new()

-- fn(player, subject, context) -> table? -- merged into the reward context
-- before CaptureRules.Check runs. A provider that has nothing to add for this
-- subject returns nil. Order is registration order; providers must be
-- side-effect-free and non-yielding (AwardFromCapture stays atomic).
local contextProviders = {}

function RewardService.RegisterContextProvider(fn: (Player, Instance, any) -> any?)
	table.insert(contextProviders, fn)
end

local ANOMALY_XP_PER_MINUTE = 20000
local recentXP = {} -- [userId] = { amount, windowStart }

Players.PlayerRemoving:Connect(function(player)
	recentXP[player.UserId] = nil
end)

local function flagIfAnomalous(player: Player, xpAmount: number)
	if xpAmount <= 0 then return end

	local now = os.clock()
	local record = recentXP[player.UserId]
	if not record or now - record.windowStart > 60 then
		record = { amount = 0, windowStart = now }
		recentXP[player.UserId] = record
	end

	record.amount += xpAmount
	if record.amount > ANOMALY_XP_PER_MINUTE then
		warn(("RewardService: %s earned %d XP in the last minute (threshold %d)"):format(
			player.Name, record.amount, ANOMALY_XP_PER_MINUTE))
	end
end

-- amounts: { [rewardTypeName]: number }. meta: { Source, SourceId }, threaded
-- through for future logging/analytics -- not persisted anywhere yet.
function RewardService.Grant(player: Player, amounts: { [string]: number }, meta): boolean
	if not player or not player.Parent then
		return false
	end

	-- The generic sink, for future reward sources (missions, achievements)
	-- that call Grant directly rather than through AwardFromCapture, which
	-- already gates itself above.
	if not isScoringActive() then
		return false
	end

	for rewardType, amount in pairs(amounts) do
		if amount ~= 0 then
			RewardLedger.Add(player, rewardType, amount)
		end
	end

	if amounts.XP then
		flagIfAnomalous(player, amounts.XP)
	end

	return true
end

-- context: { player, subject, shotQuality, distanceStuds, cameraId }
-- (context.subject is whatever PhotoCapture resolved -- re-resolved here
-- rather than trusted, closing the raycast-to-award race where a subject is
-- destroyed or detagged in between.)
--
-- ALWAYS returns a RewardResult carrying a resultCode ("Awarded", "TooFar",
-- "WrongShotQuality", "OnRepeatCooldown", "UnknownTarget", ...) -- amounts is
-- nil for every code except "Awarded". Never returns a bare "no reward" with
-- no explanation; see ShotResultCodes for the display strings.
function RewardService.AwardFromCapture(player: Player, context)
	local meters, bandLabel = RewardCalculator.Describe(context.distanceStuds)

	-- The sink-level anti-exploit gate: once a Game Server leaves Playing
	-- (Ending/Cleanup/Finished), no capture pays out. Checked before the
	-- subject/rules pipeline runs, not just before Grant, so a refusal here
	-- also skips the Awarded fire below -- ObjectiveService.Complete is only
	-- ever reached through that fire, so this one check covers both.
	if not isScoringActive() then
		return { resultCode = "MatchNotScoring", meters = meters, bandLabel = bandLabel, amounts = nil }
	end

	local subject, typeName = CaptureTargets.Resolve(context.subject)
	if not subject or not typeName or not subject:IsDescendantOf(workspace) then
		return { resultCode = "UnknownTarget", meters = meters, bandLabel = bandLabel, amounts = nil }
	end

	local typeDef = CaptureTargets.Get(typeName)
	local fullContext = table.clone(context)
	fullContext.subject = subject
	fullContext.targetType = typeName

	for _, provider in ipairs(contextProviders) do
		local extra = provider(player, subject, fullContext)
		if extra then
			for key, value in pairs(extra) do
				fullContext[key] = value
			end
		end
	end

	local rulesOk, ruleCode = CaptureRules.Check(typeDef, fullContext)
	if not rulesOk then
		return { resultCode = ruleCode, targetType = typeName, meters = meters, bandLabel = bandLabel, amounts = nil }
	end

	if not CaptureGuard.CheckRepeatPolicy(player, subject, typeDef) then
		return { resultCode = "OnRepeatCooldown", targetType = typeName, meters = meters, bandLabel = bandLabel, amounts = nil }
	end

	local result = RewardCalculator.Calculate(fullContext, typeDef)
	RewardService.Grant(player, result.amounts, { Source = "Camera", SourceId = context.cameraId, TargetType = typeName })

	result.resultCode = "Awarded"
	result.targetType = typeName

	RewardService.Awarded:Fire(player, fullContext, result)

	return result
end

return RewardService
]====])

moduleScript(GSReward, "RewardCleanupHook", [====[
-- Registers RewardLedger's save step into MatchCleanup, from its own
-- Start(). RewardLedger predates the Start() lifecycle convention and has
-- no Start() of its own -- it self-wires via PlayerCurrency.legacy.luau.
-- Registering at RewardLedger's own module scope (the Phase 7 approach)
-- made the save step's existence contingent on PlayerCurrency.legacy
-- happening to be required on this place -- a hidden keystone dependency,
-- confirmed live to be an actual gap on the Game place, not a hypothetical
-- (Phase 7.5 audit, ~/.claude/plans/before-phase-8-perform-scalable-mochi.md
-- section 1). This module makes the registration explicit, ordered by
-- GameBoot's list, and independent of any other file's require graph.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local RewardLedger = require(script.Parent.RewardLedger)
local RewardStore = require(script.Parent.RewardStore)
local MatchCleanup = require(script.Parent.Parent.Match.MatchCleanup)

local RewardCleanupHook = {}

local started = false

function RewardCleanupHook.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	MatchCleanup.RegisterSaveStep("RewardLedger", function(): boolean
		RewardStore.SaveAll(RewardLedger.CurrentPersistentValues)
		return true
	end)
end

return RewardCleanupHook
]====])

-- --- Camera ---

local GSCamera = folder(GameService, "Camera")

moduleScript(GSCamera, "PhotoCapture", [====[
-- Owns the 5x5 spread raycast used to resolve what a camera shot hit. This
-- is the seam future photo-scoring / MonsterBehavior.OnPhotographed hooks
-- attach to -- callers get back a result table, not a print statement.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CaptureTargets = require(ReplicatedStorage.Modules.Reward.CaptureTargets)

local PhotoCapture = {}

local SPREAD_OFFSETS = {-2, -1, 0, 1, 2}

-- Precomputed once at module load (previously rebuilt on every single shot)
-- and genuinely ordered center-out by radius, so a near-center ray always
-- wins over a far-corner one.
local orderedOffsets = {}
do
	for _, dx in ipairs(SPREAD_OFFSETS) do
		for _, dy in ipairs(SPREAD_OFFSETS) do
			table.insert(orderedOffsets, { dx, dy })
		end
	end
	table.sort(orderedOffsets, function(a, b)
		return (a[1] * a[1] + a[2] * a[2]) < (b[1] * b[1] + b[2] * b[2])
	end)
end

local function buildBasis(direction: Vector3)
	local worldUp = Vector3.new(0, 1, 0)
	if math.abs(direction:Dot(worldUp)) > 0.999 then
		worldUp = Vector3.new(1, 0, 0)
	end

	local right = direction:Cross(worldUp).Unit
	local up = right:Cross(direction).Unit
	return right, up
end

-- Returns a result table { subject, targetType, hitPosition, distanceStuds }
-- on a hit, or nil on a miss. targetType comes from CaptureTargets.Resolve --
-- PhotoCapture doesn't know or care what a Monster or Objective IS, only
-- that the walk found a registered attribute.
function PhotoCapture.Fire(origin: Vector3, direction: Vector3, range: number, spreadRadius: number, raycastParams: RaycastParams)
	local right, up = buildBasis(direction)

	for _, offset in ipairs(orderedOffsets) do
		local dx, dy = offset[1], offset[2]
		local spreadDirection = (direction + right * dx * spreadRadius + up * dy * spreadRadius).Unit

		local result = workspace:Raycast(origin, spreadDirection * range, raycastParams)
		if result then
			local capturable, targetType = CaptureTargets.Resolve(result.Instance)
			if capturable then
				return {
					subject = capturable,
					targetType = targetType,
					hitPosition = result.Position,
					distanceStuds = (result.Position - origin).Magnitude,
				}
			end
		end
	end

	return nil
end

return PhotoCapture
]====])

legacyScript(GSCamera, "CameraShotHandler", [====[
-- Thin remote adapter: validates the shooter and the shot itself, resolves
-- cooldown/settings, delegates the raycast to PhotoCapture, and routes any
-- hit through the Reward System. Reports the outcome (hit/miss + reward)
-- back to the shooter.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local CameraStats = require(ReplicatedStorage.Modules.Camera.CameraStats)
local Cooldown = require(ReplicatedStorage.Modules.Shared.Cooldown)
local PhotoCapture = require(script.Parent.PhotoCapture)
local CaptureGuard = require(ServerScriptService.GameService.Reward.CaptureGuard)
local RewardService = require(ServerScriptService.GameService.Reward.RewardService)
local FlashEvents = require(ServerScriptService.GameService.Flash.FlashEvents)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)

local WeakCameraShot = Remotes.Get("WeakCameraShot")
local StrongCameraShot = Remotes.Get("StrongCameraShot")
local ShotFeedback = Remotes.Get("ShotFeedback")

-- Window varies per camera + shot type, so Check() is called with an
-- explicit override each time rather than a fixed window at construction.
local shotCooldown = Cooldown.new()

-- Separate from shotCooldown, which can't gate the two warns below (they fire
-- on paths that never reach a settings-derived cooldown window). Bounds log
-- volume from a client spamming invalid shots -- previously unthrottled.
local logCooldown = Cooldown.new(2)

-- Server always resolves cameraId from the server-observed equipped tool's
-- attribute, never a client-declared identity.
local function getEquippedCameraTool(player)
	local character = player.Character
	if not character then return nil end

	local tool = character:FindFirstChildOfClass("Tool")
	if tool and tool:GetAttribute("IsCameraTool") == true then
		return tool
	end
	return nil
end

local function handleShot(player, shotType, origin, direction)
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end

	if not CaptureGuard.ValidateShot(player, origin, direction) then
		if logCooldown:Check(player.UserId) then
			warn(player.Name, "camera shot failed origin/direction validation")
		end
		return
	end

	local cameraTool = getEquippedCameraTool(player)
	if not cameraTool then
		if logCooldown:Check(player.UserId) then
			warn(player.Name, "tried to camera-shoot without holding a camera")
		end
		return
	end

	local cameraId = CameraStats.GetIdFromTool(cameraTool)
	-- Server re-derives quality from actual movement state, so a client can't
	-- just always claim Strong for the bigger payout (see REWARD_SYSTEM.md).
	local resolvedQuality = CaptureGuard.ResolveShotQuality(player, shotType, cameraId)
	local settings = CameraStats.GetShotSettings(cameraId, resolvedQuality)

	if not shotCooldown:Check(player.UserId, settings.Cooldown) then
		return
	end

	local character = player.Character
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }

	local result = PhotoCapture.Fire(origin, direction.Unit, settings.Range, settings.SpreadRadius, raycastParams)

	FlashEvents:Fire({
		player = player,
		origin = origin,
		direction = direction,
		cameraId = cameraId,
		shotQuality = resolvedQuality,
		hitPosition = result and result.hitPosition or nil,
		timestamp = os.clock(),
	})

	if not result then
		ShotFeedback:FireClient(player, {
			shotType = resolvedQuality,
			hit = false,
		})
		return
	end

	local rewardContext = {
		player = player,
		subject = result.subject,
		shotQuality = resolvedQuality,
		distanceStuds = result.distanceStuds,
		cameraId = cameraId,
	}

	-- Always routes through the full resolve/validate/calculate/grant
	-- pipeline -- the result always carries a resultCode explaining the
	-- outcome (Awarded, TooFar, WrongShotQuality, OnRepeatCooldown,
	-- UnknownTarget), amounts only present when Awarded. See RewardService.
	local rewardResult = RewardService.AwardFromCapture(player, rewardContext)

	ShotFeedback:FireClient(player, {
		shotType = resolvedQuality,
		hit = true,
		position = result.hitPosition,
		meters = rewardResult.meters,
		bandLabel = rewardResult.bandLabel,
		targetType = rewardResult.targetType,
		resultCode = rewardResult.resultCode,
		amounts = rewardResult.amounts,
		rollMultiplier = rewardResult.rollMultiplier,
	})
end

WeakCameraShot.OnServerEvent:Connect(function(player, origin, direction)
	handleShot(player, "Weak", origin, direction)
end)

StrongCameraShot.OnServerEvent:Connect(function(player, origin, direction)
	handleShot(player, "Strong", origin, direction)
end)
]====])

-- --- Player ---

local GSPlayer = folder(GameService, "Player")

legacyScript(GSPlayer, "PlayerCurrency", [====[
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local RewardLedger = require(ServerScriptService.GameService.Reward.RewardLedger)
-- ObjectiveService/ObjectiveReplicator boot from GameService/Bootstrap.legacy.luau now --
-- this file no longer doubles as their hidden keystone.

-- Cash stays hand-built here rather than as a RewardType: it's spent (not
-- earned via the camera), so RewardCalculator/RewardService have no reason
-- to own it. RewardLedger.SetupPlayer creates the leaderstats folder and the
-- XP/Score values; Cash is added into that same folder.
--
-- SetupPlayer must not yield -- it defers its DataStore load to another
-- thread precisely so leaderstats is fully populated within this handler.
-- If that ever changes, `leaderstats` here would briefly exist without Cash
-- and StartGame's `leaderstats:FindFirstChild("Cash")` would silently miss.
local function onPlayerAdded(player)
	RewardLedger.SetupPlayer(player)

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		warn("PlayerCurrency: leaderstats missing for", player.Name, "- Cash not created")
		return
	end

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 0
	cash.Parent = leaderstats
end

local function onPlayerRemoving(player)
	RewardLedger.TeardownPlayer(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Catches any player who joined in the window between server start and the
-- Connect call above (e.g. a require earlier in this script's chain yielded).
-- Without this, that player permanently gets no leaderstats/Cash.
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
]====])

-- --- Flash ---

local GSFlash = folder(GameService, "Flash")

moduleScript(GSFlash, "FlashEvents", [====[
-- The server-side perceptual bus for camera flashes. Raised by
-- CameraShotHandler from a shot it has already validated -- there is no
-- client->server "I flashed" remote; the server derives the event from
-- information it already possesses, so nothing new is trusted from the
-- client. Ships with zero subscribers; a future MonsterPerception module
-- connects here to add detection radius/angle/line-of-sight without any
-- change to the Camera or to this module.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Modules.Shared.Signal)

-- flashInfo: { player, origin: Vector3, direction: Vector3, cameraId,
--              shotQuality, hitPosition: Vector3?, timestamp: number }
return Signal.new()
]====])

-- --- Objective ---

local GSObjective = folder(GameService, "Objective")

moduleScript(GSObjective, "ObjectiveRegistry", [====[
-- Discovery and lifecycle for every IsObjective instance in workspace. The
-- single source of truth for "what objectives exist" -- consumers call
-- All()/IsRegistered() rather than scanning workspace themselves.

local ObjectiveRegistry = {}

local live = {} -- [instance] = true
local attributeConnections = {} -- [instance] = RBXScriptConnection

local function unregister(instance: Instance)
	live[instance] = nil
end

local function register(instance: Instance)
	live[instance] = true
end

-- Watches IsObjective being toggled on/off at runtime (rather than only at
-- discovery time), so an authored-later attribute still registers.
local function watchAttribute(instance: Instance)
	if attributeConnections[instance] then
		return
	end
	attributeConnections[instance] = instance:GetAttributeChangedSignal("IsObjective"):Connect(function()
		if instance:GetAttribute("IsObjective") then
			register(instance)
		else
			unregister(instance)
		end
	end)
end

-- IsObjective only ever lives on a BasePart or a Model (Resolve/GetPivot both
-- need one of those). Filtering here means the thousands of non-Part/Model
-- descendants of a typical Workspace (Scripts, Attachments, Motor6Ds,
-- Animations, Decals, ...) never get an attribute-changed connection at all,
-- instead of one per descendant regardless of class.
local function considerInstance(instance: Instance)
	if not (instance:IsA("BasePart") or instance:IsA("Model")) then
		return
	end
	watchAttribute(instance)
	if instance:GetAttribute("IsObjective") then
		register(instance)
	end
end

function ObjectiveRegistry.All(): { Instance }
	local result = {}
	for instance in pairs(live) do
		table.insert(result, instance)
	end
	return result
end

function ObjectiveRegistry.IsRegistered(instance: Instance): boolean
	return live[instance] == true
end

local function bootstrap()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		considerInstance(descendant)
	end

	workspace.DescendantAdded:Connect(considerInstance)

	workspace.DescendantRemoving:Connect(function(instance)
		local connection = attributeConnections[instance]
		if connection then
			connection:Disconnect()
			attributeConnections[instance] = nil
		end
		unregister(instance)
	end)
end

bootstrap()

return ObjectiveRegistry
]====])

moduleScript(GSObjective, "ObjectiveService", [====[
-- State authority for the Objective System. Owns GetState/SetState/Complete/
-- Reset and the StateChanged signal. Never computes a reward value -- see
-- Reward/RewardService for the two generic seams (RegisterContextProvider,
-- Awarded) this module hooks into instead of the Reward System knowing
-- anything about objectives.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Signal = require(ReplicatedStorage.Modules.Shared.Signal)
local ObjectiveStates = require(ReplicatedStorage.Modules.Objective.ObjectiveStates)
local ObjectiveTypes = require(ReplicatedStorage.Modules.Objective.ObjectiveTypes)
local ObjectiveRegistry = require(script.Parent.ObjectiveRegistry)
-- Hoisted from bottom-of-file (was line 143 of 158). Bottom placement gave no
-- actual cycle protection -- Luau raises on "required recursively" regardless
-- of statement position -- it only hid the coupling from a maintainer
-- skimming the header. See RewardService.RegisterContextProvider/Awarded
-- below for the two generic seams this actually uses.
local RewardService = require(script.Parent.Parent.Reward.RewardService)

local ObjectiveService = {}

-- (player: Player?, instance: Instance, newState: string, oldState: string)
-- player is nil for Shared-ownership changes.
ObjectiveService.StateChanged = Signal.new()

-- Player-ownership state: [userId] = weak-keyed { [instance] = stateName }.
-- Weak-keyed so a destroyed objective doesn't pin memory, same pattern as
-- CaptureGuard's per-player cooldown table.
local playerStates = {}

local function playerTable(userId: number)
	local states = playerStates[userId]
	if not states then
		states = setmetatable({}, { __mode = "k" })
		playerStates[userId] = states
	end
	return states
end

-- Without this, a player who leaves and rejoins the same server keeps their
-- old objective completions (playerTable finds the stale table by userId),
-- and the outer table itself grows by one entry per player forever.
Players.PlayerRemoving:Connect(function(player)
	playerStates[player.UserId] = nil
end)

local function ownershipFor(instance: Instance): string
	return ObjectiveTypes.Get(ObjectiveTypes.TypeOf(instance)).Ownership
end

local function initialStateFor(instance: Instance): string
	return ObjectiveTypes.Get(ObjectiveTypes.TypeOf(instance)).InitialState
end

-- Shared state lives directly on the instance's ObjectiveState attribute --
-- attributes replicate to every client automatically, which is the repo's
-- existing broadcast mechanism (IsMonster, Stage, KeepDuringCamera). See
-- ObjectiveReplicator for the Player-ownership remote path attributes can't
-- express.
local function getSharedState(instance: Instance): string
	return instance:GetAttribute("ObjectiveState") or initialStateFor(instance)
end

local function setSharedState(instance: Instance, state: string)
	instance:SetAttribute("ObjectiveState", state)
end

function ObjectiveService.GetState(player: Player?, instance: Instance): string
	if ownershipFor(instance) == "Shared" then
		return getSharedState(instance)
	end

	if not player then
		return initialStateFor(instance)
	end

	local states = playerTable(player.UserId)
	return states[instance] or initialStateFor(instance)
end

function ObjectiveService.SetState(player: Player?, instance: Instance, state: string): boolean
	if not ObjectiveStates.IsValid(state) then
		warn(("ObjectiveService: unknown state '%s'"):format(tostring(state)))
		return false
	end

	if ownershipFor(instance) == "Shared" then
		local oldState = getSharedState(instance)
		if oldState == state then
			return true
		end
		setSharedState(instance, state)
		ObjectiveService.StateChanged:Fire(nil, instance, state, oldState)
		return true
	end

	if not player then
		warn("ObjectiveService: SetState on a Player-owned objective requires a player")
		return false
	end

	local states = playerTable(player.UserId)
	local oldState = states[instance] or initialStateFor(instance)
	if oldState == state then
		return true
	end
	states[instance] = state
	ObjectiveService.StateChanged:Fire(player, instance, state, oldState)
	return true
end

function ObjectiveService.Complete(player: Player, instance: Instance): boolean
	return ObjectiveService.SetState(player, instance, "Completed")
end

-- instance nil = every registered objective. For a Player-owned objective,
-- player must be given (there is no "reset this for everyone" for
-- Player-owned state -- each player's run ends independently). For a
-- Shared objective, player is ignored. Types with ResetPolicy == "Never"
-- are skipped. Returns how many objectives were actually reset.
function ObjectiveService.Reset(player: Player?, instance: Instance?): number
	local resetCount = 0

	local function resetOne(targetInstance: Instance)
		local typeDef = ObjectiveTypes.Get(ObjectiveTypes.TypeOf(targetInstance))
		if typeDef.ResetPolicy == "Never" then
			return
		end

		if typeDef.Ownership == "Shared" then
			if ObjectiveService.SetState(nil, targetInstance, typeDef.InitialState) then
				resetCount += 1
			end
		elseif player then
			if ObjectiveService.SetState(player, targetInstance, typeDef.InitialState) then
				resetCount += 1
			end
		end
	end

	if instance then
		resetOne(instance)
	else
		for _, targetInstance in ipairs(ObjectiveRegistry.All()) do
			resetOne(targetInstance)
		end
	end

	return resetCount
end

-- Wiring into the Reward System's two generic seams. RewardService never
-- learns what an objective is: the provider only ever adds plain
-- objectiveRegistered/objectiveState fields, and the Awarded subscriber only
-- acts when targetType == "Objective".
RewardService.RegisterContextProvider(function(player, subject, context)
	if not ObjectiveRegistry.IsRegistered(subject) then
		return { objectiveRegistered = false }
	end
	return { objectiveRegistered = true, objectiveState = ObjectiveService.GetState(player, subject) }
end)

RewardService.Awarded:Connect(function(player, context, _result)
	if context.targetType == "Objective" then
		ObjectiveService.Complete(player, context.subject)
	end
end)

return ObjectiveService
]====])

moduleScript(GSObjective, "ObjectiveReplicator", [====[
-- Turns ObjectiveService.StateChanged into wire traffic. Two paths, kept
-- isolated here so neither leaks into ObjectiveService:
--   Shared  -- already replicated for free: ObjectiveService writes Shared
--             state directly onto the instance's ObjectiveState attribute,
--             and Roblox replicates attributes to every client automatically.
--   Player  -- attributes can't express per-player state, so this fires a
--             dedicated remote plus a join/respawn snapshot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ObjectiveTypes = require(ReplicatedStorage.Modules.Objective.ObjectiveTypes)
local ObjectiveRegistry = require(script.Parent.ObjectiveRegistry)
local ObjectiveService = require(script.Parent.ObjectiveService)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)

local ObjectiveReplicator = {}

-- Provisioning now flows through Remotes.Init() (called once from Bootstrap),
-- which is idempotent and defers to any Studio-placed remote of the same
-- name. This used to self-provision inline here -- the only remote in the
-- codebase that did -- because it was authored while Studio MCP access was
-- unavailable.
local ObjectiveStateSync = Remotes.Get("ObjectiveStateSync")

local function ownershipFor(instance: Instance): string
	return ObjectiveTypes.Get(ObjectiveTypes.TypeOf(instance)).Ownership
end

ObjectiveService.StateChanged:Connect(function(player, instance, newState, _oldState)
	if ownershipFor(instance) ~= "Player" then
		return -- Shared already replicated via the ObjectiveState attribute
	end
	if not player or not player.Parent then
		return
	end
	ObjectiveStateSync:FireClient(player, { instance = instance, state = newState })
end)

local function sendSnapshot(player: Player)
	local entries = {}
	for _, instance in ipairs(ObjectiveRegistry.All()) do
		if ownershipFor(instance) == "Player" then
			table.insert(entries, { instance = instance, state = ObjectiveService.GetState(player, instance) })
		end
	end
	ObjectiveStateSync:FireClient(player, { entries = entries })
end

-- Only on CharacterAdded, not also immediately on PlayerAdded: the client's
-- ObjectiveStateClient hasn't required (let alone connected OnClientEvent)
-- by the time PlayerAdded fires server-side, so that immediate send was
-- always dropped -- it only ever "worked" because CharacterAdded re-sends a
-- moment later once the client has actually loaded.
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		sendSnapshot(player)
	end)
end)

return ObjectiveReplicator
]====])

-- --- Monster ---

local GSMonster = folder(GameService, "Monster")
local GSMonsterStates = folder(GSMonster, "States")
local GSMonsterBehaviors = folder(GSMonster, "Behaviors")

moduleScript(GSMonster, "MonsterSensing", [====[
local Players = game:GetService("Players")

local MonsterSensing = {}

-- MVP: pure distance check, no line-of-sight/noise yet (see MONSTERS.md build
-- order step 4). Ignores dead/characterless players.
function MonsterSensing.GetNearestPlayer(fromPosition: Vector3, maxDistance: number): (Player?, Vector3?, number?)
	local nearestPlayer, nearestPos, nearestDist = nil, nil, math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if rootPart and humanoid and humanoid.Health > 0 then
			local dist = (rootPart.Position - fromPosition).Magnitude
			if dist <= maxDistance and dist < nearestDist then
				nearestPlayer, nearestPos, nearestDist = player, rootPart.Position, dist
			end
		end
	end

	return nearestPlayer, nearestPos, nearestDist
end

return MonsterSensing
]====])

moduleScript(GSMonster, "MonsterMovement", [====[
local MonsterMovement = {}

-- Kinematic movement: drives the root part's CFrame directly rather than
-- Humanoid:MoveTo. A lone unwelded part has nothing to keep it upright under
-- Humanoid's movement force -- it spins in place instead of walking. This is
-- also simpler to reason about for a boxy placeholder. Swapping to a real
-- rig + Humanoid animation (or PathfindingService) later is a change in this
-- file only -- the (agent, targetPosition, dt) contract doesn't change.
function MonsterMovement.MoveTo(agent, targetPosition: Vector3, dt: number)
	local rootPart = agent.rootPart
	if not rootPart or not rootPart.Parent then return end

	local current = rootPart.Position
	-- XZ-plane only; MVP assumes flat ground (see MONSTERS.md build order step
	-- 4 for ground-following/pathfinding).
	local flatTarget = Vector3.new(targetPosition.X, current.Y, targetPosition.Z)
	local toTarget = flatTarget - current
	local distance = toTarget.Magnitude
	if distance < 0.05 then return end

	local step = math.min(distance, agent.stats.WalkSpeed * dt)
	local newPosition = current + toTarget.Unit * step

	rootPart.CFrame = CFrame.new(newPosition, Vector3.new(flatTarget.X, newPosition.Y, flatTarget.Z))
end

return MonsterMovement
]====])

moduleScript(GSMonster, "MonsterDamage", [====[
local MonsterDamage = {}

-- Per-monster, per-player hit cooldown so a single Touched frame (or a player
-- standing inside the hitbox) can't fire multiple kills instantly.
-- lastHitTime[monsterModel][userId] = os.clock()
-- Weak-keyed so a monster Model removed via `model.Parent = nil` (rather than
-- :Destroy(), which ClearAgent already handles explicitly) doesn't stay
-- pinned in memory forever by this table.
local lastHitTime = setmetatable({}, { __mode = "k" })

local function getCooldownTable(agent)
	local key = agent.model
	if not lastHitTime[key] then
		lastHitTime[key] = {}
	end
	return lastHitTime[key]
end

function MonsterDamage.TryKill(agent, player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local cooldowns = getCooldownTable(agent)
	local now = os.clock()
	local cooldown = agent.stats.AttackCooldown or 1

	if cooldowns[player.UserId] and now - cooldowns[player.UserId] < cooldown then
		return
	end
	cooldowns[player.UserId] = now

	humanoid.Health = 0

	if agent.behavior and agent.behavior.OnKill then
		agent.behavior.OnKill(agent, player)
	end
end

-- Call when a monster is despawned so its cooldown table doesn't leak.
function MonsterDamage.ClearAgent(agent)
	lastHitTime[agent.model] = nil
end

return MonsterDamage
]====])

moduleScript(GSMonsterStates, "Chase", [====[
local MonsterSensing = require(script.Parent.Parent.MonsterSensing)
local MonsterMovement = require(script.Parent.Parent.MonsterMovement)
local MonsterDamage = require(script.Parent.Parent.MonsterDamage)

local Chase = {}
Chase.Name = "Chase"
Chase.TickRate = 0.1

function Chase.Enter(agent) end

function Chase.Exit(agent) end

function Chase.Update(agent, dt: number)
	local rootPart = agent.rootPart
	if not rootPart or not rootPart.Parent then return nil end

	local player, targetPos = MonsterSensing.GetNearestPlayer(rootPart.Position, agent.stats.DetectRadius)

	if player and targetPos then
		agent.target = player
		agent.lastKnownPos = targetPos
		agent.lastSeenAt = os.clock()

		local distance = (targetPos - rootPart.Position).Magnitude
		if distance <= agent.stats.AttackReach then
			MonsterDamage.TryKill(agent, player)
		else
			MonsterMovement.MoveTo(agent, targetPos, dt)
		end
	elseif agent.lastKnownPos then
		-- MVP has no Checking state yet -- just keep walking to the last known
		-- spot and stop once PursuitDuration runs out (see MONSTERS.md step 5).
		if os.clock() - agent.lastSeenAt > agent.stats.PursuitDuration then
			agent.target = nil
			agent.lastKnownPos = nil
		else
			MonsterMovement.MoveTo(agent, agent.lastKnownPos, dt)
		end
	end

	return nil -- MVP only has one state; nothing to transition to yet
end

return Chase
]====])

moduleScript(GSMonsterBehaviors, "GreyCube", [====[
-- GreyCube behavior hooks. Every hook is optional -- MonsterAgent skips any
-- that aren't defined. This one defines none: it's the plain baseline every
-- future unique monster (Stalker, Screamer, Mimic, ...) is compared against.
return {}
]====])

moduleScript(GSMonster, "MonsterAgent", [====[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MonsterStats = require(ReplicatedStorage.Modules.Monster.MonsterStats)

local States = {
	Chase = require(script.Parent.States.Chase),
}

local Behaviors = {
	GreyCube = require(script.Parent.Behaviors.GreyCube),
}

local MonsterAgent = {}
MonsterAgent.States = States

function MonsterAgent.New(model: Model, monsterId: string, stage: number?)
	local rootPart = model:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		warn("MonsterAgent.New: model '" .. model.Name .. "' is missing HumanoidRootPart")
		return nil
	end
	-- Optional: nil for the MVP grey box. Movement is driven by MonsterMovement
	-- (kinematic CFrame), not a Humanoid -- see MonsterService for why this
	-- model doesn't have one. Reserved for future rigged/animated monsters.
	local humanoid = model:FindFirstChildOfClass("Humanoid")

	local stats = MonsterStats.Get(monsterId, stage)
	if not stats then return nil end

	local initialState = stats.States[1]
	if not initialState or not States[initialState] then
		warn("MonsterAgent.New: no valid initial state for '" .. monsterId .. "'")
		return nil
	end

	local agent = {
		model = model,
		humanoid = humanoid,
		rootPart = rootPart,
		monsterId = monsterId,
		stage = stage or 1,
		stats = stats,
		behavior = Behaviors[monsterId] or {},

		state = nil, -- set below via SetState so Enter()/OnStateEnter fire consistently
		stateElapsed = 0,
		lastTick = os.clock(),

		target = nil,
		lastKnownPos = nil,
		lastSeenAt = 0,

		aggression = 0,
		memory = {},
	}

	if agent.behavior.OnSpawn then
		agent.behavior.OnSpawn(agent)
	end

	MonsterAgent.SetState(agent, initialState)

	return agent
end

function MonsterAgent.SetState(agent, newState: string)
	-- Behavior gets first refusal on any transition.
	if agent.behavior.TransitionOverride then
		local override = agent.behavior.TransitionOverride(agent, agent.state, newState)
		if override then
			newState = override
		end
	end

	-- Anti-solved-AI valve: a transition can be configured to not always fire.
	-- Not exercised by the Chase-only MVP (TransitionChance.Chase = 1.0) but
	-- wired now so later states don't require reworking SetState.
	local chance = agent.stats.TransitionChance and agent.stats.TransitionChance[newState]
	if chance and chance < 1 and math.random() > chance then
		return
	end

	local oldState = agent.state
	if oldState and States[oldState] and States[oldState].Exit then
		States[oldState].Exit(agent)
	end

	agent.state = newState
	agent.stateElapsed = 0

	local stateModule = States[newState]
	if stateModule and stateModule.Enter then
		stateModule.Enter(agent)
	end

	if agent.behavior.OnStateEnter then
		agent.behavior.OnStateEnter(agent, newState)
	end
end

function MonsterAgent.Tick(agent, dt: number)
	agent.stateElapsed += dt

	if agent.behavior.OnUpdate then
		agent.behavior.OnUpdate(agent, dt)
	end

	local stateModule = States[agent.state]
	if not stateModule then return end

	local nextState = stateModule.Update(agent, dt)
	if nextState and nextState ~= agent.state then
		MonsterAgent.SetState(agent, nextState)
	end
end

return MonsterAgent
]====])

moduleScript(GSMonster, "MonsterService", [====[
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MatchStates = require(ReplicatedStorage.Modules.Shared.MatchStates)
local MonsterAgent = require(script.Parent.MonsterAgent)
local MonsterDamage = require(script.Parent.MonsterDamage)

local MonsterService = {}

local liveAgents = {} -- [model] = agent

-- Lazy for the same reason as RewardService's isScoringActive: this module
-- currently self-wires on both places (content-migration gap), and
-- MatchManager is Game-Server-only.
local function monstersCanSpawn(): boolean
	if not ServerRole.Is("GameServer") then
		return true
	end
	local MatchManager = require(script.Parent.Parent.Match.MatchManager)
	return MatchStates.MonstersSpawn(MatchManager.Get())
end

local function gameplayActive(): boolean
	if not ServerRole.Is("GameServer") then
		return true
	end
	local MatchManager = require(script.Parent.Parent.Match.MatchManager)
	return MatchStates.IsGameplayActive(MatchManager.Get())
end

-- MVP grey box has no authored asset yet, so it's built from scratch here --
-- this keeps the system unblocked on Studio asset work. Swap this for a
-- template clone (same pattern as CAMERA_TEMPLATES_FOLDER in StartGame.luau)
-- once real monster models exist.
local function buildGreyCubeModel(cframe: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "GreyCube"

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(4, 4, 4)
	rootPart.Color = Color3.fromRGB(120, 120, 120)
	-- Anchored + code-driven CFrame (see MonsterMovement) instead of physics-
	-- simulated: a lone unwelded part has nothing to keep it upright and
	-- tumbles under Humanoid/collision forces otherwise.
	rootPart.Anchored = true
	rootPart.CanCollide = true
	rootPart.CFrame = cframe
	rootPart.Parent = model

	-- No Humanoid: a lone HumanoidRootPart with a Humanoid but no Torso/real
	-- rig underneath confuses Roblox's anatomy resolution and corrupts the
	-- part's position. Movement is fully kinematic (MonsterMovement) and
	-- damage only touches the player's Humanoid, so this model doesn't need
	-- one. Add a real Humanoid when a proper rigged/animated model exists.
	model.PrimaryPart = rootPart
	return model
end

local MODEL_BUILDERS = {
	GreyCube = buildGreyCubeModel,
}

function MonsterService.Spawn(monsterId: string, cframe: CFrame, stage: number?): Model?
	if not monstersCanSpawn() then
		warn("MonsterService.Spawn: monsters aren't allowed to spawn outside of active gameplay")
		return nil
	end

	local builder = MODEL_BUILDERS[monsterId]
	if not builder then
		warn("MonsterService.Spawn: no model builder for '" .. monsterId .. "' yet")
		return nil
	end

	local model = builder(cframe)

	-- IsMonster ties straight into CaptureTargets -- the monster is
	-- photographable (Reward/CaptureTargets.Types.Monster.Attribute) with
	-- zero camera-code changes.
	model:SetAttribute("IsMonster", true)
	model:SetAttribute("MonsterId", monsterId)
	model:SetAttribute("Stage", stage or 1)

	model.Parent = workspace

	local agent = MonsterAgent.New(model, monsterId, stage)
	if not agent then
		model:Destroy()
		return nil
	end

	liveAgents[model] = agent

	local touchedConn
	touchedConn = agent.rootPart.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if player then
			MonsterDamage.TryKill(agent, player)
		end
	end)

	model.Destroying:Connect(function()
		touchedConn:Disconnect()
		MonsterDamage.ClearAgent(agent)
		liveAgents[model] = nil
	end)

	return model
end

function MonsterService.Despawn(model: Model)
	if liveAgents[model] then
		model:Destroy() -- fires Destroying above, which cleans up liveAgents/cooldowns
	end
end

RunService.Heartbeat:Connect(function()
	-- Freezes existing monsters in place rather than despawning them once
	-- gameplay ends (Ending keeps the world visible for spectate/end
	-- screen) -- ticking just stops, per the plan's Ending contract.
	if not gameplayActive() then
		return
	end

	local now = os.clock()
	for model, agent in pairs(liveAgents) do
		if not model.Parent then
			-- Reached when a model is unparented without going through
			-- :Destroy() (which fires Destroying above and cleans up via
			-- ClearAgent there) -- Destroying does not fire on a bare
			-- `model.Parent = nil`, so this path needs its own cleanup call.
			MonsterDamage.ClearAgent(agent)
			liveAgents[model] = nil
			continue
		end

		local stateModule = MonsterAgent.States[agent.state]
		local tickRate = stateModule and stateModule.TickRate or 0.1
		local dt = now - agent.lastTick
		if dt >= tickRate then
			MonsterAgent.Tick(agent, dt)
			agent.lastTick = now
		end
	end
end)

return MonsterService
]====])

print("InstallGameMirror: done. Now paste Tools/CheckGameMirror.luau to confirm zero missing.")

-- ================================================ Bootstrap probe (read-only) ===
-- Locates the Game place's real bootstrap Script (it is not at
-- GameService.Bootstrap -- see the Phase 7.5 audit's open item) so its
-- Remotes.Init() call can be found/added by hand.
print("--- Bootstrap probe: BaseScript descendants of ServerScriptService + StarterPlayer ---")
local StarterPlayer = game:GetService("StarterPlayer")
for _, root in ipairs({ SSS, StarterPlayer }) do
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BaseScript") then
			print(d.ClassName, "|", d:GetFullName(), "| RunContext:", tostring(d.RunContext))
		end
	end
end
