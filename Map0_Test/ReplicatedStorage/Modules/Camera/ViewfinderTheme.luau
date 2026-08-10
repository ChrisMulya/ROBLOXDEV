-- Layout/chrome constants for the viewfinder that are NOT per-camera (those
-- live in CameraStats.<id>.Effects / .Viewfinder instead). Change these to
-- restyle every camera's viewfinder at once.

local ViewfinderTheme = {}

ViewfinderTheme.BarHeight = 0.12 -- fraction of screen height, top/bottom letterbox bars

ViewfinderTheme.BracketSize = UDim2.new(0, 40, 0, 40)
ViewfinderTheme.BracketThickness = 4
ViewfinderTheme.BracketColor = Color3.fromRGB(255, 255, 255)
ViewfinderTheme.BracketMarginX = 0.07
ViewfinderTheme.BracketMarginY = 0.22

ViewfinderTheme.GhostMaxScale = 1.8   -- how much bigger the ghost ring grows at full blur
ViewfinderTheme.GhostMinTransparency = 0.1 -- most visible the ghost ring ever gets (0 = fully opaque)

-- Reticle ring, in priority order (see CameraViewfinder.applyReticleColor):
--   Processing -- the whole exposure window (see CameraSession.Capture). The
--                 "hold still" cue; covers exactly the span during which
--                 moving forces the shot to Weak. Outranks Stable, so the
--                 ring does not flicker green mid-capture.
--   Stable     -- standing still, i.e. a shot taken now would qualify Strong.
--   (base)     -- moving; a shot now is Weak.
ViewfinderTheme.ReticleColor = Color3.fromRGB(255, 255, 255)
ViewfinderTheme.ReticleStableColor = Color3.fromRGB(64, 255, 118)
ViewfinderTheme.ReticleProcessingColor = Color3.fromRGB(255, 213, 0)

ViewfinderTheme.LabelFont = Enum.Font.Code
ViewfinderTheme.LabelTextSize = 16
ViewfinderTheme.LabelColor = Color3.fromRGB(255, 255, 255)

return ViewfinderTheme
