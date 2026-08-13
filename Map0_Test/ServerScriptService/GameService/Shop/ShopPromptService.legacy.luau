-- Server-side "is the Shop actually open for this player" gate, mirroring
-- CameraShelfHandler's shelfOpenFor pattern. Without this, BuyHandler had no
-- way to know whether a BuyItem request came from a legitimately opened Shop
-- UI or was hand-fired at a part the player never interacted with, and no way
-- to refuse the Shop outside an active match.
--
-- This is the one new file in the Shop refinement -- everything else refines
-- an existing file. Nothing on disk previously fired OpenShop at all; the
-- only firer was a 9-line Script living inside the Studio place with none of
-- these gates. Shared open/closed state lives in ShopSession (a ModuleScript,
-- since this Script can't be required by BuyHandler.legacy.luau directly).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MatchStates = require(ReplicatedStorage.Modules.Shared.MatchStates)
local MatchManager = require(script.Parent.Parent.Match.MatchManager)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local ShopSession = require(script.Parent.ShopSession)

local OpenShop = Remotes.Get("OpenShop")

local MAX_INTERACT_DISTANCE = 12 -- studs; same margin BuyHandler enforces on purchase

local function isShopPart(part: Instance?): boolean
	return part ~= nil and part:GetAttribute("IsShop") == true
end

local function shopAvailable(): boolean
	return ServerRole.Is("GameServer") and MatchStates.IsKitGranted(MatchManager.Get())
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	local part = prompt.Parent
	if not isShopPart(part) then
		return
	end

	if not shopAvailable() then
		return
	end

	ShopSession.Open(player, part :: BasePart)
	OpenShop:FireClient(player, part)
end)

Players.PlayerRemoving:Connect(function(player)
	ShopSession.Close(player)
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterRemoving:Connect(function()
		ShopSession.Close(player)
	end)
end)

-- Distance-based auto-clear, same interval family as CameraShelfHandler's
-- cooldowns. Keeps the session map from growing stale if a player walks away
-- without ever closing the UI client-side (alt-tab, client crash, etc).
task.spawn(function()
	while true do
		task.wait(2)
		for userId, part in pairs(ShopSession.GetAll()) do
			local player = Players:GetPlayerByUserId(userId)
			local character = player and player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			if not player or not rootPart or not part.Parent then
				if player then
					ShopSession.Close(player)
				end
			else
				local distance = (rootPart.Position - part.Position).Magnitude
				if distance > MAX_INTERACT_DISTANCE then
					ShopSession.Close(player)
				end
			end
		end
	end
end)
