-- Tints the exit's own marked Part green while that exit is usable, and
-- restores its authored colour the moment it isn't. Presentation only --
-- owns no state and decides no availability, it reads ExitState.
--
-- Server-side for the same reason ExitLabel is: the colour is derived
-- entirely from shared, identical-for-everyone state and the Part is a
-- server-owned workspace instance, so one assignment replicates to every
-- client including late joiners, with no remote and no client controller.
--
-- The authored colour is captured lazily on first sight, BEFORE this module
-- has ever written to the Part -- capturing after a write would latch the
-- green in as the "original" and the exit would never visually re-lock.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local UITheme = require(ReplicatedStorage.Modules.UI.UITheme)
local ExitTypes = require(ReplicatedStorage.Modules.Exit.ExitTypes)

local MatchManager = require(script.Parent.Parent.Match.MatchManager)
local ExitRegistry = require(script.Parent.ExitRegistry)
local ExitState = require(script.Parent.ExitState)

local ExitVisuals = {}

local AVAILABLE_COLOR = UITheme.Colors.Accent

-- [BasePart] = the colour the map author gave it.
local authoredColor: { [BasePart]: Color3 } = {}

-- Same resolution rule as ExitService.volumePartOf: the marker normally sits
-- on the Part itself, but a Model carrying it tints through its PrimaryPart
-- rather than every descendant (which would recolour the sign too).
local function tintPartOf(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	elseif instance:IsA("Model") then
		return instance.PrimaryPart
	end
	return nil
end

function ExitVisuals.Refresh()
	-- Gated on Playing for the same reason ExitLabel's sign text is:
	-- ExitState keeps its last availability until the next match's
	-- WaitingForPlayers reset, so a green exit would otherwise persist
	-- through the whole end-of-match receipt.
	local playing = MatchManager.Is("Playing")

	for _, instance in ipairs(ExitRegistry.All()) do
		local typeName = ExitTypes.TypeOf(instance)
		local part = tintPartOf(instance)

		if typeName and part then
			if authoredColor[part] == nil then
				authoredColor[part] = part.Color
			end

			-- Per instance: the Alternate exits that lost the roll stay their
			-- authored colour, so the green tint is the one honest "this one
			-- works" signal on the map.
			if playing and ExitState.IsInstanceAvailable(instance) then
				part.Color = AVAILABLE_COLOR
			else
				part.Color = authoredColor[part]
			end
		end
	end
end

local started = false

function ExitVisuals.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	-- Availability flips only -- unlike the sign, the colour carries no
	-- progress numbers, so MissionProgress.Changed would be pure churn.
	ExitState.Changed:Connect(ExitVisuals.Refresh)
	MatchManager.StateChanged:Connect(ExitVisuals.Refresh)

	ExitRegistry.Unregistered:Connect(function(instance)
		local part = tintPartOf(instance)
		if part then
			authoredColor[part] = nil
		end
	end)

	-- Capture authored colours immediately rather than on the first flip.
	ExitVisuals.Refresh()
end

return ExitVisuals
