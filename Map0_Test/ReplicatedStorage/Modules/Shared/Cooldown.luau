-- Per-key cooldown tracker (typically keyed by player.UserId).
-- Replaces the lastXTime[UserId] + PlayerRemoving-cleanup pattern that was
-- hand-written three separate times (CameraShotHandler, CameraShelfHandler,
-- and planned for the monster damage path -- now Monster/Components/Combat,
-- which tracks its own per-instance table rather than using this).

local Players = game:GetService("Players")

local Cooldown = {}
Cooldown.__index = Cooldown

-- seconds: default window used when Check() is called without an override.
function Cooldown.new(seconds: number?)
	local self = setmetatable({
		_seconds = seconds,
		_lastTime = {},
	}, Cooldown)

	Players.PlayerRemoving:Connect(function(player)
		self._lastTime[player.UserId] = nil
	end)

	return self
end

-- secondsOverride: use when the window varies per-call (e.g. shot cooldown
-- differs by camera + shot type) instead of being fixed at construction.
-- Returns true and records `now` if the key is off cooldown, false otherwise.
function Cooldown:Check(key, secondsOverride: number?): boolean
	local now = os.clock()
	local seconds = secondsOverride or self._seconds
	local last = self._lastTime[key]
	if last and now - last < seconds then
		return false
	end
	self._lastTime[key] = now
	return true
end

function Cooldown:Clear(key)
	self._lastTime[key] = nil
end

return Cooldown
