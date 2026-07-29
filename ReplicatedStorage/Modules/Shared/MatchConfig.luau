-- Per-mode match tunables. Keyed by mode id, same shape as CameraStats/
-- MonsterStats: adding a mode is one more table entry, no script changes.
-- Mode ids correspond to PlaceIds.GameModes keys.

local MatchConfig = {}

MatchConfig.Modes = {
	Default = {
		MinPlayers = 1,
		MaxPlayers = 8,
		WaitTimeout = 60, -- seconds WaitingForPlayers waits before Cleanup at zero players
		CountdownSeconds = 5,
		EndingHoldSeconds = 8, -- how long Ending stays up so the summary is readable
	},
}

function MatchConfig.Get(modeId: string)
	local config = MatchConfig.Modes[modeId]
	if not config then
		warn(("MatchConfig.Get: unknown mode '%s', falling back to Default"):format(modeId))
		config = MatchConfig.Modes.Default
	end
	return config
end

return MatchConfig
