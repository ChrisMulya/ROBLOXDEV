-- Client-side discovery + nearest-N budget pooling + the shared spin loop.
-- Structural copy of Objective/ObjectiveVisualsController.luau. Lower budget
-- than Objectives' 16 -- each pickup rig carries a PointLight, and Roblox's
-- simultaneous local-light budget is tighter than its Highlight budget.
--
-- Boot: required (for its side effect) from StarterPlayerScripts/ClientBootstrap,
-- unconditionally on both places -- this module has no dependency on
-- PickupRegistry/PickupService or match state, it just watches the IsPickup
-- attribute directly. A pickup placed on the Lobby spins and glows exactly
-- like one on the Game place, even though PickupRegistry/PickupService only
-- run Game-place-side (see those modules' headers): the ProximityPrompt
-- never gets provisioned there and nothing can be granted, so a Lobby
-- pickup is visible but inert.
--
-- Deliberate asymmetry from the server: an instance with IsPickup but a
-- missing/unknown PickupType still gets PickupVisuals.Default here, while
-- PickupService refuses to grant anything for it server-side. A
-- misconfigured pickup should be visible so a designer notices it, but must
-- never pay out.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PickupTypes = require(ReplicatedStorage.Modules.Pickup.PickupTypes)
local PickupVisuals = require(ReplicatedStorage.Modules.Pickup.PickupVisuals)

local MARKER = PickupTypes.MarkerAttribute

local MAX_VISIBLE = 12
local CULL_INTERVAL = 0.25

local known = {} -- [instance] = true
local attributeConnections = {} -- [instance] = RBXScriptConnection

local function unregister(instance: Instance)
	known[instance] = nil
	local connection = attributeConnections[instance]
	if connection then
		connection:Disconnect()
		attributeConnections[instance] = nil
	end
	PickupVisuals.Clear(instance)
end

-- The marker only ever lives on a BasePart or a Model -- see the matching
-- filter in PickupRegistry.luau (server) for why this cuts the connection
-- count from "every Workspace descendant" to just the classes that could
-- plausibly be a pickup.
local function considerInstance(instance: Instance)
	if not (instance:IsA("BasePart") or instance:IsA("Model")) then
		return
	end
	if not attributeConnections[instance] then
		attributeConnections[instance] = instance:GetAttributeChangedSignal(MARKER):Connect(function()
			if instance:GetAttribute(MARKER) then
				known[instance] = true
			else
				unregister(instance)
			end
		end)
	end

	if instance:GetAttribute(MARKER) then
		known[instance] = true
	end
end

for _, descendant in ipairs(workspace:GetDescendants()) do
	considerInstance(descendant)
end

workspace.DescendantAdded:Connect(considerInstance)

workspace.DescendantRemoving:Connect(function(instance)
	unregister(instance)
end)

local function positionOf(instance: Instance): Vector3?
	if instance:IsA("Model") then
		return instance:GetPivot().Position
	elseif instance:IsA("BasePart") then
		return instance.Position
	end
	return nil
end

local elapsed = 0

-- The set actually visible as of the last cycle. Diffing against this means
-- Apply/Clear only fire for instances whose visibility genuinely changed.
local previousVisible: { [Instance]: boolean } = {}

local function clearAllVisible()
	for instance in pairs(previousVisible) do
		PickupVisuals.Clear(instance)
	end
	table.clear(previousVisible)
end

RunService.Heartbeat:Connect(function(dt)
	for instance in pairs(previousVisible) do
		if instance.Parent then
			PickupVisuals.Step(instance, dt)
		end
	end

	elapsed += dt
	if elapsed < CULL_INTERVAL then
		return
	end
	elapsed = 0

	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		-- Without this, whatever was visible before death/respawn would
		-- stay rigged indefinitely, since nothing below would run to clear it.
		clearAllVisible()
		return
	end
	local myPosition = root.Position

	local candidates = {}
	for instance in pairs(known) do
		if instance.Parent then
			local position = positionOf(instance)
			if position then
				table.insert(candidates, { instance = instance, distance = (position - myPosition).Magnitude })
			end
		end
	end

	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)

	local shouldShow: { [Instance]: boolean } = {}
	for i = 1, math.min(MAX_VISIBLE, #candidates) do
		shouldShow[candidates[i].instance] = true
	end

	for instance in pairs(shouldShow) do
		if not previousVisible[instance] then
			local typeName = PickupTypes.TypeOf(instance)
			local typeDef = PickupTypes.Get(typeName)
			PickupVisuals.Apply(instance, typeDef and typeDef.VisualStyle or nil)
		end
	end
	for instance in pairs(previousVisible) do
		if not shouldShow[instance] then
			PickupVisuals.Clear(instance)
		end
	end

	previousVisible = shouldShow
end)

return true
