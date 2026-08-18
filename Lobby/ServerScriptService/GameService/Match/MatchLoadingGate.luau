-- Server-authoritative gate for Loading -> WaitingForPlayers. The one module
-- that may fire that transition -- MatchArrival used to, but now only seeds
-- the roster and fires Seeded. Waits for every PRESENT participant to report
-- MatchClientReady, or for MatchClock's LoadingTimeout backstop to force the
-- issue: a client that never reports must not hang the match, but the server
-- must never simply take a client's word that "everything is loaded" --
-- this is the one place that word is weighed, and only against the whole
-- present roster, never trusted on its own.
--
-- Ledger is drop-on-leave: MatchParticipants.GetPresent() is re-read on every
-- evaluate(), so a participant who disconnects mid-Loading is no longer
-- required and can't stall the match past its own departure.
--
-- Must connect before MatchArrival can seed -- placed immediately before it
-- in GameBoot's ordered list, same "registry before registrant" rule as
-- every other publisher/subscriber pairing in that list.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local Signal = require(ReplicatedStorage.Modules.Shared.Signal)

local MatchManager = require(script.Parent.MatchManager)
local MatchParticipants = require(script.Parent.MatchParticipants)
local MatchArrival = require(script.Parent.MatchArrival)
local MatchClock = require(script.Parent.MatchClock)

local MatchLoadingGate = {}

-- Fires (readyCount, totalCount) whenever the ready set or the present
-- roster changes while Loading is still current. MatchReplicator is the sole
-- subscriber -- it owns turning this into the LoadingReadyCount/
-- LoadingReadyTotal attributes, the same "only MatchReplicator touches
-- remotes/attributes" rule MatchResultBuilder.Captured already follows.
MatchLoadingGate.ReadyCountChanged = Signal.new()

local seeded = false
local readyUserIds: { [number]: boolean } = {}

local function evaluate()
	if not seeded or not MatchManager.Is("Loading") then
		return
	end

	local present = MatchParticipants.GetPresent()
	local total = #present
	local readyCount = 0
	for _, player in ipairs(present) do
		if readyUserIds[player.UserId] then
			readyCount += 1
		end
	end

	MatchLoadingGate.ReadyCountChanged:Fire(readyCount, total)

	if total > 0 and readyCount >= total then
		MatchManager.RequestTransition("WaitingForPlayers", "AllClientsReady")
	end
end

local function onClientReady(player: Player)
	if not MatchParticipants.IsParticipant(player) then
		return
	end
	readyUserIds[player.UserId] = true
	evaluate()
end

local function onPlayerRemoving(player: Player)
	readyUserIds[player.UserId] = nil
	-- Re-evaluate even for a non-ready leaver: their departure can drop the
	-- present roster's remaining-unready count to zero.
	evaluate()
end

local started = false

function MatchLoadingGate.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	Remotes.Get("MatchClientReady").OnServerEvent:Connect(onClientReady)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	MatchParticipants.Joined:Connect(evaluate)

	-- MatchClock's Loading timer has no other trigger (Loading is
	-- MatchManager's INITIAL_STATE, so it's never reached via StateChanged) --
	-- this is that trigger, and evaluate() here also covers the edge case of
	-- every participant already having reported ready before Seeded fired.
	MatchArrival.Seeded:Connect(function()
		seeded = true
		MatchClock.StartLoadingTimeout()
		evaluate()
	end)
end

return MatchLoadingGate
