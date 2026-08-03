-- The real caller MatchLauncher never had. Queues party units (atomic --
-- only a party leader can enqueue, and the whole unit moves together),
-- accumulates units from the head up to MaxPlayers, waits QueueGraceSeconds
-- for company once MinPlayers is met, then runs them through LaunchGate
-- before handing the roster to MatchLauncher. Single mode ("Default") for
-- now -- PlaceIds.GameModes/MatchConfig.Modes both only define one.
--
-- Registers its own "Roster" precondition: LaunchGate.Check and
-- MatchLauncher.Launch both yield (DataStore write, ReserveServer,
-- TeleportAsync), so the accumulated candidate list can go stale mid-flow --
-- a candidate could disconnect between accumulation and teleport. Re-reading
-- `player.Parent` immediately before Launch is not redundant with the
-- `launching` flag; the flag only prevents a second evaluate() from running
-- concurrently, it does nothing about state changing during the one that IS
-- running.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MatchConfig = require(ReplicatedStorage.Modules.Shared.MatchConfig)
local Signal = require(ReplicatedStorage.Modules.Shared.Signal)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local Cooldown = require(ReplicatedStorage.Modules.Shared.Cooldown)

local PartyService = require(script.Parent.PartyService)
local LaunchGate = require(script.Parent.LaunchGate)
local MatchLauncher = require(script.Parent.MatchLauncher)

local QueueService = {}

local DEFAULT_MODE = "Default"

type Unit = { players: { Player } }

local queue: { Unit } = {}
local launching = false
local graceStartedAt: number? = nil

QueueService.Changed = Signal.new() -- fires no payload; listeners re-read state

local requestCooldown = Cooldown.new(0.5)

local function findUnitIndex(player: Player): number?
	for i, unit in ipairs(queue) do
		for _, p in ipairs(unit.players) do
			if p == player then
				return i
			end
		end
	end
	return nil
end

function QueueService.GetPosition(player: Player): number?
	local flatIndex = 0
	for _, unit in ipairs(queue) do
		for _, p in ipairs(unit.players) do
			flatIndex += 1
			if p == player then
				return flatIndex
			end
		end
	end
	return nil
end

function QueueService.GetSize(): number
	local total = 0
	for _, unit in ipairs(queue) do
		total += #unit.players
	end
	return total
end

function QueueService.Join(player: Player): (boolean, string)
	if findUnitIndex(player) then
		return false, "AlreadyQueued"
	end
	if launching then
		return false, "LaunchInProgress"
	end
	if not PartyService.IsLeader(player) then
		return false, "NotPartyLeader"
	end

	local party = PartyService.GetParty(player)
	local cfg = MatchConfig.Get(DEFAULT_MODE)
	if #party > cfg.MaxPlayers then
		return false, "PartyTooLarge"
	end

	table.insert(queue, { players = party })
	QueueService.Changed:Fire()
	return true, "Ok"
end

function QueueService.Leave(player: Player): (boolean, string)
	local index = findUnitIndex(player)
	if not index then
		return false, "NotQueued"
	end

	table.remove(queue, index)
	QueueService.Changed:Fire()
	return true, "Ok"
end

-- Involuntary exit (disconnect): shrinks the player's unit rather than
-- pulling the whole party, unlike a voluntary Leave() -- a departed Player
-- instance can't be teleported, but partymates who are still connected
-- shouldn't lose their place in line over it.
local function removePlayerFromQueue(player: Player)
	for i, unit in ipairs(queue) do
		for j, p in ipairs(unit.players) do
			if p == player then
				table.remove(unit.players, j)
				if #unit.players == 0 then
					table.remove(queue, i)
				end
				QueueService.Changed:Fire()
				return
			end
		end
	end
end

local function fireResult(units: { Unit }, code: string)
	for _, unit in ipairs(units) do
		for _, player in ipairs(unit.players) do
			if player.Parent then
				Remotes.Get("QueueResult"):FireClient(player, code)
			end
		end
	end
end

local function syncQueuedPlayers()
	for _, unit in ipairs(queue) do
		for _, player in ipairs(unit.players) do
			Remotes.Get("QueueStateSync"):FireClient(player, {
				position = QueueService.GetPosition(player),
				size = QueueService.GetSize(),
			})
		end
	end
end

local function dequeueUnits(units: { Unit })
	for _, unit in ipairs(units) do
		for i, queued in ipairs(queue) do
			if queued == unit then
				table.remove(queue, i)
				break
			end
		end
	end
end

local function evaluate()
	if launching then
		return
	end

	local cfg = MatchConfig.Get(DEFAULT_MODE)

	local candidateUnits: { Unit } = {}
	local candidates: { Player } = {}
	local count = 0
	for _, unit in ipairs(queue) do
		if count + #unit.players > cfg.MaxPlayers then
			break
		end
		count += #unit.players
		table.insert(candidateUnits, unit)
		for _, p in ipairs(unit.players) do
			table.insert(candidates, p)
		end
	end

	if count < cfg.MinPlayers then
		graceStartedAt = nil
		return
	end

	if count < cfg.MaxPlayers then
		if not graceStartedAt then
			graceStartedAt = os.clock()
			-- Nothing else fires Changed purely from time passing, so this
			-- schedules the recheck that lets a lone player in queue
			-- eventually launch instead of waiting for company forever.
			task.delay(cfg.QueueGraceSeconds, function()
				QueueService.Changed:Fire()
			end)
			return
		end
		if os.clock() - graceStartedAt < cfg.QueueGraceSeconds then
			return
		end
	end

	graceStartedAt = nil
	launching = true

	local checkOk, checkCode = LaunchGate.Check(candidates)
	if not checkOk then
		fireResult(candidateUnits, checkCode)
		launching = false
		return
	end

	local launchOk, launchCode = MatchLauncher.Launch(candidates, DEFAULT_MODE)
	if launchOk then
		dequeueUnits(candidateUnits)
		LaunchGate.OnLaunched(candidates)
	else
		fireResult(candidateUnits, "LaunchFailed")
		warn("QueueService: MatchLauncher.Launch failed:", launchCode)
	end

	launching = false
end

local function onQueueRequest(player: Player, request: any)
	if typeof(request) ~= "table" then
		return
	end

	if not requestCooldown:Check(player.UserId) then
		Remotes.Get("QueueResult"):FireClient(player, "RateLimited")
		return
	end

	local ok, code
	if request.action == "Join" then
		ok, code = QueueService.Join(player)
	elseif request.action == "Leave" then
		ok, code = QueueService.Leave(player)
	else
		ok, code = false, "InvalidRequest"
	end

	Remotes.Get("QueueResult"):FireClient(player, code)
end

-- Re-validated immediately before every launch attempt -- see the file
-- header on why this is not redundant with the `launching` guard.
local function checkRoster(players: { Player }): (boolean, string)
	for _, player in ipairs(players) do
		if not player.Parent then
			return false, "RosterChanged"
		end
	end
	return true, "Ok"
end

local started = false

function QueueService.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertLobbyServer()

	LaunchGate.RegisterPrecondition("Roster", checkRoster)

	QueueService.Changed:Connect(evaluate)
	QueueService.Changed:Connect(syncQueuedPlayers)

	Players.PlayerRemoving:Connect(removePlayerFromQueue)
	Remotes.Get("QueueRequest").OnServerEvent:Connect(onQueueRequest)
end

return QueueService
