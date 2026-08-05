-- The missing "grant money" API. PlayerCurrency.legacy.luau owns CREATING
-- the leaderstats.Cash IntValue; this module owns CHANGING it. Cash's
-- per-life semantics (StartGame sets it to PlayerStats.StartingCash on kit
-- grant, EndGame zeroes it on death/match end) are untouched and stay owned
-- by those two files -- this module does not change when or whether Cash
-- resets, only how something other than the shop debits/credits it.
--
-- ShopFillSlot.luau's existing `cash.Value -= price` is a separate, already-
-- working write path and is intentionally not migrated onto this module.

local CashWallet = {}

local function findCash(player: Player): IntValue?
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	return cash :: IntValue?
end

function CashWallet.Get(player: Player): number?
	local cash = findCash(player)
	return cash and cash.Value
end

function CashWallet.Has(player: Player): boolean
	return findCash(player) ~= nil
end

-- Returns the new value, or nil if the player has no wallet yet (e.g. the
-- kit hasn't been granted). Clamps at 0 -- a negative amount can't put a
-- player's cash below zero through this API.
function CashWallet.Add(player: Player, amount: number): number?
	local cash = findCash(player)
	if not cash then
		return nil
	end
	cash.Value = math.max(0, cash.Value + amount)
	return cash.Value
end

return CashWallet
