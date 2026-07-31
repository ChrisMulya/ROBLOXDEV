-- Registers RewardLedger's save step into MatchCleanup, from its own
-- Start(). RewardLedger predates the Start() lifecycle convention and has
-- no Start() of its own -- it self-wires via PlayerCurrency.legacy.luau.
-- Registering at RewardLedger's own module scope (the Phase 7 approach)
-- made the save step's existence contingent on PlayerCurrency.legacy
-- happening to be required on this place -- a hidden keystone dependency,
-- confirmed live to be an actual gap on the Game place, not a hypothetical
-- (Phase 7.5 audit, ~/.claude/plans/before-phase-8-perform-scalable-mochi.md
-- section 1). This module makes the registration explicit, ordered by
-- GameBoot's list, and independent of any other file's require graph.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local RewardLedger = require(script.Parent.RewardLedger)
local RewardStore = require(script.Parent.RewardStore)
local MatchCleanup = require(script.Parent.Parent.Match.MatchCleanup)

local RewardCleanupHook = {}

local started = false

function RewardCleanupHook.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	MatchCleanup.RegisterSaveStep("RewardLedger", function(): boolean
		local successCount, total = RewardStore.SaveAll(RewardLedger.CurrentPersistentValues)
		if successCount < total then
			warn(("RewardCleanupHook: only %d/%d player saves succeeded"):format(successCount, total))
		end
		return successCount == total
	end)
end

return RewardCleanupHook
