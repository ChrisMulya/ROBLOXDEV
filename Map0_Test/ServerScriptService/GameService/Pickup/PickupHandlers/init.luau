-- Name -> handler module dispatch. Adding a pickup kind is one require here
-- plus one row in PickupTypes.Types -- nothing else in the Pickup system
-- changes. Shape of Flash/FlashRenderers/init.luau's registration table.
--
-- Handler contract (both non-yielding -- see PickupService for why):
--   Handler.Name: string
--   Handler.CanCollect(player, instance, typeDef) -> (boolean, code: string?)
--   Handler.Collect(player, instance, typeDef) -> (boolean, code: string?, amount: number?)

local PickupHandlers = {}

local handlers = {
	Cash = require(script.Cash),
	Document = require(script.Document),
}

function PickupHandlers.Get(name: string)
	return handlers[name]
end

return PickupHandlers
