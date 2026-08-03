-- TEMPORARY, Phase 8V only. MatchLauncher has no real caller until Phase 10's
-- QueueService exists, and a live PUBLISHED server has no command bar --
-- every prior phase's verification drove things from Studio's command bar,
-- which cannot reach a real ReserveServer/TeleportAsync round trip at all
-- (G10: HTTP 403 even in Studio Play against a published place). This gives
-- the Phase 8V tester a way to fire MatchLauncher.Launch from inside the
-- actual live game.
--
-- Delete this file (and its GameBoot line) once Phase 10 ships -- QueueService
-- becomes the real caller and this manual trigger has no further purpose.
--
-- Restricted to the place's Creator (chat is public on a live server, and
-- ReserveServer is not free to spam) and single-flight guarded so repeated
-- "/launch" messages can't stack overlapping launches.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MatchLauncher = require(script.Parent.MatchLauncher)

local DebugLaunchTrigger = {}

local LAUNCH_COMMAND = "/launch"

local function isCreator(player: Player): boolean
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	-- Group-owned place: no rank check here (this repo's places are
	-- currently user-owned, per MAINHANDOFF) -- fails closed rather than
	-- guessing a required rank.
	return false
end

local launching = false

local function onChatted(player: Player, message: string)
	if message:lower() ~= LAUNCH_COMMAND then
		return
	end
	if not isCreator(player) then
		return
	end
	if launching then
		warn("DebugLaunchTrigger: launch already in progress, ignoring")
		return
	end

	launching = true
	local ok, code = MatchLauncher.Launch(Players:GetPlayers())
	if not ok then
		warn("DebugLaunchTrigger: MatchLauncher.Launch failed:", code)
	end
	launching = false
end

local started = false

function DebugLaunchTrigger.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertLobbyServer()

	Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(message)
			onChatted(player, message)
		end)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		player.Chatted:Connect(function(message)
			onChatted(player, message)
		end)
	end
end

return DebugLaunchTrigger
