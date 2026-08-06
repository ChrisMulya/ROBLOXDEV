local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MatchStates = require(ReplicatedStorage.Modules.Shared.MatchStates)
local MonsterStats = require(ReplicatedStorage.Modules.Monster.MonsterStats)
local MonsterAgent = require(script.Parent.MonsterAgent)
local MonsterDamage = require(script.Parent.MonsterDamage)

local MonsterService = {}

local liveAgents = {} -- [model] = agent

-- Lazy for the same reason as RewardService's isScoringActive: this module
-- currently self-wires on both places (content-migration gap), and
-- MatchManager is Game-Server-only.
local function monstersCanSpawn(): boolean
	if not ServerRole.Is("GameServer") then
		return true
	end
	local MatchManager = require(script.Parent.Parent.Match.MatchManager)
	return MatchStates.MonstersSpawn(MatchManager.Get())
end

local function gameplayActive(): boolean
	if not ServerRole.Is("GameServer") then
		return true
	end
	local MatchManager = require(script.Parent.Parent.Match.MatchManager)
	return MatchStates.IsGameplayActive(MatchManager.Get())
end

-- MVP grey box has no authored asset yet, so it's built from scratch here --
-- this keeps the system unblocked on Studio asset work. Swap this for a
-- template clone (same pattern as CAMERA_TEMPLATES_FOLDER in StartGame.luau)
-- once real monster models exist.
local function buildGreyCubeModel(cframe: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "GreyCube"

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(4, 4, 4)
	rootPart.Color = Color3.fromRGB(120, 120, 120)
	-- Anchored + code-driven CFrame (see MonsterMovement) instead of physics-
	-- simulated: a lone unwelded part has nothing to keep it upright and
	-- tumbles under Humanoid/collision forces otherwise.
	rootPart.Anchored = true
	rootPart.CanCollide = true
	rootPart.CFrame = cframe
	rootPart.Parent = model

	-- No Humanoid: a lone HumanoidRootPart with a Humanoid but no Torso/real
	-- rig underneath confuses Roblox's anatomy resolution and corrupts the
	-- part's position. Movement is fully kinematic (MonsterMovement) and
	-- damage only touches the player's Humanoid, so this model doesn't need
	-- one. Add a real Humanoid when a proper rigged/animated model exists.
	model.PrimaryPart = rootPart
	return model
end

local MODEL_BUILDERS = {
	GreyCube = buildGreyCubeModel,
}

function MonsterService.Spawn(monsterId: string, cframe: CFrame, stage: number?): Model?
	if not monstersCanSpawn() then
		warn("MonsterService.Spawn: monsters aren't allowed to spawn outside of active gameplay")
		return nil
	end

	local builder = MODEL_BUILDERS[monsterId]
	if not builder then
		warn("MonsterService.Spawn: no model builder for '" .. monsterId .. "' yet")
		return nil
	end

	local model = builder(cframe)

	-- IsMonster ties straight into CaptureTargets -- the monster is
	-- photographable (Reward/CaptureTargets.Types.Monster.Attribute) with
	-- zero camera-code changes.
	model:SetAttribute("IsMonster", true)
	model:SetAttribute("MonsterId", monsterId)
	model:SetAttribute("Stage", stage or 1)

	model.Parent = workspace

	local agent = MonsterAgent.New(model, monsterId, stage)
	if not agent then
		model:Destroy()
		return nil
	end

	liveAgents[model] = agent

	local touchedConn
	touchedConn = agent.rootPart.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if player then
			MonsterDamage.TryKill(agent, player)
		end
	end)

	model.Destroying:Connect(function()
		touchedConn:Disconnect()
		MonsterDamage.ClearAgent(agent)
		liveAgents[model] = nil
	end)

	return model
end

-- Re-stats a LIVE agent in place. Until this existed, Stage was read once at
-- spawn and never again, so MonsterStats' stage-override merge -- the most
-- match-time-shaped seam in the repo -- had no way to actually drive
-- difficulty during a match.
--
-- Swaps the resolved stats table wholesale rather than mutating fields:
-- Chase/MonsterDamage read agent.stats.* fresh on each use, so a reference
-- swap is atomic from their point of view and cannot leave a half-applied
-- stat set mid-tick.
--
-- Deliberately does NOT reset state, target, or position -- a monster that
-- gets faster at midnight should keep chasing whoever it was chasing, not
-- forget them.
function MonsterService.Restage(model: Model, stage: number): boolean
	local agent = liveAgents[model]
	if not agent then
		return false
	end

	if agent.stage == stage then
		return false
	end

	local stats = MonsterStats.Get(agent.monsterId, stage)
	if not stats then
		return false
	end

	agent.stage = stage
	agent.stats = stats
	model:SetAttribute("Stage", stage)
	return true
end

function MonsterService.Despawn(model: Model)
	if liveAgents[model] then
		model:Destroy() -- fires Destroying above, which cleans up liveAgents/cooldowns
	end
end

RunService.Heartbeat:Connect(function()
	-- Freezes existing monsters in place rather than despawning them once
	-- gameplay ends (Ending keeps the world visible for spectate/end
	-- screen) -- ticking just stops, per the plan's Ending contract.
	if not gameplayActive() then
		return
	end

	local now = os.clock()
	for model, agent in pairs(liveAgents) do
		if not model.Parent then
			-- Reached when a model is unparented without going through
			-- :Destroy() (which fires Destroying above and cleans up via
			-- ClearAgent there) -- Destroying does not fire on a bare
			-- `model.Parent = nil`, so this path needs its own cleanup call.
			MonsterDamage.ClearAgent(agent)
			liveAgents[model] = nil
			continue
		end

		local stateModule = MonsterAgent.States[agent.state]
		local tickRate = stateModule and stateModule.TickRate or 0.1
		local dt = now - agent.lastTick
		if dt >= tickRate then
			MonsterAgent.Tick(agent, dt)
			agent.lastTick = now
		end
	end
end)

return MonsterService
