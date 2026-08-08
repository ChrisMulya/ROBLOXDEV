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

local CharacterMovementService = {}

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
}

local entries: { [Player]: Entry } = {}
local sprintRemote: RemoteEvent
local staminaRemote: RemoteEvent
local syncAccumulator = 0

local function targetWalkSpeed(entry: Entry): number
	local base = entry.sprinting and PlayerStats.SprintSpeed or PlayerStats.WalkSpeed
	return base * BUDGET_HEADROOM
end

local function applyBudget(entry: Entry)
	local speed = targetWalkSpeed(entry)
	if entry.humanoid.WalkSpeed ~= speed then
		entry.humanoid.WalkSpeed = speed
	end
end

local function syncPlayer(player: Player, entry: Entry)
	staminaRemote:FireClient(player, entry.stamina)
	-- Mirrored to an attribute purely for observability: stamina lived only in
	-- this module's private table, so "is the server actually regenerating?"
	-- was unanswerable from Studio without adding print statements. Nothing
	-- reads this -- the HUD goes through StaminaSync.
	player:SetAttribute("Stamina", entry.stamina)
	player:SetAttribute("Sprinting", entry.sprinting)
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
	-- exhausted.
	local entry: Entry = {
		humanoid = humanoid,
		stamina = PlayerStats.MaxStamina,
		sprinting = false,
		jumpBlocked = false,
		idleTime = 0,
	}
	entries[player] = entry
	applyBudget(entry)
	syncPlayer(player, entry)

	humanoid.StateChanged:Connect(function(_old, new)
		if entries[player] == entry then
			onStateChanged(player, entry, new)
		end
	end)
end

local function onSprintRequest(player: Player, wantsSprint: any)
	if typeof(wantsSprint) ~= "boolean" then
		return
	end

	local entry = entries[player]
	if not entry or entry.humanoid.Health <= 0 then
		return
	end

	local granted = wantsSprint and entry.stamina >= PlayerStats.MinStaminaToSprint
	if entry.sprinting == granted then
		return
	end
	entry.sprinting = granted
	applyBudget(entry)
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
		entry.stamina = math.clamp(entry.stamina, 0, PlayerStats.MaxStamina)

		if entry.sprinting ~= wasSprinting then
			applyBudget(entry)
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
