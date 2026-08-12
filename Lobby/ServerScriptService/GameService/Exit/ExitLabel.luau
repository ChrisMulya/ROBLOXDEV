-- Renders the current exit requirement onto each exit's authored
-- world-space sign (DisplayLabel > BillboardGui > TextLabel).
--
-- Server-side rather than a client controller: the sign text is derived
-- entirely from shared, identical-for-everyone state, and the BillboardGui
-- lives in workspace where the server already owns it -- so setting .Text
-- once replicates to every client (including late joiners) with no remote,
-- no client bootstrap entry, and no client-side discovery pass. A client
-- controller would be the right call only if the text ever differed per
-- player, which by design it never does.
--
-- Presentation only. Owns no state, decides no availability -- it reads
-- ExitState/MissionProgress and writes the sign's text. All wording comes
-- from ExitRequirements (the shared pure module), never a literal here, so
-- the sign and any future Mission UI row can't drift apart.
--
-- The sign is deliberately always white and unlit: BillboardGui.LightInfluence
-- is forced to 0 so a night-time exit stays legible regardless of what
-- MatchTimeLighting is doing to the scene. Availability is communicated by
-- the text itself (OPEN), not by colour -- a colour-coded sign would be
-- exactly the thing the lighting rig washes out.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local UITheme = require(ReplicatedStorage.Modules.UI.UITheme)
local MatchTimeMath = require(ReplicatedStorage.Modules.MatchTime.MatchTimeMath)
local ExitTypes = require(ReplicatedStorage.Modules.Exit.ExitTypes)
local ExitConfig = require(ReplicatedStorage.Modules.Exit.ExitConfig)
local ExitRequirements = require(ReplicatedStorage.Modules.Exit.ExitRequirements)

local MissionProgress = require(script.Parent.Parent.Match.MissionProgress)
local MatchManager = require(script.Parent.Parent.Match.MatchManager)
local ExitRegistry = require(script.Parent.ExitRegistry)
local ExitState = require(script.Parent.ExitState)

local ExitLabel = {}

local OPEN_TEXT = "OPEN"

-- An Alternate that lost this match's roll. Not "Sealed until 3 AM" (that is
-- a promise this sign can no longer keep) and not the requirement progress
-- (satisfying it will never open THIS door) -- the sign has to say the exit is
-- simply out of play.
local SEALED_TEXT = "Sealed"

-- The authored sign is 200x50 at TextSize 20, which fits two lines. MainExit
-- needs three (title + Objectives + Documents), so the sign is resized to its
-- content here rather than left to clip the last line away silently.
-- SIGN_WIDTH is chosen so the longest string this module can produce
-- ("Monster Photo : 1400/2000") never wraps -- a wrapped line would make the
-- newline count below under-report the real height.
local SIGN_WIDTH = 320
local SIGN_LINE_HEIGHT = 26 -- TextSize 20 plus breathing room
local SIGN_PADDING = 10

-- [exitInstance] = { billboard, label }. Refresh runs on every
-- MissionProgress.Changed (i.e. every awarded capture), so the recursive
-- FindFirstChild walk is done once per exit rather than once per photo.
type Sign = { billboard: BillboardGui, label: TextLabel }

local signCache: { [Instance]: Sign } = {}

-- The marker attributes sit on the exit's collision Part, and DisplayLabel is
-- that Part's SIBLING inside a shared Model -- so a descendant-only search
-- finds nothing. Try the registered instance first (in case a future map
-- marks the Model itself), then its Model parent.
local function findSign(instance: Instance): Sign?
	local labelPart = instance:FindFirstChild(ExitTypes.LabelPartName, true)

	if not labelPart then
		local parent = instance.Parent
		if parent and parent:IsA("Model") then
			labelPart = parent:FindFirstChild(ExitTypes.LabelPartName, true)
		end
	end

	if not labelPart then
		return nil
	end

	local billboard = labelPart:FindFirstChildWhichIsA("BillboardGui", true)
	if not billboard then
		return nil
	end

	local label = billboard:FindFirstChildWhichIsA("TextLabel", true)
	if not label then
		return nil
	end

	-- Both set once here, on the cache-miss path, rather than every Refresh.
	--
	-- LightInfluence: authored as 1 (fully lit), which fades the sign to
	-- near-black under the night lighting the match runs in.
	--
	-- ClipsDescendants: authored as true, which is what silently ate
	-- MainExit's third line. Off is the belt-and-braces pairing for the
	-- computed height below -- if a future string does overflow, it renders
	-- past the sign rather than vanishing without a trace.
	billboard.LightInfluence = 0
	billboard.ClipsDescendants = false

	return { billboard = billboard, label = label }
end

local function signFor(instance: Instance): Sign?
	local cached = signCache[instance]
	if cached and cached.label.Parent then
		return cached
	end

	local sign = findSign(instance)
	if sign then
		signCache[instance] = sign
	end
	return sign
end

-- Grows the sign to fit however many lines the current text needs, so the
-- two-line Alternate sign stays compact and the three-line Main sign isn't
-- cropped. Assigning an unchanged UDim2 is a no-op, so this is safe to call
-- on every Refresh.
local function applySize(sign: Sign, text: string)
	local _, newlines = text:gsub("\n", "")
	local height = (newlines + 1) * SIGN_LINE_HEIGHT + SIGN_PADDING
	local size = UDim2.fromOffset(SIGN_WIDTH, height)

	sign.billboard.Size = size
	sign.label.Size = size
end

-- Returns the sign text for one exit kind. Outside Playing the sign shows
-- only the exit's name: ExitReplicator clears its attributes there too, and
-- a stale "OPEN" on a sign between matches would be actively misleading.
-- Takes the instance, not just its kind: after the unlock hour the Alternate
-- exits no longer share a sign, because only the chosen one can ever open.
local function describe(instance: Instance, typeName: string, snapshot): string
	local typeDef = ExitTypes.Get(typeName)
	local title = typeDef and typeDef.DisplayName or typeName

	if not MatchManager.Is("Playing") then
		return title
	end

	if ExitState.IsInstanceAvailable(instance) then
		return ("%s\n%s"):format(title, OPEN_TEXT)
	end

	if typeName == "Main" then
		return ("%s\n%s"):format(title, ExitRequirements.DescribeMainProgress(snapshot))
	end

	-- Alternate, still locked: before the hour-27 roll there is no
	-- requirement to show yet, so name the time it unlocks instead. The hour
	-- string is formatted from ExitConfig.AlternateUnlockHour rather than
	-- written out, so retuning the unlock hour retitles the sign for free.
	local requirement = ExitState.GetRequirement()
	if not requirement then
		local unlockText = MatchTimeMath.FormatHour(ExitConfig.AlternateUnlockHour)
		return ("%s\nSealed until %s"):format(title, unlockText)
	end

	-- The roll has happened and this one lost: its requirement progress is no
	-- longer its own story to tell.
	if ExitState.GetSelectedAlternate() ~= instance then
		return ("%s\n%s"):format(title, SEALED_TEXT)
	end

	return ("%s\n%s"):format(title, ExitRequirements.DescribeProgress(requirement, snapshot))
end

-- Writes Text, forces white, and sizes the sign to the line count.
-- LightInfluence/ClipsDescendants are handled once at resolve time. Font,
-- TextSize, alignment and world placement all stay the designer's.
function ExitLabel.Refresh()
	local snapshot = MissionProgress.Get()

	for _, instance in ipairs(ExitRegistry.All()) do
		local typeName = ExitTypes.TypeOf(instance)
		if typeName then
			local sign = signFor(instance)
			if sign then
				local text = describe(instance, typeName, snapshot)
				sign.label.Text = text
				sign.label.TextColor3 = UITheme.Colors.Text
				applySize(sign, text)
			end
		end
	end
end

local started = false

function ExitLabel.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	-- Availability flips and the hour-27 requirement roll.
	ExitState.Changed:Connect(ExitLabel.Refresh)

	-- Progress numbers move without availability changing (1400 -> 1500 of
	-- 2000), which ExitState.Changed deliberately does not fire for.
	MissionProgress.Changed:Connect(ExitLabel.Refresh)

	-- Entering/leaving Playing swaps the whole sign between the name-only
	-- form and the live form.
	MatchManager.StateChanged:Connect(ExitLabel.Refresh)

	ExitRegistry.Unregistered:Connect(function(instance)
		signCache[instance] = nil
	end)

	-- Paint the pre-match state immediately rather than leaving the authored
	-- placeholder text up until the first signal fires.
	ExitLabel.Refresh()
end

return ExitLabel
