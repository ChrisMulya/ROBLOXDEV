-- Discovery and lifecycle for every IsObjective instance in workspace. The
-- single source of truth for "what objectives exist" -- consumers call
-- All()/IsRegistered() rather than scanning workspace themselves.

local ObjectiveRegistry = {}

local live = {} -- [instance] = true
local attributeConnections = {} -- [instance] = RBXScriptConnection

local function unregister(instance: Instance)
	live[instance] = nil
end

local function register(instance: Instance)
	live[instance] = true
end

-- Watches IsObjective being toggled on/off at runtime (rather than only at
-- discovery time), so an authored-later attribute still registers.
local function watchAttribute(instance: Instance)
	if attributeConnections[instance] then
		return
	end
	attributeConnections[instance] = instance:GetAttributeChangedSignal("IsObjective"):Connect(function()
		if instance:GetAttribute("IsObjective") then
			register(instance)
		else
			unregister(instance)
		end
	end)
end

-- IsObjective only ever lives on a BasePart or a Model (Resolve/GetPivot both
-- need one of those). Filtering here means the thousands of non-Part/Model
-- descendants of a typical Workspace (Scripts, Attachments, Motor6Ds,
-- Animations, Decals, ...) never get an attribute-changed connection at all,
-- instead of one per descendant regardless of class.
local function considerInstance(instance: Instance)
	if not (instance:IsA("BasePart") or instance:IsA("Model")) then
		return
	end
	watchAttribute(instance)
	if instance:GetAttribute("IsObjective") then
		register(instance)
	end
end

function ObjectiveRegistry.All(): { Instance }
	local result = {}
	for instance in pairs(live) do
		table.insert(result, instance)
	end
	return result
end

function ObjectiveRegistry.IsRegistered(instance: Instance): boolean
	return live[instance] == true
end

local function bootstrap()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		considerInstance(descendant)
	end

	workspace.DescendantAdded:Connect(considerInstance)

	workspace.DescendantRemoving:Connect(function(instance)
		local connection = attributeConnections[instance]
		if connection then
			connection:Disconnect()
			attributeConnections[instance] = nil
		end
		unregister(instance)
	end)
end

bootstrap()

return ObjectiveRegistry
