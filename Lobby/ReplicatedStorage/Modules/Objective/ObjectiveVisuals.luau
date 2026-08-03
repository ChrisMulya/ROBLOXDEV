-- Client-only rendering. Knows how to turn a style name into Highlight
-- properties; knows nothing about what a state means or which objective
-- type maps to which style -- that's ObjectiveTypes' and the controller's
-- job. Swapping a look is editing the Styles table, never this file's logic.

local ObjectiveVisuals = {}

ObjectiveVisuals.Styles = {
	StandardGlow = {
		FillColor = Color3.fromRGB(255, 220, 120),
		FillTransparency = 0.85,
		OutlineColor = Color3.fromRGB(255, 240, 180),
		OutlineTransparency = 0.1,
		DepthMode = Enum.HighlightDepthMode.Occluded,
	},
	RareGlow = {
		FillColor = Color3.fromRGB(180, 120, 255),
		FillTransparency = 0.75,
		OutlineColor = Color3.fromRGB(220, 180, 255),
		OutlineTransparency = 0.05,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	},
	CoopGlow = {
		FillColor = Color3.fromRGB(120, 220, 255),
		FillTransparency = 0.8,
		OutlineColor = Color3.fromRGB(180, 240, 255),
		OutlineTransparency = 0.1,
		DepthMode = Enum.HighlightDepthMode.Occluded,
	},
}

local activeHighlights = {} -- [instance] = Highlight

function ObjectiveVisuals.Apply(instance: Instance, styleName: string)
	local style = ObjectiveVisuals.Styles[styleName]
	if not style then
		return
	end

	local highlight = activeHighlights[instance]
	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.Adornee = instance
		highlight.Parent = instance
		activeHighlights[instance] = highlight
	end

	highlight.FillColor = style.FillColor
	highlight.FillTransparency = style.FillTransparency
	highlight.OutlineColor = style.OutlineColor
	highlight.OutlineTransparency = style.OutlineTransparency
	highlight.DepthMode = style.DepthMode
end

function ObjectiveVisuals.Clear(instance: Instance)
	local highlight = activeHighlights[instance]
	if highlight then
		highlight:Destroy()
		activeHighlights[instance] = nil
	end
end

function ObjectiveVisuals.ClearAll()
	for instance in pairs(activeHighlights) do
		ObjectiveVisuals.Clear(instance)
	end
end

return ObjectiveVisuals
