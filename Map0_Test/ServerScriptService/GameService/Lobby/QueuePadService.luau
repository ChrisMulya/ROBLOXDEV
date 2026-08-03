-- The bridge between the lobby's physical queue pads and QueueService. Owns
-- no queue state -- only "who is currently standing inside which pad" -- and
-- translates enter/exit transitions into QueueService.JoinPad/LeavePad.
--
-- Occupancy is polled from server-side HumanoidRootPart positions rather than
-- driven by Touched. Touched is client-physics-authored: it doesn't fire for a
-- player who is already standing still when the pad appears, double-fires on
-- limb contact, and is trivially spoofable. Polling a point against the pad's
-- bounding box is server-authoritative and structure-agnostic -- it doesn't
-- care what parts the pad model is built from.
--
-- Also mirrors QueueService's pad state onto the pad instance as attributes
-- (QueuePadCount / QueuePadCapacity / QueuePadEndsAt) so the world-space
-- display replicates to every player, queued or not, with no remote traffic.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local QueueService = require(script.Parent.QueueService)

local QueuePadService = {}

local SIZE_ATTRIBUTE = "QueuePadSize"
local POLL_INTERVAL = 0.2 -- 5 Hz; a pad is entered by walking, not by a frame
local MIN_HEIGHT = 8 -- rescues a flat floor plate; a real zone volume is taller

type Volume = { cframe: CFrame, halfSize: Vector3 }

local volumes: { [Instance]: Volume } = {}
local attributeConnections: { [Instance]: RBXScriptConnection } = {}
local insidePad: { [Player]: Instance } = {} -- geometric truth, not queue truth
local pollAccumulator = 0

-- Cached at registration: the pads are anchored lobby geometry, so recomputing
-- this every tick would buy nothing.
--
-- Tagging the zone part rather than the pad Model is deliberate: a Model's
-- bounding box would swallow the floating DisplayLabel above it, making the
-- trigger volume several times taller than the area a player can see they're
-- standing in. The authored part IS the volume.
local function computeVolume(instance: Instance): Volume?
	local cframe, size
	if instance:IsA("BasePart") then
		cframe, size = instance.CFrame, instance.Size
	elseif instance:IsA("Model") then
		cframe, size = instance:GetBoundingBox()
	else
		return nil
	end

	size = Vector3.new(size.X, math.max(size.Y, MIN_HEIGHT), size.Z)
	return { cframe = cframe, halfSize = size / 2 }
end

local function isInside(volume: Volume, position: Vector3): boolean
	local local_ = volume.cframe:PointToObjectSpace(position)
	return math.abs(local_.X) <= volume.halfSize.X
		and math.abs(local_.Y) <= volume.halfSize.Y
		and math.abs(local_.Z) <= volume.halfSize.Z
end

local function unregister(instance: Instance)
	if not volumes[instance] then
		return
	end
	volumes[instance] = nil
	for player, pad in pairs(insidePad) do
		if pad == instance then
			insidePad[player] = nil
		end
	end
	QueueService.UnregisterPad(instance)
end

local function register(instance: Instance)
	local size = instance:GetAttribute(SIZE_ATTRIBUTE)
	if typeof(size) ~= "number" or size < 1 then
		unregister(instance)
		return
	end

	local volume = computeVolume(instance)
	if not volume then
		return
	end

	volumes[instance] = volume
	QueueService.RegisterPad(instance, size)
end

-- Watches QueuePadSize being authored or retuned at runtime, so a pad tagged
-- after boot still registers -- same pattern as ObjectiveRegistry.
local function considerInstance(instance: Instance)
	if not (instance:IsA("BasePart") or instance:IsA("Model")) then
		return
	end

	if not attributeConnections[instance] then
		attributeConnections[instance] = instance
			:GetAttributeChangedSignal(SIZE_ATTRIBUTE)
			:Connect(function()
				register(instance)
			end)
	end

	if instance:GetAttribute(SIZE_ATTRIBUTE) ~= nil then
		register(instance)
	end
end

local function padContaining(player: Player): Instance?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil -- dead, loading, or teleporting: treated as outside every pad
	end

	for instance, volume in pairs(volumes) do
		if isInside(volume, root.Position) then
			return instance
		end
	end
	return nil
end

local function reportRejection(player: Player, code: string)
	if code == "Ok" then
		return
	end
	Remotes.Get("QueueResult"):FireClient(player, code)
end

local function poll()
	for _, player in ipairs(Players:GetPlayers()) do
		local current = padContaining(player)
		local previous = insidePad[player]

		if current ~= previous then
			insidePad[player] = current

			if previous then
				QueueService.LeavePad(player)
			end
			if current then
				local ok, code = QueueService.JoinPad(player, current)
				if not ok then
					-- Only the deliberate act of stepping on earns a message;
					-- the retry path below stays silent.
					reportRejection(player, code)
				end
			end
		end
	end
end

-- A player standing on a pad that was full (or mid-launch) when they arrived
-- gets no further enter transition to ride in on. Retrying whenever pad state
-- changes is what lets a freed slot pick them up, and it is silent -- they
-- already got one rejection message on entry.
local function retryStandingPlayers()
	for player, instance in pairs(insidePad) do
		if player.Parent and volumes[instance] and not QueueService.GetPadOf(player) then
			QueueService.JoinPad(player, instance)
		end
	end
end

local function syncPadAttributes()
	for _, instance in ipairs(QueueService.GetPads()) do
		local state = QueueService.GetPadState(instance)
		if state then
			instance:SetAttribute("QueuePadCapacity", state.capacity)
			instance:SetAttribute("QueuePadCount", state.count)
			-- 0 rather than nil: the client reads one type and never has to
			-- distinguish "idle" from "attribute hasn't replicated yet".
			instance:SetAttribute("QueuePadEndsAt", state.endsAt or 0)
		end
	end
end

local started = false

function QueuePadService.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertLobbyServer()

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

	if next(volumes) == nil then
		warn(
			("QueuePadService: no queue pads found -- tag each lobby pad with a %s attribute (1/2/4)"):format(
				SIZE_ATTRIBUTE
			)
		)
	end

	Players.PlayerRemoving:Connect(function(player)
		insidePad[player] = nil
	end)

	QueueService.Changed:Connect(retryStandingPlayers)
	QueueService.Changed:Connect(syncPadAttributes)
	syncPadAttributes()

	RunService.Heartbeat:Connect(function(delta)
		pollAccumulator += delta
		if pollAccumulator < POLL_INTERVAL then
			return
		end
		pollAccumulator = 0
		poll()
	end)
end

return QueuePadService
