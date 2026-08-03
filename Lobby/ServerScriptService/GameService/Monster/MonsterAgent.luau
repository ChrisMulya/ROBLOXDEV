local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MonsterStats = require(ReplicatedStorage.Modules.Monster.MonsterStats)

local States = {
	Chase = require(script.Parent.States.Chase),
}

local Behaviors = {
	GreyCube = require(script.Parent.Behaviors.GreyCube),
}

local MonsterAgent = {}
MonsterAgent.States = States

function MonsterAgent.New(model: Model, monsterId: string, stage: number?)
	local rootPart = model:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		warn("MonsterAgent.New: model '" .. model.Name .. "' is missing HumanoidRootPart")
		return nil
	end
	-- Optional: nil for the MVP grey box. Movement is driven by MonsterMovement
	-- (kinematic CFrame), not a Humanoid -- see MonsterService for why this
	-- model doesn't have one. Reserved for future rigged/animated monsters.
	local humanoid = model:FindFirstChildOfClass("Humanoid")

	local stats = MonsterStats.Get(monsterId, stage)
	if not stats then return nil end

	local initialState = stats.States[1]
	if not initialState or not States[initialState] then
		warn("MonsterAgent.New: no valid initial state for '" .. monsterId .. "'")
		return nil
	end

	local agent = {
		model = model,
		humanoid = humanoid,
		rootPart = rootPart,
		monsterId = monsterId,
		stage = stage or 1,
		stats = stats,
		behavior = Behaviors[monsterId] or {},

		state = nil, -- set below via SetState so Enter()/OnStateEnter fire consistently
		stateElapsed = 0,
		lastTick = os.clock(),

		target = nil,
		lastKnownPos = nil,
		lastSeenAt = 0,

		aggression = 0,
		memory = {},
	}

	if agent.behavior.OnSpawn then
		agent.behavior.OnSpawn(agent)
	end

	MonsterAgent.SetState(agent, initialState)

	return agent
end

function MonsterAgent.SetState(agent, newState: string)
	-- Behavior gets first refusal on any transition.
	if agent.behavior.TransitionOverride then
		local override = agent.behavior.TransitionOverride(agent, agent.state, newState)
		if override then
			newState = override
		end
	end

	-- Anti-solved-AI valve: a transition can be configured to not always fire.
	-- Not exercised by the Chase-only MVP (TransitionChance.Chase = 1.0) but
	-- wired now so later states don't require reworking SetState.
	local chance = agent.stats.TransitionChance and agent.stats.TransitionChance[newState]
	if chance and chance < 1 and math.random() > chance then
		return
	end

	local oldState = agent.state
	if oldState and States[oldState] and States[oldState].Exit then
		States[oldState].Exit(agent)
	end

	agent.state = newState
	agent.stateElapsed = 0

	local stateModule = States[newState]
	if stateModule and stateModule.Enter then
		stateModule.Enter(agent)
	end

	if agent.behavior.OnStateEnter then
		agent.behavior.OnStateEnter(agent, newState)
	end
end

function MonsterAgent.Tick(agent, dt: number)
	agent.stateElapsed += dt

	if agent.behavior.OnUpdate then
		agent.behavior.OnUpdate(agent, dt)
	end

	local stateModule = States[agent.state]
	if not stateModule then return end

	local nextState = stateModule.Update(agent, dt)
	if nextState and nextState ~= agent.state then
		MonsterAgent.SetState(agent, nextState)
	end
end

return MonsterAgent
