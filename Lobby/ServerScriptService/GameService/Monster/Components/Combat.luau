-- Damage. Absorbs MonsterDamage.luau.
--
-- Two changes from the module it replaces, both consequences of being a
-- component rather than a global:
--
--   * The per-player hit cooldown was a weak-keyed module-level table keyed by
--     model. It's per-instance state now, so it dies with the monster and
--     needs no weak keys and no ClearAgent call.
--   * The Touched connection lived in MonsterService.Spawn, one layer away
--     from the code that decided what a hit meant. Combat owns both halves.
--
-- Two detection modes, chosen by config.Combat.Mode:
--
--   "Contact" -- rootPart.Touched. Correct for a simple model whose root IS
--                its whole visible, colliding body.
--   "Reach"   -- distance against Stats.AttackReach, checked on tick. Correct
--                for a real rig, where HumanoidRootPart is invisible,
--                CanCollide false, and buried inside the Torso -- a player
--                bumping the monster contacts the Torso, so Touched on the
--                root is an unreliable hitbox.

local Players = game:GetService("Players")

local Combat = {}
Combat.__index = Combat

Combat.Name = "Combat"
Combat.Writes = { "LastAttackAt" }
-- Only meaningful in Reach mode; Contact mode's Tick returns immediately.
Combat.TickRate = 0.1

-- config is accepted for interface symmetry and deliberately not captured:
-- instance.config is replaced wholesale on re-stage and evolution, so anything
-- held from construction would silently keep stage-1 values. Read through
-- self.instance.config instead.
function Combat.new(instance, _config)
	local self = setmetatable({
		instance    = instance,
		-- [userId] = os.clock() of last hit
		lastHitTime = {},
	}, Combat)

	instance.blackboard.LastAttackAt = 0

	return self
end

function Combat:Mode(): string
	local combatConfig = self.instance.config.Combat
	return (combatConfig and combatConfig.Mode) or "Contact"
end

function Combat:Start()
	if self:Mode() ~= "Contact" then
		return
	end

	local rootPart = self.instance.rootPart
	if not rootPart then
		return
	end

	-- Owned by the instance Trove, so teardown can't drift from setup.
	self.instance.trove:Add(rootPart.Touched:Connect(function(hit: BasePart)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if player then
			self:TryKill(player)
		end
	end))
end

-- Reach mode only. Deliberately scans every player rather than reading
-- Blackboard.VisibleTargets: standing on a monster should kill you whether or
-- not it has noticed you, and gating contact damage on perception would make a
-- blind monster harmless to touch.
function Combat:Tick(_dt: number)
	if self:Mode() ~= "Reach" then
		return
	end

	local rootPart = self.instance.rootPart
	if not rootPart or not rootPart.Parent then
		return
	end

	local reach = self.instance.config.Stats.AttackReach
	if not reach then
		return
	end

	local origin = rootPart.Position
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
		if targetRoot and (targetRoot.Position - origin).Magnitude <= reach then
			self:TryKill(player)
		end
	end
end

function Combat:TryKill(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	local now = os.clock()
	local cooldown = self.instance.config.Stats.AttackCooldown or 1
	local last = self.lastHitTime[player.UserId]
	if last and now - last < cooldown then
		return false
	end
	self.lastHitTime[player.UserId] = now

	humanoid.Health = 0

	self.instance.blackboard.LastAttackAt = now
	self.instance.bus:Fire("Killed", { UserId = player.UserId })
	return true
end

-- multiplier widens the reach for the caller's own purposes without changing
-- what Stats.AttackReach means -- Attack passes one so that releasing an
-- attack takes more distance than entering it. Kept here rather than letting
-- callers do their own distance math, so "in reach" has one definition.
function Combat:IsInReach(position: Vector3, multiplier: number?): boolean
	local rootPart = self.instance.rootPart
	local reach = self.instance.config.Stats.AttackReach
	if not rootPart or not reach then
		return false
	end
	return (position - rootPart.Position).Magnitude <= reach * (multiplier or 1)
end

function Combat:Destroy()
	table.clear(self.lastHitTime)
end

return Combat
