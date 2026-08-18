-- Wiring for the match loading curtain -- LoadingHud renders, this decides
-- what to render and when. Four client stages (replication, asset preload,
-- local character/camera, server handshake) followed by a single report to
-- the server (MatchClientReady) and a wait for the server's own verdict
-- (MatchInfo.MatchState leaving "Loading"). The client never decides gameplay
-- may start on its own opinion -- see MatchLoadingGate, the server-side
-- authority this hands off to.
--
-- Runs at module scope on require, same convention as every other
-- ClientBootstrap-required controller (DeathScreenController et al. -- no
-- caller ever calls a .Start() on these). Required first in ClientBootstrap's
-- Game branch so ControlLock.Acquire lands before any other controller could
-- plausibly Release it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local ControlLock = require(ReplicatedStorage.Modules.Shared.ControlLock)
local LoadingManifest = require(ReplicatedStorage.Modules.Shared.LoadingManifest)
local LoadingHud = require(script.Parent.LoadingHud)

local LOCK_REASON = "MatchLoading"
local REMOTE_WAIT_TIMEOUT = 15 -- stage A's own deadline; Remotes.Get itself never times out
local CHARACTER_WAIT_TIMEOUT = 10
local SOFT_WARN_SECONDS = 20
-- LoadingTimeout (45s, MatchConfig) + slack for the round trip and the fade,
-- so a slow-but-succeeding match doesn't flash the failure panel right as it
-- resolves. Not read from MatchConfig directly -- the client has no
-- replicated mode id to key it with, and this is cosmetic pacing, not a
-- correctness boundary.
local HARD_WATCHDOG_SECONDS = 60
-- Floor so a same-frame local ready report can't strobe the curtain. Mirrors
-- MatchConfig.Modes.Default.LoadingMinSeconds -- kept as a local constant for
-- the same reason as HARD_WATCHDOG_SECONDS above.
local LOADING_MIN_SECONDS = 0.5

local player = Players.LocalPlayer

-- Bounded WaitForChild -- Remotes.Get/ReplicatedStorage:WaitForChild never
-- time out, which is fine for gameplay code that can afford to hang until a
-- module is fixed, but wrong here: a missing Remotes folder or MatchInfo
-- folder must degrade the curtain, never freeze it.
local function waitForChildTimeout(parent: Instance, name: string, timeout: number): Instance?
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end

	local found: Instance? = nil
	local conn = parent.ChildAdded:Connect(function(child)
		if child.Name == name then
			found = child
		end
	end)

	local waited = 0
	while not found and waited < timeout do
		task.wait(0.1)
		waited += 0.1
	end
	conn:Disconnect()
	return found
end

-- Stage A: replication. Indeterminate -- there is no denominator for "has
-- ReplicatedStorage finished streaming".
local function runStageA(): Instance?
	LoadingHud.SetStage("Connecting...")

	local remotesFolder = waitForChildTimeout(ReplicatedStorage, "Remotes", REMOTE_WAIT_TIMEOUT)
	if not remotesFolder then
		warn("LoadingController: Remotes folder never replicated within timeout -- continuing anyway")
	elseif not waitForChildTimeout(remotesFolder, "MatchClientReady", REMOTE_WAIT_TIMEOUT) then
		warn("LoadingController: MatchClientReady remote never replicated within timeout -- continuing anyway")
	end

	local matchInfo = waitForChildTimeout(ReplicatedStorage, "MatchInfo", REMOTE_WAIT_TIMEOUT)
	if not matchInfo then
		warn("LoadingController: MatchInfo folder never replicated within timeout -- continuing anyway")
	end

	return matchInfo
end

-- Stage B: asset preload. The one stage with a real denominator, so the one
-- stage that gets a real percentage -- see LoadingManifest for what's in the
-- list and why. A failed asset is counted and warned, never fatal: a missing
-- Assets subtree is an already-documented normal condition (ShopCatalog).
local function runStageB()
	local ok, manifest = pcall(LoadingManifest.Collect)
	if not ok then
		warn("LoadingController: LoadingManifest.Collect failed:", manifest)
		LoadingHud.SetStage("Loading assets...", 1)
		return
	end

	local total = #manifest
	if total == 0 then
		LoadingHud.SetStage("Loading assets...", 1)
		return
	end

	local completed = 0
	local failed = 0
	LoadingHud.SetStage(("Loading assets...  %d / %d"):format(0, total), 0)

	ContentProvider:PreloadAsync(manifest, function(_contentId, status)
		completed += 1
		if status == Enum.AssetFetchStatus.Failure then
			failed += 1
		end
		LoadingHud.SetStage(("Loading assets...  %d / %d"):format(completed, total), completed / total)
	end)

	if failed > 0 then
		warn(("LoadingController: %d/%d preload entries failed -- continuing anyway"):format(failed, total))
	end
end

-- Stage C: local character + camera. MatchSpawner (server) loads the
-- character during Loading specifically so this can happen under the
-- curtain -- see MatchStates.Loading.KitGranted/AcceptsJoins and
-- MatchSpawner's own header. Never caches Workspace.CurrentCamera (G12).
local function runStageC()
	LoadingHud.SetStage("Preparing...")

	local character = player.Character
	if not character then
		local ok = pcall(function()
			character = player.CharacterAdded:Wait()
		end)
		if not ok then
			return
		end
	end

	character:WaitForChild("Humanoid", CHARACTER_WAIT_TIMEOUT)
	character:WaitForChild("HumanoidRootPart", CHARACTER_WAIT_TIMEOUT)

	local waited = 0
	while not Workspace.CurrentCamera and waited < 5 do
		task.wait(0.1)
		waited += 0.1
	end
end

-- Stage D: server handshake. Event-driven, not polled -- the curtain lifts
-- on the replicated MatchState attribute leaving "Loading", never on the
-- client's own opinion that it's done. After SOFT_WARN_SECONDS, decorates the
-- status with the replicated ready count so a genuinely slow match doesn't
-- look frozen.
local function runStageD(matchInfo: Instance?)
	LoadingHud.SetStage("Waiting for players...")
	LoadingHud.SetSubtext("")

	if not matchInfo or matchInfo:GetAttribute("MatchState") ~= "Loading" then
		return
	end

	local softWarned = false
	local function refreshSubtext()
		if not softWarned then
			return
		end
		local ready = matchInfo:GetAttribute("LoadingReadyCount")
		local total = matchInfo:GetAttribute("LoadingReadyTotal")
		if ready and total then
			LoadingHud.SetSubtext(("Still loading...  (%d of %d ready)"):format(ready, total))
		else
			LoadingHud.SetSubtext("Still loading...")
		end
	end

	task.delay(SOFT_WARN_SECONDS, function()
		if matchInfo:GetAttribute("MatchState") == "Loading" then
			softWarned = true
			refreshSubtext()
		end
	end)

	local readyConn = matchInfo:GetAttributeChangedSignal("LoadingReadyCount"):Connect(refreshSubtext)

	while matchInfo:GetAttribute("MatchState") == "Loading" do
		matchInfo:GetAttributeChangedSignal("MatchState"):Wait()
	end

	readyConn:Disconnect()
end

-- Independent of the stage sequence above: fires once at HARD_WATCHDOG_SECONDS
-- if the whole sequence hasn't finished by then, and gives the player an
-- escape (ReturnToLobbyRequest -- Loading is now in ALLOWED_RETURN_STATES)
-- without aborting the stages still running in the background, in case the
-- match resolves a moment later anyway.
local function armHardWatchdog(isFinished: () -> boolean)
	task.delay(HARD_WATCHDOG_SECONDS, function()
		if isFinished() then
			return
		end
		LoadingHud.ShowFailure(
			"Loading is taking much longer than expected. You can keep waiting, or return to the lobby.",
			function()
				local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
				local remote = remotesFolder and remotesFolder:FindFirstChild("ReturnToLobbyRequest")
				if remote then
					remote:FireServer()
				end
			end
		)
	end)
end

local function main()
	if ServerRole.Is("LobbyServer") then
		-- The Lobby provisions this curtain purely to keep ReplicatedFirst
		-- identical across trees -- nothing there ever gates on it.
		LoadingHud.HideInstant()
		return
	end

	ServerRole.AssertGameServer()

	local startClock = os.clock()
	local finished = false

	ControlLock.Acquire(LOCK_REASON)
	LoadingHud.Show()
	armHardWatchdog(function()
		return finished
	end)

	local matchInfo = runStageA()
	runStageB()
	runStageC()

	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	local readyRemote = remotesFolder and remotesFolder:FindFirstChild("MatchClientReady")
	if readyRemote then
		readyRemote:FireServer()
	else
		warn("LoadingController: could not fire MatchClientReady -- relying on the server's LoadingTimeout")
	end

	runStageD(matchInfo)

	finished = true

	local elapsed = os.clock() - startClock
	local floorRemaining = LOADING_MIN_SECONDS - elapsed
	if floorRemaining > 0 then
		task.wait(floorRemaining)
	end

	LoadingHud.FadeOut(0.5, function()
		ControlLock.Release(LOCK_REASON)
	end)
end

-- Runs in its own thread rather than inline: the sequence yields repeatedly
-- (WaitForChild, PreloadAsync, Wait), and requiring this module must return
-- immediately so the rest of ClientBootstrap's Game branch keeps loading
-- alongside the curtain instead of blocking behind it.
task.spawn(main)

return {}
