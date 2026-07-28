local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local RewardLedger = require(ServerScriptService.GameService.Reward.RewardLedger)

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