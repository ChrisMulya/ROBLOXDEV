-- CharacterMovementService
-- Server authority for character movement: the Humanoid movement properties,
-- sprint state, and stamina.
--
-- Why this is server-side at all: PlayerMovementController (client) drives
-- horizontal motion with a LinearVelocity constraint, not with WalkSpeed. But
-- live Roblox servers validate character motion against the SERVER's copy of
-- Humanoid.WalkSpeed, and Humanoid property writes made from a LocalScript no
-- longer replicate. A client that set WalkSpeed = 0 left the server believing
-- the default 16 -- walking slipped under the budget, sprinting got rejected
-- and rubber-banded. Studio playtest doesn't run that validation, which is
-- why it only ever showed up live.
--
-- So the server sets WalkSpeed, and it sets it to walk or sprint speed
-- according to stamina IT owns. A client can't sprint without having earned
-- it: SprintRequest is a request, and if stamina is spent the server's budget
-- stays at walking speed and the validator clamps anything faster.
--
-- The client still zeroes WalkSpeed locally (see PlayerMovementController) so
-- the engine's own WalkSpeed-driven movement doesn't fight the LinearVelocity.
-- That local write stays local, which is exactly what we want.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStats = require(ReplicatedStorage.Modules.PlayerStats)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local PlayerEffects = require(script.Parent.PlayerEffects)
local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local Cooldown = require(ReplicatedStorage.Modules.Shared.Cooldown)

local CharacterMovementService = {}

-- Lobby mode: sprint is free (no stamina resource exists there), so the
-- stamina gate, the drain/regen loop, and the sync remote all become no-ops.
-- WalkSpeed authority itself stays live on both places -- see the file header
-- for why that can never be dropped.
local isLobby = ServerRole.Is("LobbyServer")

-- SprintRequest's own no-op branch (see onSprintRequest below) used to sync
-- unconditionally on every duplicate request -- one FireClient + two
-- Player-attribute writes, both broadcast to every client, with no server-
-- side ceiling on how often a client could ask. Throttles the correction to
-- 2/sec/player; the regular SYNC_INTERVAL sweep already re-syncs everyone
-- every 100ms regardless, so this only removes redundant *extra* syncs, not
-- the correction itself.
local noopSyncCooldown = Cooldown.new(0.5)

-- Slack above the target speed. The client's accel lerp, slopes, and knockback
-- all overshoot the nominal top speed by a stud or two; without headroom the
-- validator clamps legitimate movement. It is deliberately small enough that
-- it can't be spent as a second sprint.
local BUDGET_HEADROOM = 1.15

-- Stamina is replicated on a timer, not per-frame. The client does NOT predict
-- it -- this is the only source, so the rate is what the HUD's smoothness
-- actually depends on. 10Hz reads as continuous on a bar this size and is far
-- cheaper than a per-frame remote.
local SYNC_INTERVAL = 0.1

type Entry = {
	humanoid: Humanoid,
	stamina: number,
	sprinting: boolean,
	jumpBlocked: boolean,
	idleTime: number,
	locked: boolean,
	requestId: number,
}

local entries: { [Player]: Entry } = {}
local sprintRemote: RemoteEvent
local staminaRemote: RemoteEvent
local syncAccumulator = 0

-- Reads PlayerEffects.GetStat rather than PlayerStats directly -- WalkSpeed/
-- SprintSpeed/MaxStamina are all buffable per-player (Pills, Adrenaline Shot,
-- Energy Drink), and PlayerStats.Get would return the shared base for every
-- player on the server. locked (ItemUseService's movement hold) wins over
-- both: a player mid-item-use gets a zero budget regardless of any buff.
local function targetWalkSpeed(player: Player, entry: Entry): number
	if entry.locked then
		return 0
	end
	local base = entry.sprinting and PlayerEffects.GetStat(player, "SprintSpeed") or PlayerEffects.GetStat(player, "WalkSpeed")
	return base * BUDGET_HEADROOM
end

local function applyBudget(player: Player, entry: Entry)
	local speed = targetWalkSpeed(player, entry)
	if entry.humanoid.WalkSpeed ~= speed then
		entry.humanoid.WalkSpeed = speed
	end
end

local function syncPlayer(player: Player, entry: Entry)
	-- No stamina resource on the Lobby: nothing to sync, nothing to mirror.
	if isLobby then
		return
	end
	staminaRemote:FireClient(player, {
		stamina = entry.stamina,
		maxStamina = PlayerEffects.GetStat(player, "MaxStamina"),
		walkSpeed = PlayerEffects.GetStat(player, "WalkSpeed"),
		sprintSpeed = PlayerEffects.GetStat(player, "SprintSpeed"),
		-- The server's sprint verdict, plus the id of the request it answers.
		-- The client applies it as a CANCEL only, and only when the id matches
		-- its own most recent request -- see the staminaRemote handler in
		-- PlayerMovementController for why the pairing is required.
		--
		-- Without this the client had no way to learn the server had revoked
		-- (or never granted) a sprint: it inferred exhaustion from seeing a
		-- synced stamina of 0, which is a single packet the very next sync
		-- overwrites with a regenerating value. Miss that one packet and the
		-- client sprinted on a budget it was never given, with the server not
		-- draining a thing.
		sprinting = entry.sprinting,
		requestId = entry.requestId,
	})
	-- Mirrored to an attribute purely for observability: stamina lived only in
	-- this module's private table, so "is the server actually regenerating?"
	-- was unanswerable from Studio without adding print statements. Nothing
	-- reads this -- the HUD goes through StaminaSync. Player attributes
	-- replicate to every client, so on a live server this was 40 broadcast
	-- writes/sec for a value with zero readers -- Studio-only now, since that
	-- is the only place anything ever looked at it.
	if RunService:IsStudio() then
		player:SetAttribute("Stamina", entry.stamina)
		player:SetAttribute("Sprinting", entry.sprinting)
	end
end

-- ItemUseService's movement hold. Cleared unconditionally on every session
-- exit path (completion, cancel, death, disconnect, invalidation) by that
-- module's Trove -- never left set past the session that requested it.
function CharacterMovementService.SetMovementLocked(player: Player, locked: boolean)
	local entry = entries[player]
	if not entry or entry.locked == locked then
		return
	end
	entry.locked = locked
	applyBudget(player, entry)
end

-- Server-granted sprint, not the client's request: onSprintRequest only sets
-- this after the stamina gate. FootstepEmitter reads it so a sprint is always
-- audible even in the moments its measured speed is still ramping up to the
-- noise threshold.
function CharacterMovementService.IsSprinting(player: Player): boolean
	local entry = entries[player]
	return entry ~= nil and entry.sprinting
end

-- Jump rate limit. The character is client-simulated, so the cooldown that the
-- player actually feels is enforced in PlayerMovementController; disabling the
-- state here is the server-side half, and it is also what makes the cooldown
-- hold for any humanoid the server simulates (no network owner assigned yet,
-- e.g. the first moments after a respawn).
--
-- Runs from LANDING, not takeoff -- same reasoning as the client half: a
-- jump's airtime exceeds JumpCooldown, so a takeoff-anchored cooldown expires
-- mid-air and rate-limits nothing.
local function onStateChanged(player: Player, entry: Entry, newState: Enum.HumanoidStateType)
	local humanoid = entry.humanoid

	if newState == Enum.HumanoidStateType.Jumping then
		if not entry.jumpBlocked then
			entry.jumpBlocked = true
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		end
		return
	end

	-- Any grounded state counts as the landing: a jump ending on a slope or in
	-- water can skip Landed entirely, and the block would never lift.
	local grounded = newState == Enum.HumanoidStateType.Landed
		or newState == Enum.HumanoidStateType.Running
		or newState == Enum.HumanoidStateType.RunningNoPhysics
		or newState == Enum.HumanoidStateType.Swimming
		or newState == Enum.HumanoidStateType.Climbing
	if not entry.jumpBlocked or not grounded then
		return
	end

	-- Cleared before the delay, not inside it: Landed is immediately followed
	-- by Running, which would otherwise schedule the cooldown twice.
	entry.jumpBlocked = false
	task.delay(PlayerStats.JumpCooldown, function()
		-- The character may be gone (death/respawn/match cleanup) by now, and
		-- a stale entry means this humanoid is no longer the live one.
		if entries[player] ~= entry or humanoid.Parent == nil then
			return
		end
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end)
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
		or character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	-- The player may have left, or respawned again, while we waited.
	if player.Character ~= character then
		return
	end

	humanoid.UseJumpPower = false
	humanoid.JumpHeight = PlayerStats.JumpHeight

	-- Full stamina on every spawn: dying while exhausted must not respawn you
	-- exhausted. locked defaults false -- a respawn must never inherit a
	-- movement lock from whatever the previous character was mid-doing.
	local entry: Entry = {
		humanoid = humanoid,
		stamina = PlayerEffects.GetStat(player, "MaxStamina"),
		sprinting = false,
		jumpBlocked = false,
		idleTime = 0,
		locked = false,
		-- 0 matches no client request (the client's counter starts at 1), so
		-- the syncs sent before this character's first SprintRequest carry a
		-- verdict the client correctly ignores. It has nothing to cancel then
		-- anyway -- a fresh character starts not sprinting on both sides.
		requestId = 0,
	}
	entries[player] = entry
	applyBudget(player, entry)
	syncPlayer(player, entry)

	humanoid.StateChanged:Connect(function(_old, new)
		if entries[player] == entry then
			onStateChanged(player, entry, new)
		end
	end)
end

local function onSprintRequest(player: Player, wantsSprint: any, requestId: any)
	if typeof(wantsSprint) ~= "boolean" then
		return
	end

	local entry = entries[player]
	if not entry or entry.humanoid.Health <= 0 then
		return
	end

	-- Recorded before the gate, so every sync from here on answers THIS
	-- request. A client on an older build sends no id; the entry keeps its
	-- previous one and the verdict simply goes unmatched, which is the old
	-- behaviour rather than a wrong one.
	if typeof(requestId) == "number" then
		entry.requestId = requestId
	end

	-- Lobby: the request path stays the same shape, but there's no stamina
	-- budget to check against -- wanting to sprint is enough.
	local granted = wantsSprint and (isLobby or entry.stamina >= PlayerStats.MinStaminaToSprint)
	if entry.sprinting == granted then
		-- A DENIED request is this branch, not a no-op: sprinting was already
		-- false and stays false. The client still has to hear the "no" --
		-- its own stamina copy is up to SYNC_INTERVAL stale, so it can read
		-- above MinStaminaToSprint and locally grant itself a sprint the
		-- server just refused. Syncing here is what corrects that faster than
		-- the periodic sweep below would.
		--
		-- Throttled: nothing stops a client sending this exact request in a
		-- tight loop, and every hit used to sync unconditionally. Skipping an
		-- occasional correction here is safe -- the SYNC_INTERVAL sweep at the
		-- bottom of step() re-syncs every entry every 100ms regardless, so the
		-- worst case is a 500ms-late correction, not a stuck one.
		if noopSyncCooldown:Check(player.UserId) then
			syncPlayer(player, entry)
		end
		return
	end
	entry.sprinting = granted
	applyBudget(player, entry)
	syncPlayer(player, entry)
end

local function step(dt: number)
	for player, entry in pairs(entries) do
		local humanoid = entry.humanoid
		if humanoid.Parent == nil or humanoid.Health <= 0 then
			continue
		end

		local moving = humanoid.MoveDirection.Magnitude > 0.01
		if moving then
			entry.idleTime = 0
		else
			entry.idleTime += dt
		end

		local wasSprinting = entry.sprinting
		-- Lobby: entry.sprinting was already granted unconditionally in
		-- onSprintRequest above, and stays granted -- no budget to drain, so no
		-- drain, regen, or forced-off-at-zero to run.
		if not isLobby then
			if entry.sprinting then
				-- Standing still while holding sprint costs nothing, same rule the
				-- client used before this moved server-side -- but after
				-- StaminaIdleRegenDelay of not moving, regen anyway rather than
				-- leaving a player who stopped stuck at whatever they had left.
				if moving then
					entry.stamina -= PlayerStats.StaminaDrainRate * dt
				elseif entry.idleTime >= PlayerStats.StaminaIdleRegenDelay then
					entry.stamina += PlayerStats.StaminaRegenRate * dt
				end
				if entry.stamina <= 0 then
					entry.sprinting = false
				end
			else
				entry.stamina += PlayerStats.StaminaRegenRate * dt
			end
			entry.stamina = math.clamp(entry.stamina, 0, PlayerEffects.GetStat(player, "MaxStamina"))
		end

		-- Called every tick, not just on a sprint toggle: WalkSpeed/SprintSpeed
		-- are buffable now (Pills, Adrenaline Shot), so the budget can change
		-- with no sprint-state change at all (a buff expiring mid-stride). The
		-- equality check inside applyBudget keeps this a no-op write on every
		-- tick where nothing actually changed. Immediate sync is still gated on
		-- the sprint toggle -- a buff change reaches the client on the regular
		-- 10Hz sync below instead, which is frequent enough for a stat that
		-- only steps at multi-second intervals.
		applyBudget(player, entry)
		if entry.sprinting ~= wasSprinting then
			syncPlayer(player, entry)
		end
	end

	syncAccumulator += dt
	if syncAccumulator < SYNC_INTERVAL then
		return
	end
	syncAccumulator = 0
	for player, entry in pairs(entries) do
		syncPlayer(player, entry)
	end
end

local function setupPlayer(player: Player)
	-- Shift Lock Switch binds Shift, so with it enabled the toggle swallows the
	-- sprint key instead of sprinting. Sprint owns Shift; shift lock is off.
	-- Set per-player as well as on StarterPlayer because StarterPlayer only
	-- seeds players who join after it is set.
	player.DevEnableMouseLock = false

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

function CharacterMovementService.Start()
	StarterPlayer.EnableMouseLockOption = false

	sprintRemote = Remotes.Get("SprintRequest")
	staminaRemote = Remotes.Get("StaminaSync")
	sprintRemote.OnServerEvent:Connect(onSprintRequest)

	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(function(player)
		entries[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		setupPlayer(player)
	end

	RunService.Heartbeat:Connect(step)
end

return CharacterMovementService
