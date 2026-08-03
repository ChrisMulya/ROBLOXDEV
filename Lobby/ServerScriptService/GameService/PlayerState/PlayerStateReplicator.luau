-- Mirrors PlayerStateService's authoritative state onto a `PlayerState`
-- attribute on the Player instance -- shared, identical-for-everyone state,
-- so it rides an attribute rather than a remote (the ObjectiveReplicator
-- rule: shared state -> attribute, per-player detail -> remote). No private
-- per-player detail exists yet (e.g. a respawn timer), so there is no
-- remote here -- one lands whenever a future phase needs to replicate
-- something that can't be public.
--
-- Started after PlayerStateService in the boot list (publishers before
-- subscribers) so no StateChanged fire is missed.

local PlayerStateService = require(script.Parent.PlayerStateService)

local PlayerStateReplicator = {}

local started = false

function PlayerStateReplicator.Start()
	if started then
		return
	end
	started = true

	PlayerStateService.StateChanged:Connect(function(player: Player, newState: string)
		if player and player.Parent then
			player:SetAttribute("PlayerState", newState)
		end
	end)
end

return PlayerStateReplicator
