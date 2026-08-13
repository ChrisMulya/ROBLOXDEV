-- Places a PlacedPortableCCTV at the player's feet, inert -- the feed does
-- NOT open here. Runs on the PortableCCTV tool the player bought;
-- ItemUseService then swaps that tool for PortableCCTVTablet (ShopCatalog's
-- ReplaceWith), and clicking the tablet is what opens, and shuts, the view
-- (see ItemHandlers/CCTVControl and ItemWorld/CCTVService).

local DeployablePlacement = require(script.Parent.Parent.ItemWorld.DeployablePlacement)
local DeployableRegistry = require(script.Parent.Parent.ItemWorld.DeployableRegistry)
local CCTVService = require(script.Parent.Parent.ItemWorld.CCTVService)

local Handler = {}

function Handler.Apply(player: Player, ctx): (boolean, string)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return false, "NoCharacter"
	end

	local groundPos = DeployablePlacement.Probe(rootPart)
	if not groundPos then
		return false, "NoGround"
	end

	local effect = ctx.item.Effect
	local model = DeployablePlacement.Place(effect.PlacedAsset, groundPos)
	if not model then
		return false, "Failed"
	end

	local record = DeployableRegistry.Register(model, player, "PortableCCTV")
	CCTVService.Place(record, player)

	return true, "Success"
end

return Handler
