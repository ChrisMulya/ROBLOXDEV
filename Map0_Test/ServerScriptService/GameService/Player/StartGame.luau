local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PlayerStats = require(ReplicatedStorage.Modules.PlayerStats)
local CameraInventory = require(script.Parent.Parent.CameraShelf.CameraInventory)
local LoadoutService = require(ReplicatedStorage.Modules.Loadout.LoadoutService)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
-- Remotes.Get is a WaitForChild -- kept out of module scope (called inside
-- GivePlayerStarterKit instead) so a require from a boot list can't hang if
-- something ever requires this before Remotes.Init() has run.

local StartGameService = {}

local SLOT_NAMES = {"Slot 1", "Slot 2"} -- Camera is handled separately below

local function createEmptySlot(slotName)
	local slot = Instance.new("Tool")
	slot.Name = slotName
	slot.RequiresHandle = false
	slot.CanBeDropped = false
	slot:SetAttribute("IsEmpty", true)
	return slot
end

-- Exposed so ItemConsumption can revert a used support item to exactly this
-- placeholder shape instead of hand-rolling a second copy of it.
StartGameService.CreateEmptySlot = createEmptySlot

-- Gives the player their actual camera (not an empty placeholder), based on
-- the CurrentCamera attribute set server-side (e.g. by CameraShelfSwap on a
-- previous visit to the shelf). Falls back to CameraInventory.DefaultCameraId
-- for first-time players, or if the recorded CameraId no longer matches a
-- real template.
--
-- Returns whether a REAL camera was granted. The empty-placeholder branch
-- returns false so GivePlayerStarterKit doesn't claim KitGiven over a broken
-- kit -- a retry once the asset is fixed replaces the placeholder cleanly,
-- since Give destroys whatever occupies the slot.
local function giveStarterCamera(player): boolean
	local cameraId = LoadoutService.GetCameraId(player)

	local ok = CameraInventory.Give(player, cameraId)
	if not ok and cameraId ~= CameraInventory.DefaultCameraId then
		warn("StartGameService: no camera template for", cameraId, "- falling back to default")
		ok = CameraInventory.Give(player, CameraInventory.DefaultCameraId)
	end

	if not ok then
		warn("StartGameService: default camera template missing entirely, giving empty Camera slot")
		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			createEmptySlot("Camera").Parent = backpack
		end
		return false
	end

	return true
end

-- Is the whole kit sitting in the player's CURRENT Backpack right now?
-- Deliberately re-reads the Backpack rather than trusting the one the grant
-- was written into -- the whole point is to catch the case where that one is
-- no longer the player's.
local function kitIsPresent(player: Player): boolean
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return false
	end
	if not CameraInventory.FindSlot(player) then
		return false
	end
	for _, slotName in ipairs(SLOT_NAMES) do
		if not backpack:FindFirstChild(slotName) then
			return false
		end
	end
	return true
end

-- This yields now (see below), so KitGiven alone no longer serializes callers:
-- KitLifecycleHook can call in from CharacterAdded and from
-- MatchParticipants.Joined for the same character, and two overlapping calls
-- would grant the kit twice. Always cleared before returning -- every path out
-- of the loop below is bounded.
local granting: { [Player]: boolean } = {}

local MAX_ATTEMPTS = 3

function StartGameService.GivePlayerStarterKit(player)
	if player:GetAttribute("KitGiven") or granting[player] then return end
	granting[player] = true

	-- The character this grant belongs to. Re-checked after every yield: if the
	-- player respawned meanwhile, that spawn's own CharacterAdded owns the
	-- grant and this call must not write into it.
	local character = player.Character

	-- Roblox recreates the Backpack as part of the same spawn that the
	-- CharacterAdded we were called from announces, and that swap is not
	-- ordered against the event. Both orderings used to lose the kit outright:
	-- swap-after-us destroyed the tools we had just parented, and swap-not-yet-
	-- started meant FindFirstChild("Backpack") returned nil and this returned
	-- having granted nothing at all -- which is why the symptom was no camera
	-- AND no Slot 1/Slot 2, rather than a partial kit. Studio-only in practice
	-- because a live arrival spawns well after the player instance settles.
	--
	-- So: wait for a Backpack, grant, then verify a frame later against the
	-- player's current Backpack and retry. One frame is enough to see the swap
	-- -- it belongs to this spawn, it can't arrive arbitrarily later.
	local granted = false
	for attempt = 1, MAX_ATTEMPTS do
		local backpack = player:FindFirstChild("Backpack") or player:WaitForChild("Backpack", 5)
		if not backpack or player.Parent == nil or player.Character ~= character then
			break
		end

		-- KitGiven is claimed at the END, not up front. Claiming it first meant a
		-- failed camera grant left the player permanently marked as kitted with
		-- nothing, and re-triggering the prompt no-op'd forever.
		if not giveStarterCamera(player) then
			-- A missing template doesn't get better on the next attempt.
			break
		end

		for _, slotName in ipairs(SLOT_NAMES) do
			-- Guarded so a retry tops up whatever the swap took rather than
			-- stacking a second "Slot 1" beside a surviving one. (The camera is
			-- already idempotent: CameraInventory.Give destroys the old slot.)
			if not backpack:FindFirstChild(slotName) then
				createEmptySlot(slotName).Parent = backpack
			end
		end

		RunService.Heartbeat:Wait()
		if player.Parent == nil or player.Character ~= character then
			break
		end
		if kitIsPresent(player) then
			granted = true
			break
		end

		warn("StartGameService: starter kit for", player.Name, "did not survive the Backpack swap - retrying, attempt", attempt)
	end

	granting[player] = nil

	if not granted then
		warn("StartGameService: starter kit could not be granted to", player.Name, "- kit not marked given, retry is safe")
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash then
		cash.Value = PlayerStats.StartingCash
	end

	Remotes.Get("ShowCurrencyUI"):FireClient(player)

	player:SetAttribute("KitGiven", true)
end

return StartGameService
