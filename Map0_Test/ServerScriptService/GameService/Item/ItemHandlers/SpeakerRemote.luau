-- The CompactSpeakerRemotes the player is left holding after placing a
-- Compact Speaker. Arms that speaker: sound, lure, 15-second window, and the
-- monster-contact rule all start here, not at placement.
--
-- Trigger-kind, so it runs the ordinary 3-second hold (movement lock,
-- progress bar, cancellable) rather than the tablet's instant toggle -- this
-- is a one-shot commitment, and holding still for three seconds to set off a
-- noisemaker that draws monsters is the trade, not an inconvenience to
-- optimise away.
--
-- ItemUseService consumes the remotes on success (Effect.Consume), so the
-- slot empties and there is nothing left to fire twice.

local SpeakerService = require(script.Parent.Parent.ItemWorld.SpeakerService)

local Handler = {}

function Handler.Apply(player: Player, _ctx): (boolean, string)
	-- False means there is no inert speaker left to arm -- it already went off,
	-- a monster reached it, or the match tore it down while the remotes
	-- outlived it. Failing here means the remotes are NOT consumed, so the
	-- player keeps them rather than losing the slot to a no-op.
	if not SpeakerService.Activate(player) then
		return false, "NoSpeaker"
	end
	return true, "Success"
end

return Handler
