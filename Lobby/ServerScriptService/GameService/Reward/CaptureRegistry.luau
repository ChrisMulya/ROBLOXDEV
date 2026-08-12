-- Discovery and lifecycle for every capturable instance in workspace (any
-- type registered in Reward/CaptureTargets -- Monster, Objective, and
-- whatever gets added later). The single source of truth for "what can be
-- photographed right now" -- PhotoCapture's broad phase calls All() instead
-- of scanning workspace itself. Modelled on Objective/ObjectiveRegistry.luau,
-- generalized to every CaptureTargets attribute instead of hardcoding
-- IsObjective, per the project rule that CaptureTargets owns attribute names.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CaptureTargets = require(ReplicatedStorage.Modules.Reward.CaptureTargets)

local CaptureRegistry = {}

local watchedAttributes = CaptureTargets.OrderedNames() -- type names; attribute looked up per name below

local live = {} -- [instance] = true
local attributeConnections = {} -- [instance] = { RBXScriptConnection, ... }

local function isLiveCapturable(instance: Instance): boolean
	for _, typeName in ipairs(watchedAttributes) do
		if instance:GetAttribute(CaptureTargets.AttributeFor(typeName)) then
			return true
		end
	end
	return false
end

local function unregister(instance: Instance)
	live[instance] = nil
end

local function register(instance: Instance)
	live[instance] = true
end

local function refresh(instance: Instance)
	if isLiveCapturable(instance) then
		register(instance)
	else
		unregister(instance)
	end
end

-- Watches every registered type's attribute being toggled on/off at runtime
-- (rather than only at discovery time), so an authored-later attribute still
-- registers, and clearing the last one still unregisters.
local function watchAttributes(instance: Instance)
	if attributeConnections[instance] then
		return
	end

	local connections = {}
	for _, typeName in ipairs(watchedAttributes) do
		local attribute = CaptureTargets.AttributeFor(typeName)
		table.insert(
			connections,
			instance:GetAttributeChangedSignal(attribute):Connect(function()
				refresh(instance)
			end)
		)
	end
	attributeConnections[instance] = connections
end

-- Capturable attributes only ever live on a BasePart or a Model (bounding
-- volume math needs GetPivot/GetExtentsSize from one of those). Filtering
-- here keeps the thousands of non-Part/Model descendants of a typical
-- Workspace from getting per-attribute connections at all.
local function considerInstance(instance: Instance)
	if not (instance:IsA("BasePart") or instance:IsA("Model")) then
		return
	end
	watchAttributes(instance)
	refresh(instance)
end

function CaptureRegistry.All(): { Instance }
	local result = {}
	for instance in pairs(live) do
		table.insert(result, instance)
	end
	return result
end

function CaptureRegistry.IsRegistered(instance: Instance): boolean
	return live[instance] == true
end

local function bootstrap()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		considerInstance(descendant)
	end

	workspace.DescendantAdded:Connect(considerInstance)

	workspace.DescendantRemoving:Connect(function(instance)
		local connections = attributeConnections[instance]
		if connections then
			for _, connection in ipairs(connections) do
				connection:Disconnect()
			end
			attributeConnections[instance] = nil
		end
		unregister(instance)
	end)
end

bootstrap()

return CaptureRegistry
