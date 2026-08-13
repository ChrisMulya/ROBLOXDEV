-- Placement, ownership, and view-authorisation for every placed Portable
-- CCTV. Server owns all three; the client (CCTVViewController) only renders
-- the lens part it is told to look through -- it cannot self-authorise a
-- view, and the server can revoke one at any time.
--
-- Two-stage, same shape as the Compact Speaker: placing the camera leaves it
-- inert and does NOT open the feed. The PortableCCTVTablet the placement
-- leaves in the slot is what opens it, toggles it shut, and (below) what
-- keeps it open.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local DeployablePlacement = require(script.Parent.DeployablePlacement)
local DeathService = require(ServerScriptService.GameService.Death.DeathService)
local CharacterMovementService = require(script.Parent.Parent.Parent.Player.CharacterMovementService)

local CCTVService = {}

local TABLET_ITEM_ID = "PortableCCTVTablet"

-- [model] = { record, lens }
local placedByModel = {}
-- [player] = model currently being viewed
local viewing: { [Player]: Instance } = {}

local cctvViewState: RemoteEvent

-- Prefers a part named "Lens" -- the authored convention -- and falls back to
-- whatever BasePart the model offers, so a differently-authored model still
-- produces a usable view rather than none at all.
local function findLens(model: Instance): BasePart?
	local lens = model:FindFirstChild("Lens")
	if lens and lens:IsA("BasePart") then
		return lens
	end
	return DeployablePlacement.ResolvePart(model)
end

local function stopViewing(player: Player)
	if viewing[player] then
		viewing[player] = nil
		-- Released here rather than left to the client: the lock is the
		-- server's WalkSpeed budget, and every exit path (toggle, slot change,
		-- death, disconnect, camera destroyed) funnels through this one
		-- function precisely so none of them can leave a player frozen.
		CharacterMovementService.SetMovementLocked(player, false)
		cctvViewState:FireClient(player, nil)
	end
end

-- The tablet must be the equipped Tool for the feed to stay open. Read off
-- the server-observed Character, never a client claim.
local function isTabletEquipped(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end
	local tool = character:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool:GetAttribute("ItemId") == TABLET_ITEM_ID
end

function CCTVService.StopViewing(player: Player)
	stopViewing(player)
end

function CCTVService.EnterView(player: Player, model: Instance): boolean
	local placed = placedByModel[model]
	-- Owner-only. Shared viewing is a design question this was never asked to
	-- decide, so the conservative default is what ships.
	if not placed or placed.record.owner ~= player then
		return false
	end
	if not placed.lens then
		return false
	end
	viewing[player] = model
	-- Watching a monitor is not something you do while walking -- and more
	-- practically, the player's body is left standing unattended wherever
	-- they opened the feed, so letting them drive it blind would be a way to
	-- move through the map without looking at it.
	CharacterMovementService.SetMovementLocked(player, true)
	-- The whole model goes over too, not just the lens: the client hides it
	-- locally, because the camera sits inside the housing and would otherwise
	-- be staring at the inside of its own shell.
	cctvViewState:FireClient(player, placed.lens, model)
	return true
end

-- Registers a freshly placed camera. Deliberately does NOT open the feed --
-- the player places the camera, then raises the tablet to look through it.
function CCTVService.Place(record, player: Player)
	placedByModel[record.model] = { record = record, lens = findLens(record.model) }

	record.trove:Add(function()
		placedByModel[record.model] = nil
		if viewing[player] == record.model then
			stopViewing(player)
		end
	end)
end

-- The tablet's use: open this player's camera, or shut it if already open.
-- Returns false when they have no placed camera at all, so the caller can
-- report that rather than silently doing nothing.
function CCTVService.TryToggle(player: Player): boolean
	if viewing[player] then
		stopViewing(player)
		return true
	end

	for model, placed in pairs(placedByModel) do
		if placed.record.owner == player then
			return CCTVService.EnterView(player, model)
		end
	end
	return false
end

function CCTVService.IsViewing(player: Player): boolean
	return viewing[player] ~= nil
end

local started = false

function CCTVService.Start()
	if started then
		return
	end
	started = true

	cctvViewState = Remotes.Get("CCTVViewState")

	-- Server-authoritative exit. Switching slots, dropping the tablet, having
	-- it consumed, or losing the character all unequip the tablet, and every
	-- one of those must drop the feed -- so rather than trusting the client to
	-- report each case (and letting a modified one simply not), this watches
	-- the one condition they all reduce to. Same-frame, so the camera returns
	-- the instant the player presses another hotbar key.
	--
	-- Cheap by construction: `viewing` is empty for almost every player almost
	-- always, and a viewer costs one FindFirstChildOfClass plus one attribute
	-- read. Removing the current key inside pairs is safe in Luau.
	RunService.Heartbeat:Connect(function()
		for player in pairs(viewing) do
			if not isTabletEquipped(player) then
				stopViewing(player)
			end
		end
	end)

	-- Dying exits the feed; the placed camera itself survives to match end.
	-- Redundant with the equip watch above (a dead player has no equipped
	-- tool), kept because it fires on the death edge rather than on the next
	-- frame, and because it states the intent explicitly.
	DeathService.Died:Connect(function(payload)
		stopViewing(payload.player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		viewing[player] = nil
	end)
end

return CCTVService
