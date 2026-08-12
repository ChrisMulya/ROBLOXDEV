-- Client-side discovery + range gate + nearest-N budget pooling. Roblox
-- renders roughly 31 Highlights before silently dropping the rest, so this
-- never applies a highlight to more than MAX_VISIBLE objectives at once,
-- re-evaluated on a slow loop rather than every frame. Objectives beyond
-- MAX_DISTANCE studs are excluded before that budget is applied.
--
-- Boot: required (for its side effect) from StarterPlayerScripts/ClientBootstrap,
-- so objectives glow from game start regardless of whether the player has
-- picked up a camera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ObjectiveTypes = require(ReplicatedStorage.Modules.Objective.ObjectiveTypes)
local ObjectiveStates = require(ReplicatedStorage.Modules.Objective.ObjectiveStates)
local ObjectiveStateClient = require(ReplicatedStorage.Modules.Objective.ObjectiveStateClient)
local ObjectiveVisuals = require(ReplicatedStorage.Modules.Objective.ObjectiveVisuals)

local MAX_VISIBLE = 150
-- Studs. An objective farther than this draws no outline at all, regardless
-- of how few are on screen. Distinct from MAX_VISIBLE, which is a Highlight
-- budget: this is a hard range gate applied FIRST, so the nearest-N budget
-- only ever chooses among objectives already in range.
local MAX_DISTANCE = 210
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
	ObjectiveVisuals.Clear(instance)
end

-- IsObjective only ever lives on a BasePart or a Model -- see the matching
-- filter in ObjectiveRegistry.luau (server) for why this cuts the connection
-- count from "every Workspace descendant" to just the classes that could
-- plausibly be an objective.
local function considerInstance(instance: Instance)
	if not (instance:IsA("BasePart") or instance:IsA("Model")) then
		return
	end
	if not attributeConnections[instance] then
		attributeConnections[instance] = instance:GetAttributeChangedSignal("IsObjective"):Connect(function()
			if instance:GetAttribute("IsObjective") then
				known[instance] = true
			else
				unregister(instance)
			end
		end)
	end

	if instance:GetAttribute("IsObjective") then
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

-- The set actually highlighted as of the last cycle. Diffing against this
-- means Apply/Clear only fire for instances whose visibility genuinely
-- changed, instead of rewriting all five Highlight properties on every
-- shown instance every 0.25s regardless of whether anything changed.
local previousVisible: { [Instance]: boolean } = {}

local function clearAllVisible()
	for instance in pairs(previousVisible) do
		ObjectiveVisuals.Clear(instance)
	end
	table.clear(previousVisible)
end

RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < CULL_INTERVAL then
		return
	end
	elapsed = 0

	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		-- Previously this early-out left whatever was highlighted before
		-- death/respawn applied indefinitely, since nothing below ever ran
		-- to clear it.
		clearAllVisible()
		return
	end
	local myPosition = root.Position

	local candidates = {}
	for instance in pairs(known) do
		if instance.Parent then
			local state = ObjectiveStateClient.GetEffectiveState(instance)
			if ObjectiveStates.IsVisible(state) then
				local position = positionOf(instance)
				if position then
					local distance = (position - myPosition).Magnitude
					if distance <= MAX_DISTANCE then
						table.insert(candidates, { instance = instance, distance = distance })
					end
				end
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
			local typeName = ObjectiveTypes.TypeOf(instance)
			ObjectiveVisuals.Apply(instance, ObjectiveTypes.Get(typeName).VisualStyle)
		end
	end
	for instance in pairs(previousVisible) do
		if not shouldShow[instance] then
			ObjectiveVisuals.Clear(instance)
		end
	end

	previousVisible = shouldShow
end)

return true
