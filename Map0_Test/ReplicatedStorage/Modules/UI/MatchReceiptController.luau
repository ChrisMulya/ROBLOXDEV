-- Wires MatchReceipt (pure UI) to the MatchResultSync remote. Required from
-- BOTH ClientBootstrap role branches, for its side effects -- MatchReplicator
-- fires MatchResultSync on the Game place (on Ending) and ArrivalService
-- fires it on the Lobby (on arrival with a receipt in TeleportData); this one
-- controller renders either.
--
-- Also hides DeathScreen when the receipt shows: the receipt's DisplayOrder
-- already wins the stacking fight (see UIBuilder.CreateScreenGui), but the
-- match ending genuinely supersedes "you died" as the thing on screen, not
-- just visually -- there's no reason for both to stay toggled on.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MatchReceipt = require(script.Parent.MatchReceipt)
local DeathScreen = require(script.Parent.DeathScreen)

local resultSync = Remotes.Get("MatchResultSync")

-- Return To Lobby only makes sense on the Game place -- the Lobby arrival
-- receipt (fired from ArrivalService's TeleportData, not this remote) has
-- nowhere left to "return" to, so it never gets a handler and the button
-- stays hidden there (see MatchReceipt.Show). ServerRole.Is reads
-- game.PlaceId, which is available client-side same as server-side.
--
-- unlockReceiptMouse stays nil on the Lobby: that place never forces
-- LockFirstPerson (see FirstPersonCrosshair, Game-place only), so its mouse
-- is already free by default and there is nothing to fight.
local unlockReceiptMouse: (() -> ())? = nil

if ServerRole.Is("GameServer") then
	local returnRequest = Remotes.Get("ReturnToLobbyRequest")
	MatchReceipt.SetReturnHandler(function()
		returnRequest:FireServer()
	end)

	-- The receipt needs a real clickable cursor (Return To Lobby / Close), but
	-- the camera must stay LockFirstPerson throughout -- the player may have
	-- been alive and playing normally seconds before Ending, and dropping out
	-- of first person for a modal would be a jarring, pointless camera snap.
	-- Contrast with Dead/Spectating (FirstPersonCrosshair), where the camera
	-- itself has nothing left to look at in first person and switches to
	-- Classic instead.
	--
	-- Same pattern CameraShelfClient/PlayerShop already use, for the same
	-- reason: a one-shot MouseBehavior = Default does not stick while
	-- CameraMode is LockFirstPerson -- Roblox's own camera script re-forces
	-- LockCenter every frame -- so this has to fight it back every frame too,
	-- for as long as the receipt is up.
	local mouseUnlocked = false

	unlockReceiptMouse = function()
		if mouseUnlocked then
			return
		end
		mouseUnlocked = true
		UserInputService.MouseIconEnabled = true
		RunService:BindToRenderStep("MatchReceiptMouseUnlock", Enum.RenderPriority.Camera.Value + 1, function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end)
	end

	local function relockReceiptMouse()
		if not mouseUnlocked then
			return
		end
		mouseUnlocked = false
		RunService:UnbindFromRenderStep("MatchReceiptMouseUnlock")
		-- Deliberately does not force MouseBehavior/MouseIconEnabled back:
		-- CameraMode never left LockFirstPerson, so FirstPersonCrosshair's own
		-- RenderStepped loop reclaims both the moment Roblox's camera script
		-- settles MouseBehavior back to LockCenter on its own -- same one-frame
		-- settle CameraShelfClient/PlayerShop already rely on.
	end

	MatchReceipt.SetOnHide(relockReceiptMouse)
end

resultSync.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	DeathScreen.Hide()
	MatchReceipt.Show(payload)
	if unlockReceiptMouse then
		unlockReceiptMouse()
	end
end)

return {}
