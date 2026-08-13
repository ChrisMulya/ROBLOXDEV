-- Ground probe + clone/anchor helper shared by every Deploy-kind item
-- (Motion Sensor, Compact Speaker, Portable CCTV). No general-purpose
-- placement utility exists yet in the repo -- FlashlightService's emitter
-- Part is the nearest construction precedent, and Monster/Components/
-- Navigation:ResolveReachable is the nearest ground-probe precedent, but
-- both are instance methods on something this module has no access to
-- (a Character, a monster component). This is the standalone equivalent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopCatalog = require(ReplicatedStorage.Modules.Shop.ShopCatalog)

local DeployablePlacement = {}

local GROUND_PROBE_UP = 3
local GROUND_PROBE_DOWN = 12

local probeParams = RaycastParams.new()
probeParams.FilterType = Enum.RaycastFilterType.Exclude
probeParams.RespectCanCollide = true

-- Returns a ground position under rootPart, or nil if there is no floor
-- within the probe envelope (a ledge, mid-air) -- checked by ItemUseGuard
-- BEFORE the 3-second hold starts, so a doomed placement fails immediately
-- instead of consuming a full hold for nothing.
function DeployablePlacement.Probe(rootPart: BasePart): Vector3?
	local character = rootPart.Parent
	probeParams.FilterDescendantsInstances = character and { character } or {}

	local origin = rootPart.Position + Vector3.new(0, GROUND_PROBE_UP, 0)
	local drop = Vector3.new(0, -(GROUND_PROBE_UP + GROUND_PROBE_DOWN), 0)
	local result = workspace:Raycast(origin, drop, probeParams)
	if not result then
		return nil
	end
	return result.Position
end

-- Clones the named PlacedItem asset, anchors every BasePart in it, and
-- parents it to Workspace.Deployables -- the world, never the player's
-- character. Returns nil if the asset is missing, same graceful-degrade
-- shape as ShopCatalog.ResolveTemplate: a missing Studio asset becomes a
-- "Failed" result code, not a hard error.
function DeployablePlacement.Place(assetName: string, groundPosition: Vector3): Instance?
	local template = ShopCatalog.ResolvePlacedAsset(assetName)
	if not template then
		warn("DeployablePlacement: no PlacedItem asset named", assetName, "under Assets.Tool.SupportItem.PlacedItem")
		return nil
	end

	local instance = template:Clone()

	local folder = workspace:FindFirstChild("Deployables")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Deployables"
		folder.Parent = workspace
	end

	-- Anchor BEFORE positioning, so nothing settles under physics between the
	-- two writes once this is parented.
	if instance:IsA("Model") then
		for _, descendant in ipairs(instance:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
			end
		end

		-- PivotTo unconditionally. This used to be gated on
		-- `instance.PrimaryPart`, which is the bug that left a hand-authored
		-- model (PrimaryPart unset, which Studio does NOT set for you) sitting
		-- at its template coordinates instead of at the player's feet -- with
		-- no error, because skipping the move is silent. Model:PivotTo needs no
		-- PrimaryPart; GetPivot falls back to the bounding-box centre.
		--
		-- Lifted so the model's BOTTOM rests on the ground rather than its
		-- pivot: groundPosition is the floor surface, and a centre pivot would
		-- bury half the object. Measured against the pivot rather than assumed
		-- centred, so an authored off-centre PrimaryPart still lands right.
		local boxCFrame, boxSize = instance:GetBoundingBox()
		local lift = instance:GetPivot().Position.Y - (boxCFrame.Position.Y - boxSize.Y * 0.5)
		instance:PivotTo(CFrame.new(groundPosition + Vector3.new(0, lift, 0)))
	elseif instance:IsA("BasePart") then
		instance.Anchored = true
		instance.CanCollide = false
		instance.CFrame = CFrame.new(groundPosition + Vector3.new(0, instance.Size.Y * 0.5, 0))
	end

	instance.Parent = folder
	return instance
end

-- The BasePart to hang things off a placed deployable: a Sound, a light, an
-- Attachment. PrimaryPart when the author set one, otherwise the first
-- BasePart in the model -- the same "don't require PrimaryPart, Studio does
-- not set it for you" reasoning as Place above.
function DeployablePlacement.ResolvePart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") then
		if instance.PrimaryPart then
			return instance.PrimaryPart
		end
		return instance:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

return DeployablePlacement
