-- Lobby's trivial death policy: Dead -> (new character) -> Alive,
-- immediately, no UI, no spectating, no teleport, no progression write.
-- DeathService/DeathPolicy are Game-Server-only companions; this module
-- binds Humanoid.Died itself since nothing else does that on this place.
--
-- Also tears the kit down on death -- absorbed from the now-deleted
-- PlayerStateHandler.legacy.luau, which bound its own independent
-- Humanoid.Died listener for exactly this on both places. The Game place's
-- equivalent now lives in KitLifecycleHook instead.

local Players = game:GetService("Players")
local PlayerStateService = require(script.Parent.Parent.PlayerState.PlayerStateService)
local RemoveAllSlot = require(script.Parent.Parent.Player.EndGame)

local LobbyDeathPolicy = {}

local function onCharacterAdded(player: Player)
	-- Disconnected alongside Dead: a player who left and rejoined THIS same
	-- Lobby server lands here still marked Disconnected (PlayerStateService
	-- retains that entry on PlayerRemoving by design -- see its own header --
	-- and nothing else on the Lobby ever moves them back to Alive). Both are
	-- legal transitions to Alive (PlayerStates.Transitions), and a spawned
	-- character is unambiguously alive either way.
	if PlayerStateService.Is(player, "Dead") or PlayerStateService.Is(player, "Disconnected") then
		PlayerStateService.Set(player, "Alive", "CharacterAdded")
	end
end

local function bindCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then
		return
	end
	humanoid.Died:Connect(function()
		PlayerStateService.Set(player, "Dead", "HumanoidDied")
		-- Destroys the tools from Backpack and character AND clears KitGiven.
		-- This used to only flip the attribute, which left a dead player's
		-- tools sitting in their Backpack. Same call the Game place's
		-- KitLifecycleHook makes -- one rule for what death does to a kit.
		RemoveAllSlot.ClearPlayerTools(player)
		player:LoadCharacter()
	end)
end

local started = false

function LobbyDeathPolicy.Start()
	if started then
		return
	end
	started = true

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player)
			bindCharacter(player, character)
		end)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player)
			bindCharacter(player, character)
		end)
		if player.Character then
			bindCharacter(player, player.Character)
		end
	end
end

return LobbyDeathPolicy
