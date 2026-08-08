-- Locomotion strategy registry. config.Navigation.Locomotion names one; the
-- Navigation component constructs it and never learns which it got.
--
-- HumanoidPath / Fly / Teleport land in step 6 and after. Until then an
-- unknown name falls back to Kinematic with a warn rather than leaving a
-- monster that computes movement and never applies it.

local Locomotion = {}

local strategies = {
	Kinematic = require(script.KinematicLocomotion),
	-- Written, registered, and NOT exercised -- no config selects it yet.
	-- See the header of HumanoidPathLocomotion for why.
	HumanoidPath = require(script.HumanoidPathLocomotion),
}

Locomotion.Default = "Kinematic"

function Locomotion.Get(name: string?)
	local resolved = strategies[name or Locomotion.Default]
	if not resolved then
		warn(("Locomotion: unknown strategy '%s' -- falling back to %s")
			:format(tostring(name), Locomotion.Default))
		return strategies[Locomotion.Default]
	end
	return resolved
end

return Locomotion
