-- One live monster. Coordinates; contains no gameplay logic.
--
-- It owns a Trove (everything acquired is released by reference), a MonsterBus,
-- a Blackboard, the components its capabilities resolve to, a StateMachine and
-- a Brain. It routes the tick and nothing else.
--
-- Any `if monsterId == ...` in this file is a design failure -- differences
-- between monsters come from config and capabilities, never from branching.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Modules.Shared.Trove)
local MonsterConfig = require(ReplicatedStorage.Modules.Monster.MonsterConfig)
local MonsterConstants = require(ReplicatedStorage.Modules.Monster.MonsterConstants)
local Components = require(script.Parent.Components)
local MonsterBus = require(script.Parent.MonsterBus)
local Brain = require(script.Parent.Brain.Brain)
local StateMachine = require(script.Parent.Brain.StateMachine)

local MonsterInstance = {}
MonsterInstance.__index = MonsterInstance

-- Single-writer enforcement, made mechanical. Two components declaring the
-- same Blackboard key is the failure that collapses this architecture back
-- into the one it replaced, so it's an assert at construction rather than a
-- convention in a comment. Free: it runs once per spawn, not per tick.
local function claimWrites(writers, componentName: string, component)
	for _, key in ipairs(component.Writes or {}) do
		local existing = writers[key]
		assert(existing == nil, ("MonsterInstance: components '%s' and '%s' both declare Blackboard key '%s'")
			:format(tostring(existing), componentName, key))
		writers[key] = componentName
	end
end

-- Tick order, and the pipeline the monster actually runs each tick:
-- sense -> commit to a target -> move -> hit.
--
-- This is load-bearing, not cosmetic. Perception writes VisibleTargets and
-- Targeting reads it in the SAME tick, so iterating components with pairs()
-- would let Targeting run first on an arbitrary subset of frames and act on
-- last tick's data -- a nondeterministic one-tick lag varying per monster and
-- per run.
--
-- Construction order is not constrained: no component reads another's
-- Blackboard keys at construction, only during Tick. So one list serves both.
-- Anything not named here is built and ticked after, in capability order.
-- Aggression sits after Targeting because its Proximity modifier reads
-- VisibleTargets, and before the Brain (which runs after all components) so a
-- threshold crossed this tick is acted on this tick.
local TICK_ORDER = { "Perception", "Targeting", "Aggression", "Navigation", "Combat" }

local function buildComponents(self)
	local writers = {}
	local seen = {}

	local function build(name: string)
		if seen[name] or not self.config.Components[name] then
			return
		end
		seen[name] = true

		local module = Components.Get(name)
		if not module then
			return -- planned but not implemented yet; Components warns on typos
		end

		claimWrites(writers, name, module)
		self.components[name] = module.new(self, self.config)
		table.insert(self.componentOrder, name)
	end

	for _, name in ipairs(TICK_ORDER) do
		build(name)
	end

	-- Anything the capabilities resolved to that TICK_ORDER doesn't name.
	for name in pairs(self.config.Components) do
		build(name)
	end

	-- Perception before Targeting is the ordering that actually matters, so
	-- assert it rather than trusting TICK_ORDER to stay correct through edits.
	local perceptionIndex, targetingIndex
	for index, name in ipairs(self.componentOrder) do
		if name == "Perception" then perceptionIndex = index end
		if name == "Targeting" then targetingIndex = index end
	end
	if perceptionIndex and targetingIndex then
		assert(perceptionIndex < targetingIndex,
			"MonsterInstance: Perception must tick before Targeting")
	end

	-- Static for the instance's lifetime -- see GetTickRate.
	local fastest = math.huge
	for _, name in ipairs(self.componentOrder) do
		local component = self.components[name]
		if component.Tick and component.TickRate and component.TickRate < fastest then
			fastest = component.TickRate
		end
	end
	self._componentTickRate = fastest

	self.blackboardWriters = writers
end

function MonsterInstance.new(model: Model, monsterId: string, stage: number?)
	local config = MonsterConfig.Get(monsterId, stage)
	if not config then
		return nil
	end

	local rootPart = model:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		warn(("MonsterInstance: model '%s' is missing HumanoidRootPart"):format(model.Name))
		return nil
	end

	local self = setmetatable({
		model      = model,
		rootPart   = rootPart,
		-- nil for the kinematic placeholder. HumanoidPathLocomotion (step 6)
		-- requires one.
		humanoid   = model:FindFirstChildOfClass("Humanoid"),
		monsterId  = monsterId,
		stage      = config.Stage,
		config     = config,

		trove      = Trove.new(),
		bus        = MonsterBus.new(),
		blackboard = {},
		components = {},
		-- Deterministic tick sequence; see TICK_ORDER.
		componentOrder = {},

		lastTick   = os.clock(),
		destroyed  = false,

		_componentAccumulators = {},
	}, MonsterInstance)

	self.trove:Add(function()
		self.bus:Destroy()
	end)

	-- Where the monster started. Reset leashes against it; nothing writes it
	-- after construction, so it needs no owning component.
	self.blackboard.SpawnPosition = rootPart.Position

	buildComponents(self)

	self.stateMachine = StateMachine.new(self)
	self.brain = Brain.new(self)

	for _, component in pairs(self.components) do
		if component.Start then
			component:Start()
		end
	end
	self.brain:Start()

	self.trove:Add(function()
		self.brain:Destroy()
		self.stateMachine:Destroy()
		for _, component in pairs(self.components) do
			if component.Destroy then
				component:Destroy()
			end
		end
		table.clear(self.components)
	end)

	-- Perception has never run at this point, so the Brain would score every
	-- state against an empty Blackboard. Idle is the correct answer to that,
	-- and it gives the state machine a valid state before the first tick.
	self.brain:Evaluate()

	return self
end

function MonsterInstance:GetComponent(name: string)
	return self.components[name]
end

function MonsterInstance:Has(capability: string): boolean
	return self.config.Capabilities[capability] == true
end

-- The scheduler ticks at the fastest cadence anything needs; each component
-- and the Brain throttle themselves to their own rate from there.
--
-- The component minimum is computed once at construction rather than per call:
-- the scheduler asks every Heartbeat for every monster, and component tick
-- rates are static for an instance's lifetime. Only the active state's rate
-- changes, so only that is read live.
function MonsterInstance:GetTickRate(): number
	local stateRate = self.stateMachine.module and self.stateMachine.module.TickRate
		or MonsterConstants.DefaultTickRate

	return math.min(stateRate, self._componentTickRate)
end

function MonsterInstance:Tick(dt: number)
	if self.destroyed then
		return
	end

	-- Ordered, never pairs() -- see TICK_ORDER.
	for _, name in ipairs(self.componentOrder) do
		local component = self.components[name]
		if component and component.Tick then
			local accumulated = (self._componentAccumulators[name] or 0) + dt
			if accumulated >= (component.TickRate or 0) then
				self._componentAccumulators[name] = 0
				component:Tick(accumulated)
			else
				self._componentAccumulators[name] = accumulated
			end
		end
	end

	self.brain:Tick(dt)
	self.stateMachine:Tick(dt)
end

-- Re-stats in place. Swaps the whole resolved table by reference rather than
-- mutating fields: readers take config.Stats.* fresh on each use, so the swap
-- is atomic from their point of view and can never leave a half-applied stat
-- set mid-tick. Deliberately does NOT reset state, target or position -- a
-- monster that gets faster at midnight keeps chasing whoever it was chasing.
function MonsterInstance:SetStage(stage: number): boolean
	if self.stage == stage then
		return false
	end

	local config = MonsterConfig.Get(self.monsterId, stage)
	if not config then
		return false
	end

	self.stage = stage
	self.config = config

	self.model:SetAttribute(MonsterConstants.Attributes.Stage, stage)
	self.bus:Fire("StageChanged", { Stage = stage })
	return true
end

-- Does NOT destroy the model. MonsterService.Despawn owns that, and the
-- model's Destroying handler routes back here via the registry -- destroying
-- from both ends would recurse.
function MonsterInstance:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.trove:Clean()
end

return MonsterInstance
