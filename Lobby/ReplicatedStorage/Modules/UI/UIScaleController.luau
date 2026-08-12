-- One shared scale factor for the persistent HUD (Cash / MatchTime / Stamina),
-- applied via a UIScale per HUD root so the designed pixel geometry magnifies
-- uniformly instead of stretching per-axis. See plans/responsive-hud.md.
--
-- ViewportSize alone can't tell a 1080p phone from a 1080p monitor, so
-- TouchSession.IsActive() supplies a single density term -- one formula, one
-- coefficient shifts, not a branch that picks between two sets of sizes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local TouchSession = require(ReplicatedStorage.Modules.Shared.TouchSession)

local UIScaleController = {}

local DESIGN_BASIS = Vector2.new(1920, 1080)
local TOUCH_DENSITY = 0.78

-- Two floors, not one. ViewportSize is the render WINDOW, not the monitor: a
-- windowed client, or a Studio play session with the Explorer/Properties docks
-- open, reports far less than the physical resolution. A single low floor made
-- that shrink a perfectly correct desktop HUD.
--
-- Pointer clients therefore never render below the authored pixel sizes --
-- those were designed to read at 1:1, so 1.0 is the floor and the viewport
-- ratio only ever scales UP. Touch keeps the low floor; shrinking there is the
-- entire point of this module.
local MIN_SCALE_POINTER = 1.0
local MIN_SCALE_TOUCH = 0.62
local MAX_SCALE = 1.35

-- root (GuiObject) -> UIScale
local scales: { [GuiObject]: UIScale } = {}
local currentFactor = 1.0

local listeners: { (number) -> () } = {}

local function computeFactor(): number
	local camera = Workspace.CurrentCamera
	if not camera then
		return currentFactor
	end

	local viewport = camera.ViewportSize
	if viewport.X <= 0 or viewport.Y <= 0 then
		return currentFactor
	end

	local viewportFactor = math.min(viewport.X / DESIGN_BASIS.X, viewport.Y / DESIGN_BASIS.Y)
	local isTouch = TouchSession.IsActive()
	local densityFactor = isTouch and TOUCH_DENSITY or 1.0
	local minScale = isTouch and MIN_SCALE_TOUCH or MIN_SCALE_POINTER

	return math.clamp(viewportFactor * densityFactor, minScale, MAX_SCALE)
end

local function applyFactor(factor: number)
	for root, uiScale in pairs(scales) do
		if root.Parent then
			uiScale.Scale = factor
		else
			scales[root] = nil
		end
	end
end

-- Recomputes the factor and, only if it actually changed, writes every
-- registered UIScale and fires Changed. UIScale.Scale writes re-layout the
-- whole subtree, so an unconditional write per input/viewport event is a
-- real, avoidable cost.
local function recompute()
	local factor = computeFactor()
	if factor == currentFactor then
		return
	end

	currentFactor = factor
	applyFactor(factor)

	for _, listener in ipairs(listeners) do
		listener(factor)
	end
end

local function connectViewport(camera: Camera)
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(recompute)
end

-- CurrentCamera is replaced on respawn and by camera-mode code; the previous
-- ViewportSize connection dies with the old camera instance. Without this
-- reconnect, scaling works until the first respawn and then goes stale.
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	local camera = Workspace.CurrentCamera
	if camera then
		connectViewport(camera)
	end
	recompute()
end)

if Workspace.CurrentCamera then
	connectViewport(Workspace.CurrentCamera)
end

-- TouchSession's own contract: never cache IsActive(), always re-check on an
-- actual input-type change (touch-capable laptop, phone + paired controller).
UserInputService.LastInputTypeChanged:Connect(recompute)

currentFactor = computeFactor()

function UIScaleController.Attach(root: GuiObject): UIScale
	local existing = scales[root]
	if existing and existing.Parent then
		return existing
	end

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = currentFactor
	uiScale.Parent = root

	scales[root] = uiScale
	return uiScale
end

function UIScaleController.Detach(root: GuiObject)
	local uiScale = scales[root]
	if uiScale then
		uiScale:Destroy()
		scales[root] = nil
	end
end

function UIScaleController.Get(): number
	return currentFactor
end

UIScaleController.Changed = {
	Connect = function(_self, callback: (number) -> ())
		table.insert(listeners, callback)
		return {
			Disconnect = function()
				local index = table.find(listeners, callback)
				if index then
					table.remove(listeners, index)
				end
			end,
		}
	end,
}

return UIScaleController
