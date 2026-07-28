local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local MonsterAgent = require(script.Parent.MonsterAgent)
local MonsterDamage = require(script.Parent.MonsterDamage)

local MonsterService = {}

local liveAgents = {} -- [model] = agent

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

function MonsterService.Despawn(model: Model)
	if liveAgents[model] then
		model:Destroy() -- fires Destroying above, which cleans up liveAgents/cooldowns
	end
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for model, agent in pairs(liveAgents) do
		if not model.Parent then
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
