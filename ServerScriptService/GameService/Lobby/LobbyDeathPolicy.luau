-- Lobby's trivial death policy: Dead -> (new character) -> Alive,
-- immediately, no UI, no spectating, no teleport, no progression write.
-- DeathService/DeathPolicy are Game-Server-only companions; this module
-- binds Humanoid.Died itself since nothing else does that on this place.

local Players = game:GetService("Players")
local PlayerStateService = require(script.Parent.Parent.PlayerState.PlayerStateService)

local LobbyDeathPolicy = {}

local function onCharacterAdded(player: Player)
	if PlayerStateService.Is(player, "Dead") then
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
