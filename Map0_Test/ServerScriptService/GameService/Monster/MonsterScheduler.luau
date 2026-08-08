-- The single Heartbeat that drives every live monster.
--
-- This used to be a RunService.Heartbeat:Connect at MonsterService's MODULE
-- SCOPE, which meant requiring MonsterService from anywhere started the loop --
-- the one service in the repo that didn't follow the .Start() boot-list
-- convention. It's a Start() now, called only from MonsterFramework, which is
-- listed only in GameBoot.
--
-- Behaviour is otherwise unchanged: the same gameplay gate, the same per-state
-- tick rate, the same orphan sweep.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchStates = require(ReplicatedStorage.Modules.Shared.MatchStates)
local MatchManager = require(script.Parent.Parent.Match.MatchManager)
local MonsterRegistry = require(script.Parent.MonsterRegistry)

local MonsterScheduler = {}

-- MonsterService needed a lazy require and a ServerRole bypass here because it
-- self-wired on both places. This module only ever starts on the Game Server
-- (MonsterFramework asserts it), so MatchManager can be a plain top-level
-- require -- same as EncounterDirector does.
local function gameplayActive(): boolean
	return MatchStates.IsGameplayActive(MatchManager.Get())
end

local started = false

function MonsterScheduler.Start()
	if started then
		return
	end
	started = true

	RunService.Heartbeat:Connect(function()
		-- Freezes existing monsters in place rather than despawning them once
		-- gameplay ends -- Ending keeps the world visible for spectate and the
		-- end screen, so ticking just stops.
		if not gameplayActive() then
			return
		end

		local now = os.clock()

		MonsterRegistry.ForEach(function(model: Model, instance)
			-- Reached when a model is unparented without going through
			-- :Destroy(). Destroying does not fire on a bare
			-- `model.Parent = nil`, so this path needs its own cleanup.
			if not model.Parent then
				MonsterRegistry.Remove(model)
				return
			end

			local dt = now - instance.lastTick
			if dt >= instance:GetTickRate() then
				instance:Tick(dt)
				instance.lastTick = now
			end
		end)
	end)
end

return MonsterScheduler
