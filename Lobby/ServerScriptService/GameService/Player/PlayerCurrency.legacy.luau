local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local RewardLedger = require(ServerScriptService.GameService.Reward.RewardLedger)
-- ObjectiveService/ObjectiveReplicator boot from GameService/Bootstrap.legacy.luau now --
-- this file no longer doubles as their hidden keystone.

-- Cash stays hand-built here rather than as a RewardType: it's spent (not
-- earned via the camera), so RewardCalculator/RewardService have no reason
-- to own it. RewardLedger.SetupPlayer creates the leaderstats folder and the
-- XP/Score values; Cash is added into that same folder.
--
-- SetupPlayer must not yield -- it defers its DataStore load to another
-- thread precisely so leaderstats is fully populated within this handler.
-- If that ever changes, `leaderstats` here would briefly exist without Cash
-- and StartGame's `leaderstats:FindFirstChild("Cash")` would silently miss.
local function onPlayerAdded(player)
	RewardLedger.SetupPlayer(player)

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		warn("PlayerCurrency: leaderstats missing for", player.Name, "- Cash not created")
		return
	end

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 0
	cash.Parent = leaderstats
end

local function onPlayerRemoving(player)
	RewardLedger.TeardownPlayer(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Catches any player who joined in the window between server start and the
-- Connect call above (e.g. a require earlier in this script's chain yielded).
-- Without this, that player permanently gets no leaderstats/Cash.
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end