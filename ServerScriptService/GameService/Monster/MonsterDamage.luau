local MonsterDamage = {}

-- Per-monster, per-player hit cooldown so a single Touched frame (or a player
-- standing inside the hitbox) can't fire multiple kills instantly.
-- lastHitTime[monsterModel][userId] = os.clock()
-- Weak-keyed so a monster Model removed via `model.Parent = nil` (rather than
-- :Destroy(), which ClearAgent already handles explicitly) doesn't stay
-- pinned in memory forever by this table.
local lastHitTime = setmetatable({}, { __mode = "k" })

local function getCooldownTable(agent)
	local key = agent.model
	if not lastHitTime[key] then
		lastHitTime[key] = {}
	end
	return lastHitTime[key]
end

function MonsterDamage.TryKill(agent, player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local cooldowns = getCooldownTable(agent)
	local now = os.clock()
	local cooldown = agent.stats.AttackCooldown or 1

	if cooldowns[player.UserId] and now - cooldowns[player.UserId] < cooldown then
		return
	end
	cooldowns[player.UserId] = now

	humanoid.Health = 0

	if agent.behavior and agent.behavior.OnKill then
		agent.behavior.OnKill(agent, player)
	end
end

-- Call when a monster is despawned so its cooldown table doesn't leak.
function MonsterDamage.ClearAgent(agent)
	lastHitTime[agent.model] = nil
end

return MonsterDamage
