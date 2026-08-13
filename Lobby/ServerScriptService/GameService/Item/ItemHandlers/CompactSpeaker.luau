-- Places a PlacedCompactSpeaker at the player's feet, INERT. Runs on the
-- CompactSpeaker tool the player bought; ItemUseService then swaps that tool
-- for CompactSpeakerRemotes (ShopCatalog's ReplaceWith), and using those
-- remotes is what actually arms the thing -- see ItemHandlers/SpeakerRemote
-- and ItemWorld/SpeakerService.
--
-- Deliberately does NOT try to reclaim the remotes when the speaker dies. A
-- player with two slots can be holding two sets of remotes for two speakers,
-- and nothing distinguishes them, so a teardown hook here would consume
-- whichever it found first -- destroying speaker A would eat speaker B's
-- remotes and strand it unfireable. Arming already consumes the remotes on
-- success, and match cleanup clears every tool anyway (KitTeardown), so there
-- is no case left where a live remote outlives its speaker.

local DeployablePlacement = require(script.Parent.Parent.ItemWorld.DeployablePlacement)
local DeployableRegistry = require(script.Parent.Parent.ItemWorld.DeployableRegistry)
local SpeakerService = require(script.Parent.Parent.ItemWorld.SpeakerService)

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

	local record = DeployableRegistry.Register(model, player, "CompactSpeaker")
	SpeakerService.Track(record, effect.Lifetime or 15)

	return true, "Success"
end

return Handler
