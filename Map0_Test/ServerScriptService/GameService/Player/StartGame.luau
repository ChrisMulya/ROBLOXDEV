local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

function StartGameService.ResetKit(player)
	player:SetAttribute("KitGiven", false)
end

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

function StartGameService.GivePlayerStarterKit(player)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		warn("StartGameService: no Backpack for", player.Name, "- starter kit not given")
		return
	end
	if player:GetAttribute("KitGiven") then return end

	-- KitGiven is claimed at the END, not up front. Claiming it first meant a
	-- failed camera grant left the player permanently marked as kitted with
	-- nothing, and re-triggering the prompt no-op'd forever.
	if not giveStarterCamera(player) then
		warn("StartGameService: starter camera could not be granted to", player.Name, "- kit not marked given, retry is safe")
		return
	end

	for _, slotName in ipairs(SLOT_NAMES) do
		createEmptySlot(slotName).Parent = backpack
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
