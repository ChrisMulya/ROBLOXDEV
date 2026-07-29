-- Server identity only. Resolved once from game.PlaceId -- engine-provided,
-- unforgeable, and knowable before the first player arrives (unlike
-- TeleportData, which is client-routed and only exists after a join).
--
-- No setter is exposed on purpose: a settable role would let a test, a
-- stray call, or an exploit path flip a lobby into a game server.

local PlaceIds = require(script.Parent.PlaceIds)

local ServerRole = {}

local LOBBY = "LobbyServer"
local GAME = "GameServer"

local resolved: string? = nil

local function resolve(): string
	if resolved then
		return resolved
	end

	local placeId = game.PlaceId
	if placeId == PlaceIds.Lobby then
		resolved = LOBBY
	elseif placeId == PlaceIds.Game then
		resolved = GAME
	else
		error(("ServerRole: unrecognised PlaceId %d -- add it to PlaceIds.luau"):format(placeId), 0)
	end

	return resolved
end

function ServerRole.Get(): string
	return resolve()
end

function ServerRole.Is(role: string): boolean
	return resolve() == role
end

-- Errors here, not at module scope, so a stray require() stays inert and
-- only *activating* a Game-Server-only service on the wrong place fails.
function ServerRole.AssertGameServer()
	if resolve() ~= GAME then
		error("ServerRole.AssertGameServer: this module may only run on a Game Server", 2)
	end
end

function ServerRole.AssertLobbyServer()
	if resolve() ~= LOBBY then
		error("ServerRole.AssertLobbyServer: this module may only run on a Lobby Server", 2)
	end
end

return ServerRole
