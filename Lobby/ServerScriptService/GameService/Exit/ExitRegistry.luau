-- Discovery and lifecycle for every IsExit instance in workspace. The single
-- source of truth for "what exits exist" -- consumers call
-- All()/AllOfType()/IsRegistered() rather than scanning workspace
-- themselves. Directly mirrors Pickup/PickupRegistry.luau.
--
-- Reads ExitTypes.MarkerAttribute/TypeAttribute rather than hardcoding
-- "IsExit"/"ExitType" -- see ExitTypes.luau header for why.
--
-- Game place only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local ExitTypes = require(ReplicatedStorage.Modules.Exit.ExitTypes)
local Signal = require(ReplicatedStorage.Modules.Shared.Signal)

local ExitRegistry = {}

local MARKER = ExitTypes.MarkerAttribute

local live = {} -- [instance] = true
local attributeConnections = {} -- [instance] = RBXScriptConnection
local warnedUnanchored = {} -- [instance] = true, so the warn below fires once per instance

-- Fires (instance) once an exit leaves live -- ExitState/ExitService
-- subscribe to drop any per-instance bookkeeping.
ExitRegistry.Unregistered = Signal.new()

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
	ExitRegistry.Unregistered:Fire(instance)
end

local function register(instance: Instance)
	if live[instance] then
		return
	end
	live[instance] = true

	if not isAnchored(instance) and not warnedUnanchored[instance] then
		warnedUnanchored[instance] = true
		warn(("ExitRegistry: %s is not Anchored"):format(instance:GetFullName()))
	end

	local typeName = ExitTypes.TypeOf(instance)
	if not ExitTypes.Get(typeName) then
		warn(("ExitRegistry: %s has %s but no valid %s -- it will never open"):format(
			instance:GetFullName(), MARKER, ExitTypes.TypeAttribute))
	end
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

-- The marker only ever lives on a BasePart or a Model -- same filter as
-- PickupRegistry/ObjectiveRegistry, to cut the connection count from "every
-- Workspace descendant" to just the classes that could plausibly be an exit.
local function considerInstance(instance: Instance)
	if not (instance:IsA("BasePart") or instance:IsA("Model")) then
		return
	end
	watchAttribute(instance)
	if instance:GetAttribute(MARKER) then
		register(instance)
	end
end

function ExitRegistry.All(): { Instance }
	local result = {}
	for instance in pairs(live) do
		table.insert(result, instance)
	end
	return result
end

function ExitRegistry.AllOfType(typeName: string): { Instance }
	local result = {}
	for instance in pairs(live) do
		if ExitTypes.TypeOf(instance) == typeName then
			table.insert(result, instance)
		end
	end
	return result
end

function ExitRegistry.IsRegistered(instance: Instance): boolean
	return live[instance] == true
end

local started = false

function ExitRegistry.Start()
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

return ExitRegistry
