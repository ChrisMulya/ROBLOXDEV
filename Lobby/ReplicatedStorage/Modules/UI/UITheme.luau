-- Canonical colors/fonts for client UI. Seeded from CurrencyUI's existing
-- values (the audit found six divergent "dark grey" values across five
-- files) -- widening adoption past CurrencyUI needs a palette sign-off first,
-- since making things "consistent" will visibly change several screens.

local UITheme = {}

UITheme.Colors = {
	PanelBackground = Color3.fromRGB(20, 20, 20),
	Accent = Color3.fromRGB(85, 255, 127),
	Text = Color3.fromRGB(255, 255, 255),
}

UITheme.Fonts = {
	Bold = Enum.Font.GothamBold,
}

return UITheme
