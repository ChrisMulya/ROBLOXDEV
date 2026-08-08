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
			-- 80, not the 60 inherited from GreyCube. That 60 was tuned when
			-- vision had no cone and no line-of-sight -- 60 studs in every
			-- direction, through walls. A 120 degree cone plus LOS cuts the
			-- effective detection volume to roughly a third, so keeping 60
			-- silently made the monster far blinder than it was ever meant to
			-- be. This restores the intended threat range while keeping the
			-- rules (cone, occlusion) that make it fair.
			DetectRadius    = 80,
			PursuitDuration = 20,
			AttackReach     = 5,
			AttackCooldown  = 1,
			-- Above the max chase envelope, computed from the HIGHEST *effective*
			-- speed, which since Limits.WalkSpeed.Max was removed is the
			-- EVOLVED stage-2 speed, not the raw stage-2 stat:
			--   DetectRadius + (WalkSpeed * EvolutionMultiplier) * PursuitDuration
			--   stage 2 evolved: 100 + (24 * 1.3) * 30 = 100 + 31.2 * 30 = 1036
			-- Recompute whenever DetectRadius, WalkSpeed, PursuitDuration OR any
			-- Evolution tier's WalkSpeed multiplier changes -- this has already
			-- been wrong three times, twice before evolution even existed to
			-- complicate it. Below the envelope the monster leashes
			-- mid-legitimate-chase, which reads as it randomly giving up rather
			-- than as the recovery path it is.
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
			DetectRadius    = 100,
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
		DetectRadius = { Max = 140 },
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
		-- actually play against. 120 is generous enough that flanking takes
		-- intent rather than luck.
		Sensors = { Vision = { FOV = 120, RequiresLOS = true } },
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
		AgentParams = {
			AgentRadius  = 1.5,
			AgentHeight  = 5,
			AgentCanJump = false,
		},
	},

	-- Tuned so the monster still commits at close to the range it did before
	-- aggression existed, rather than sitting at 0.15 forever and looking
	-- broken. The numbers are coupled -- changing one without re-deriving the
	-- others is how this ends up feeling dead:
	--
	--   Ease, not InverseSquare. InverseSquare needs closeness 0.91 to clear a
	--   0.5 threshold -- roughly 7 studs on an 80-stud DetectRadius, so the
	--   monster would ignore you across a room. Ease climbs fast instead:
	--   half range already reads 0.75.
	--
	--   Threshold 0.15 with Proximity weight 0.7 puts the commit point at
	--   about 70 of the 80 studs it can see. MatchTime adds up to 0.3 on top
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
	--   Proximity 0.85 so the ceiling is reachable without MatchTime: at 10
	--   studs the target is 0.85 * Ease(0.875) = 0.84, comfortably into High
	--   (0.67). At weight 0.7 the peak was 0.689 -- over the band by 0.02 and
	--   only asymptotically, so High could not be observed before the monster
	--   reached AttackReach.
	--
	--   Threshold 0.12 puts the crossing at ~74 studs of the 80 it can see.
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
	Evolution = {
		Tiers = {
			Witching = { AtHour = 27, Stats = { WalkSpeed = 1.3 }, Stacks = false },
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
