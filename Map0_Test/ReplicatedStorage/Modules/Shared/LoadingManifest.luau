-- Narrow, explicit preload list for the match loading curtain. Data only, no
-- side effects -- same shape as Remotes.ALL_NAMES: a flat list a caller feeds
-- to the real API (here ContentProvider:PreloadAsync, there Remotes.Init).
--
-- Deliberately NOT a blind recursive walk of ReplicatedStorage.Assets: that
-- would preload things gameplay never needs before Playing (e.g. the CCTV
-- tablet's own remotes folder) and would break silently every time someone
-- adds an unrelated asset. Every entry below is required to render or equip
-- something during Loading/WaitingForPlayers -- see the plan's "required vs
-- optional" table.
--
-- The Assets tree is hand-placed in Studio and not guaranteed present (see
-- ShopCatalog's own note on this) -- Collect() skips anything missing rather
-- than erroring, and the caller counts/warns misses instead of failing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LoadingManifest = {}

local function addChildren(list: { Instance }, parent: Instance?)
	if not parent then
		return
	end
	for _, child in ipairs(parent:GetChildren()) do
		table.insert(list, child)
	end
end

-- Returns every Instance worth preloading before gameplay starts. Missing
-- subtrees are skipped, not errored -- a fresh map with no Assets folder yet
-- must still be playable.
function LoadingManifest.Collect(): { Instance }
	local list: { Instance } = {}

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets then
		addChildren(list, assets:FindFirstChild("Monster"))

		local tool = assets:FindFirstChild("Tool")
		if tool then
			addChildren(list, tool:FindFirstChild("Camera"))

			local supportItem = tool:FindFirstChild("SupportItem")
			if supportItem then
				-- Plain equippable support-item Tools themselves.
				for _, child in ipairs(supportItem:GetChildren()) do
					if child:IsA("Tool") then
						table.insert(list, child)
					end
				end
				-- World-placed variants (PlacedMotionSensor, PlacedCompactSpeaker,
				-- PlacedPortableCCTV) render mid-match with no curtain covering
				-- them. ItemRemotes (the CCTV tablet UI) is excluded on purpose --
				-- it only appears on use, not at match start.
				addChildren(list, supportItem:FindFirstChild("PlacedItem"))
			end
		end

		addChildren(list, assets:FindFirstChild("Pickup"))
	end

	local sounds = ReplicatedStorage:FindFirstChild("Sounds")
	if sounds then
		addChildren(list, sounds:FindFirstChild("Tool"))
	end

	return list
end

return LoadingManifest
