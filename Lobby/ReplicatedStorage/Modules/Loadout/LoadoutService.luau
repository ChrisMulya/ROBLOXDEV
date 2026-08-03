-- Facade for "what camera should this player be given" -- now backed by a
-- DataStore, so the choice survives a teleport (attributes don't cross a
-- server boundary) and a plain rejoin (CurrentCamera was never persisted
-- before this phase). StartGame.giveStarterCamera routes through
-- GetCameraId instead of reading CurrentCamera directly, so this backend
-- swap touched exactly one other file's call site.
--
-- Deliberately does NOT read TeleportData -- it's client-routed, and a
-- camera is a purchase-backed capability grant, so a forged cameraId would
-- be a free upgrade. The Lobby is the only writer of a player's actual
-- choice (CameraShelfSwap.TakeCamera calls Save); CameraInventory.Give on
-- the Game place only ever re-materializes an existing choice as a Tool,
-- so it must never call Save itself.
--
-- Smaller than RewardStore on purpose: one value per player, not several
-- currencies, and a preference isn't a loss-of-progress risk the way XP is.
-- Save is best-effort and immediate (not gated behind IsReady, not batched)
-- because it fires directly from the one deliberate player action that
-- changes this value, and there's no "top up a currency" analog for a
-- camera choice to make an autosave/BindToClose loop worth the complexity.

local DataStoreService = game:GetService("DataStoreService")

local LoadoutService = {}

-- Matches CameraInventory.DefaultCameraId. Duplicated rather than required
-- to avoid a ReplicatedStorage module depending on a ServerScriptService one.
local DEFAULT_CAMERA_ID = "Camera1"

local MAX_ATTEMPTS = 3
local RETRY_BASE_SECONDS = 0.5

LoadoutService.Backend = DataStoreService:GetDataStore("LoadoutStore_v1")

-- [userId] = { state: "Loading" | "Ready" | "Failed", cameraId: string? }
local sessions = {}

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

local function attempt(fn, ...)
	local args = { ... }
	for tries = 1, MAX_ATTEMPTS do
		local ok, result = pcall(fn, table.unpack(args))
		if ok then
			return true, result
		end
		warn(("LoadoutService: DataStore call failed (attempt %d/%d) - %s"):format(tries, MAX_ATTEMPTS, tostring(result)))
		if tries < MAX_ATTEMPTS then
			task.wait(RETRY_BASE_SECONDS * 2 ^ (tries - 1))
		end
	end
	return false, nil
end

-- Fire-and-forget from PlayerCurrency.legacy's PlayerAdded handler on both
-- places. On success, also restores the CurrentCamera attribute so the
-- Lobby's existing shelf/UI code (which reads the attribute directly, same
-- as before this phase) reflects a returning player's real choice with zero
-- changes to that code -- GetCameraId's own fallback chain covers the Game
-- place, where the attribute never gets set at all.
function LoadoutService.Load(player: Player)
	sessions[player.UserId] = { state = "Loading", cameraId = nil }

	local ok, data = attempt(function()
		return LoadoutService.Backend:GetAsync(keyFor(player))
	end)

	if not ok then
		sessions[player.UserId] = { state = "Failed", cameraId = nil }
		warn(("LoadoutService: could not load %s -- falling back to default until next save"):format(player.Name))
		return
	end

	-- ok with nil data is a genuinely new player, not an error.
	local cameraId = data
	sessions[player.UserId] = { state = "Ready", cameraId = cameraId }

	if cameraId and player.Parent then
		player:SetAttribute("CurrentCamera", cameraId)
	end
end

function LoadoutService.IsReady(player: Player): boolean
	local session = sessions[player.UserId]
	return session ~= nil and session.state == "Ready"
end

-- Attribute first (the Lobby's live, just-changed truth), then the loaded
-- session (covers the Game place, where the attribute is never set, and a
-- Lobby player who hasn't touched the shelf this visit), then the default.
-- A Load() that hasn't finished yet (or failed) falls through to the
-- default here exactly like before this phase -- an accepted, self-
-- correcting degradation (worst case: one match with the wrong camera,
-- fixed the moment the player revisits the shelf), not worth a blocking
-- wait for what is a cosmetic preference, not a currency.
function LoadoutService.GetCameraId(player: Player): string
	local attributeValue = player:GetAttribute("CurrentCamera")
	if attributeValue then
		return attributeValue
	end

	local session = sessions[player.UserId]
	if session and session.state == "Ready" and session.cameraId then
		return session.cameraId
	end

	return DEFAULT_CAMERA_ID
end

-- Called only from CameraShelfSwap.TakeCamera (the one place a player's
-- choice actually changes) -- never from CameraInventory.Give directly,
-- since Give also runs on the Game place to re-materialize an existing
-- choice, which must not overwrite it with itself on every match start.
function LoadoutService.Save(player: Player, cameraId: string): boolean
	local session = sessions[player.UserId]
	if session then
		session.cameraId = cameraId
		session.state = "Ready"
	else
		sessions[player.UserId] = { state = "Ready", cameraId = cameraId }
	end

	local ok = attempt(function()
		LoadoutService.Backend:SetAsync(keyFor(player), cameraId)
	end)

	if not ok then
		warn(("LoadoutService: failed to save %s's camera choice -- attribute still updated, will not survive a teleport/rejoin until the next successful save"):format(player.Name))
	end

	return ok
end

function LoadoutService.ClearSession(player: Player)
	sessions[player.UserId] = nil
end

return LoadoutService
