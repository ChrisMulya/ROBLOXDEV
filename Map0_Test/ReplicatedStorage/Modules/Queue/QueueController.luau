-- Wires QueueHud to the server's QueueRequest/QueueResult/QueueStateSync
-- remotes. Lobby only -- required from ClientBootstrap's Lobby branch for
-- its side effects, same pattern as SpectateController on the Game branch.
--
-- QueueStateSync only ever targets players currently IN the queue (see
-- QueueService.syncQueuedPlayers) -- a successful Leave removes the player
-- before that sync runs, so no further QueueStateSync will ever arrive
-- telling the client "you're not queued anymore". This controller tracks
-- its own last-sent action and infers the cleared state locally on an "Ok"
-- Leave result instead of waiting for a sync that isn't coming.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local QueueResultCodes = require(ReplicatedStorage.Modules.Shared.QueueResultCodes)
local QueueHud = require(script.Parent.QueueHud)

local lastAction: string? = nil

QueueHud.SetActionHandler(function(action: string)
	lastAction = action
	Remotes.Get("QueueRequest"):FireServer({ action = action })
end)

Remotes.Get("QueueResult").OnClientEvent:Connect(function(code: string)
	-- Leave succeeding is the one outcome no later QueueStateSync will ever
	-- confirm (see file header) -- everything else (Join succeeding, any
	-- failure) either gets corrected by the next sync or must not touch the
	-- queued/button state at all (e.g. "AlreadyQueued" means the player IS
	-- queued; flipping the button to "Join Queue" would be wrong).
	if code == "Ok" and lastAction == "Leave" then
		QueueHud.Update({ queued = false, position = nil, size = 0 })
		return
	end

	QueueHud.SetMessage(QueueResultCodes.GetMessage(code))
end)

Remotes.Get("QueueStateSync").OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	QueueHud.Update({
		queued = payload.position ~= nil,
		position = payload.position,
		size = payload.size or 0,
	})
end)

QueueHud.Show()

return {}
