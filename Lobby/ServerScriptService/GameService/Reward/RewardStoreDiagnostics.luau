-- The fourth instance of the RewardCleanupHook pattern: subscribes from its
-- own Start(), booted from a list, rather than at module scope. Closes the
-- observability gap Phase 12 shipped with -- ProfileStore's OnError,
-- OnOverwrite, and OnCriticalToggle had zero subscribers repo-wide, so a
-- real DataStore failure and a quiet success were indistinguishable one
-- layer below where Phase 8.1 already fixed exactly this for MatchCleanup's
-- own save step.
--
-- These three signals are ProfileStore-module-global, not per-store --
-- requires Vendor/ProfileStore directly rather than going through
-- RewardStore.Backend, which is one specific store instance.
--
-- OnOverwrite matters specifically for the v1->v2 migration (item 1): it
-- fires when a DataStore key held data that wasn't a ProfileStore profile.
-- It should never fire for RewardStore_v2 in normal operation -- if it
-- does, something is wrong at the migration boundary and is worth knowing
-- immediately, not discovering later as an unexplained data gap.

local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStoreLib = require(ServerScriptService.Vendor.ProfileStore)

local RewardStoreDiagnostics = {}

local started = false

function RewardStoreDiagnostics.Start()
	if started then
		return
	end
	started = true

	ProfileStoreLib.OnError:Connect(function(message, storeName, profileKey)
		warn(("RewardStoreDiagnostics: ProfileStore error -- store=%s key=%s -- %s"):format(
			tostring(storeName), tostring(profileKey), tostring(message)))
	end)

	ProfileStoreLib.OnOverwrite:Connect(function(storeName, profileKey)
		warn(("RewardStoreDiagnostics: *** OnOverwrite -- store=%s key=%s held data that wasn't a ProfileStore profile. If store is RewardStore_v2, investigate immediately -- this is the exact signature of a corrupted migration."):format(
			tostring(storeName), tostring(profileKey)))
	end)

	ProfileStoreLib.OnCriticalToggle:Connect(function(isCritical)
		if isCritical then
			warn("RewardStoreDiagnostics: *** ProfileStore entered CRITICAL STATE -- too many consecutive DataStore errors. Saves may be failing broadly.")
		else
			warn("RewardStoreDiagnostics: ProfileStore exited critical state.")
		end
	end)
end

return RewardStoreDiagnostics
