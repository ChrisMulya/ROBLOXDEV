-- Provisions or adopts the ProximityPrompt for a pickup instance, and
-- maintains the prompt -> instance reverse map PickupService needs to
-- resolve a PromptTriggered event in O(1) -- ProximityPromptService fires
-- PromptTriggered for every prompt in the game, including the camera
-- shelf's, so that lookup cannot be an ancestor walk.
--
-- An authored prompt (placed by a designer) wins over a created one -- same
-- convention CameraShelfHandler.legacy.luau assumes for IsCameraShelf parts.

local PickupPrompt = {}

local promptOwner = {} -- [ProximityPrompt] = Instance (the pickup root)
local promptFor = {} -- [Instance] = ProximityPrompt
local createdByUs = {} -- [Instance] = true, so Clear knows whether to Destroy or just release an authored one

local function anchorPartOf(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	elseif instance:IsA("Model") then
		return instance.PrimaryPart
	end
	return nil
end

function PickupPrompt.OwnerOf(prompt: Instance): Instance?
	return promptOwner[prompt]
end

function PickupPrompt.Provision(instance: Instance, typeDef: any)
	if promptFor[instance] then
		return
	end

	local part = anchorPartOf(instance)
	if not part then
		warn(("PickupPrompt: %s has no BasePart to attach a ProximityPrompt to"):format(instance:GetFullName()))
		return
	end

	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	local authored = prompt ~= nil
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = part
		createdByUs[instance] = true
	end

	if not authored then
		local promptConfig = typeDef.Prompt
		prompt.ActionText = promptConfig.ActionText
		prompt.ObjectText = promptConfig.ObjectText
		prompt.HoldDuration = promptConfig.HoldDuration
		prompt.MaxActivationDistance = promptConfig.MaxActivationDistance
		prompt.RequiresLineOfSight = promptConfig.RequiresLineOfSight
	end

	promptFor[instance] = prompt
	promptOwner[prompt] = instance
end

function PickupPrompt.Enable(instance: Instance)
	local prompt = promptFor[instance]
	if prompt then
		prompt.Enabled = true
	end
end

function PickupPrompt.Disable(instance: Instance)
	local prompt = promptFor[instance]
	if prompt then
		prompt.Enabled = false
	end
end

-- Releases bookkeeping for instance's prompt. Destroys it only if this
-- module created it -- an authored prompt is the designer's instance to own.
function PickupPrompt.Clear(instance: Instance)
	local prompt = promptFor[instance]
	if not prompt then
		return
	end

	promptOwner[prompt] = nil
	promptFor[instance] = nil

	if createdByUs[instance] then
		createdByUs[instance] = nil
		if prompt.Parent then
			prompt:Destroy()
		end
	end
end

return PickupPrompt
