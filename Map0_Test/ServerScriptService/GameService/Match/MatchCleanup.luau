-- Saves and destroys. Requires no feature system -- systems register into
-- it (R2) via RegisterSaveStep/RegisterTeardownStep, the same shape as
-- RewardService.RegisterContextProvider. Must not teleport (that's
-- ReturnToLobbyService, Phase 8) or compute rewards itself.
--
-- The Ending -> Cleanup hold itself is MatchClock's job (Phase 8) -- this
-- module only reacts once "Cleanup" is actually reached, regardless of what
-- triggered the transition.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local Signal = require(ReplicatedStorage.Modules.Shared.Signal)

local MatchManager = require(script.Parent.MatchManager)

local MatchCleanup = {}

-- Real module field, not a local (Phase 12.5 item 3): RewardStore's own
-- SAVE_CONFIRM_TIMEOUT_SECONDS must stay below this, or RewardCleanupHook's
-- save step gets abandoned before a save can ever confirm (roadmap R-6).
-- RewardCleanupHook.Start() asserts the relationship at boot.
MatchCleanup.STEP_TIMEOUT_SECONDS = 10
local STEP_TIMEOUT_SECONDS = MatchCleanup.STEP_TIMEOUT_SECONDS

-- { {name, fn} }, registration order.
local saveSteps = {}
local teardownSteps = {}
local cleanupStarted = false

MatchCleanup.Finished = Signal.new()

function MatchCleanup.RegisterSaveStep(name: string, fn: () -> boolean)
	if cleanupStarted then
		warn(("MatchCleanup: '%s' tried to register a save step after Cleanup began -- ignored"):format(name))
		return
	end
	table.insert(saveSteps, { name = name, fn = fn })
end

function MatchCleanup.RegisterTeardownStep(name: string, fn: () -> ())
	if cleanupStarted then
		warn(("MatchCleanup: '%s' tried to register a teardown step after Cleanup began -- ignored"):format(name))
		return
	end
	table.insert(teardownSteps, { name = name, fn = fn })
end

-- Runs fn on its own thread and polls for completion rather than blocking on
-- it directly -- one hung save step (a stuck DataStore call) must never
-- block the teleport home for everyone else. A step that times out keeps
-- running in the background; its thread is simply no longer waited on.
local function runWithTimeout(fn: () -> boolean): boolean
	local completed = false
	local ok = false

	task.spawn(function()
		local success, stepResult = pcall(fn)
		ok = success and stepResult ~= false
		completed = true
	end)

	local waited = 0
	while not completed and waited < STEP_TIMEOUT_SECONDS do
		task.wait(0.1)
		waited += 0.1
	end

	if not completed then
		warn("MatchCleanup: a step exceeded its timeout -- proceeding without waiting for it")
	end

	return completed and ok
end

local function runCleanup()
	cleanupStarted = true

	for _, step in ipairs(saveSteps) do
		if not runWithTimeout(step.fn) then
			warn(("MatchCleanup: save step '%s' failed or timed out"):format(step.name))
		end
	end

	for _, step in ipairs(teardownSteps) do
		runWithTimeout(function()
			step.fn()
			return true
		end)
	end

	MatchCleanup.Finished:Fire()
	MatchManager.RequestTransition("Finished", "CleanupComplete")
end

local started = false

function MatchCleanup.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	MatchManager.StateChanged:Connect(function(newState: string)
		if newState == "Cleanup" then
			runCleanup()
		end
	end)
end

return MatchCleanup
