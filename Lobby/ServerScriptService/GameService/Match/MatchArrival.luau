-- Consumes TeleportData on the Game Server: seeds MatchParticipants from the
-- reserved server's participant roster + mode id, captures MatchSettings, and
-- fires Seeded once that's done. This is the Game-side counterpart to
-- ArrivalService, which handles the return leg on the Lobby.
--
-- Does NOT transition Loading -> WaitingForPlayers itself -- that used to
-- happen here, but the match loading screen needs a real Loading window
-- (character spawn, asset preload, a client readiness handshake) rather than
-- a transition that fires in the same frame as the first arrival.
-- MatchLoadingGate owns that transition now, gated on Seeded plus every
-- present participant's MatchClientReady report.
--
-- Falls back to seeding a solo participant (the arriving player themselves)
-- when no TeleportData is present -- a direct Studio Play-test or a stray
-- direct join still produces a runnable match of one, rather than getting
-- stuck in Loading forever (every phase leaves the game runnable).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local Signal = require(ReplicatedStorage.Modules.Shared.Signal)
local MatchParticipants = require(script.Parent.MatchParticipants)
local MatchSettings = require(script.Parent.MatchSettings)

local MatchArrival = {}

-- Fires once, after the roster is seeded and MatchSettings captured.
-- MatchLoadingGate and MatchSpawner are its subscribers.
MatchArrival.Seeded = Signal.new()

local DEFAULT_MODE = "Default"

local modeId = DEFAULT_MODE

-- Two separate latches, because they answer two different questions.
-- rosterLatched: "is the roster already complete?" -- true only once a
-- TeleportData roster has been read, since that single payload carries every
-- participant. advanced: "has Loading -> WaitingForPlayers already fired?" --
-- always exactly once, no matter how many players seed.
--
-- These used to be one flag, which silently broke every multi-client Studio
-- test: the fallback path below latched on the FIRST arrival, so every later
-- client stayed out of MatchParticipants -- and therefore never got a
-- character, since GameBoot sets CharacterAutoLoads = false and MatchSpawner
-- only loads for the roster.
local rosterLatched = false
local advanced = false

-- MatchClock needs the mode id to look up MatchConfig tunables but has no
-- other way to learn it -- this is the one piece of state MatchArrival
-- exposes beyond its own Start().
function MatchArrival.GetModeId(): string
	return modeId
end

local function seedFrom(player: Player)
	if rosterLatched then
		return
	end

	local joinData = player:GetJoinData()
	local teleportData = joinData and joinData.TeleportData

	if teleportData and teleportData.participantUserIds then
		-- Production: the first arrival's payload already names every
		-- participant, so one seed is the complete answer and later arrivals
		-- must not re-seed.
		rosterLatched = true
		modeId = teleportData.modeId or DEFAULT_MODE
		MatchParticipants.Seed(teleportData.participantUserIds)
	else
		-- Studio Play-test or a direct join: there is no roster to read, so
		-- each arrival is its own participant. Deliberately does NOT latch --
		-- see the comment on rosterLatched above.
		MatchParticipants.Seed({ player.UserId })
	end

	-- Guarded separately: a second Seeded fire would be wrong regardless of
	-- transition legality, and in the Studio path this runs once per arriving
	-- player. MatchSettings.Capture happens here too, immediately before the
	-- Signal it gates on -- MatchParticipants.All() is already correct at this
	-- point (the roster is seeded above), and every Seeded subscriber must see
	-- MatchSettings.Get() succeed with no dependency on subscriber order (G20).
	if not advanced then
		advanced = true
		MatchSettings.Capture(teleportData, modeId)
		MatchArrival.Seeded:Fire()
	end
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
