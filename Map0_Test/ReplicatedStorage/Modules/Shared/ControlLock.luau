-- Refcounted freeze switch over the client's PlayerModule controls. Replaces
-- three independent, unrefcounted controls:Disable()/Enable() call sites
-- (ItemUseClient, CameraShelfClient, PlayerShop) that shared one boolean
-- switch with no coordination -- any one of them calling Enable() while
-- another still wanted the player frozen silently unfroze them. ItemUseClient
-- had already grown a local two-flag workaround for exactly this
-- (refreshControls); this module generalises that pattern so every freeze
-- reason, including the match loading curtain, composes safely.
--
-- Acquire/Release take a reason string rather than being a bare counter: a
-- double Acquire from one owner is idempotent instead of leaking a second
-- reference that owner never releases, and a Release from an owner that never
-- acquired is a warn, not a silent unfreeze of someone else's lock.

local Players = game:GetService("Players")

local ControlLock = {}

local player = Players.LocalPlayer

local reasons: { [string]: boolean } = {}
local controls: any = nil

local function resolveControls()
	local playerScripts = player:WaitForChild("PlayerScripts")
	local playerModule = require(playerScripts:WaitForChild("PlayerModule"))
	controls = playerModule:GetControls()
end

local function derive()
	if not controls then
		return
	end
	if next(reasons) ~= nil then
		controls:Disable()
	else
		controls:Enable()
	end
end

function ControlLock.Acquire(reason: string)
	reasons[reason] = true
	derive()
end

function ControlLock.Release(reason: string)
	if not reasons[reason] then
		warn(("ControlLock.Release: '%s' was not held"):format(reason))
		return
	end
	reasons[reason] = nil
	derive()
end

function ControlLock.IsHeld(reason: string): boolean
	return reasons[reason] == true
end

resolveControls()

-- The control module is rebuilt per character, so a cached reference from a
-- previous life is stale -- re-resolve and re-apply whatever locks are still
-- held (e.g. a respawn mid-loading-curtain must stay frozen under the new
-- character's controls too).
player.CharacterAdded:Connect(function()
	resolveControls()
	derive()
end)

return ControlLock
