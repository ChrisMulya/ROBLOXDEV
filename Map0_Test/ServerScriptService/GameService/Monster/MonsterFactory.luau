-- Turns a monster config into a workspace Model.
--
-- Two sources, chosen by config.Model.Source:
--   "Asset"   -- clone ReplicatedStorage/Assets/Monster/<Path>
--   "Builder" -- run a code builder from MonsterService's MODEL_BUILDERS,
--                for a monster that has no art yet (none today)
--
-- The factory also VALIDATES the result against the model contract, because a
-- rig that violates it fails in ways that look like framework bugs: an anchored
-- assembly computes perfect paths and never moves, and a Humanoid with
-- MaxHealth 0 dies on spawn and (with BreakJointsOnDeath) scatters into loose
-- parts. Both are silent. Reporting them by name at spawn is the difference
-- between a five-minute fix and an afternoon.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Locomotion = require(script.Parent.Locomotion)

local MonsterFactory = {}

local ASSETS_FOLDER = "Monster"

-- Locomotion strategies have OPPOSITE anchoring requirements, and getting it
-- backwards is invisible at spawn. The factory sets Anchored from the config
-- rather than trusting whatever the template was saved with, so a template
-- authored the wrong way still works.
local ANCHORED_BY_LOCOMOTION = {
	Kinematic = true,     -- direct CFrame writes; physics must not fight them
	HumanoidPath = false, -- Humanoid:MoveTo applies force; anchored ignores it
	Fly = false,
	Teleport = true,
}

-- Must agree with Locomotion.Get, which falls back to Locomotion.Default for an
-- unknown name. If this returned nil instead, a config with a typo'd strategy
-- would get Kinematic movement with the template's own anchoring -- an
-- unanchored part driven by direct CFrame writes, fighting physics every frame.
local function resolveLocomotionName(config): string
	local name = config.Navigation and config.Navigation.Locomotion
	if name and ANCHORED_BY_LOCOMOTION[name] ~= nil then
		return name
	end
	return Locomotion.Default
end

local function assetsRoot(): Folder?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild(ASSETS_FOLDER)
	return folder :: Folder?
end

-- Returns (ok, issues). Never mutates. Issues are phrased as what to fix, not
-- what is wrong, because they're read by whoever has the model open in Studio.
function MonsterFactory.Validate(model: Model, config): (boolean, { string })
	local issues = {}

	local rootPart = model:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		table.insert(issues, "needs a BasePart named exactly 'HumanoidRootPart'")
	end

	if not model.PrimaryPart then
		table.insert(issues, "PrimaryPart is not set (should be HumanoidRootPart)")
	end

	local locomotion = resolveLocomotionName(config)
	local wantsHumanoid = locomotion == "HumanoidPath"
	local humanoid = model:FindFirstChildOfClass("Humanoid")

	if wantsHumanoid then
		if not humanoid then
			table.insert(issues, "Locomotion 'HumanoidPath' requires a Humanoid")
		else
			-- Health is clamped to MaxHealth, so MaxHealth 0 kills the monster
			-- the moment it spawns. With BreakJointsOnDeath the rig then falls
			-- apart. This is the single most common broken-rig symptom.
			if humanoid.MaxHealth <= 0 then
				table.insert(issues, "Humanoid.MaxHealth is 0 -- it will die on spawn; set it above 0")
			end

			-- R15 drives scaling and part lookup off UpperTorso/LowerTorso/etc.
			-- A rig with R6 names under R15 has neither.
			if humanoid.RigType == Enum.HumanoidRigType.R15 and not model:FindFirstChild("UpperTorso") then
				table.insert(issues, "Humanoid.RigType is R15 but the rig has no UpperTorso -- set RigType to R6 if these are R6 parts")
			end

			if humanoid.RequiresNeck and not model:FindFirstChild("Torso") then
				table.insert(issues, "Humanoid.RequiresNeck is true but there is no Torso -- the neck check can kill it; set RequiresNeck false or add a Torso")
			end

			if not model:FindFirstChildWhichIsA("Motor6D", true) then
				table.insert(issues, "no Motor6D joints -- animation will not play")
			end
		end
	end

	-- Anchoring is per-ASSEMBLY: one anchored part immobilises the whole rig,
	-- so this has to walk every descendant, not just the root.
	local wantAnchored = ANCHORED_BY_LOCOMOTION[locomotion]
	if wantAnchored == false then
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant.Anchored then
				table.insert(issues, ("'%s' is anchored -- one anchored part immobilises the whole assembly (corrected at spawn, but fix the template)"):format(descendant.Name))
				break
			end
		end

		local collides = false
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant.CanCollide then
				collides = true
				break
			end
		end
		if not collides then
			table.insert(issues, "no part has CanCollide -- it will fall through the map")
		end
	end

	return #issues == 0, issues
end

local function cloneAsset(config): Model?
	local root = assetsRoot()
	if not root then
		warn("MonsterFactory: ReplicatedStorage/Assets/Monster is missing")
		return nil
	end

	local path = config.Model.Path or config.Id
	local template = root:FindFirstChild(path)
	if not template or not template:IsA("Model") then
		warn(("MonsterFactory: no Model named '%s' in Assets/Monster"):format(tostring(path)))
		return nil
	end

	return template:Clone()
end

-- Applies the anchoring the locomotion strategy needs, overriding whatever the
-- template was saved with. Cosmetic descendants keep their own CanCollide.
local function applyAnchoring(model: Model, config)
	local anchored = ANCHORED_BY_LOCOMOTION[resolveLocomotionName(config)]

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = anchored
		end
	end
end

-- Returns the model UNPARENTED. The caller sets attributes and pivots it into
-- place before parenting -- an unanchored rig parented first and positioned
-- second falls for a frame and can end up under the floor.
function MonsterFactory.Create(config, builders): Model?
	local source = config.Model and config.Model.Source or "Builder"
	local model

	if source == "Asset" then
		model = cloneAsset(config)
	elseif source == "Builder" then
		local builderName = config.Model.Builder or config.Id
		local builder = builders and builders[builderName]
		if not builder then
			warn(("MonsterFactory: no builder '%s'"):format(tostring(builderName)))
			return nil
		end
		model = builder()
	else
		warn(("MonsterFactory: unknown Model.Source '%s'"):format(tostring(source)))
		return nil
	end

	if not model then
		return nil
	end

	-- Validate BEFORE correcting anchoring, so the report describes the
	-- template as authored. Running it after would make the anchoring check
	-- dead code -- applyAnchoring has already fixed exactly what it looks for,
	-- and a silently-corrected template never gets fixed at the source.
	local ok, issues = MonsterFactory.Validate(model, config)
	applyAnchoring(model, config)

	if not ok then
		-- Warn but still spawn: a monster that appears and behaves oddly is
		-- more debuggable than one that silently never appears, and the issue
		-- list says exactly what to open in Studio.
		warn(("MonsterFactory: '%s' violates the model contract:\n  - %s")
			:format(config.Id, table.concat(issues, "\n  - ")))
	end

	return model
end

return MonsterFactory
