local MonsterStats = {}

-- Every stat that affects monster behavior lives here, keyed by MonsterId then
-- Stage. Stage 1 must be a full table; every later stage is a SPARSE override
-- merged on top of stage 1 (see MonsterStats.Get).

MonsterStats.Stats = {
	GreyCube = {
		[1] = {
			-- Above the player's WalkSpeed (16), below SprintSpeed (25): you
			-- cannot walk away from a GreyCube, you have to spend stamina.
			WalkSpeed        = 18,     -- studs/sec
			DetectRadius     = 60,     -- studs -- max distance it will target a player from
			LoseInterestDist = 90,     -- studs -- reserved for future Wandering/Checking states
			PursuitDuration  = 20,     -- secs -- how long it keeps hunting after losing the player
			AttackReach      = 4,      -- studs -- Touched-based hit; this mostly documents intent
			AttackCooldown   = 1,      -- secs -- per-player damage cooldown, prevents multi-hit per frame
			States = { "Chase" },      -- MVP: chase is the whole brain

			-- Chance (0-1) that a requested transition into this state actually
			-- happens. Keeps the state machine from being 100% predictable once
			-- more states exist. At 1.0 it's a no-op.
			TransitionChance = { Chase = 1.0 },
		},

		-- Sparse override, merged on top of stage 1. Reached from DeepNight
		-- (midnight) onward via MatchPhases.MonsterStage -> EncounterDirector
		-- .restageEncounter, so the same monster that was survivable at dusk
		-- hunts harder after midnight without respawning.
		--
		-- 23 leaves only 2 studs/sec of margin under SprintSpeed (25), so
		-- after midnight escaping costs stamina faster than it regenerates
		-- (drain 15/s vs regen 10/s) -- outrunning one is no longer free,
		-- it's a budget. DetectRadius/PursuitDuration widen the net to match.
		[2] = {
			WalkSpeed = 23,
			DetectRadius = 75,
			PursuitDuration = 30,
		},
	},
}

-- Merges every stage override from 2 up to `stage` on top of the Stage 1 base,
-- so a stage entry only needs to list what actually changed.
function MonsterStats.Get(monsterId: string, stage: number?)
	local monsterTable = MonsterStats.Stats[monsterId]
	if not monsterTable then
		warn("MonsterStats.Get: unknown monster '" .. tostring(monsterId) .. "'")
		return nil
	end

	local resolvedStage = stage or 1
	local base = monsterTable[1]
	if not base then
		warn("MonsterStats.Get: monster '" .. monsterId .. "' has no Stage 1 base table")
		return nil
	end

	if resolvedStage == 1 then
		return base
	end

	local merged = table.clone(base)
	for s = 2, resolvedStage do
		local override = monsterTable[s]
		if override then
			for key, value in pairs(override) do
				merged[key] = value
			end
		end
	end

	return merged
end

return MonsterStats
