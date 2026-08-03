-- World-space readout above each lobby queue pad: occupancy and the launch
-- countdown. Lobby only -- required from ClientBootstrap's Lobby branch for
-- its side effects, same pattern as QueueController.
--
-- Drives the BillboardGui the pad was authored with (the part tagged
-- QueuePadLabel) rather than building a parallel one. The pad's placement,
-- size and styling stay the level designer's call; this module only writes
-- text into it. A pad with no tagged label simply shows nothing -- it still
-- queues and launches, since none of that depends on the display.
--
-- Reads pad state entirely from replicated attributes (QueuePadCount /
-- QueuePadCapacity / QueuePadEndsAt, written by QueuePadService). No remote,
-- and every player sees every pad whether or not they're queued -- which is
-- the point: you decide which pad to walk to by looking at it.
--
-- QueuePadEndsAt is a workspace:GetServerTimeNow() timestamp, not a remaining
-- duration, so the per-second tick is pure local subtraction -- the countdown
-- animates smoothly at zero network cost and can't drift.

local RunService = game:GetService("RunService")

local QueuePadLabels = require(script.Parent.QueuePadLabels)

local QueuePadDisplay = {}

local SIZE_ATTRIBUTE = "QueuePadSize"
local LABEL_ATTRIBUTE = "QueuePadLabel"
local TICK_INTERVAL = 0.1

local labels: { [Instance]: TextLabel } = {}
local connections: { [Instance]: { RBXScriptConnection } } = {}
local tickAccumulator = 0

-- The label lives beside the zone inside the pad model, so the search starts
-- at the zone's parent. Attribute, not name -- a pad can call its label
-- whatever it likes.
local function findLabel(pad: Instance): TextLabel?
	local root = pad.Parent
	if not root then
		return nil
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:GetAttribute(LABEL_ATTRIBUTE) then
			local billboard = descendant:FindFirstChildWhichIsA("BillboardGui")
			local label = billboard and billboard:FindFirstChildWhichIsA("TextLabel")
			if label then
				return label
			end
		end
	end
	return nil
end

local function refresh(pad: Instance)
	local label = labels[pad]
	if not label then
		return
	end

	local count = pad:GetAttribute("QueuePadCount") or 0
	local capacity = pad:GetAttribute("QueuePadCapacity") or pad:GetAttribute(SIZE_ATTRIBUTE) or 0
	local endsAt = pad:GetAttribute("QueuePadEndsAt") or 0

	local status
	if endsAt > 0 then
		local remaining = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
		status = QueuePadLabels.Counting(remaining)
	elseif capacity > 0 and count >= capacity then
		status = QueuePadLabels.Full
	else
		status = QueuePadLabels.Idle
	end

	label.Text = QueuePadLabels.Format(count, capacity, status)
end

local function teardown(pad: Instance)
	labels[pad] = nil

	local padConnections = connections[pad]
	if padConnections then
		for _, connection in ipairs(padConnections) do
			connection:Disconnect()
		end
		connections[pad] = nil
	end
end

local function considerInstance(instance: Instance)
	if instance:GetAttribute(SIZE_ATTRIBUTE) == nil then
		return
	end
	if labels[instance] then
		return
	end

	local label = findLabel(instance)
	if not label then
		return
	end

	-- No styling asserted here -- TextScaled/TextWrapped/AlwaysOnTop are the
	-- authored asset's call (set on the label/BillboardGui directly in
	-- Studio). This module only ever writes .Text.
	labels[instance] = label

	-- QueuePadEndsAt is deliberately not watched here: its only consumer is
	-- the per-tick refresh below, which re-reads it anyway.
	connections[instance] = {
		instance:GetAttributeChangedSignal("QueuePadCount"):Connect(function()
			refresh(instance)
		end),
		instance:GetAttributeChangedSignal("QueuePadCapacity"):Connect(function()
			refresh(instance)
		end),
	}

	refresh(instance)
end

local function bootstrap()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		considerInstance(descendant)
	end

	workspace.DescendantAdded:Connect(considerInstance)
	workspace.DescendantRemoving:Connect(teardown)

	RunService.Heartbeat:Connect(function(delta)
		tickAccumulator += delta
		if tickAccumulator < TICK_INTERVAL then
			return
		end
		tickAccumulator = 0

		for pad in pairs(labels) do
			refresh(pad)
		end
	end)
end

bootstrap()

return QueuePadDisplay
