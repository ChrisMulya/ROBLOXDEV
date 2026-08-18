-- Mirrors MatchManager's authoritative state onto an attribute on
-- ReplicatedStorage.MatchInfo -- shared, identical-for-everyone state, so it
-- rides an attribute rather than a remote (the ObjectiveReplicator rule).
-- The only match module allowed to touch remotes: on entering Ending, it
-- also builds and sends the per-player MatchResultSync payload (private to
-- each player, so it's a remote rather than an attribute).
--
-- Started after MatchManager in the boot list (publisher before subscriber)
-- so no StateChanged fire is missed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local MatchManager = require(script.Parent.MatchManager)
local MatchParticipants = require(script.Parent.MatchParticipants)
local MatchResultBuilder = require(script.Parent.MatchResultBuilder)
local MatchClock = require(script.Parent.MatchClock)
local MatchLoadingGate = require(script.Parent.MatchLoadingGate)

local MatchReplicator = {}

local function ensureMatchInfoFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild("MatchInfo")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "MatchInfo"
		folder.Parent = ReplicatedStorage
	end
	return folder
end

local started = false

function MatchReplicator.Start()
	if started then
		return
	end
	started = true

	local matchInfo = ensureMatchInfoFolder()
	matchInfo:SetAttribute("MatchState", MatchManager.Get())

	MatchManager.StateChanged:Connect(function(newState: string)
		matchInfo:SetAttribute("MatchState", newState)

		-- Nil, not 0/0 -- a client reading these outside Loading should see
		-- "no such data" rather than a stale count from the match that just
		-- ended, same nil-outside-scope convention as MatchTimeService's
		-- GetHour/GetPhase/GetProgress.
		if newState ~= "Loading" then
			matchInfo:SetAttribute("LoadingReadyCount", nil)
			matchInfo:SetAttribute("LoadingReadyTotal", nil)
		end
	end)

	-- Shared, identical-for-everyone counts -- attributes, not a remote, same
	-- rule as MatchState itself. LoadingController only reads these to
	-- decorate its own status text after a soft-warn threshold; it never
	-- gates the curtain's lift on them, only on MatchState leaving "Loading".
	MatchLoadingGate.ReadyCountChanged:Connect(function(readyCount: number, total: number)
		matchInfo:SetAttribute("LoadingReadyCount", readyCount)
		matchInfo:SetAttribute("LoadingReadyTotal", total)
	end)

	-- Fired by MatchResultBuilder itself once its Ending capture has actually
	-- run -- NOT MatchManager.StateChanged -> "Ending" (a second subscriber
	-- to that same event), which only worked if this one happened to run
	-- after Builder's. See MatchResultBuilder.Captured's own comment.
	MatchResultBuilder.Captured:Connect(function()
		local result = MatchResultBuilder.Build()
		local resultSync = Remotes.Get("MatchResultSync")
		-- Same workspace:GetServerTimeNow()-deadline trick as QueueService's
		-- pad countdown: a timestamp, not a remaining duration, so the
		-- client's per-second tick is pure local subtraction and can't drift.
		--
		-- Read from MatchClock rather than recomputed from EndingHoldSeconds
		-- here: MatchClock is the authority on when Cleanup actually fires,
		-- and computing the same deadline twice let the receipt's countdown
		-- disagree with the real transition. No fallback needed -- the getter
		-- anchors the deadline on first request, so it is correct regardless
		-- of which module asks first.
		local returnsAt = MatchClock.GetEndingDeadline()
		for _, userId in ipairs(MatchParticipants.All()) do
			local player = Players:GetPlayerByUserId(userId)
			if player then
				resultSync:FireClient(player, {
					resultCode = result.resultCode,
					durationSeconds = result.durationSeconds,
					perPlayer = result.perPlayer[userId] or {},
					-- Everyone's slices, for the scoreboard. Not private
					-- data -- it's the same end-of-match summary every
					-- participant sees, same as any match scoreboard.
					roster = result.roster,
					returnsAt = returnsAt,
					-- Tells MatchReceipt which of its sections to show,
					-- rather than inferring from payload shape (the old
					-- "#roster > 1" / "perPlayer.Stats exists" rules guessed
					-- wrong for solo runs). See UI/MatchReceipt.luau.
					variant = "Match",
				})
			end
		end
	end)
end

return MatchReplicator
