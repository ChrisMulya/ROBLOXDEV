-- Wires DeathScreen (pure UI) to PlayerStateClient (state source). Game
-- Server only -- required directly from ClientBootstrap's GameServer branch
-- for its side effects, the same pattern already used there for
-- FlashRenderers/ObjectiveVisualsController (systems with no natural first
-- caller of their own).
--
-- Shows only on Dead -- Spectating hands off to SpectateHud (Phase 6)
-- instead, per the plan's death flow (section 7).

local PlayerStateClient = require(script.Parent.Parent.Shared.PlayerStateClient)
local DeathScreen = require(script.Parent.DeathScreen)

PlayerStateClient.Start()

PlayerStateClient.Changed:Connect(function(newState: string)
	if newState == "Dead" then
		DeathScreen.Show({ state = newState })
	else
		DeathScreen.Hide()
	end
end)

return {}
