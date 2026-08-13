-- Validation for the item-use lifecycle. Two entry points: CanBegin gates
-- starting a hold, StillValid re-gates an active one every Heartbeat tick.
-- Both are read-only -- ItemUseService owns the session and all mutation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ShopCatalog = require(ReplicatedStorage.Modules.Shop.ShopCatalog)
local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MatchStates = require(ReplicatedStorage.Modules.Shared.MatchStates)
local PlayerStates = require(ReplicatedStorage.Modules.Shared.PlayerStates)
local MatchManager = require(ServerScriptService.GameService.Match.MatchManager)
local PlayerStateService = require(ServerScriptService.GameService.PlayerState.PlayerStateService)
local DeployablePlacement = require(script.Parent.ItemWorld.DeployablePlacement)

local ItemUseGuard = {}

-- Studs of root-position drift tolerated during an active hold -- absorbs the
-- movement-lock's own settle and any knockback, without needing client
-- cooperation to enforce "remained stationary".
local MOVE_TOLERANCE = 2

-- (ok, code, tool, itemId, item). tool/itemId/item are only meaningful when
-- ok is true.
function ItemUseGuard.CanBegin(player: Player): (boolean, string?, Tool?, string?, any?)
	if not (ServerRole.Is("GameServer") and MatchStates.IsKitGranted(MatchManager.Get())) then
		return false, "NotInMatch"
	end

	local state = PlayerStateService.Get(player)
	if not state or not PlayerStates.CanControlCharacter(state) then
		return false, "NotAlive"
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not rootPart then
		return false, "NoCharacter"
	end

	-- Server-observed, never client-declared: reads whatever Tool is actually
	-- parented into the Character, not anything the client claims to hold.
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool then
		return false, "NotEquipped"
	end

	local itemId = tool:GetAttribute("ItemId")
	if typeof(itemId) ~= "string" then
		return false, "NotUsable"
	end

	local item = ShopCatalog.Get(itemId)
	if not item or not item.Effect then
		return false, "NotUsable"
	end

	if item.Effect.Kind == "Deploy" then
		if not DeployablePlacement.Probe(rootPart) then
			return false, "NoGround"
		end
	end

	return true, nil, tool, itemId, item
end

-- Returns a cancel code once the session is no longer valid, nil while it may
-- keep running.
function ItemUseGuard.StillValid(session): string?
	local player = session.player
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not rootPart then
		return "NoCharacter"
	end

	-- Compares the Tool INSTANCE, not just its name/ItemId -- catches a
	-- destroy-and-replace (a slot change, a re-purchase) that a name
	-- comparison alone would miss.
	if session.tool.Parent ~= character then
		return "NotEquipped"
	end
	if session.tool:GetAttribute("ItemId") ~= session.itemId then
		return "NotEquipped"
	end

	local state = PlayerStateService.Get(player)
	if not state or not PlayerStates.CanControlCharacter(state) then
		return "NotAlive"
	end

	if not MatchStates.IsKitGranted(MatchManager.Get()) then
		return "NotInMatch"
	end

	if (rootPart.Position - session.anchorPos).Magnitude > MOVE_TOLERANCE then
		return "Moved"
	end

	return nil
end

return ItemUseGuard
