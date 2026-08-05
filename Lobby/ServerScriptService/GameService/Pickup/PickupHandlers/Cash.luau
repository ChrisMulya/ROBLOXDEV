-- The Cash pickup: grants leaderstats.Cash via CashWallet.
--
-- Gated on KitGiven, not just on leaderstats.Cash existing: StartGame sets
-- KitGiven LAST, specifically so a failed camera grant leaves the kit
-- retryable (StartGame.luau). Gating on KitGiven closes the window where an
-- in-flight kit grant could overwrite a pickup's cash with StartingCash a
-- moment after this handler adds to it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MatchStates = require(ReplicatedStorage.Modules.Shared.MatchStates)
local MatchManager = require(ServerScriptService.GameService.Match.MatchManager)
local MatchParticipants = require(ServerScriptService.GameService.Match.MatchParticipants)
local CashWallet = require(ServerScriptService.GameService.Player.CashWallet)

local Cash = {}

Cash.Name = "Cash"

function Cash.CanCollect(player: Player, instance: Instance, typeDef: any): (boolean, string?)
	if not ServerRole.Is("GameServer") then
		return false, "NotInMatch"
	end
	if not MatchStates.IsScoringActive(MatchManager.Get()) then
		return false, "MatchNotActive"
	end
	if not MatchParticipants.IsParticipant(player) then
		return false, "NotInMatch"
	end
	if not player:GetAttribute("KitGiven") then
		return false, "CurrencyNotReady"
	end
	if not CashWallet.Has(player) then
		return false, "CurrencyNotReady"
	end
	return true, nil
end

function Cash.Collect(player: Player, instance: Instance, typeDef: any): (boolean, string?, number?)
	local amount = instance:GetAttribute("PickupAmount")
	if typeof(amount) ~= "number" then
		amount = typeDef.Params.Amount
	end
	if typeof(amount) ~= "number" or amount <= 0 then
		return false, "HandlerFailed", nil
	end

	amount = math.floor(amount)
	local newValue = CashWallet.Add(player, amount)
	if not newValue then
		return false, "CurrencyNotReady", nil
	end

	return true, "Success", amount
end

return Cash
