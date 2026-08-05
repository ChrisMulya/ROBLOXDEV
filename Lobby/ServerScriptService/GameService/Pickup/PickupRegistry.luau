-- Discovery and lifecycle for every IsPickup instance in workspace. The
-- single source of truth for "what pickups exist" -- consumers call
-- All()/IsRegistered() rather than scanning workspace themselves. Also
-- provisions/adopts each pickup's ProximityPrompt via PickupPrompt, so a
-- pickup and its prompt appear and disappear together.
--
-- Reads PickupTypes.MarkerAttribute/TypeAttribute rather than hardcoding
-- "IsPickup"/"PickupType" -- ObjectiveRegistry/ObjectiveVisualsController
-- hardcode "IsObjective" instead of going through CaptureTargets, which is
-- exactly the coupling CaptureTargets exists to prevent. Don't repeat that
-- mistake here.
--
-- Game place only -- Pickup does not run on the Lobby in v1.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local PickupTypes = require(ReplicatedStorage.Modules.Pickup.PickupTypes)
local Signal = require(ReplicatedStorage.Modules.Shared.Signal)
local PickupPrompt = require(script.Parent.PickupPrompt)

local PickupRegistry = {}

local MARKER = PickupTypes.MarkerAttribute

local live = {} -- [instance] = true
local attributeConnections = {} -- [instance] = RBXScriptConnection
local warnedUnanchored = {} -- [instance] = true, so the warn below fires once per instance

-- Fires (instance) once a pickup leaves live -- PickupService subscribes to
-- drop its claim-set entry, so that table can't leak across a match.
PickupRegistry.Unregistered = Signal.new()

local function isAnchored(instance: Instance): boolean
	if instance:IsA("BasePart") then
		return instance.Anchored
	elseif instance:IsA("Model") then
		local primaryPart = instance.PrimaryPart
		return primaryPart ~= nil and primaryPart.Anchored
	end
	return true
end

local function unregister(instance: Instance)
	if not live[instance] then
		return
	end
	live[instance] = nil
	PickupPrompt.Clear(instance)
	PickupRegistry.Unregistered:Fire(instance)
end

local function register(instance: Instance)
	if live[instance] then
		return
	end
	live[instance] = true

	-- The client-side idle spin (PickupVisualsController) is a client-local
	-- PivotTo -- on an unanchored part that fights physics instead of
	-- rendering a clean spin.
	if not isAnchored(instance) and not warnedUnanchored[instance] then
		warnedUnanchored[instance] = true
		warn(("PickupRegistry: %s is not Anchored -- the client-side idle spin will fight physics"):format(instance:GetFullName()))
	end

	local typeName = PickupTypes.TypeOf(instance)
	local typeDef = typeName and PickupTypes.Get(typeName)
	if not typeDef then
		warn(("PickupRegistry: %s has %s but no valid %s -- no prompt will be provisioned"):format(
			instance:GetFullName(), MARKER, PickupTypes.TypeAttribute))
		return
	end

	PickupPrompt.Provision(instance, typeDef)
end

-- Watches the marker attribute being toggled on/off at runtime (rather than
-- only at discovery time), so an authored-later attribute still registers.
local function watchAttribute(instance: Instance)
	if attributeConnections[instance] then
		return
	end
	attributeConnections[instance] = instance:GetAttributeChangedSignal(MARKER):Connect(function()
		if instance:GetAttribute(MARKER) then
			register(instance)
		else
			unregister(instance)
		end
	end)
end

-- The marker only ever lives on a BasePart or a Model -- see the matching
-- filter in Objective/ObjectiveRegistry.luau for why this cuts the
-- connection count from "every Workspace descendant" to just the classes
-- that could plausibly be a pickup.
local function considerInstance(instance: Instance)
	if not (instance:IsA("BasePart") or instance:IsA("Model")) then
		return
	end
	watchAttribute(instance)
	if instance:GetAttribute(MARKER) then
		register(instance)
	end
end

function PickupRegistry.All(): { Instance }
	local result = {}
	for instance in pairs(live) do
		table.insert(result, instance)
	end
	return result
end

function PickupRegistry.IsRegistered(instance: Instance): boolean
	return live[instance] == true
end

local started = false

function PickupRegistry.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

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
		warnedUnanchored[instance] = nil
		unregister(instance)
	end)
end

return PickupRegistry
