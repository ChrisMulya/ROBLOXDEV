-- One queue per physical lobby pad, not one global queue. A pad's capacity is
-- a roster cap, not a requirement: a 4-capacity pad holding 2 players launches
-- a 2-player match. The countdown starts when the first unit steps onto an
-- empty pad, does not reset when more join, and cancels only when the pad
-- empties -- so "whoever is still standing there at zero" is the roster.
--
-- Entry is no longer client-initiated. QueuePadService senses occupancy from
-- server-side character positions and calls JoinPad/LeavePad; there is no
-- QueueRequest remote and therefore nothing to rate-limit -- a client cannot
-- assert that it is queued at all, only stand somewhere.
--
-- `launching` is per-pad rather than module-global: two pads must be able to
-- launch concurrently. LaunchGate is a stateless registry, so concurrent
-- Check/OnLaunched calls across pads are safe.
--
-- Registers its own "Roster" precondition: LaunchGate.Check and
-- MatchLauncher.Launch both yield (DataStore write, ReserveServer,
-- TeleportAsync), so the accumulated candidate list can go stale mid-flow --
-- a candidate could disconnect between accumulation and teleport. Re-reading
-- `player.Parent` immediately before Launch is not redundant with the
-- `launching` flag; the flag only prevents a second launch on the same pad,
-- it does nothing about state changing during the one that IS running.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MatchConfig = require(ReplicatedStorage.Modules.Shared.MatchConfig)
local Signal = require(ReplicatedStorage.Modules.Shared.Signal)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)

local PartyService = require(script.Parent.PartyService)
local LaunchGate = require(script.Parent.LaunchGate)
local MatchLauncher = require(script.Parent.MatchLauncher)

local QueueService = {}

local DEFAULT_MODE = "Default"

type Unit = { players: { Player } }
type Pad = {
	instance: Instance,
	capacity: number,
	units: { Unit },
	endsAt: number?, -- workspace:GetServerTimeNow() deadline; nil = idle
	generation: number, -- bumped to invalidate an in-flight countdown callback
	launching: boolean,
}

-- Keyed by the pad Instance itself, never by name -- same identity rule as
-- ObjectiveRegistry. Two pads can't collide and a rename can't orphan one.
local pads: { [Instance]: Pad } = {}

-- Players handed to MatchLauncher and awaiting their teleport. They are still
-- physically standing on the pad, so without this they would be re-admitted
-- the moment the launch clears the roster -- arming a phantom countdown on a
-- pad whose occupants are already leaving. Cleared when they actually go, or
-- when the launch is aborted and they turn out to be staying.
local teleporting: { [Player]: boolean } = {}

QueueService.Changed = Signal.new() -- fires no payload; listeners re-read state

local function occupancy(pad: Pad): number
	local total = 0
	for _, unit in ipairs(pad.units) do
		total += #unit.players
	end
	return total
end

local function findUnit(player: Player): (Pad?, number?)
	for _, pad in pairs(pads) do
		for i, unit in ipairs(pad.units) do
			for _, p in ipairs(unit.players) do
				if p == player then
					return pad, i
				end
			end
		end
	end
	return nil, nil
end

function QueueService.GetPadOf(player: Player): Instance?
	local pad = findUnit(player)
	return pad and pad.instance or nil
end

function QueueService.GetPads(): { Instance }
	local result = {}
	for instance in pairs(pads) do
		table.insert(result, instance)
	end
	return result
end

-- Read model for the display layer: QueuePadService mirrors this onto the pad
-- instance as attributes. Nothing outside this module writes pad state.
function QueueService.GetPadState(instance: Instance): { capacity: number, count: number, endsAt: number? }?
	local pad = pads[instance]
	if not pad then
		return nil
	end
	return {
		capacity = pad.capacity,
		count = occupancy(pad),
		endsAt = pad.endsAt,
	}
end

local function fireResultToPad(pad: Pad, code: string)
	for _, unit in ipairs(pad.units) do
		for _, player in ipairs(unit.players) do
			if player.Parent then
				Remotes.Get("QueueResult"):FireClient(player, code)
			end
		end
	end
end

local launchPad -- forward declaration; arm() schedules it

-- Nothing fires Changed purely from time passing, so the countdown is a
-- scheduled callback rather than a re-evaluated predicate. The generation
-- capture is what makes cancellation work: disarm() bumps it, and the pending
-- callback sees a stale value and no-ops instead of launching an empty pad.
local function arm(pad: Pad)
	local cfg = MatchConfig.Get(DEFAULT_MODE)
	pad.generation += 1
	local generation = pad.generation
	pad.endsAt = workspace:GetServerTimeNow() + cfg.PadCountdownSeconds

	task.delay(cfg.PadCountdownSeconds, function()
		if pads[pad.instance] ~= pad or pad.generation ~= generation then
			return
		end
		launchPad(pad)
	end)
end

local function disarm(pad: Pad)
	pad.generation += 1
	pad.endsAt = nil
end

function launchPad(pad: Pad)
	if pad.launching then
		return
	end

	local cfg = MatchConfig.Get(DEFAULT_MODE)

	local candidates: { Player } = {}
	for _, unit in ipairs(pad.units) do
		for _, player in ipairs(unit.players) do
			table.insert(candidates, player)
		end
	end

	-- Unreachable at MinPlayers = 1, but a pad that can't meet the floor must
	-- keep waiting rather than sit with a dead timer and no way to rearm.
	if #candidates < cfg.MinPlayers then
		arm(pad)
		QueueService.Changed:Fire()
		return
	end

	pad.launching = true
	pad.endsAt = nil

	local checkOk, checkCode = LaunchGate.Check(candidates)
	if not checkOk then
		fireResultToPad(pad, checkCode)
		pad.launching = false
		if occupancy(pad) > 0 then
			arm(pad) -- the "-- Requeued" half of the result message
		end
		QueueService.Changed:Fire()
		return
	end

	local launchOk, launchCode = MatchLauncher.Launch(candidates, DEFAULT_MODE)
	if launchOk then
		pad.units = {}
		disarm(pad)
		for _, player in ipairs(candidates) do
			teleporting[player] = true
		end
		LaunchGate.OnLaunched(candidates)
	else
		-- launchCode is one of MatchLauncher's own reasons (UnknownMode,
		-- ReserveFailed, ...), a real key in QueueResultCodes.Messages -- pass
		-- it straight through instead of flattening to "LaunchFailed" so the
		-- player hears why, not just that it failed.
		fireResultToPad(pad, launchCode)
		warn("QueueService: MatchLauncher.Launch failed:", launchCode)
		if occupancy(pad) > 0 then
			arm(pad)
		end
	end

	pad.launching = false
	QueueService.Changed:Fire()
end

-- Idempotent: re-registering an existing pad only refreshes its capacity, so
-- an attribute edited live in Studio takes effect without dropping occupants.
function QueueService.RegisterPad(instance: Instance, capacity: number)
	local cfg = MatchConfig.Get(DEFAULT_MODE)
	local clamped = math.clamp(math.floor(capacity), 1, cfg.MaxPlayers)

	local existing = pads[instance]
	if existing then
		existing.capacity = clamped
		QueueService.Changed:Fire()
		return
	end

	pads[instance] = {
		instance = instance,
		capacity = clamped,
		units = {},
		endsAt = nil,
		generation = 0,
		launching = false,
	}
	QueueService.Changed:Fire()
end

function QueueService.UnregisterPad(instance: Instance)
	local pad = pads[instance]
	if not pad then
		return
	end
	disarm(pad)
	pads[instance] = nil
	QueueService.Changed:Fire()
end

function QueueService.JoinPad(player: Player, instance: Instance): (boolean, string)
	local pad = pads[instance]
	if not pad then
		return false, "InvalidRequest"
	end
	if pad.launching then
		return false, "LaunchInProgress"
	end
	if not PartyService.IsLeader(player) then
		return false, "NotPartyLeader"
	end

	local party = PartyService.GetParty(player)
	-- The whole unit moves together, so a partymate already standing on some
	-- other pad would have to be pulled off it -- reject instead.
	for _, member in ipairs(party) do
		if teleporting[member] then
			return false, "LaunchInProgress"
		end
		if QueueService.GetPadOf(member) then
			return false, "AlreadyQueued"
		end
	end

	if #party > pad.capacity then
		return false, "PartyTooLarge"
	end
	if occupancy(pad) + #party > pad.capacity then
		return false, "QueueFull"
	end

	local wasEmpty = occupancy(pad) == 0
	table.insert(pad.units, { players = party })
	if wasEmpty then
		arm(pad)
	end

	QueueService.Changed:Fire()
	return true, "Ok"
end

-- The (boolean, string) return is advisory, not a player-facing result: the
-- sensor (QueuePadService) calls this unconditionally on every pad exit,
-- including walking off a pad you were never admitted to because it was
-- full. "NotQueued" is the expected, silent outcome of that case -- not an
-- error worth surfacing -- which is why it isn't in QueueResultCodes.
function QueueService.LeavePad(player: Player): (boolean, string)
	local pad, index = findUnit(player)
	if not pad or not index then
		return false, "NotQueued"
	end

	table.remove(pad.units, index)
	if occupancy(pad) == 0 then
		disarm(pad)
	end

	QueueService.Changed:Fire()
	return true, "Ok"
end

-- Involuntary exit (disconnect): shrinks the player's unit rather than pulling
-- the whole party, unlike a voluntary LeavePad() -- a departed Player instance
-- can't be teleported, but partymates still standing on the pad shouldn't lose
-- their slot over it.
local function removePlayerFromQueue(player: Player)
	-- Before the early return below: a player mid-teleport isn't in any unit,
	-- but their lock still has to go when they leave.
	teleporting[player] = nil

	local pad, index = findUnit(player)
	if not pad or not index then
		return
	end

	local unit = pad.units[index]
	for j, p in ipairs(unit.players) do
		if p == player then
			table.remove(unit.players, j)
			break
		end
	end
	if #unit.players == 0 then
		table.remove(pad.units, index)
	end
	if occupancy(pad) == 0 then
		disarm(pad)
	end

	QueueService.Changed:Fire()
end

-- Re-validated immediately before every launch attempt -- see the file header
-- on why this is not redundant with the `launching` guard.
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

	-- MatchLauncher retries TeleportInitFailed and eventually gives up, at
	-- which point the player is staying in the lobby -- release the lock so
	-- they can step back onto a pad instead of being stuck outside every queue.
	LaunchGate.RegisterOnLaunchAborted("QueuePadLock", function(players: { Player })
		for _, player in ipairs(players) do
			teleporting[player] = nil
		end
		QueueService.Changed:Fire()
	end)

	Players.PlayerRemoving:Connect(removePlayerFromQueue)
end

return QueueService
