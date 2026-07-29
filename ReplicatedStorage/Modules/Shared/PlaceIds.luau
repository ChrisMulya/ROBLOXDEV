-- The only file that changes when a place is added to the experience.
-- ServerRole resolves game.PlaceId against this table to decide identity.
-- Both places must stay in this same universe (GameId 10535406765) --
-- RewardStore_v1 is scoped per-universe, not per-place, and cross-universe
-- teleport would silently orphan a player's saved XP.

local PlaceIds = {}

PlaceIds.Lobby = 91205326584169
PlaceIds.Game = 100171816233157

-- Mode id -> PlaceId. Every mode reserves the same place today; this is the
-- seam for per-mode places (hardcore/nightmare/etc.) later without touching
-- ServerRole or any caller of it.
PlaceIds.GameModes = {
	Default = PlaceIds.Game,
}

return PlaceIds
