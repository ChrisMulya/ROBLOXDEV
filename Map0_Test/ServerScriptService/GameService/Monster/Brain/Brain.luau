-- Chooses which state should be active. That is its ONLY job -- it never
-- perceives, never moves, never attacks. Keep it small.
--
-- Selection:
--   1. eligible = states this monster's capabilities allow AND its config
--      gives a weight
--   2. utility = State.Score(instance, blackboard) -> [0,1] or nil (ineligible)
--   3. weighted = utility * config weight
--   4. highest Band wins outright; within a band, highest weighted score
--
-- Utility is normalized so a state only has to be internally consistent
-- ("how much do I want to run, 0 to 1"). All cross-state calibration is the
-- per-monster Weight table, so tuning one monster can't shift another.
--
-- Bands are hard precedence, not a tie-break: Attack outranks Chase no matter
-- how badly Chase wants to run. Without them you tune weights until the
-- ordering happens to come out right, which stops working as monsters are
-- added.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterConstants = require(ReplicatedStorage.Modules.Monster.MonsterConstants)
local States = require(script.Parent.Parent.States)

local Brain = {}
Brain.__index = Brain

-- Events that make a decision potentially stale. Polling alone is a
-- correctness bug, not a latency preference: at 23 studs/sec a 0.2s tick lets
-- a monster overshoot by ~4.6 studs and AttackReach is 4, so a polled-only
-- Brain would visibly fail attacks it should have landed.
local WAKE_EVENTS = {
	"TargetAcquired", "TargetLost", "Arrived", "Evolved", "StageChanged",
	"AggressionThreshold",
	-- D4: a fresh stimulus makes Check.Score() eligible again immediately.
	-- Without this, an investigation waits out the Brain's own poll interval
	-- (up to TickRate, 0.2s) before reacting -- inside the same latency
	-- argument WAKE_EVENTS already makes for the others.
	"StimulusReceived",
	-- Targeting redirected a pursuit onto a heard position. Same argument: a
	-- monster tracking a sprinting player should turn on the new lead rather
	-- than finish walking to the old one first.
	"TrailUpdated",
}

function Brain.new(instance)
	local brainConfig = instance.config.Brain or {}

	local self = setmetatable({
		instance   = instance,
		tickRate   = brainConfig.TickRate or MonsterConstants.DefaultBrainTickRate,
		hysteresis = brainConfig.Hysteresis or MonsterConstants.DefaultHysteresis,
		accumulator = 0,
		dirty      = true,
		candidates = {},
	}, Brain)

	-- Eligible = capability allows it AND the config weights it. Both halves
	-- matter: capabilities say what the monster CAN do, weights say how much
	-- this particular monster cares.
	local weights = instance.config.States or {}
	local added = {}

	local function addCandidate(name: string, weight: number)
		if added[name] then
			return
		end
		local module = States.Get(name)
		if not module then
			return
		end
		added[name] = true
		table.insert(self.candidates, {
			name   = name,
			module = module,
			weight = weight,
			band   = module.Band or 0,
		})
	end

	for name in pairs(instance.config.StateSet or {}) do
		if weights[name] then
			addCandidate(name, weights[name].Weight or 1)
		end
	end

	-- Always-available states (Idle, Reset) need no capability. Without Idle a
	-- monster whose every state scores nil has nothing valid to run; without
	-- Reset a stuck monster has no recovery path. Both are inert when they
	-- have nothing to do.
	--
	-- A config MAY weight them to tune how readily the monster idles or
	-- leashes; addCandidate's dedupe means that overrides the default rather
	-- than dropping the state. Getting this wrong (skipping the always-state
	-- when a weight exists) would silently delete Idle from any config that
	-- tried to tune it, leaving the monster with no fallback.
	for _, name in ipairs(States.Always) do
		local weighted = weights[name]
		addCandidate(name, weighted and (weighted.Weight or 1) or 1)
	end

	return self
end

function Brain:Start()
	for _, event in ipairs(WAKE_EVENTS) do
		self.instance.trove:Add(self.instance.bus:On(event, function()
			self.dirty = true
		end))
	end
end

function Brain:Wake()
	self.dirty = true
end

-- Returns the winning candidate, or nil if nothing is eligible.
function Brain:Select()
	local blackboard = self.instance.blackboard
	local bestBand, bestScore, best = -math.huge, -math.huge, nil

	for _, candidate in ipairs(self.candidates) do
		local utility = candidate.module.Score(self.instance, blackboard)

		if utility ~= nil then
			-- A state returning an unnormalized score would silently dominate
			-- every band-mate, so clamp rather than trust.
			utility = math.clamp(utility, 0, 1)
			local score = utility * candidate.weight

			if candidate.band > bestBand or (candidate.band == bestBand and score > bestScore) then
				bestBand, bestScore, best = candidate.band, score, candidate
			end
		end
	end

	return best, bestScore, bestBand
end

function Brain:Evaluate()
	self.dirty = false

	local machine = self.instance.stateMachine
	local pick, score, band = self:Select()
	if not pick then
		return
	end

	if pick.name == machine.current then
		return
	end

	-- Hysteresis applies WITHIN a band only: a challenger has to be clearly
	-- better than the incumbent to justify the switch, which is what stops two
	-- near-tied states oscillating. A higher band ignores it by design.
	local currentModule = machine.module
	if currentModule and (currentModule.Band or 0) == band then
		local currentUtility = currentModule.Score(self.instance, self.instance.blackboard)
		if currentUtility ~= nil then
			local currentWeight = 1
			for _, candidate in ipairs(self.candidates) do
				if candidate.name == machine.current then
					currentWeight = candidate.weight
					break
				end
			end

			if score <= math.clamp(currentUtility, 0, 1) * currentWeight * self.hysteresis then
				return
			end
		end
	end

	machine:Transition(pick.name, pick.module.Band and pick.module.Band >= 2)
end

function Brain:Tick(dt: number)
	self.accumulator += dt

	if self.dirty or self.accumulator >= self.tickRate then
		self.accumulator = 0
		self:Evaluate()
	end
end

function Brain:Destroy()
	table.clear(self.candidates)
end

return Brain
