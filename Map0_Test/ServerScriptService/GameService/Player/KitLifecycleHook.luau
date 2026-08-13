-- Grants/tears down the starter kit across the match lifecycle by calling
-- into the existing StartGame/EndGame lifecycle -- neither is rewritten,
-- this just supplies the trigger neither had (both had zero in-code callers
-- otherwise; MAINHANDOFF "Half-built / not wired").
--
-- Grant fires on CharacterAdded, not a state transition -- the Backpack is
-- recreated on every character load, so a grant tied to a transition would
-- be silently destroyed by any later respawn. Gated by MatchStates.KitGranted
-- so it only fires while the match is actually in a kit-appropriate state.
--
-- A feature-layer module requiring DOWN into the Match layer (MatchManager,
-- MatchParticipants, MatchCleanup) -- must not live in Match/, since it also
-- requires StartGame/EndGame, which Match-layer modules must never touch (R2).
--
-- Absorbs PlayerStateHandler.legacy.luau's Humanoid.Died -> kit teardown
-- behavior for this place -- that Script is deleted (see MAINHANDOFF); the
-- Lobby's equivalent now lives in LobbyDeathPolicy instead.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MatchStates = require(ReplicatedStorage.Modules.Shared.MatchStates)
local MatchManager = require(script.Parent.Parent.Match.MatchManager)
local MatchParticipants = require(script.Parent.Parent.Match.MatchParticipants)
local MatchCleanup = require(script.Parent.Parent.Match.MatchCleanup)
local StartGameService = require(script.Parent.StartGame)
local RemoveAllSlot = require(script.Parent.EndGame)

local KitLifecycleHook = {}

local function onCharacterAdded(player: Player, character: Model)
	if not MatchParticipants.IsParticipant(player) then
		return
	end
	if not MatchStates.IsKitGranted(MatchManager.Get()) then
		return
	end

	-- Died is bound BEFORE the grant, not after: GivePlayerStarterKit yields
	-- now (it waits for the Backpack and verifies the grant survived the
	-- spawn's Backpack swap), and a teardown listener attached only after that
	-- returns would miss a death during the wait.
	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid then
		humanoid.Died:Connect(function()
			-- Destroys the tools from both Backpack and character AND clears
			-- KitGiven. This used to only flip the attribute, which left the
			-- dead player's tools sitting in their Backpack through the whole
			-- spectate session. The respawn re-grant path
			-- (onCharacterAdded -> GivePlayerStarterKit) is unchanged.
			RemoveAllSlot.ClearPlayerTools(player)
		end)
	end

	StartGameService.GivePlayerStarterKit(player)
end

local started = false

function KitLifecycleHook.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end)

	-- Backfill players/characters that already exist before Start() ran.
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			onCharacterAdded(player, player.Character)
		end
	end

	-- Covers the reverse ordering: a participant whose character already
	-- existed BEFORE MatchParticipants.Seed ran (a Studio Play-test timing
	-- quirk MatchParticipants/MatchArrival's own comments already flag) would
	-- otherwise never get a fresh CharacterAdded to react to, since
	-- MatchSpawner's loadIfNeeded no-ops when a Character is already present.
	MatchParticipants.Joined:Connect(function(player: Player)
		if player.Character then
			onCharacterAdded(player, player.Character)
		end
	end)

	MatchCleanup.RegisterTeardownStep("KitTeardown", function()
		for _, player in ipairs(MatchParticipants.GetPresent()) do
			RemoveAllSlot.ClearPlayerTools(player)
		end
	end)
end

return KitLifecycleHook
