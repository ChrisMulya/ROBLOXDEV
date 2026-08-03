-- Per-mode death behavior. Keyed by mode id, same shape/convention as
-- MatchConfig -- adding a mode (or a future Downed/Revive row that switches
-- RespawnPolicy to something like "EnterDowned") is one more table entry,
-- not a new branch in DeathService.
--
-- Lobby's death handling is entirely separate (LobbyDeathPolicy.luau,
-- always immediate, no data table) -- this module and DeathService are
-- Game-Server-only companions.

local DeathPolicy = {}

DeathPolicy.Modes = {
	Default = {
		RespawnPolicy = "EnterSpectate", -- "Immediate" | "EnterSpectate"
		SpectateDelay = 2, -- seconds between Dead and Spectating
	},
}

function DeathPolicy.Get(modeId: string)
	local policy = DeathPolicy.Modes[modeId]
	if not policy then
		warn(("DeathPolicy.Get: unknown mode '%s', falling back to Default"):format(modeId))
		policy = DeathPolicy.Modes.Default
	end
	return policy
end

return DeathPolicy
