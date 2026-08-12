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
local MatchDifficulty = require(ReplicatedStorage.Modules.Shared.MatchDifficulty)
local SpawnMath = require(ReplicatedStorage.Modules.Shared.SpawnMath)
local MatchManager = require(ServerScriptService.GameService.Match.MatchManager)
local MatchParticipants = require(ServerScriptService.GameService.Match.MatchParticipants)
local MatchSettings = require(ServerScriptService.GameService.Match.MatchSettings)
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

	-- TryGet, not Get: this runs inside PickupService's claim window, which is
	-- not pcalled and has already set claimed[instance] and disabled the
	-- prompt. An assert here would escape before that module's un-claim path
	-- and brick the pickup for the rest of the match. Returning HandlerFailed
	-- instead reuses the recovery PickupService already has for a bad amount.
	-- Unreachable in practice -- CanCollect gates on Playing, which is strictly
	-- downstream of MatchArrival's Capture() -- but the failure mode is bad
	-- enough to not rely on that.
	local settings = MatchSettings.TryGet()
	if not settings then
		warn("Cash.Collect: MatchSettings not captured -- refusing to grant rather than guess a multiplier")
		return false, "HandlerFailed", nil
	end

	-- Roster-size devaluation of VALUE only -- never touches how many Cash
	-- pickups were selected to spawn (that's SpawnSelection/MatchDifficulty.
	-- SpawnFraction.Cash, driven by PlayerScaling.Cash = 0 so it never scales).
	-- math.max(1, ...) after the multiply, not just after the raw amount,
	-- because a small authored PickupAmount override could otherwise floor to
	-- 0 under a heavy multiplier and become an uncollectable pickup that looks
	-- collectable (Cash.CanCollect already passed).
	local scaling = MatchDifficulty.CashRewardScaling
	local multiplier = SpawnMath.CashRewardMultiplier(settings.playerCount, scaling.PerExtraPlayer, scaling.Floor)
	amount = math.max(1, math.floor(amount * multiplier))
	local newValue = CashWallet.Add(player, amount)
	if not newValue then
		return false, "CurrencyNotReady", nil
	end

	return true, "Success", amount
end

return Cash
