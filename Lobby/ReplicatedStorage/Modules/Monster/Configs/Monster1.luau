-- The reference monster: clones ReplicatedStorage/Assets/Monster/Monster1.
--
-- Also the template for every monster after it. Adding one is this file and
-- nothing else -- Configs/init discovers it by its presence, capabilities
-- decide which components and states it gets, and no existing file changes.
--
-- Stats are declared inline here. There is no shared stats module: a monster
-- owns its own numbers, so tuning one can never move another.

return {
	Id          = "Monster1",
	DisplayName = "Monster",

	Model = { Source = "Asset", Path = "Monster1" },

	Capabilities = {
		"CanNavigate",
		"CanSee",
		"CanChase",
		"CanAttack",
		"CanEvolve",
		-- D4/D5/D6: hearing, flash-sight, and investigation. CanHear/
		-- CanSeeFlash build their sensors at D3 even though nothing publishes
		-- either kind until D5/D6 -- harmless, and means neither needs a
		-- further edit to this file once its emitter lands.
		"CanHear",
		"CanSeeFlash",
		"CanInvestigate",
		-- D7: pairs with Check -- a monster that finishes investigating a
		-- stimulus releases into Wander rather than standing still.
		"CanWander",
		-- Phase F: the actual default now. Scores above Wander (0.35 vs 0.3),
		-- so this monster patrols the map's IsPatrolPoint network and only
		-- falls back to aimless Wander if the graph has nothing to offer it
		-- (no points authored, or none reachable from wherever it is).
		"CanPatrol",
	},

	Stats = {
		[1] = {
			-- The PURSUIT speed, not a single speed for every state. Wander and
			-- Patrol run at half this and Check at three quarters, via each
			-- state's SpeedScale -- so a monster moving at full 20 is a monster
			-- that has seen you, and that difference is readable from across a
			-- room. Override per state with States.<Name>.SpeedScale.
			--
			-- Sits between the player's WalkSpeed (10) and SprintSpeed (25),
			-- which is the whole chase dynamic in one number: walking away from
			-- this is impossible, sprinting away works but spends stamina. 20
			-- leaves a 5 stud/sec sprint margin -- more breathing room than 22
			-- did, at the cost of an escape being less of a knife-edge.
			WalkSpeed       = 20,
			-- Doubled from 80 on request. History: 80 replaced the 60 inherited
			-- from GreyCube, which was tuned when vision had no cone and no
			-- line-of-sight (60 studs in every direction, through walls); a
			-- cone plus LOS cuts the effective detection VOLUME to roughly a
			-- third, so 60 had silently made the monster far blinder than
			-- intended.
			--
			-- At 160 with a 150 degree cone the monster sees most of a mall
			-- corridor end to end. LOS is what keeps this fair -- the counter
			-- play is geometry, not distance, so open sightlines are now
			-- genuinely dangerous and cover is genuinely worth using. Watch for
			-- the monster committing from across an atrium; if that reads as
			-- unfair, this is the number to walk back, not the cone.
			DetectRadius    = 160,
			PursuitDuration = 20,
			AttackReach     = 5,
			AttackCooldown  = 1,
			-- Chance to stand still for a few seconds on reaching a
			-- PatrolPoint. Lives in Stats rather than Navigation.Patrol so the
			-- Evolution tier below can multiply it to zero -- see
			-- States/Patrol's pauseChanceFor for why that asymmetry exists.
			PatrolPauseChance = 0.15,
			-- Above the max chase envelope, computed from the HIGHEST *effective*
			-- speed, which since Limits.WalkSpeed.Max was removed is the
			-- EVOLVED stage-2 speed, not the raw stage-2 stat:
			--   DetectRadius + (WalkSpeed * EvolutionMultiplier) * PursuitDuration
			--   stage 2 evolved: 200 + (24 * 1.3) * 30 = 200 + 31.2 * 30 = 1136
			-- Recompute whenever DetectRadius, WalkSpeed, PursuitDuration OR any
			-- Evolution tier's WalkSpeed multiplier changes -- this has already
			-- been wrong three times, twice before evolution even existed to
			-- complicate it. Below the envelope the monster leashes
			-- mid-legitimate-chase, which reads as it randomly giving up rather
			-- than as the recovery path it is.
			--
			-- 1200 still clears 1136, so doubling DetectRadius did not require
			-- moving this -- but the margin is down from 164 to 64 studs.
			-- Another DetectRadius bump will need this raised with it.
			LeashDistance   = 1200,
		},
		[2] = {
			-- Must stay above stage 1 (20) or the difficulty ramp inverts at
			-- midnight. 24 is now an UNCLAMPED stat, not a value pinned to a
			-- removed ceiling -- see the WalkSpeed Limits note below for what
			-- that means once evolution multiplies it.
			WalkSpeed       = 24,
			-- Must stay above stage 1 or the difficulty ramp inverts at
			-- midnight, which is the opposite of what a stage bump is for.
			-- Doubled alongside stage 1 to preserve that ordering.
			DetectRadius    = 200,
			PursuitDuration = 30,
		},
	},

	Limits = {
		-- Max removed on request. WalkSpeed no longer has a ceiling -- Min = 4
		-- remains so nothing (a future debuff, a mistuned modifier) can stat
		-- the monster down to a crawl or zero.
		--
		-- CONSEQUENCE: at hour 27 (DeepNight, stage 2), the Witching tier's
		-- 1.3x multiplier now actually applies instead of clamping back to 24
		-- -- 24 * 1.3 = 31.2, which is FASTER than the player's SprintSpeed
		-- (25). From that hour on, a player who has been seen can no longer
		-- out-sprint this monster; going quiet and breaking the trail (see
		-- Targeting:FollowTrail) becomes the only escape once it commits.
		-- That may be exactly the late-match escalation you want -- it just
		-- was not possible before this change, and previously required a
		-- different lever (teleport, minions) precisely because raw speed was
		-- capped under SprintSpeed on purpose.
		WalkSpeed    = { Min = 4 },
		-- Raised from 140 with the DetectRadius doubling. 140 would have
		-- CLAMPED both new values (160 and 200) straight back down, silently
		-- undoing the change and leaving stage 2 no sharper than stage 1 --
		-- the same trap Limits.WalkSpeed.Max sprang on the evolution tier.
		-- Kept as a ceiling rather than removed: unlike WalkSpeed, nothing
		-- wants DetectRadius unbounded, and 220 leaves headroom for a future
		-- perception multiplier without letting one make the monster omniscient.
		DetectRadius = { Max = 220 },
	},

	Brain = {
		TickRate         = 0.2,
		MinStateDuration = 0.5,
		Hysteresis       = 1.1,
	},

	States = {
		Chase = { Weight = 1.0, TickRate = 0.1 },
		-- Band 0, same as Idle -- weight just has to comfortably clear Idle's
		-- constant 0.01, which any real stimulus score does. Chase (Band 1)
		-- always outranks this regardless of weight.
		Check  = { Weight = 1.0, TickRate = 0.1 },
		Wander = { Weight = 1.0, TickRate = 0.5 },
		-- Required for Patrol to ever be a Brain candidate at all -- CanPatrol
		-- only grants the CAPABILITY; without a weight row here the state is
		-- never added to Brain.candidates, same rule every state in this
		-- table follows (see Attack's identical note below).
		Patrol = { Weight = 1.0, TickRate = 0.5 },
		-- D7: required for Attack to ever be a Brain candidate at all --
		-- CanAttack only grants the CAPABILITY (and the Combat component);
		-- without a weight row here the state is never added to
		-- Brain.candidates, same rule every other state in this table follows.
		Attack = { Weight = 1.0, TickRate = 0.1 },
	},

	Perception = {
		-- A real cone, unlike GreyCube's 360: this rig has a face, so "it
		-- didn't see me, I was behind it" is a readable rule the player can
		-- actually play against.
		--
		-- FULL width, not a half-angle -- VisionSensor halves it for the cone
		-- test. 150 leaves a 210 degree blind arc behind the monster, so
		-- flanking still works but is a much tighter window than the 240 degree
		-- blind arc 120 gave; getting behind it now takes real commitment
		-- rather than a casual sidestep.
		Sensors = { Vision = { FOV = 150, RequiresLOS = true } },
	},

	Navigation = {
		Locomotion = "HumanoidPath",
		-- Sized to the actual rig: HumanoidRootPart is 2 x 3 x 1 and an R6
		-- character stands about 5 studs.
		--
		-- AgentRadius is the number to suspect when a monster stops chasing at
		-- range: it demands a corridor twice this wide, so 2 needed 4 clear
		-- studs and failed to path through normal mall furniture. On failure
		-- the monster straight-lines and snags on geometry, which reads as
		-- "it gave up". 1.5 still respects doorways without being precious
		-- about clutter. Raise it if the monster starts clipping corners.
		-- AgentCanJump is the BACKUP for broken navmesh, not the primary answer.
		-- With it off, a gap the mesh won't span leaves the monster detouring
		-- or refusing outright; with it on, the mesh can bridge one. But a jump
		-- is loud and readable, and a monster hopping over a 2-stud floor slit
		-- looks wrong -- so HumanoidPathLocomotion probes for a straight walk
		-- first and overrides any route that jumps a gap it could have strolled
		-- across. Jumping survives only where walking genuinely cannot reach.
		-- Tune the threshold via Config.Navigation.GapTolerance.
		AgentParams = {
			AgentRadius  = 1.5,
			AgentHeight  = 5,
			AgentCanJump = true,
		},
	},

	-- Tuned so the monster still commits at close to the range it did before
	-- aggression existed, rather than sitting at 0.15 forever and looking
	-- broken. The numbers are coupled -- changing one without re-deriving the
	-- others is how this ends up feeling dead.
	--
	-- Every stud figure below is a FRACTION OF DetectRadius, not an absolute.
	-- The derivation was done at DetectRadius 80; the stud numbers quoted are
	-- the current 160. The proportions are what the tuning actually fixes, so
	-- they survived the doubling untouched -- but the absolute distances did
	-- not, which is the whole reason a 160-stud radius plays so differently:
	--
	--   Ease, not InverseSquare. InverseSquare needs closeness 0.91 to clear a
	--   0.5 threshold -- roughly 14 studs of a 160-stud DetectRadius, so the
	--   monster would ignore you across a room. Ease climbs fast instead:
	--   half range already reads 0.75.
	--
	--   Threshold 0.15 with Proximity weight 0.7 puts the commit point at
	--   about 87% of what it can see. MatchTime adds up to 0.3 on top
	--   as the night wears on, which walks that out to the full radius --
	--   the ramp is the point.
	--
	--   Rise 0.15 / Decay 0.9. Every number below is derived for the DAYTIME
	--   case, where MatchTime contributes 0 and Proximity is the only driver.
	--   Tuning against the night case is the mistake that produced the first
	--   pass: it silently assumed 0.3 of headroom that does not exist for most
	--   of a match, which put the top band out of reach and the commit point
	--   ~10 studs short.
	--
	--   Proximity 0.85 so the ceiling is reachable without MatchTime: at 20
	--   studs the target is 0.85 * Ease(0.875) = 0.84, comfortably into High
	--   (0.67). At weight 0.7 the peak was 0.689 -- over the band by 0.02 and
	--   only asymptotically, so High could not be observed before the monster
	--   reached AttackReach.
	--
	--   Threshold 0.12 puts the crossing at ~148 studs of the 160 it can see.
	--   Rise is fast enough that the lag costs only a few studs rather than
	--   the ~10 that a symmetric rate cost.
	--
	--   The sum of the weights exceeds 1 on purpose. The target is clamped, so
	--   MatchTime's job at night is to hold aggression at the ceiling from
	--   further out, not to raise a ceiling Proximity cannot already reach.
	Aggression = {
		Rise       = 0.15,
		Decay      = 0.9,
		Modifiers  = {
			Proximity = { Weight = 0.85, Curve = "Ease" },
			MatchTime = { Weight = 0.3, Curve = "NightRamp" },
		},
		Thresholds = { Chase = 0.12 },
	},

	-- Reach, not Contact: on this rig HumanoidRootPart is invisible,
	-- CanCollide false and buried inside the Torso, so a player bumping the
	-- monster contacts the Torso and Touched on the root is unreliable.
	Combat = { Mode = "Reach", Lethal = true },

	-- Hour 27 (3 AM) -- the schedule's DeepNight phase (stage 2 since hour 24),
	-- so this multiplies stage 2's WalkSpeed: 24 * 1.3 = 31.2. No longer
	-- clamped -- see the Limits.WalkSpeed note above for what that means
	-- (faster than the player's SprintSpeed) and LeashDistance for the
	-- envelope this now has to stay above.
	--
	-- PatrolPauseChance = 0 multiplies the 0.15 loitering chance to exactly
	-- zero, so from 3 AM the monster never stops at a PatrolPoint again -- it
	-- just keeps moving, permanently. Multiplying by zero rather than setting
	-- an absolute is what keeps this inside the Stats-only evolution pipeline
	-- that actually ships (plans/EvolutionPlan.md); a `Set`-shaped operation
	-- is declared in the blueprint's pipeline but has no implementation.
	--
	-- Note this is one-way: nothing un-multiplies a zero, so a later tier
	-- could never restore loitering. That is correct for an escalation ladder
	-- and worth knowing before writing a tier that tries.
	Evolution = {
		Tiers = {
			Witching = {
				AtHour = 27,
				Stats  = { WalkSpeed = 1.3, PatrolPauseChance = 0 },
				Stacks = false,
			},
		},
	},

	Presentation = { AnimationSet = "Monster1", SFXSet = "Monster1" },
}

--[[
RIG VERIFIED (Studio inspection, both places):

  Torso with all five R6 joints (Neck, both Shoulders, both Hips)
  HumanoidRootPart 2x2x1, Transparency 1, CanCollide false, Anchored false
  RootJoint Motor6D, Part0 = HumanoidRootPart, Part1 = Torso
  PrimaryPart = HumanoidRootPart
  Humanoid: MaxHealth 100, RigType R6, AutomaticScalingEnabled false

Torso.Anchored is true in the template. Harmless -- MonsterFactory unanchors
the whole assembly at spawn for HumanoidPath -- but fix it in Studio if you
ever want to test the template in place.

This is MonsterConstants.DefaultMonsterId, so any Workspace part with
IsMonsterSpawn = true spawns it. Set a MonsterId attribute to override.
--]]
