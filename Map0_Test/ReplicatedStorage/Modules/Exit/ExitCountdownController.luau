-- Wires ExitDwellSync to ExitCountdownHud. Holds no state and runs no timer
-- of its own -- every value on screen came from the server's own dwell
-- sample, and a nil payload is the server saying "stop showing this".
--
-- Same shape as MissionHudController: a controller that only translates a
-- server push into a pure-UI call.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local ExitCountdownHud = require(script.Parent.ExitCountdownHud)

local ExitCountdownController = {}

local function onDwellSync(payload: any)
	-- nil (left the exit, died, exit re-locked, match ended) or a malformed
	-- payload both mean "hide" rather than "render zero".
	if typeof(payload) ~= "table" then
		ExitCountdownHud.Hide()
		return
	end

	local remaining = payload.remaining
	local total = payload.total
	if typeof(remaining) ~= "number" or typeof(total) ~= "number" then
		ExitCountdownHud.Hide()
		return
	end

	ExitCountdownHud.Update(remaining, total)
end

Remotes.Get("ExitDwellSync").OnClientEvent:Connect(onDwellSync)

return ExitCountdownController
