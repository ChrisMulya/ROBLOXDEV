-- Routes the server's QueueResult codes into QueueHud. Lobby only -- required
-- from ClientBootstrap's Lobby branch for its side effects, same pattern as
-- SpectateController on the Game branch.
--
-- One-way now. The client no longer initiates anything: queueing is entered by
-- standing on a pad, and occupancy/countdown arrive as replicated pad
-- attributes rendered by QueuePadDisplay. The old lastAction bookkeeping
-- existed solely to infer the cleared state after a client-initiated Leave,
-- which no longer exists.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local QueueResultCodes = require(ReplicatedStorage.Modules.Shared.QueueResultCodes)
local QueueHud = require(script.Parent.QueueHud)

Remotes.Get("QueueResult").OnClientEvent:Connect(function(code: string)
	QueueHud.SetMessage(QueueResultCodes.GetMessage(code))
end)

return {}
