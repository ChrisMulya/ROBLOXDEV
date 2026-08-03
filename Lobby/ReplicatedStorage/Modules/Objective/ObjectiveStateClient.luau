-- Client-side merge point for both ownership paths. ObjectiveVisuals (and
-- anything else that wants "what state is this objective in right now")
-- consumes only GetEffectiveState and never learns whether a given objective
-- is Player- or Shared-owned.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ObjectiveTypes = require(ReplicatedStorage.Modules.Objective.ObjectiveTypes)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)

local ObjectiveStateClient = {}

-- Previously this indexed `.Remotes` raw (no WaitForChild on the folder
-- itself) -- a hard error if Remotes hadn't replicated yet, which fused this
-- module's failure into the whole camera require chain (CameraClient ->
-- CameraSession -> ObjectiveVisualsController -> here). Remotes.Get waits for
-- both the folder and the remote.
local ObjectiveStateSync = Remotes.Get("ObjectiveStateSync")

-- Player-ownership state pushed from the server. Weak-keyed so a streamed-out
-- or destroyed objective doesn't pin memory for the rest of the session --
-- same pattern as CaptureGuard's per-player cooldown table.
local playerStates = setmetatable({}, { __mode = "k" })

local function applyEntry(entry)
	if entry.instance then
		playerStates[entry.instance] = entry.state
	end
end

ObjectiveStateSync.OnClientEvent:Connect(function(payload)
	if payload.entries then
		for _, entry in ipairs(payload.entries) do
			applyEntry(entry)
		end
	else
		applyEntry(payload)
	end
end)

-- Precedence: per-player pushed state, then the Shared ObjectiveState
-- attribute (replicates automatically), then the type's InitialState.
function ObjectiveStateClient.GetEffectiveState(instance: Instance): string
	local pushed = playerStates[instance]
	if pushed then
		return pushed
	end

	local attributeState = instance:GetAttribute("ObjectiveState")
	if attributeState then
		return attributeState
	end

	return ObjectiveTypes.Get(ObjectiveTypes.TypeOf(instance)).InitialState
end

return ObjectiveStateClient
