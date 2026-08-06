-- Wires MatchTimeClient to MatchTimeHud. Owns no state and no UI -- the same
-- controller/hud split as SpectateController/SpectateHud.
--
-- Required for its side effects from ClientBootstrap's GameServer branch
-- only. The Lobby never requires this, so no clock is ever built there.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MatchStates = require(ReplicatedStorage.Modules.Shared.MatchStates)
local MatchTimeClient = require(script.Parent.MatchTimeClient)
local MatchTimeHud = require(script.Parent.MatchTimeHud)

-- 0.1s: the bar advances ~0.03% of its width per tick on the Default
-- schedule, well under a pixel, so this reads as continuous without costing
-- a per-frame update.
local TICK_INTERVAL = 0.1

local tickAccumulator = 0

local function getMatchState(): string?
	local matchInfo = ReplicatedStorage:FindFirstChild("MatchInfo")
	if not matchInfo then
		return nil
	end
	return matchInfo:GetAttribute("MatchState")
end

local function tick()
	-- Gate on the flag, never on the state name. ShowsMatchTime is true for
	-- Playing only -- the clock is match-scoped and its anchors are cleared
	-- the moment Playing ends. Progress is clamped to 1, so the last frame
	-- drawn before that is a completely full bar.
	local state = getMatchState()
	if not state or not MatchStates.ShowsMatchTime(state) then
		MatchTimeHud.Hide()
		return
	end

	-- Anchors absent: the clock hasn't been published yet, or has been
	-- cleared. Either way there is no match time to draw -- hide rather than
	-- rendering a zeroed bar.
	local progress = MatchTimeClient.GetProgress()
	local hourText = MatchTimeClient.GetHourText()
	if not progress or not hourText then
		MatchTimeHud.Hide()
		return
	end

	MatchTimeHud.Update(progress, hourText)
end

RunService.Heartbeat:Connect(function(delta)
	tickAccumulator += delta
	if tickAccumulator < TICK_INTERVAL then
		return
	end
	tickAccumulator = 0
	tick()
end)

return {}
