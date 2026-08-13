-- The only thing that destroys a used support-item Tool. Reverts the slot to
-- exactly the same IsEmpty placeholder StartGameService grants at kit time,
-- via StartGameService.CreateEmptySlot -- not a second hand-rolled copy of
-- it -- so a consumed item and a freshly-granted empty slot are
-- indistinguishable, and ShopFillSlot's existing AlreadyOwned/NoSlot checks
-- keep working with zero changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConsumption = {}

local StartGameService = require(script.Parent.Parent.Player.StartGame)
local ShopCatalog = require(ReplicatedStorage.Modules.Shop.ShopCatalog)

-- Which container a Tool currently lives in, preserving equipped-ness the
-- same way ShopFillSlot.PurchaseItem and CameraInventory.Give already do: a
-- Tool parented to the Character is equipped, one in the Backpack is not, and
-- a swap must not silently unequip what the player was holding.
local function containerOf(player: Player, tool: Tool): Instance?
	if player.Character and tool.Parent == player.Character then
		return player.Character
	end
	return player:FindFirstChild("Backpack")
end

function ItemConsumption.ConsumeTool(player: Player, tool: Tool)
	if not tool or not tool.Parent then
		return
	end

	local slotName = tool.Name
	local container = containerOf(player, tool)

	tool:Destroy()

	if not container then
		return
	end

	local placeholder = StartGameService.CreateEmptySlot(slotName)
	placeholder.Parent = container
end

-- Swaps a used Tool for a different catalog item in the SAME slot: Compact
-- Speaker becomes its remotes, Portable CCTV becomes its tablet. The player
-- buys the deployable and is left holding its controller, rather than buying
-- the controller directly.
--
-- Clone-then-destroy, never the reverse -- the same "nothing below this point
-- may fail" ordering ShopFillSlot.PurchaseItem uses, so a missing replacement
-- asset leaves the player holding the original item instead of an empty slot.
function ItemConsumption.ReplaceTool(player: Player, tool: Tool, replacementItemId: string): boolean
	if not tool or not tool.Parent then
		return false
	end

	local replacement = ShopCatalog.Get(replacementItemId)
	local template = replacement and ShopCatalog.ResolveTemplate(replacementItemId)
	if not template then
		warn("ItemConsumption: no Tool asset for replacement item", replacementItemId)
		return false
	end

	local container = containerOf(player, tool)
	if not container then
		return false
	end

	local slotName = tool.Name
	local newTool = template:Clone()
	newTool.Name = slotName
	newTool:SetAttribute("ItemId", replacement.Id)

	tool:Destroy()
	newTool.Parent = container
	return true
end

return ItemConsumption
