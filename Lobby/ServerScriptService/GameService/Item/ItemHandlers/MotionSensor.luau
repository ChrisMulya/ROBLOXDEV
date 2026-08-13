-- Places a PlacedMotionSensor at the player's feet and hands it to
-- MotionSensorService for detection. World object, not a Tool -- the used
-- MotionSensor Tool is consumed by ItemUseService same as every other item.

local DeployablePlacement = require(script.Parent.Parent.ItemWorld.DeployablePlacement)
local DeployableRegistry = require(script.Parent.Parent.ItemWorld.DeployableRegistry)
local MotionSensorService = require(script.Parent.Parent.ItemWorld.MotionSensorService)

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

	local record = DeployableRegistry.Register(model, player, "MotionSensor")
	MotionSensorService.Track(record, effect.DetectRadius or 35)

	return true, "Success"
end

return Handler
