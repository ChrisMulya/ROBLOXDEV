-- Generic handler for every Stat-kind item (Energy Drink, Pills, Adrenaline
-- Shot). All three apply one PlayerEffects delta from ShopCatalog's Effect
-- data and differ only in which stat/delta/duration -- one handler reused by
-- id in ItemHandlers/init.luau rather than three near-identical files.

local PlayerEffects = require(script.Parent.Parent.Parent.Player.PlayerEffects)

local StatEffect = {}

function StatEffect.Apply(player: Player, ctx): (boolean, string)
	local effect = ctx.item.Effect
	PlayerEffects.Apply(player, {
		Stat = effect.Stat,
		Delta = effect.Delta,
		Duration = effect.Duration,
		SourceId = ctx.item.Id,
	})
	return true, "Success"
end

return StatEffect
