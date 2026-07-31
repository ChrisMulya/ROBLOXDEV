-- Wires MatchReceipt (pure UI) to the MatchResultSync remote. Required from
-- BOTH ClientBootstrap role branches, for its side effects -- MatchReplicator
-- fires MatchResultSync on the Game place (on Ending) and ArrivalService
-- fires it on the Lobby (on arrival with a receipt in TeleportData); this one
-- controller renders either.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local MatchReceipt = require(script.Parent.MatchReceipt)

local resultSync = Remotes.Get("MatchResultSync")

resultSync.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	MatchReceipt.Show(payload)
end)

return {}
