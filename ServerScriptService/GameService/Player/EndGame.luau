local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
-- Remotes.Get is a WaitForChild -- kept out of module scope (called inside
-- ClearPlayerTools instead) so a require from a boot list can't hang if
-- something ever requires this before Remotes.Init() has run.
local RewardLedger = require(ServerScriptService.GameService.Reward.RewardLedger)
local ObjectiveService = require(ServerScriptService.GameService.Objective.ObjectiveService)

local RemoveAllSlot = {}

function RemoveAllSlot.ClearPlayerTools(player)
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character

	for _, container in ipairs({backpack, character}) do
		if container then
			for _, item in ipairs(container:GetChildren()) do
				if item:IsA("Tool") then
					item:Destroy()
				end
			end
		end
	end

	player:SetAttribute("KitGiven", false)

	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash then
		cash.Value = 0
	end

	RewardLedger.ResetRunScoped(player) -- Score; XP is persistent and untouched
	ObjectiveService.Reset(player) -- ResetPolicy == "OnRunEnd" objectives only; "Never" ones stay Completed

	Remotes.Get("HideCurrencyUI"):FireClient(player)
end

return RemoveAllSlot