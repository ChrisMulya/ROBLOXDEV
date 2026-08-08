-- Sole writer of Blackboard.Aggression: one scalar in [0,1] describing how
-- worked up this monster is. Many things read it; exactly one thing computes
-- it, which is the rule that keeps "why is it angry" answerable.
--
-- Always constructed (MonsterCapabilities.AlwaysOn), for the same reason
-- Targeting is: something has to own the key, and a monster that declares no
-- Aggression config simply sits at 0 forever with an empty modifier loop. That
-- is cheaper than making every reader nil-check.
--
-- The accumulation is exponential smoothing toward a weighted target:
--
--   target = clamp01( sum over modifiers of Weight * Evaluate() )
--   A     += (target - A) * (1 - Decay^dt)
--
-- The blueprint wrote this as `A * Decay^dt + sum(...)`, which is degenerate:
-- with Decay 0.85 at a 0.2s tick, old value retention is 0.9678, so ANY
-- non-zero modifier sum compounds to 1.0 within a couple of seconds and
-- aggression is permanently pinned. Smoothing keeps Decay meaning what it
-- reads as -- how much of the old value survives per second -- while making
-- the modifier sum a genuine target rather than an increment, and it is
-- symmetric: anger bleeds off at the same rate it built.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterConstants = require(ReplicatedStorage.Modules.Monster.MonsterConstants)
local AggressionModifiers = require(script.Parent.Parent.Aggression.AggressionModifiers)

local Aggression = {}
Aggression.__index = Aggression

Aggression.Name = "Aggression"
-- ThreatMap is in the blueprint but deliberately not claimed here: per-player
-- threat has no consumer yet, and reserving a key nothing writes makes it look
-- implemented. Whoever adds it adds it to this list.
Aggression.Writes = { "Aggression" }
Aggression.TickRate = 0.2

-- config is not captured: see GetSettings. The parameter exists for interface
-- symmetry with every other component.
function Aggression.new(instance, _config)
	local self = setmetatable({
		instance = instance,
		level    = nil,
	}, Aggression)

	instance.blackboard.Aggression = 0

	return self
end

function Aggression:Start()
	self:_publishLevel(0)
end

-- Read fresh, never the constructor's copy. instance.config is REPLACED
-- wholesale on re-stage and on evolution, and an evolution tier is exactly the
-- kind of thing that would retune Decay or a threshold.
function Aggression:GetSettings()
	return self.instance.config.Aggression
end

-- Quantised Low/Medium/High, never the raw float. The attribute replicates, and
-- handing clients the exact scalar hands them a solve: they could read the
-- precise moment a monster is about to commit. Presentation (step 11) reads
-- this band, which is all it needs to pick an animation or a growl.
local function levelFor(value: number): string
	for _, band in ipairs(MonsterConstants.AggressionLevels) do
		if value >= band.Min then
			return band.Name
		end
	end
	return MonsterConstants.AggressionLevels[#MonsterConstants.AggressionLevels].Name
end

function Aggression:_publishLevel(value: number)
	local level = levelFor(value)
	if level == self.level then
		return
	end
	self.level = level
	self.instance.model:SetAttribute(MonsterConstants.Attributes.AggressionLevel, level)
end

-- Weighted sum of every modifier this monster names. Unknown names warn once
-- via the registry miss below rather than every tick.
function Aggression:_target(settings, dt: number): number
	local total = 0

	for name, modifierSettings in pairs(settings.Modifiers or {}) do
		local fn = AggressionModifiers.Get(name)
		if fn then
			local value = fn(self.instance, self.instance.blackboard, dt, modifierSettings)
			total += (modifierSettings.Weight or 0) * math.clamp(tonumber(value) or 0, 0, 1)
		else
			-- Once per bad NAME, not once per tick and not once per component:
			-- a config with two typos should report both.
			self._warned = self._warned or {}
			if not self._warned[name] then
				self._warned[name] = true
				warn(("Aggression: monster '%s' names unregistered modifier '%s'")
					:format(self.instance.monsterId, tostring(name)))
			end
		end
	end

	return math.clamp(total, 0, 1)
end

-- Any threshold the config declares, crossed in either direction, wakes the
-- Brain. Polling alone would leave up to a full Brain tick between "angry
-- enough to chase" and actually chasing, which is the same latency bug that
-- made WAKE_EVENTS necessary in the first place.
function Aggression:_checkThresholds(settings, previous: number, current: number)
	for name, threshold in pairs(settings.Thresholds or {}) do
		if (previous < threshold) ~= (current < threshold) then
			self.instance.bus:Fire("AggressionThreshold", {
				Name     = name,
				Value    = current,
				Crossed  = current >= threshold,
			})
		end
	end
end

function Aggression:Tick(dt: number)
	local blackboard = self.instance.blackboard
	local previous = blackboard.Aggression or 0

	local settings = self:GetSettings()
	if not settings then
		-- No config, no drivers. Stays at whatever it was -- which is 0, since
		-- nothing else may write this key.
		return
	end

	local target = self:_target(settings, dt)

	-- Asymmetric by design: noticing is fast, forgetting is slow.
	--
	-- A single rate cannot do both, and the failure is not subtle. Tuned fast
	-- enough to commit at a believable distance, anger also vanishes the instant
	-- you break line of sight -- Proximity reads 0 with no visible target, so
	-- there is nothing holding it up. Tuned slow enough to linger, aggression
	-- lags the real distance by its whole time constant: at 40%/sec and a 16
	-- stud/sec approach it reports where you were ~10 studs ago, which drags the
	-- commit point in and makes the top band unreachable during an approach.
	--
	-- Rise governs target > current, Decay governs target < current. Both are
	-- "fraction of the current value surviving one second", so lower is faster.
	local rate = if target > previous
		then (settings.Rise or MonsterConstants.DefaultAggressionRise)
		else (settings.Decay or MonsterConstants.DefaultAggressionDecay)

	-- 1 - rate^dt is the fraction of the gap closed this tick. Frame-rate
	-- independent by construction: two 0.1s ticks close the same fraction as
	-- one 0.2s tick.
	local current = previous + (target - previous) * (1 - rate ^ dt)
	current = math.clamp(current, 0, 1)

	blackboard.Aggression = current
	self:_checkThresholds(settings, previous, current)
	self:_publishLevel(current)
end

function Aggression:Destroy() end

return Aggression
