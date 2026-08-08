-- Shaping functions for aggression modifiers. Every curve maps a NORMALIZED
-- input in [0,1] to an output in [0,1].
--
-- Normalization is the modifier's job; shaping is the curve's. That split is
-- what lets Proximity and MatchTime -- studs and hours -- share one curve table
-- without either knowing the other's units, and it is why these take a plain
-- number rather than raw domain values.
--
-- Deliberately NOT built on Reward/Curves/CurveFactory. Its two shapes are a
-- key->value lookup and a stepped falloff measured in METERS; neither can
-- express a continuous normalized ramp. Adding a third shape there would put
-- monster tuning inside the reward system, which owns a different problem.

local AggressionCurves = {}

local function clamp01(t: number): number
	return math.clamp(t, 0, 1)
end

AggressionCurves.All = {
	Linear = function(t: number): number
		return clamp01(t)
	end,

	-- Falls off fast: half the input is already down to a quarter of the
	-- output. For Proximity this reads as "only things genuinely close to me
	-- are worth being angry about" -- the far half of DetectRadius contributes
	-- almost nothing, so a monster does not sit permanently enraged simply
	-- because someone is technically within its detection sphere.
	InverseSquare = function(t: number): number
		t = clamp01(t)
		return t * t
	end,

	-- InverseSquare mirrored: climbs fast then flattens. For inputs where the
	-- LOW end is the significant one.
	Ease = function(t: number): number
		t = clamp01(t)
		return 1 - (1 - t) * (1 - t)
	end,

	-- Smoothstep. Flat at both ends, steep in the middle: early hours
	-- contribute nothing, the pressure arrives over the small hours, and it
	-- saturates rather than spiking at the boundary.
	NightRamp = function(t: number): number
		t = clamp01(t)
		return t * t * (3 - 2 * t)
	end,
}

AggressionCurves.Default = "Linear"

local warned = {}

function AggressionCurves.Get(name: string?)
	if name == nil then
		return AggressionCurves.All[AggressionCurves.Default]
	end

	local curve = AggressionCurves.All[name]
	if curve then
		return curve
	end

	-- Warn once per bad name, not once per tick. A typo'd curve is a config
	-- mistake worth surfacing, but this runs inside the aggression loop.
	if not warned[name] then
		warned[name] = true
		warn(("AggressionCurves: unknown curve '%s' -- falling back to %s")
			:format(tostring(name), AggressionCurves.Default))
	end
	return AggressionCurves.All[AggressionCurves.Default]
end

return AggressionCurves
