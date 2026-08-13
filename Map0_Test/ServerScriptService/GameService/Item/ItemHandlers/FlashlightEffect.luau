-- Brighter Flashlight. Applies three PlayerEffects deltas (range, brightness,
-- angle -- angle widens the beam's radius, not just its reach); never touches
-- flashlight rendering directly -- FlashlightService reads the effective
-- values through its own existing getBeamStats seam. No new Tool, no slot
-- occupied: the used Tool is still consumed by ItemUseService same as every
-- other item, it just grants nothing back.

local PlayerEffects = require(script.Parent.Parent.Parent.Player.PlayerEffects)

local FlashlightEffect = {}

function FlashlightEffect.Apply(player: Player, ctx): (boolean, string)
	local effect = ctx.item.Effect
	PlayerEffects.Apply(player, {
		Stat = "FlashlightRange",
		Delta = effect.RangeDelta,
		Duration = effect.Duration,
		SourceId = ctx.item.Id,
	})
	PlayerEffects.Apply(player, {
		Stat = "FlashlightBrightness",
		Delta = effect.BrightnessDelta,
		Duration = effect.Duration,
		SourceId = ctx.item.Id,
	})
	PlayerEffects.Apply(player, {
		Stat = "FlashlightAngle",
		Delta = effect.AngleDelta,
		Duration = effect.Duration,
		SourceId = ctx.item.Id,
	})
	return true, "Success"
end

return FlashlightEffect
