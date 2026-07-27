local MonsterSensing = require(script.Parent.Parent.MonsterSensing)
local MonsterMovement = require(script.Parent.Parent.MonsterMovement)
local MonsterDamage = require(script.Parent.Parent.MonsterDamage)

local Chase = {}
Chase.Name = "Chase"
Chase.TickRate = 0.1

function Chase.Enter(agent) end

function Chase.Exit(agent) end

function Chase.Update(agent, dt: number)
	local rootPart = agent.rootPart
	if not rootPart or not rootPart.Parent then return nil end

	local player, targetPos = MonsterSensing.GetNearestPlayer(rootPart.Position, agent.stats.DetectRadius)

	if player and targetPos then
		agent.target = player
		agent.lastKnownPos = targetPos
		agent.lastSeenAt = os.clock()

		local distance = (targetPos - rootPart.Position).Magnitude
		if distance <= agent.stats.AttackReach then
			MonsterDamage.TryKill(agent, player)
		else
			MonsterMovement.MoveTo(agent, targetPos, dt)
		end
	elseif agent.lastKnownPos then
		-- MVP has no Checking state yet -- just keep walking to the last known
		-- spot and stop once PursuitDuration runs out (see MONSTERS.md step 5).
		if os.clock() - agent.lastSeenAt > agent.stats.PursuitDuration then
			agent.target = nil
			agent.lastKnownPos = nil
		else
			MonsterMovement.MoveTo(agent, agent.lastKnownPos, dt)
		end
	end

	return nil -- MVP only has one state; nothing to transition to yet
end

return Chase
