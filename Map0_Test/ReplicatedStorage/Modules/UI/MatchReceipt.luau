-- Pure UI: renders whatever MatchResultSync's payload contains. No remote
-- access, no game logic. Panel chrome (backdrop, rounded panel, close button)
-- comes from UIBuilder so this and DeathScreen stay visually identical.
--
-- Three kinds of content, top to bottom, and the panel sizes itself to
-- whichever of them are actually present (same philosophy as
-- DeathScreen.renderButtons resizing to its surviving button count):
--   * GRADE + PERSONAL STATS reads payload.perPlayer.Stats -- this player's
--     own slice from Match/MatchStats.luau: survivedSeconds, a grade letter,
--     and a capture count per CaptureTargets type. The per-type rows are
--     driven entirely by CaptureTargets.OrderedNames()/StatLabel, so a
--     future Artifact row appears here with zero edits to this file.
--   * The SCOREBOARD reads payload.roster -- an ordered array of
--     { userId, slices } for every participant -- but only when there are
--     2+ of them. A solo run has nothing to rank itself against, so it shows
--     just the personal stats above instead of a one-row table.
--   * The DETAIL block still renders any OTHER contributor's slice off
--     payload.perPlayer generically, key by key (skipping Player/Reward/
--     Stats, which already have dedicated UI). That's what keeps R2: a
--     genuinely new, unanticipated contributor still shows up here with no
--     edit to this file, even though the three named ones don't.
--
-- Missing fields degrade rather than error: an absent Player slice (the
-- participant disconnected before Ending) falls back to the userId, an
-- absent Reward slice renders as 0, and an absent Stats slice simply hides
-- the grade/personal-stats section instead of showing zeroes for data that
-- was never computed.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UIBuilder = require(script.Parent.UIBuilder)
local UITheme = require(script.Parent.UITheme)
local MatchResultCodes = require(script.Parent.Parent.Shared.MatchResultCodes)
local CaptureTargets = require(script.Parent.Parent.Reward.CaptureTargets)

local MatchReceipt = {}

local PANEL_WIDTH = 420
local ROW_HEIGHT = 30
local HEADER_HEIGHT = 60 -- title + subtitle, fixed regardless of content below
local GAP = 12 -- vertical breathing room between sections
local GRADE_HEIGHT = 76
local STAT_ROW_HEIGHT = 22
local STAT_ROW_GAP = 2
local COLUMN_HEADER_HEIGHT = 18
local SCOREBOARD_HEIGHT = 132
local DETAIL_HEIGHT = 40
local BUTTON_HEIGHT = 36

local screenGui: ScreenGui? = nil
local panel: Frame? = nil
local titleLabel: TextLabel? = nil
local subtitleLabel: TextLabel? = nil
local gradeLabel: TextLabel? = nil
local statsHolder: Frame? = nil
local columnHeader: Frame? = nil
local scoreList: ScrollingFrame? = nil
local detailLabel: TextLabel? = nil
local returnButton: TextButton? = nil

-- Set via MatchReceipt.SetReturnHandler, same convention as
-- QueueHud.SetActionHandler: this module never touches a remote itself, the
-- caller decides what "return" means. The button only renders once a
-- handler is registered -- a click target that's known to do nothing is
-- worse than no button, and MatchReceiptController is the one that decides
-- WHETHER to register one (only on the Game place, once the request remote
-- exists to back it).
local returnHandler: (() -> ())? = nil

-- workspace:GetServerTimeNow() deadline for the automatic return (set from
-- payload.returnsAt, Game place only -- see MatchReplicator). nil means no
-- countdown is running, either because there's no handler or the payload
-- didn't carry one (e.g. the Lobby arrival receipt).
local returnsAt: number? = nil

function MatchReceipt.SetReturnHandler(fn: (() -> ())?)
	returnHandler = fn
end

local function returnButtonText(): string
	if returnsAt then
		local remaining = math.max(0, math.ceil(returnsAt - workspace:GetServerTimeNow()))
		return ("Return To Lobby (%d)"):format(remaining)
	end
	return "Return To Lobby"
end

local function buildHeader(parent: Frame)
	local pad = UITheme.Layout.PanelPadding

	titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -(pad * 2) - 34, 0, 28)
	titleLabel.Position = UDim2.fromOffset(pad, 16)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = UITheme.Fonts.Bold
	titleLabel.TextColor3 = UITheme.Colors.Text
	titleLabel.TextSize = 22
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.ZIndex = 2
	titleLabel.Text = ""
	titleLabel.Parent = parent

	subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.Size = UDim2.new(1, -(pad * 2), 0, 16)
	subtitleLabel.Position = UDim2.fromOffset(pad, 44)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Font = UITheme.Fonts.Regular
	subtitleLabel.TextColor3 = UITheme.Colors.TextMuted
	subtitleLabel.TextSize = 13
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.ZIndex = 2
	subtitleLabel.Text = ""
	subtitleLabel.Parent = parent
end

-- The letter itself: large, bold, accent-coloured, centered -- the visual
-- anchor of the screen. Position.Y is set per-Show() by the layout cursor.
local function buildGrade(parent: Frame)
	local pad = UITheme.Layout.PanelPadding

	gradeLabel = Instance.new("TextLabel")
	gradeLabel.Name = "Grade"
	gradeLabel.Size = UDim2.new(1, -(pad * 2), 0, GRADE_HEIGHT)
	gradeLabel.BackgroundTransparency = 1
	gradeLabel.Font = UITheme.Fonts.Bold
	gradeLabel.TextColor3 = UITheme.Colors.Accent
	gradeLabel.TextSize = 64
	gradeLabel.TextXAlignment = Enum.TextXAlignment.Center
	gradeLabel.TextYAlignment = Enum.TextYAlignment.Center
	gradeLabel.ZIndex = 2
	gradeLabel.Visible = false
	gradeLabel.Text = ""
	gradeLabel.Parent = parent
end

local function buildStatsHolder(parent: Frame)
	local pad = UITheme.Layout.PanelPadding

	statsHolder = Instance.new("Frame")
	statsHolder.Name = "Stats"
	statsHolder.Size = UDim2.new(1, -(pad * 2), 0, 0)
	statsHolder.BackgroundTransparency = 1
	statsHolder.ZIndex = 2
	statsHolder.Parent = parent
end

local function buildStatRow(text: string, order: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "StatRow" .. tostring(order)
	label.Size = UDim2.new(1, 0, 0, STAT_ROW_HEIGHT)
	label.Position = UDim2.new(0, 0, 0, (order - 1) * (STAT_ROW_HEIGHT + STAT_ROW_GAP))
	label.BackgroundTransparency = 1
	label.Font = UITheme.Fonts.Medium
	label.TextColor3 = UITheme.Colors.Text
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 2
	label.Text = text
	return label
end

-- Column header + the scrolling body. Widths are shared with buildRow below
-- via the same three UDim2s, so a column can't drift between them.
local COL_NAME = UDim2.new(1, -150, 1, 0)
local COL_SCORE = UDim2.fromOffset(70, ROW_HEIGHT)
local COL_XP = UDim2.fromOffset(70, ROW_HEIGHT)

local function buildColumnHeader(parent: Frame)
	local pad = UITheme.Layout.PanelPadding

	columnHeader = Instance.new("Frame")
	columnHeader.Name = "Columns"
	columnHeader.Size = UDim2.new(1, -(pad * 2), 0, COLUMN_HEADER_HEIGHT)
	columnHeader.BackgroundTransparency = 1
	columnHeader.ZIndex = 2

	local function column(name: string, text: string, size: UDim2, position: UDim2, alignment)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Size = size
		label.Position = position
		label.BackgroundTransparency = 1
		label.Font = UITheme.Fonts.Medium
		label.TextColor3 = UITheme.Colors.TextMuted
		label.TextSize = 11
		label.TextXAlignment = alignment
		label.ZIndex = 2
		label.Text = text
		label.Parent = columnHeader
	end

	column("NameHeader", "PLAYER", COL_NAME, UDim2.fromOffset(10, 0), Enum.TextXAlignment.Left)
	column("ScoreHeader", "SCORE", COL_SCORE, UDim2.new(1, -140, 0, 0), Enum.TextXAlignment.Right)
	column("XpHeader", "XP", COL_XP, UDim2.new(1, -70, 0, 0), Enum.TextXAlignment.Right)

	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.Position = UDim2.new(0, 0, 1, 0)
	divider.BackgroundColor3 = UITheme.Colors.Divider
	divider.BackgroundTransparency = 0.4
	divider.BorderSizePixel = 0
	divider.ZIndex = 2
	divider.Parent = columnHeader

	columnHeader.Parent = parent
end

local function buildScoreList(parent: Frame)
	local pad = UITheme.Layout.PanelPadding

	scoreList = Instance.new("ScrollingFrame")
	scoreList.Name = "Scoreboard"
	scoreList.Size = UDim2.new(1, -(pad * 2), 0, SCOREBOARD_HEIGHT)
	scoreList.BackgroundTransparency = 1
	scoreList.BorderSizePixel = 0
	scoreList.ScrollBarThickness = 3
	scoreList.ScrollBarImageColor3 = UITheme.Colors.Divider
	scoreList.CanvasSize = UDim2.new()
	scoreList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scoreList.ZIndex = 2

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scoreList

	scoreList.Parent = parent
end

local function buildDetailLabel(parent: Frame)
	local pad = UITheme.Layout.PanelPadding

	detailLabel = Instance.new("TextLabel")
	detailLabel.Name = "Detail"
	detailLabel.Size = UDim2.new(1, -(pad * 2), 0, DETAIL_HEIGHT)
	detailLabel.BackgroundTransparency = 1
	detailLabel.Font = UITheme.Fonts.Regular
	detailLabel.TextColor3 = UITheme.Colors.TextMuted
	detailLabel.TextSize = 12
	detailLabel.TextXAlignment = Enum.TextXAlignment.Left
	detailLabel.TextYAlignment = Enum.TextYAlignment.Top
	detailLabel.TextWrapped = true
	detailLabel.ZIndex = 2
	detailLabel.Text = ""
	detailLabel.Visible = false
	detailLabel.Parent = parent
end

local function buildReturnButton(parent: Frame)
	local pad = UITheme.Layout.PanelPadding

	returnButton = Instance.new("TextButton")
	returnButton.Name = "ReturnToLobby"
	returnButton.Size = UDim2.new(1, -(pad * 2), 0, BUTTON_HEIGHT)
	returnButton.BackgroundColor3 = UITheme.Colors.Accent
	returnButton.BorderSizePixel = 0
	returnButton.AutoButtonColor = false
	returnButton.Font = UITheme.Fonts.Bold
	-- Dark text on the bright accent -- white on this green is unreadable.
	-- Same styling as DeathScreen's buttons, deliberately: one button
	-- language across both modals.
	returnButton.TextColor3 = UITheme.Colors.PanelBackground
	returnButton.TextSize = 16
	returnButton.Text = "Return To Lobby"
	returnButton.ZIndex = 2
	returnButton.Visible = false

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UITheme.Layout.RowCornerRadius
	corner.Parent = returnButton

	returnButton.MouseEnter:Connect(function()
		returnButton.BackgroundTransparency = 0.15
	end)
	returnButton.MouseLeave:Connect(function()
		returnButton.BackgroundTransparency = 0
	end)

	-- Reads the CURRENT handler at click time rather than capturing one at
	-- build time -- SetReturnHandler can be called after ensureBuilt already
	-- ran (it will have, since Show() always calls ensureBuilt first).
	returnButton.Activated:Connect(function()
		if returnHandler then
			returnHandler()
		end
	end)

	returnButton.Parent = parent
end

-- Single Heartbeat connection for the button's own lifetime (built once,
-- same as everything else in ensureBuilt), ticking at 5/sec -- same interval
-- style as QueuePadDisplay's accumulator, just simpler since there's only
-- ever one button. No-ops whenever there's nothing to count down.
local tickAccumulator = 0
local TICK_INTERVAL = 0.2

local function connectCountdown()
	RunService.Heartbeat:Connect(function(delta)
		if not returnsAt or not returnButton.Visible then
			return
		end
		tickAccumulator += delta
		if tickAccumulator < TICK_INTERVAL then
			return
		end
		tickAccumulator = 0
		returnButton.Text = returnButtonText()
	end)
end

local function ensureBuilt()
	if screenGui then
		return
	end

	-- DisplayOrder 50: above DeathScreenGui (40) so the match-end summary
	-- wins the coin flip if both are ever shown in the same instant (a solo
	-- death that also ends the match) -- see UIBuilder.CreateScreenGui.
	screenGui = UIBuilder.CreateScreenGui("MatchReceiptGui", UIBuilder.GetPlayerGui(), 50)
	-- Exempts this from CameraSession.hideOtherGuis: tools/cameras aren't
	-- stripped until Cleanup (several seconds after Ending), so a camera
	-- session can still be entered while the receipt is up. Without this
	-- attribute the receipt would go dark and nothing ever re-shows it.
	screenGui:SetAttribute("KeepDuringCamera", true)
	UIBuilder.CreateBackdrop(screenGui)

	panel = UIBuilder.CreatePanel(screenGui, UDim2.fromOffset(PANEL_WIDTH, HEADER_HEIGHT))
	UIBuilder.CreateCloseButton(panel, function()
		MatchReceipt.Hide()
	end)

	buildHeader(panel)
	buildGrade(panel)
	buildStatsHolder(panel)
	buildColumnHeader(panel)
	buildScoreList(panel)
	buildDetailLabel(panel)
	buildReturnButton(panel)
	connectCountdown()
end

local function buildRow(entry: { userId: number, slices: any }, order: number, isLocalPlayer: boolean): Frame
	local reward = (typeof(entry.slices) == "table" and entry.slices.Reward) or {}
	local playerSlice = (typeof(entry.slices) == "table" and entry.slices.Player) or {}
	local name = playerSlice.name or ("Player %s"):format(tostring(entry.userId))

	local row = Instance.new("Frame")
	row.Name = "Row_" .. tostring(entry.userId)
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.BackgroundColor3 = isLocalPlayer and UITheme.Colors.PanelElevated or UITheme.Colors.PanelRow
	row.BackgroundTransparency = isLocalPlayer and 0 or 0.35
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.ZIndex = 2

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UITheme.Layout.RowCornerRadius
	corner.Parent = row

	-- The local player's own row gets an accent edge rather than a different
	-- fill -- readable without turning the row into a second colour language.
	if isLocalPlayer then
		local stroke = Instance.new("UIStroke")
		stroke.Color = UITheme.Colors.Accent
		stroke.Thickness = 1
		stroke.Transparency = 0.5
		stroke.Parent = row
	end

	local function cell(cellName: string, text: string, size: UDim2, position: UDim2, alignment, color: Color3)
		local label = Instance.new("TextLabel")
		label.Name = cellName
		label.Size = size
		label.Position = position
		label.BackgroundTransparency = 1
		label.Font = UITheme.Fonts.Medium
		label.TextColor3 = color
		label.TextSize = 14
		label.TextXAlignment = alignment
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.ZIndex = 3
		label.Text = text
		label.Parent = row
	end

	-- "PlayerName", not "Name": a child called Name is shadowed by the
	-- Frame's own Name property under dot-indexing, which makes the row
	-- painful to inspect from the command bar.
	cell(
		"PlayerName",
		name,
		COL_NAME,
		UDim2.fromOffset(10, 0),
		Enum.TextXAlignment.Left,
		isLocalPlayer and UITheme.Colors.Accent or UITheme.Colors.Text
	)
	-- Earned-this-match, not the lifetime totals that also ride along in the
	-- slice: a scoreboard showing a player's whole XP balance reads as
	-- nonsense next to a single match's Score.
	cell(
		"Score",
		tostring(reward.scoreEarned or 0),
		COL_SCORE,
		UDim2.new(1, -140, 0, 0),
		Enum.TextXAlignment.Right,
		UITheme.Colors.Text
	)
	cell(
		"Xp",
		tostring(reward.xpEarned or 0),
		COL_XP,
		UDim2.new(1, -70, 0, 0),
		Enum.TextXAlignment.Right,
		UITheme.Colors.Text
	)

	return row
end

local function renderScoreboard(roster: { any })
	for _, child in ipairs(scoreList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local localUserId = Players.LocalPlayer and Players.LocalPlayer.UserId

	-- Highest score first, so the scoreboard reads as a ranking. Ties fall
	-- back to userId purely so the order is stable between the in-match
	-- screen and the Lobby arrival receipt.
	local sorted = table.clone(roster)
	table.sort(sorted, function(a, b)
		local aReward = (typeof(a.slices) == "table" and a.slices.Reward) or {}
		local bReward = (typeof(b.slices) == "table" and b.slices.Reward) or {}
		local aScore = aReward.scoreEarned or 0
		local bScore = bReward.scoreEarned or 0
		if aScore == bScore then
			return (tonumber(a.userId) or 0) < (tonumber(b.userId) or 0)
		end
		return aScore > bScore
	end)

	for index, entry in ipairs(sorted) do
		local row = buildRow(entry, index, tonumber(entry.userId) == localUserId)
		row.Parent = scoreList
	end
end

-- Renders every OTHER contributor's slice generically -- Player, Reward and
-- Stats already have dedicated UI (name/columns, the scoreboard, the grade +
-- personal-stats block), so repeating them here would just be noise. This is
-- what keeps R2 for anything genuinely new: a future contributor's field
-- shows up here with zero edits, even though the three named ones don't.
local function formatDetail(perPlayer: { [string]: any }): string
	local lines = {}
	for contributorName, slice in pairs(perPlayer) do
		if contributorName ~= "Player" and contributorName ~= "Reward" and contributorName ~= "Stats" then
			if typeof(slice) == "table" then
				for key, value in pairs(slice) do
					table.insert(lines, ("%s.%s: %s"):format(contributorName, key, tostring(value)))
				end
			else
				table.insert(lines, ("%s: %s"):format(contributorName, tostring(slice)))
			end
		end
	end
	table.sort(lines)
	return table.concat(lines, "\n")
end

local function formatDuration(seconds: number?): string
	local total = math.max(0, math.floor(seconds or 0))
	return ("Match lasted %d:%02d"):format(total // 60, total % 60)
end

local function formatSurvived(seconds: number?): string
	local total = math.max(0, math.floor(seconds or 0))
	return ("Survived for %d:%02d"):format(total // 60, total % 60)
end

-- Renders the grade + personal-stats block and returns the height it used
-- (0 if there was nothing to show). CaptureTargets.OrderedNames() drives the
-- row list, so a future Artifact row appears here the moment it's added to
-- that table -- nothing in this file needs to change.
local function renderStats(stats: { survivedSeconds: number?, captures: { [string]: number }?, grade: string? }?): number
	if typeof(stats) ~= "table" then
		gradeLabel.Visible = false
		for _, child in ipairs(statsHolder:GetChildren()) do
			child:Destroy()
		end
		return 0
	end

	gradeLabel.Visible = true
	gradeLabel.Text = stats.grade or "?"

	for _, child in ipairs(statsHolder:GetChildren()) do
		child:Destroy()
	end

	local captures = stats.captures or {}
	local order = 1
	buildStatRow(formatSurvived(stats.survivedSeconds), order).Parent = statsHolder
	for _, typeName in ipairs(CaptureTargets.OrderedNames()) do
		order += 1
		local typeDef = CaptureTargets.Get(typeName)
		local label = (typeDef and typeDef.StatLabel) or typeName
		local count = captures[typeName] or 0
		buildStatRow(("%s: %d"):format(label, count), order).Parent = statsHolder
	end

	return order * STAT_ROW_HEIGHT + (order - 1) * STAT_ROW_GAP
end

-- payload: { resultCode: string?, durationSeconds: number?, perPlayer: table?,
-- roster: array?, variant: string? }
--
-- variant picks which sections render, rather than guessing from payload
-- shape (the old "#roster > 1" / "perPlayer.Stats exists" rules guessed
-- wrong for a solo run -- see Part 5.5):
--   "Match"   -- MatchReplicator, in-match Ending receipt. Grade + personal
--               stats + Return button. Never the roster -- other players'
--               scores are the Lobby arrival receipt's job.
--   "Arrival" -- ArrivalService, Lobby receipt after teleporting back.
--               Roster scoreboard at any size (including solo). Never grade/
--               stats/button -- there's nothing left to return FROM.
--   nil/other -- unrecognised payload (a stale client, a hand-fired remote):
--               falls back to the old shape-inference so it degrades
--               instead of going blank.
function MatchReceipt.Show(payload: { [string]: any })
	ensureBuilt()

	titleLabel.Text = MatchResultCodes.GetMessage(payload.resultCode)
	subtitleLabel.Text = formatDuration(payload.durationSeconds)

	local perPlayer = typeof(payload.perPlayer) == "table" and payload.perPlayer or {}
	local roster = typeof(payload.roster) == "table" and payload.roster or {}
	local variant = payload.variant

	local showsRoster
	if variant == "Arrival" then
		showsRoster = #roster >= 1
	elseif variant == "Match" then
		showsRoster = false
	else
		showsRoster = #roster > 1
	end

	local pad = UITheme.Layout.PanelPadding
	local y = HEADER_HEIGHT

	local hasStats
	if variant == "Arrival" then
		hasStats = false
	else
		hasStats = typeof(perPlayer.Stats) == "table"
	end
	if hasStats then
		y += GAP
		gradeLabel.Position = UDim2.fromOffset(pad, y)
		y += GRADE_HEIGHT
		y += GAP
		statsHolder.Position = UDim2.fromOffset(pad, y)
		local statsHeight = renderStats(perPlayer.Stats)
		statsHolder.Size = UDim2.new(1, -(pad * 2), 0, statsHeight)
		y += statsHeight
	else
		renderStats(nil)
	end

	if showsRoster then
		y += GAP
		columnHeader.Position = UDim2.fromOffset(pad, y)
		y += COLUMN_HEADER_HEIGHT + 6
		scoreList.Position = UDim2.fromOffset(pad, y)
		renderScoreboard(roster)
		y += SCOREBOARD_HEIGHT
	else
		-- Still clears any rows from a PREVIOUS Show() call, even though the
		-- list is about to be hidden -- otherwise a receipt that toggled from
		-- multiplayer to solo across two Show() calls (Game place, then the
		-- Lobby arrival receipt) leaves orphaned rows sitting invisibly in
		-- the ScrollingFrame forever.
		renderScoreboard({})
	end
	columnHeader.Visible = showsRoster
	scoreList.Visible = showsRoster

	local detailText = formatDetail(perPlayer)
	-- Neither personal stats, a multi-player scoreboard, nor any other
	-- contributor's data is indistinguishable from a genuine crash upstream
	-- (a stale server build, or every contributor erroring) unless it says
	-- so -- a silently blank panel below the title is exactly the bug this
	-- line exists to stop being invisible.
	if not hasStats and not showsRoster and detailText == "" then
		detailText = "No match data received."
	end
	detailLabel.Text = detailText
	detailLabel.Visible = detailText ~= ""
	if detailText ~= "" then
		y += GAP
		detailLabel.Position = UDim2.fromOffset(pad, y)
		y += DETAIL_HEIGHT
	end

	returnsAt = typeof(payload.returnsAt) == "number" and payload.returnsAt or nil

	-- variant == "Arrival" excludes the button even if a handler is somehow
	-- registered (it shouldn't be -- MatchReceiptController only calls
	-- SetReturnHandler on the Game place -- but this is the second,
	-- independent condition Part 5.5 asked for rather than relying on that
	-- alone). Any other variant (including nil/fallback) keeps the original
	-- rule: show it whenever a handler is registered.
	local showsReturnButton = returnHandler ~= nil and variant ~= "Arrival"
	returnButton.Visible = showsReturnButton
	if showsReturnButton then
		returnButton.Text = returnButtonText()
		y += GAP
		returnButton.Position = UDim2.fromOffset(pad, y)
		y += BUTTON_HEIGHT
	end

	panel.Size = UDim2.fromOffset(PANEL_WIDTH, y + pad)

	screenGui.Enabled = true
end

function MatchReceipt.Hide()
	if screenGui then
		screenGui.Enabled = false
	end
end

return MatchReceipt
