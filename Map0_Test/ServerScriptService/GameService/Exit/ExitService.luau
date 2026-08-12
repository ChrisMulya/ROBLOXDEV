-- Escape is a DWELL, not an interaction: a player standing continuously
-- inside an open exit's marked Part for ExitConfig.DwellSeconds gets out.
-- No ProximityPrompt anywhere in this flow -- there is nothing for a client
-- to trigger, forge, or spam, because the only input is where the server
-- says the character is.
--
-- Sampling mirrors MatchTimeService: one Heartbeat connection with an
-- accumulator, connected on entering Playing and fully disconnected on
-- leaving it, so nothing runs between matches.
--
-- The dwell RESETS to zero rather than pausing when a player steps out,
-- dies, or the exit re-locks. That's a design choice, not an implementation
-- shortcut -- see ExitConfig.DwellSeconds.
--
-- HARD CONTRACT: escape() below contains no yield. That is what lets its
-- "is anyone still active" check and MatchManager.RequestEnd("Extracted")
-- land before MatchEndCondition's own (deferred) StateChanged subscriber can
-- stamp "AllPlayersDown" -- same ordering discipline SunriseEndHook uses.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local Signal = require(ReplicatedStorage.Modules.Shared.Signal)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local PlayerStates = require(ReplicatedStorage.Modules.Shared.PlayerStates)
local ExitTypes = require(ReplicatedStorage.Modules.Exit.ExitTypes)
local ExitConfig = require(ReplicatedStorage.Modules.Exit.ExitConfig)
local PlayerStateService = require(ServerScriptService.GameService.PlayerState.PlayerStateService)

local MatchManager = require(script.Parent.Parent.Match.MatchManager)
local MatchParticipants = require(script.Parent.Parent.Match.MatchParticipants)
local MatchTimeService = require(script.Parent.Parent.MatchTime.MatchTimeService)
local ExitRegistry = require(script.Parent.ExitRegistry)
local ExitState = require(script.Parent.ExitState)

local ExitService = {}

local REQUIRED_SECONDS = ExitConfig.DwellSeconds
local SAMPLE_INTERVAL = ExitConfig.DwellSampleInterval

-- Fires (player, { exitType, atHour }) AFTER the state transition and
-- character removal -- Signal:Fire is deferred, so subscribers must not
-- assume player.Character still exists.
ExitService.Escaped = Signal.new()

-- [userId] = { exitType: string, elapsed: number }
local dwell: { [number]: { exitType: string, elapsed: number } } = {}
-- [userId] = last whole second pushed to that client, so a 4 Hz sample only
-- costs a remote fire when the number on screen actually changes.
local lastSentSecond: { [number]: number } = {}

local heartbeatConnection: RBXScriptConnection? = nil
local accumulator = 0
local dwellRemote: RemoteEvent? = nil

-- Same resolution rule as ExitVisuals: the marker normally sits on the Part
-- itself; a Model carrying it uses its PrimaryPart as the volume.
local function volumePartOf(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	elseif instance:IsA("Model") then
		return instance.PrimaryPart
	end
	return nil
end

-- Object-space containment, so a rotated exit Part still tests correctly --
-- MainExit is authored at Rotation 0,90,0, which a naive world-space AABB
-- would get wrong.
local function isInside(part: BasePart, position: Vector3): boolean
	local localPoint = part.CFrame:PointToObjectSpace(position)
	local half = part.Size * 0.5
	return math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Y) <= half.Y
		and math.abs(localPoint.Z) <= half.Z
end

local function rootPartOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- The open exit this player is standing in, or nil. A locked exit is not a
-- candidate at all, so standing in one accrues nothing.
local function occupiedExitType(player: Player): string?
	local rootPart = rootPartOf(player)
	if not rootPart then
		return nil
	end

	for _, instance in ipairs(ExitRegistry.All()) do
		local exitType = ExitTypes.TypeOf(instance)
		-- Per INSTANCE, not per type: only one of the map's Alternate exits
		-- opens per match, and standing in one of the others must accrue
		-- nothing even while the Alternate requirement is satisfied.
		if exitType and ExitState.IsInstanceAvailable(instance) then
			local part = volumePartOf(instance)
			if part and isInside(part, rootPart.Position) then
				return exitType
			end
		end
	end

	return nil
end

local function pushProgress(player: Player, elapsed: number)
	if not dwellRemote then
		return
	end

	local remaining = math.max(0, REQUIRED_SECONDS - elapsed)
	local whole = math.ceil(remaining)
	if lastSentSecond[player.UserId] == whole then
		return
	end
	lastSentSecond[player.UserId] = whole

	dwellRemote:FireClient(player, {
		remaining = remaining,
		total = REQUIRED_SECONDS,
	})
end

local function clearProgress(player: Player)
	local userId = player.UserId
	if dwell[userId] == nil and lastSentSecond[userId] == nil then
		return
	end

	dwell[userId] = nil
	lastSentSecond[userId] = nil

	if dwellRemote then
		dwellRemote:FireClient(player, nil)
	end
end

-- Mirrors MatchEndCondition.evaluate()'s roster/state correlation --
-- duplicated rather than reused because that module exposes only Start().
local function anyoneCountsAsActive(): boolean
	local allStates = PlayerStateService.GetAll()
	for _, userId in ipairs(MatchParticipants.All()) do
		local state = allStates[userId]
		if state and PlayerStates.CountsAsActive(state) then
			return true
		end
	end
	return false
end

local function escape(player: Player, exitType: string)
	local hour = MatchTimeService.GetHour()
	ExitState.RecordEscape(player.UserId, exitType, hour)

	local ok = PlayerStateService.Set(player, "Escaped", "Exit:" .. exitType)
	if not ok then
		return
	end

	ExitService.Escaped:Fire(player, { exitType = exitType, atHour = hour })

	local character = player.Character
	if character then
		character:Destroy()
	end

	-- No yield since PlayerStateService.Set above -- still the same
	-- uninterrupted resumption, so this beats MatchEndCondition's deferred
	-- handler to the resultCode.
	if not anyoneCountsAsActive() then
		MatchManager.RequestEnd("Extracted")
	end
end

local function sample(delta: number)
	for _, player in ipairs(MatchParticipants.GetPresent()) do
		local userId = player.UserId

		-- Alive-only: an already-escaped, dead, or spectating player is not a
		-- dwell candidate, which is also what stops a second escape.
		if not PlayerStateService.Is(player, "Alive") then
			clearProgress(player)
			continue
		end

		local exitType = occupiedExitType(player)
		if not exitType then
			clearProgress(player)
			continue
		end

		local record = dwell[userId]
		-- Switching exits mid-dwell restarts the count: the two exits are
		-- separate escapes, not a shared progress bar.
		if not record or record.exitType ~= exitType then
			record = { exitType = exitType, elapsed = 0 }
			dwell[userId] = record
			lastSentSecond[userId] = nil
		end

		record.elapsed += delta

		if record.elapsed >= REQUIRED_SECONDS then
			clearProgress(player)
			escape(player, exitType)
		else
			pushProgress(player, record.elapsed)
		end
	end
end

local function startSampling()
	if heartbeatConnection then
		return
	end

	accumulator = 0
	heartbeatConnection = RunService.Heartbeat:Connect(function(delta)
		accumulator += delta
		if accumulator < SAMPLE_INTERVAL then
			return
		end
		local elapsed = accumulator
		accumulator = 0
		sample(elapsed)
	end)
end

local function stopSampling()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end

	for _, player in ipairs(MatchParticipants.GetPresent()) do
		clearProgress(player)
	end

	dwell = {}
	lastSentSecond = {}
end

local started = false

function ExitService.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	-- Resolved once: Remotes.Get does a WaitForChild, and the sample loop and
	-- escape() both have to stay yield-free.
	dwellRemote = Remotes.Get("ExitDwellSync")

	MatchManager.StateChanged:Connect(function(newState: string)
		if newState == "Playing" then
			startSampling()
		else
			stopSampling()
		end
	end)
end

return ExitService
