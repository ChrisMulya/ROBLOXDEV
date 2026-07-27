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

Players.PlayerAdded:Connect(function(player)
	if player.Character then
		bindDeathHandler(player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		bindDeathHandler(player, character)
	end)
end)