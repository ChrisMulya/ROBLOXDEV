-- Names and defaults shared by every part of the Monster Framework. Anything
-- a monster module would otherwise spell as a string literal or a magic number
-- lives here, so a rename is one edit rather than a grep.

local MonsterConstants = {}

-- Attribute names owned by the Monster Framework.
--
-- IsMonster is deliberately ABSENT: Reward/CaptureTargets owns it
-- (CaptureTargets.Types.Monster.Attribute) and is the only module allowed to
-- decide what it means. Get it from CaptureTargets.AttributeFor("Monster") --
-- mirroring the string here would be a second source of truth for exactly the
-- thing CLAUDE.md says must have one.
MonsterConstants.Attributes = {
	MonsterId       = "MonsterId",
	Stage           = "Stage",
	EvolutionTier   = "EvolutionTier",
	AIState         = "AIState",
	AggressionLevel = "AggressionLevel",
	IsMonsterSpawn  = "IsMonsterSpawn",
	-- Phase F: hand-placed navigation network. Same convention as
	-- IsMonsterSpawn -- an invisible BasePart carrying the attribute, plus an
	-- optional MonsterId attribute to restrict a point to one monster type.
	-- See PatrolGraph and States/Patrol.
	IsPatrolPoint   = "IsPatrolPoint",
	IsSearchPoint   = "IsSearchPoint",
}

-- Used when an IsMonsterSpawn point carries no MonsterId attribute.
MonsterConstants.DefaultMonsterId = "Monster1"
MonsterConstants.DefaultStage     = 1

-- Fallback when a state module declares no TickRate. Matches the literal that
-- was previously inline in MonsterService's Heartbeat.
MonsterConstants.DefaultTickRate = 0.1

MonsterConstants.DefaultBrainTickRate    = 0.2
-- Fraction of the gap to the target that SURVIVES one second, so lower is
-- faster. Rise applies while aggression is climbing, Decay while it falls.
--
-- They are deliberately far apart. Rise has to be fast or aggression lags the
-- real distance and the monster commits late; Decay has to be slow or the anger
-- is gone before the player can notice it was ever there. 0.15 is ~85% per
-- second, 0.9 is ~10% -- roughly a 7-second bleed-off.
MonsterConstants.DefaultAggressionRise   = 0.15
MonsterConstants.DefaultAggressionDecay  = 0.9
MonsterConstants.DefaultMinStateDuration = 0.5
-- How long a stimulus stays worth walking toward before Check gives up on it
-- as stale. Overridable per monster via Config.Perception.InvestigationWindow.
MonsterConstants.DefaultInvestigationWindow = 8
-- Check runs in three phases: travel to the stimulus, HOLD (stand and look
-- around), then SEARCH (sweep random points around it) before giving up.
-- All overridable under Config.Perception.
--
-- The hold alone used to be the whole arrival behaviour, and at 2s it read as
-- the monster touching the spot and immediately losing interest. The search
-- phase is what makes an investigation look like one.
MonsterConstants.DefaultInvestigationHold = 3
-- Randomised per investigation, so repeat visits to the same spot don't play
-- out on an identical, learnable timer.
MonsterConstants.DefaultSearchDurationMin = 10
MonsterConstants.DefaultSearchDurationMax = 20
-- How far from the stimulus the search points are drawn. Deliberately smaller
-- than hearing range: this is "sweep the area around the noise", not a second
-- patrol.
MonsterConstants.DefaultSearchRadius = 15
-- Beat spent standing at each search point before moving to the next.
MonsterConstants.DefaultSearchPause = 1.2
-- D7: how far from its spawn anchor Wander picks a fresh point, and how long
-- it stands still between points. Overridable via Config.Navigation
-- .WanderRadius; the pause has no per-monster override -- nothing has asked
-- for one yet.
MonsterConstants.DefaultWanderRadius = 20
MonsterConstants.DefaultWanderPause  = 1.5
MonsterConstants.DefaultHysteresis       = 1.1

-- Phase F: Config.Navigation.Patrol overrides any of these per monster. See
-- States/Patrol and plans/create-a-read-only-implementation-calm-ripple.md §20.
MonsterConstants.DefaultPatrolLinkRadius         = 60
MonsterConstants.DefaultPatrolForwardConeDegrees = 45
MonsterConstants.DefaultPatrolReverseCutoff      = -0.5
MonsterConstants.DefaultPatrolHistoryLength      = 2
-- Longer than any single leg should plausibly take; exists only to recover
-- from a path a closed door or a body-blocking player made impossible.
MonsterConstants.DefaultPatrolLegTimeout         = 30
-- Chance to stand still on reaching a PatrolPoint, and how long for. A monster
-- that walks its route at a constant pace reads as a patrolling machine; one
-- that occasionally stops to look around reads as something deciding where to
-- go next. Also gives a hiding player a window where the monster is stationary
-- and audible-adjacent rather than always closing distance.
MonsterConstants.DefaultPatrolPointPauseChance   = 0.15
MonsterConstants.DefaultPatrolPointPauseMin      = 3
MonsterConstants.DefaultPatrolPointPauseMax      = 5
MonsterConstants.DefaultPatrolSearchChance       = 0.3
MonsterConstants.DefaultPatrolSearchPointRadius  = 40
MonsterConstants.DefaultPatrolSearchScanInterval = 1
MonsterConstants.DefaultPatrolSearchDurationMin  = 10
MonsterConstants.DefaultPatrolSearchDurationMax  = 20
MonsterConstants.DefaultPatrolSearchSweepRadius  = 12
MonsterConstants.DefaultPatrolSearchPointCooldown = 90

-- Bands the AggressionLevel attribute is quantised into, highest Min first.
-- The raw scalar is never replicated: it would let a client read the exact
-- moment a monster is about to commit, which is a solve, not a tell.
--
-- These describe INTENSITY, not behaviour, and nothing may infer one from the
-- other. They are global while Aggression.Thresholds are per-monster, so the
-- two do not line up and are not meant to: Monster1 commits to a chase at 0.12,
-- well inside Low, so a monster can be mid-chase and read Low. That is correct.
--
-- Presentation (step 11) therefore picks the ANIMATION from the AIState
-- attribute and uses this only to modulate intensity -- playback speed, growl
-- volume, breathing. Reading behaviour out of this band would give a chasing
-- monster its calm animation set.
MonsterConstants.AggressionLevels = {
	{ Name = "High",   Min = 0.67 },
	{ Name = "Medium", Min = 0.34 },
	{ Name = "Low",    Min = 0 },
}

-- Debug-only Blackboard write guard. When true, MonsterInstance wraps the
-- blackboard in a __newindex proxy that rejects writes to keys no component
-- declared in Component.Writes. Off in production: the proxy costs a metamethod
-- call on every write, and the construction-time duplicate-writer assertion
-- (which is free) already catches the static case.
MonsterConstants.StrictBlackboard = false

-- Warns whenever a path computation fails and the monster falls back to
-- walking straight at its target, which is what "it stops chasing at range"
-- usually turns out to be: the straight line runs into geometry. Off by
-- default because a monster that legitimately cannot reach a player would spam
-- it. Turn on when tuning AgentParams.
MonsterConstants.DebugPathfinding = false

return MonsterConstants
