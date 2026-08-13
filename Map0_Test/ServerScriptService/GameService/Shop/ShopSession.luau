-- Shared "is the Shop open for this player, and on which part" state.
-- A ModuleScript rather than living inside ShopPromptService because both
-- ShopPromptService.legacy.luau (writer) and BuyHandler.legacy.luau (reader)
-- are Scripts -- Scripts can't be require()'d, so the shared state needs its
-- own requirable home.

local ShopSession = {}

-- userId -> the shop BasePart currently open for that player.
local openFor: { [number]: BasePart } = {}

function ShopSession.Open(player: Player, part: BasePart)
	openFor[player.UserId] = part
end

function ShopSession.Close(player: Player)
	openFor[player.UserId] = nil
end

-- Returns the part the player's Shop UI is open against, or nil if it isn't
-- open (or the part it was opened against has since been destroyed).
function ShopSession.GetOpenPart(player: Player): BasePart?
	local part = openFor[player.UserId]
	if part and not part.Parent then
		openFor[player.UserId] = nil
		return nil
	end
	return part
end

function ShopSession.IsOpen(player: Player): boolean
	return ShopSession.GetOpenPart(player) ~= nil
end

-- For ShopPromptService's distance sweep only.
function ShopSession.GetAll(): { [number]: BasePart }
	return openFor
end

return ShopSession
