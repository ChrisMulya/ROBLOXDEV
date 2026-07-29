-- ServerScriptService/GameService/PlayerLifecycleHandler (Script)
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local StartGameService = require(game.ServerScriptService.GameService.Player.StartGame)

local function bindDeathHandler(player, character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		StartGameService.ResetKit(player)
	end)
end

local function onPlayerAdded(player)
	if player.Character then
		bindDeathHandler(player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		bindDeathHandler(player, character)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- Catches any player who joined before this Connect call executed --
-- otherwise that player's character never gets a death handler, silently.
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end