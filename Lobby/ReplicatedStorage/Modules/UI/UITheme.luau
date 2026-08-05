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
