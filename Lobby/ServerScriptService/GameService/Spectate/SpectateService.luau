-- Spectating only. Owns valid-target resolution and per-spectator target
-- assignment, server-side. Must not set a player's state (a player is
-- Spectating because PlayerStateService/DeathService said so, not because
-- they opened a spectate UI) and must not move a camera itself (that's the
-- client's SpectateCameraController). Game Server only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MatchStates = require(ReplicatedStorage.Modules.Shared.MatchStates)
local PlayerStates = require(ReplicatedStorage.Modules.Shared.PlayerStates)
local Signal = require(ReplicatedStorage.Modules.Shared.Signal)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local Cooldown = require(ReplicatedStorage.Modules.Shared.Cooldown)

local MatchManager = require(script.Parent.Parent.Match.MatchManager)
local PlayerStateService = require(script.Parent.Parent.PlayerState.PlayerStateService)
local SpectateTargets = require(script.Parent.SpectateTargets)

local SpectateService = {}

-- spectatorUserId -> targetUserId (absent = no target / FreeCamera fallback)
local assignments: { [number]: number } = {}

SpectateService.TargetChanged = Signal.new() -- fires (spectator, target: Player?, resultCode)

local requestCooldown = Cooldown.new(0.25) -- ~4/sec, matches CaptureGuard-style rate limits elsewhere

function SpectateService.GetValidTargets(): { Player }
	return SpectateTargets.GetValidTargets()
end

function SpectateService.GetTarget(spectator: Player): Player?
	local targetUserId = assignments[spectator.UserId]
	return targetUserId and Players:GetPlayerByUserId(targetUserId)
end

local function fireSync(spectator: Player, target: Player?, resultCode: string)
	local validTargets = SpectateService.GetValidTargets()
	local index = 0
	if target then
		for i, p in ipairs(validTargets) do
			if p == target then
				index = i
				break
			end
		end
	end
	Remotes.Get("SpectateStateSync"):FireClient(spectator, {
		targetUserId = target and target.UserId or nil,
		resultCode = resultCode,
		index = index,
		total = #validTargets,
	})
end

-- target == nil is a legal, explicit "free camera" assignment (NoTargets).
function SpectateService.SetTarget(spectator: Player, target: Player?): (boolean, string)
	if not PlayerStates.CanSpectate(PlayerStateService.Get(spectator)) then
		return false, "NotSpectating"
	end
	if not MatchStates.IsSpectateAllowed(MatchManager.Get()) then
		return false, "SpectateNotAllowed"
	end

	if target ~= nil then
		local valid = false
		for _, p in ipairs(SpectateService.GetValidTargets()) do
			if p == target then
				valid = true
				break
			end
		end
		if not valid then
			return false, "InvalidTarget"
		end
	end

	if target then
		assignments[spectator.UserId] = target.UserId
	else
		assignments[spectator.UserId] = nil
	end

	SpectateService.TargetChanged:Fire(spectator, target, "Ok")
	fireSync(spectator, target, target and "Ok" or "NoTargets")
	return true, "Ok"
end

-- Picks the first valid target for a spectator with none, or explicitly
-- assigns FreeCamera (nil) if nothing is available.
local function assignBest(spectator: Player)
	local validTargets = SpectateService.GetValidTargets()
	local target = SpectateTargets.SelectNext(nil, validTargets)
	SpectateService.SetTarget(spectator, target)
end

-- Next/Previous report "NoTargets" themselves when there's nothing to
-- cycle to, distinct from SetTarget's own "assigning nil always succeeds"
-- contract -- a client asking to cycle and getting told "Ok" with nothing
-- to look at would be misleading.
function SpectateService.Next(spectator: Player): (boolean, string)
	if not requestCooldown:Check(spectator.UserId) then
		return false, "RateLimited"
	end
	local validTargets = SpectateService.GetValidTargets()
	local nextTarget = SpectateTargets.SelectNext(SpectateService.GetTarget(spectator), validTargets)
	if not nextTarget then
		SpectateService.SetTarget(spectator, nil)
		return false, "NoTargets"
	end
	return SpectateService.SetTarget(spectator, nextTarget)
end

function SpectateService.Previous(spectator: Player): (boolean, string)
	if not requestCooldown:Check(spectator.UserId) then
		return false, "RateLimited"
	end
	local validTargets = SpectateService.GetValidTargets()
	local prevTarget = SpectateTargets.SelectPrevious(SpectateService.GetTarget(spectator), validTargets)
	if not prevTarget then
		SpectateService.SetTarget(spectator, nil)
		return false, "NoTargets"
	end
	return SpectateService.SetTarget(spectator, prevTarget)
end

-- Any spectator currently watching `targetUserId` gets reassigned when that
-- target leaves a CanControlCharacter state (dies, disconnects) -- covers
-- both cases through the same PlayerStateService.StateChanged path.
local function reassignSpectatorsWatching(targetUserId: number)
	for spectatorUserId, watchedUserId in pairs(assignments) do
		if watchedUserId == targetUserId then
			local spectator = Players:GetPlayerByUserId(spectatorUserId)
			if spectator then
				assignBest(spectator)
			end
		end
	end
end

local function onPlayerStateChanged(player: Player, newState: string, oldState: string?)
	-- Order matters, and the early return this used to open with was wrong for
	-- any state that both ENDS a run and starts a spectate in one transition.
	-- Alive -> Escaped is exactly that: the player stops being a valid target
	-- for others AND becomes a spectator themselves, so both halves below have
	-- to run. Dead -> Spectating never exposed the bug because Alive -> Dead
	-- had already done the reassign a moment earlier.
	if oldState and PlayerStates.CanControlCharacter(oldState) and not PlayerStates.CanControlCharacter(newState) then
		reassignSpectatorsWatching(player.UserId)
	end

	if oldState and PlayerStates.CanSpectate(oldState) and not PlayerStates.CanSpectate(newState) then
		assignments[player.UserId] = nil
	end

	-- Reads the CanSpectate FLAG rather than the literal "Spectating", per
	-- this repo's own rule (see PlayerStates' header: never branch on a state
	-- name outside PlayerStateService's guard). Without this an Escaped player
	-- has a destroyed character, no camera subject, and an empty viewport --
	-- and a future Observer state gets its camera here for free.
	if PlayerStates.CanSpectate(newState) then
		assignBest(player)
	end
end

local function onPlayerRemoving(player: Player)
	assignments[player.UserId] = nil
	reassignSpectatorsWatching(player.UserId)
end

-- Cleanup destroys instances; spectate must not be left pointing at
-- something that's about to disappear.
local function onMatchStateChanged(newState: string)
	if newState == "Cleanup" then
		for spectatorUserId in pairs(assignments) do
			local spectator = Players:GetPlayerByUserId(spectatorUserId)
			if spectator then
				fireSync(spectator, nil, "MatchEnded")
			end
		end
		assignments = {}
	end
end

local function onSpectateRequest(spectator: Player, request: any)
	if typeof(request) ~= "table" then
		return
	end

	local ok, resultCode
	if request.action == "Next" then
		ok, resultCode = SpectateService.Next(spectator)
	elseif request.action == "Prev" then
		ok, resultCode = SpectateService.Previous(spectator)
	elseif request.action == "Target" and typeof(request.targetUserId) == "number" then
		local target = Players:GetPlayerByUserId(request.targetUserId)
		ok, resultCode = SpectateService.SetTarget(spectator, target)
	else
		ok, resultCode = false, "InvalidRequest"
	end

	Remotes.Get("SpectateResult"):FireClient(spectator, resultCode)
end

local started = false

function SpectateService.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	PlayerStateService.StateChanged:Connect(onPlayerStateChanged)
	MatchManager.StateChanged:Connect(onMatchStateChanged)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	Remotes.Get("SpectateRequest").OnServerEvent:Connect(onSpectateRequest)
end

return SpectateService
