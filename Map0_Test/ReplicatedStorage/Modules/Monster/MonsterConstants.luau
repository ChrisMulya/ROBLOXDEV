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

-- Navmesh gap tolerance. Roblox has NO agent parameter for "ignore small
-- gaps": the navmesh either connects two surfaces or it does not, so a 2-stud
-- slit between two floor pieces splits the mesh and pathfinding either detours
-- the long way around it or refuses outright -- over an imperfection a player
-- walks across without noticing.
--
-- These drive a direct-route override in HumanoidPathLocomotion: a ground
-- break no wider than this, or a step no taller than this, is something the
-- Humanoid crosses on its own, so the pathfinder's answer is overridden and
-- the monster walks straight. Overridable per monster under Config.Navigation.
MonsterConstants.DefaultNavGapTolerance           = 2
-- Only probe for a direct route within this range. Bounds the cost: the probe
-- is one spherecast plus a ground raycast every GapTolerance/2 studs, and a
-- gap worth stepping over is a short-range problem.
MonsterConstants.DefaultNavDirectRouteMaxDistance = 40
-- How much longer than the straight line a computed path must be before it
-- counts as a detour worth second-guessing. Below this the navmesh and the
-- straight line agree and the probe is skipped entirely, which is the common
-- case and costs nothing.
MonsterConstants.DefaultNavDirectRouteDetourRatio = 1.5

-- Phase F: Config.Navigation.Patrol overrides any of these per monster. See
-- States/Patrol and plans/create-a-read-only-implementation-calm-ripple.md §20.
MonsterConstants.DefaultPatrolLinkRadius         = 60
-- Fallback radius used ONLY when nothing inside LinkRadius is selectable
-- without turning back into recent history. Points spaced further apart than
-- LinkRadius would otherwise be invisible to selection entirely, leaving the
-- monster bouncing between the two neighbours it can see -- radius must be a
-- cheaper concession than reversing, or sparse networks oscillate forever.
MonsterConstants.DefaultPatrolMaxLinkRadius      = 150
-- No longer read by selection (bearing clustering replaced the fixed forward
-- cone) -- retained so an existing config that sets it does not error.
MonsterConstants.DefaultPatrolForwardConeDegrees = 45
MonsterConstants.DefaultPatrolReverseCutoff      = -0.5
-- Visited-point ring size: how many of the monster's own last stops it will
-- not turn back into.
MonsterConstants.DefaultPatrolHistoryLength      = 3
-- Bearing gap (degrees) that starts a new "direction" cluster when candidate
-- PatrolPoints are sorted by angle from the monster's travel heading.
MonsterConstants.DefaultPatrolDirectionSplitDegrees   = 45
-- A cluster wider than this is split at its largest internal gap, so a fan of
-- points spanning a wide arc doesn't read as one direction.
MonsterConstants.DefaultPatrolDirectionMaxSpanDegrees = 90
-- Within a chosen direction, candidates within this many studs of the closest
-- one are tied and broken at random, so stacked/clustered points don't lock
-- to one deterministic pick.
MonsterConstants.DefaultPatrolDistanceTieStuds        = 4
-- How long a PatrolPoint that timed out or got the monster stuck is held out
-- of selection. Temporary, unlike the resolve-failure cache below -- the
-- block (a closed door, a body-blocking player) may clear.
MonsterConstants.DefaultPatrolDeferDuration           = 20
-- How long a PatrolPoint that failed ResolveReachable stays excluded before
-- being re-probed. Without this a point that was briefly unreachable (a door
-- shut when first checked) is excluded for the monster's entire lifetime.
MonsterConstants.DefaultPatrolUnreachableRetryAfter   = 60
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

-- LOS-loss investigation: how far past LastKnownPos the monster projects
-- along LastSeenDirection, continuing the player's escape trajectory instead
-- of stopping dead at the corner where sight broke. Overridable per monster
-- under Config.Investigation.
MonsterConstants.DefaultLoSProjectionMin = 10
MonsterConstants.DefaultLoSProjectionMax = 20
-- Window (seconds, ending at the moment sight was lost) sampled to derive
-- LastSeenDirection. Short on purpose -- a long window would smear a recent
-- turn into a stale average heading.
MonsterConstants.DefaultDirectionSampleWindow = 0.5
-- Minimum horizontal displacement across that window before a direction is
-- considered real rather than sensor/position noise. Below this the target
-- read as stationary and LastSeenDirection is left nil (no overshoot).
MonsterConstants.DefaultDirectionMinDisplacement = 1
-- How long after LoSLostAt the Visual investigation candidate stays eligible,
-- on top of PursuitDuration. Investigation is evaluated independently of
-- Chase's own pursuit window, so this is its own grace period.
MonsterConstants.DefaultVisualInvestigationGrace = 4

-- SearchPoint investigation (the phase after Check's initial sweep). All
-- overridable under Config.Investigation.
MonsterConstants.DefaultSearchPointEnabled = true
MonsterConstants.DefaultInvestigationSearchPointRadius = 40
MonsterConstants.DefaultInvestigationSearchPointMinDistance = 6
MonsterConstants.DefaultInvestigationSearchPointFocusRadius = 40
-- Maximum angle (degrees) a SearchPoint may sit off LastSeenDirection,
-- measured from LastKnownPos, to count as relevant to THIS investigation.
-- Skipped (full 360) when there is no direction.
MonsterConstants.DefaultSearchPointConeDegrees = 120
-- Reject a SearchPoint whose resolved ground height differs from the
-- monster's current height by more than this -- the "different floor" gate.
MonsterConstants.DefaultSearchPointMaxElevationDelta = 12
-- How long a checked SearchPoint is excluded from re-selection.
MonsterConstants.DefaultInvestigationSearchPointCooldown = 90
-- How many SearchPoints one investigation will visit before giving up and
-- lingering. Caps searchpoint -> scan from chaining indefinitely.
MonsterConstants.DefaultSearchPointsPerInvestigation = 1
-- An occluded (no-LOS-from-monster) SearchPoint is demoted, not rejected --
-- dead ends and rooms around a corner are exactly where a player hides -- but
-- only chosen when no LOS-clear candidate exists. Set false to hard-reject.
MonsterConstants.DefaultAllowOccludedSearchPoints = true

-- Refinement 2: after LOS breaks, Check settles for this long (measured from
-- LoSLostAt) before committing to a PatrolPoint -- a readable "lost you" beat
-- rather than reacting instantly. Not a stimulus; a phase timer over
-- information Targeting already wrote. Overridable under Config.Investigation.
MonsterConstants.DefaultLoSLostSettleDelay = 1

-- PatrolPoint relocation after a Visual LOS-loss investigation: the monster
-- continues the player's escape route to a PatrolPoint rather than milling at
-- LastKnownPos. Discovery is 360 degrees around the investigation focus, NOT
-- gated by a directional cone (unlike SearchPoints) -- direction only ranks
-- candidates, never rejects one, so a PatrolPoint behind the monster is still
-- selected when it's all that exists. All overridable under Config.Investigation.
MonsterConstants.DefaultInvestigationPatrolPointRadius = 60
MonsterConstants.DefaultInvestigationPatrolPointMinDistance = 6
-- How long a checked PatrolPoint is excluded from re-selection.
MonsterConstants.DefaultInvestigationPatrolPointCooldown = 45
-- Bounded retries (stuck/unreachable) before falling through to SearchPoint
-- investigation rather than grinding on the same failed selection.
MonsterConstants.DefaultPatrolPointSelectAttempts = 2
-- Anti-stall deadline for the whole PatrolPoint travel phase. Displacement-
-- based stuck detection (Navigation's STUCK_WINDOW/STUCK_DISTANCE) can miss a
-- monster that is moving but not actually making progress (slow circling);
-- this is the belt-and-braces backstop.
MonsterConstants.DefaultPatrolPointTravelTimeout = 20
-- Randomised per investigation, same reasoning as SearchDurationMin/Max: a
-- flat duration would be the only non-randomised beat in the whole chain.
MonsterConstants.DefaultPatrolPointWanderMin = 4
MonsterConstants.DefaultPatrolPointWanderMax = 6
-- How far from the PatrolPoint the wander roams. Deliberately tight -- this
-- is a brief look-around at a route node, not working an area, and a wide
-- radius reads as aimless drifting rather than checking a spot. Note
-- Navigation's MIN_ROAM_DISTANCE (2) discards rolls shorter than that, so
-- shrinking this much further starts costing re-rolls instead of tightening
-- the pattern.
MonsterConstants.DefaultPatrolPointWanderRadius = 8

-- Deliberate visual scan performed at a SearchPoint: rotate left, then right,
-- then return, while normal perception/LOS stays active throughout.
--
-- The sweep travels 640 degrees in total, not 160: out to one extreme (160),
-- across to the other (320), then back to the starting heading (160). So the
-- scan costs 640/Speed seconds of rotation plus one Pause at each of the
-- three leg ends -- ~6.5s at the current values. Still deliberate rather than
-- a snap; drop Speed toward 60 if it should read slower.
MonsterConstants.DefaultScanSweepDegrees = 160
MonsterConstants.DefaultScanSpeed = 120 -- degrees/second
MonsterConstants.DefaultScanPause = 0.4 -- seconds held at each extreme

-- After a completed (nothing found) SearchPoint scan: wander the area for a
-- randomised duration before leaving and resuming Patrol. Kept in the same
-- 4-8s band as the PatrolPoint wander above -- both are "look around briefly
-- and move on", and a long tail here is what made the whole investigation
-- chain outstay its welcome.
MonsterConstants.DefaultPostSearchLingerMin = 4
MonsterConstants.DefaultPostSearchLingerMax = 8
MonsterConstants.DefaultPostSearchLingerRadius = 8

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

-- Prints one line per PatrolPoint selection: cluster count, chosen bearing,
-- chosen point. Off by default; turn on to verify direction-split behaviour
-- (e.g. T-junction 50/50) in Studio, since that's impractical to eyeball.
MonsterConstants.DebugPatrol = false

-- Prints Investigation's candidate arbitration (Visual/Trail/Stimulus) and
-- SearchPoint selection decisions. Off by default; turn on to verify LOS-loss
-- projection and SearchPoint gating in Studio.
MonsterConstants.DebugInvestigation = false

return MonsterConstants
