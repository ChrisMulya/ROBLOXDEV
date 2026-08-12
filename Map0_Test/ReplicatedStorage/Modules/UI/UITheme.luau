-- Canonical colors/fonts for client UI. Seeded from CurrencyUI's existing
-- values (the audit found six divergent "dark grey" values across five
-- files) -- widening adoption past CurrencyUI needs a palette sign-off first,
-- since making things "consistent" will visibly change several screens.

local UITheme = {}

UITheme.Colors = {
	PanelBackground = Color3.fromRGB(20, 20, 20),
	Accent = Color3.fromRGB(85, 255, 127),
	Text = Color3.fromRGB(255, 255, 255),

	-- Added for the death/receipt panels. Purely additive -- the three values
	-- above are untouched, so nothing that already reads them changes look.
	-- These are the tokens a modern panel needs beyond a flat background:
	-- a raised surface, a hairline, de-emphasised text, and a warning hue.
	PanelElevated = Color3.fromRGB(32, 32, 34),
	PanelRow = Color3.fromRGB(27, 27, 29),
	Divider = Color3.fromRGB(58, 58, 62),
	TextMuted = Color3.fromRGB(158, 158, 166),
	Danger = Color3.fromRGB(255, 92, 92),
	Backdrop = Color3.fromRGB(0, 0, 0),

	-- Added for the 3 AM enrage announcer. Purely additive, same rule as the
	-- block above. Deliberately much darker than Danger and than the bar's
	-- own Dawn-phase red so the two reads stay distinguishable when both fire
	-- at hour 27 simultaneously.
	DangerDeep = Color3.fromRGB(138, 18, 18),

	-- Added for the event announcer line (see MatchTime/MatchEvents). Purely
	-- additive. A high-luminance yellow rather than a saturated one: the
	-- announcer sits over whatever the night lighting is doing to the scene,
	-- and pure RGB(255,255,0) reads as a UI error state next to Danger.
	Warning = Color3.fromRGB(255, 209, 71),
}

UITheme.Fonts = {
	Bold = Enum.Font.GothamBold,
	Medium = Enum.Font.GothamMedium,
	Regular = Enum.Font.Gotham,
}

-- Shared geometry so the panels agree without copying magic numbers.
UITheme.Layout = {
	CornerRadius = UDim.new(0, 12),
	RowCornerRadius = UDim.new(0, 8),
	PanelPadding = 18,
}

return UITheme
