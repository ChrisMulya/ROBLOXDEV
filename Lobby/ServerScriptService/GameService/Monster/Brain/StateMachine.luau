-- Runs the active state. Does NOT choose it -- that's the Brain.
--
-- The split matters: MonsterAgent's states returned their own successor, so
-- adding a state meant editing every state that could reach it, and in
-- practice Chase.Update returned nil unconditionally and the transition
-- machinery never ran once. States are inert behaviour modules now.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterConstants = require(ReplicatedStorage.Modules.Monster.MonsterConstants)
local States = require(script.Parent.Parent.States)

local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine.new(instance)
	return setmetatable({
		instance = instance,
		current  = nil,
		module   = nil,
		elapsed  = 0,
	}, StateMachine)
end

function StateMachine:GetElapsed(): number
	return self.elapsed
end

-- forced skips MinStateDuration and Interruptible. Reset and evolution-driven
-- transitions always force; ordinary scoring never does.
function StateMachine:CanLeave(forced: boolean): boolean
	if forced or not self.module then
		return true
	end

	if self.module.Interruptible == false then
		return false
	end

	local minDuration = (self.instance.config.Brain and self.instance.config.Brain.MinStateDuration)
		or MonsterConstants.DefaultMinStateDuration
	return self.elapsed >= minDuration
end

function StateMachine:Transition(name: string, forced: boolean?): boolean
	if name == self.current then
		return false
	end

	local nextModule = States.Get(name)
	if not nextModule then
		warn(("StateMachine: no state module '%s'"):format(tostring(name)))
		return false
	end

	if not self:CanLeave(forced == true) then
		return false
	end

	local previous = self.current

	if self.module and self.module.Exit then
		self.module.Exit(self.instance)
	end

	self.current = name
	self.module = nextModule
	self.elapsed = 0

	if nextModule.Enter then
		nextModule.Enter(self.instance)
	end

	-- Replicated so the client can drive animation off it. Written on
	-- transition only, never per tick -- every attribute write replicates.
	self.instance.model:SetAttribute(MonsterConstants.Attributes.AIState, name)
	self.instance.bus:Fire("StateChanged", { State = name, Previous = previous })

	return true
end

function StateMachine:Tick(dt: number)
	if not self.module then
		return
	end

	self.elapsed += dt

	if self.module.Update then
		self.module.Update(self.instance, dt)
	end
end

function StateMachine:Destroy()
	if self.module and self.module.Exit then
		self.module.Exit(self.instance)
	end
	self.module = nil
	self.current = nil
end

return StateMachine
