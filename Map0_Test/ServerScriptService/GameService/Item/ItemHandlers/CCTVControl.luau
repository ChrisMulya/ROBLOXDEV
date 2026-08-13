-- The PortableCCTVTablet the player is left holding after placing a Portable
-- CCTV. Control-kind: an instant toggle of the placed camera's view, no hold
-- (ItemUseService dispatches this without opening a session at all).
--
-- Placement lives in ItemHandlers/PortableCCTV -- that runs once, on the
-- ORIGINAL PortableCCTV tool, and is what swaps the tool for this tablet.

local CCTVService = require(script.Parent.Parent.ItemWorld.CCTVService)

local Handler = {}

function Handler.Apply(player: Player, _ctx): (boolean, string)
	-- False means this player has no placed CCTV to look through -- the
	-- camera was destroyed (match end) while the tablet outlived it.
	if not CCTVService.TryToggle(player) then
		return false, "NoCamera"
	end
	return true, "Success"
end

return Handler
