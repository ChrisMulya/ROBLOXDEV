-- Wires MatchReceipt (pure UI) to the MatchResultSync remote. Required from
-- BOTH ClientBootstrap role branches, for its side effects -- MatchReplicator
-- fires MatchResultSync on the Game place (on Ending) and ArrivalService
-- fires it on the Lobby (on arrival with a receipt in TeleportData); this one
-- controller renders either.
--
-- Also hides DeathScreen when the receipt shows: the receipt's DisplayOrder
-- already wins the stacking fight (see UIBuilder.CreateScreenGui), but the
-- match ending genuinely supersedes "you died" as the thing on screen, not
-- just visually -- there's no reason for both to stay toggled on.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MatchReceipt = require(script.Parent.MatchReceipt)
local DeathScreen = require(script.Parent.DeathScreen)

local resultSync = Remotes.Get("MatchResultSync")

-- Return To Lobby only makes sense on the Game place -- the Lobby arrival
-- receipt (fired from ArrivalService's TeleportData, not this remote) has
-- nowhere left to "return" to, so it never gets a handler and the button
-- stays hidden there (see MatchReceipt.Show). ServerRole.Is reads
-- game.PlaceId, which is available client-side same as server-side.
if ServerRole.Is("GameServer") then
	local returnRequest = Remotes.Get("ReturnToLobbyRequest")
	MatchReceipt.SetReturnHandler(function()
		returnRequest:FireServer()
	end)
end

resultSync.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	DeathScreen.Hide()
	MatchReceipt.Show(payload)
end)

return {}
