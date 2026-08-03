-- Consumes TeleportData on the Game Server: seeds MatchParticipants from the
-- reserved server's participant roster + mode id, then advances
-- Loading -> WaitingForPlayers once that's done. This is the Game-side
-- counterpart to ArrivalService, which handles the return leg on the Lobby.
--
-- Falls back to seeding a solo participant (the arriving player themselves)
-- when no TeleportData is present -- a direct Studio Play-test or a stray
-- direct join still produces a runnable match of one, rather than getting
-- stuck in Loading forever (every phase leaves the game runnable).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MatchManager = require(script.Parent.MatchManager)
local MatchParticipants = require(script.Parent.MatchParticipants)

local MatchArrival = {}

local DEFAULT_MODE = "Default"

local modeId = DEFAULT_MODE
local seeded = false

-- MatchClock needs the mode id to look up MatchConfig tunables but has no
-- other way to learn it -- this is the one piece of state MatchArrival
-- exposes beyond its own Start().
function MatchArrival.GetModeId(): string
	return modeId
end

local function seedFrom(player: Player)
	if seeded then
		return
	end
	seeded = true

	local joinData = player:GetJoinData()
	local teleportData = joinData and joinData.TeleportData

	if teleportData and teleportData.participantUserIds then
		modeId = teleportData.modeId or DEFAULT_MODE
		MatchParticipants.Seed(teleportData.participantUserIds)
	else
		MatchParticipants.Seed({ player.UserId })
	end

	MatchManager.RequestTransition("WaitingForPlayers", "MatchArrival")
end

local started = false

function MatchArrival.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	-- Reserved servers boot before any player teleports in, so this loop is
	-- normally a no-op -- kept for the same reason MatchParticipants.Seed
	-- checks already-present players: boot order isn't guaranteed relative to
	-- a player already being in the DataModel (Studio Play-test quirk).
	for _, player in ipairs(Players:GetPlayers()) do
		seedFrom(player)
	end

	Players.PlayerAdded:Connect(seedFrom)
end

return MatchArrival
