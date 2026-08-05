-- Client-only rendering. Knows how to turn a style name into a spin rate +
-- light-pillar rig; knows nothing about what a pickup grants or which kind
-- maps to which style -- that's PickupTypes' and the controller's job.
-- Swapping a look is editing the Styles table, never this file's logic.
-- Structural twin of Objective/ObjectiveVisuals.luau.
--
-- Every rig is parented under workspace.CurrentCamera -- nothing there
-- replicates or is considered by server queries, the standard idiom for
-- client-only cosmetics (also used for spectate). Apply captures the
-- pickup's own CFrame once, on first sight, so Clear can restore it exactly;
-- the controller's Heartbeat step (not this module) advances the spin angle.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Modules.Shared.Trove)

local PickupVisuals = {}

PickupVisuals.Styles = {
	CashGlow = {
		Spin = { DegreesPerSecond = 45 },
		Pillar = {
			Color = Color3.new(1, 1, 1),
			Height = 5,
			Width0 = 1,
			Width1 = 1,
		},
		Light = {
			Enabled = true,
			Color = Color3.new(1, 1, 1),
			Brightness = 1,
			Range = 12,
		},
	},
}

PickupVisuals.Default = PickupVisuals.Styles.CashGlow

-- [instance] = { trove, baseCFrame, angle, style }
local rigs = {}

function PickupVisuals.Apply(instance: Instance, styleName: string?)
	if rigs[instance] then
		return
	end

	local style = (styleName and PickupVisuals.Styles[styleName]) or PickupVisuals.Default

	local ok, baseCFrame = pcall(function()
		return instance:IsA("Model") and instance:GetPivot() or (instance :: BasePart).CFrame
	end)
	if not ok or not baseCFrame then
		return
	end

	local trove = Trove.new()

	local host = Instance.new("Part")
	host.Name = "PickupRig"
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.CastShadow = false
	host.Transparency = 1
	host.Massless = true
	host.Size = Vector3.new(0.2, 0.2, 0.2)
	host.CFrame = baseCFrame
	host.Parent = workspace.CurrentCamera
	trove:Add(host)

	local bottomAttachment = Instance.new("Attachment")
	bottomAttachment.Position = Vector3.new(0, 0, 0)
	bottomAttachment.Parent = host
	trove:Add(bottomAttachment)

	local topAttachment = Instance.new("Attachment")
	topAttachment.Position = Vector3.new(0, style.Pillar.Height, 0)
	topAttachment.Parent = host
	trove:Add(topAttachment)

	local transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})

	local beam = Instance.new("Beam")
	beam.Attachment0 = bottomAttachment
	beam.Attachment1 = topAttachment
	beam.Color = ColorSequence.new(style.Pillar.Color)
	beam.Transparency = transparency
	beam.Width0 = style.Pillar.Width0
	beam.Width1 = style.Pillar.Width1
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Parent = host
	trove:Add(beam)

	if style.Light.Enabled then
		local light = Instance.new("PointLight")
		light.Color = style.Light.Color
		light.Brightness = style.Light.Brightness
		light.Range = style.Light.Range
		light.Parent = host
		trove:Add(light)
	end

	rigs[instance] = {
		trove = trove,
		baseCFrame = baseCFrame,
		angle = 0,
		spinDegreesPerSecond = style.Spin.DegreesPerSecond,
	}
end

-- Advances instance's spin by dt seconds and writes the pivot. Client-local
-- only -- never replicates. No-ops for an instance PickupVisuals doesn't
-- know about (already cleared, or Apply never ran).
function PickupVisuals.Step(instance: Instance, dt: number)
	local rig = rigs[instance]
	if not rig then
		return
	end

	rig.angle = (rig.angle + rig.spinDegreesPerSecond * dt) % 360

	local ok = pcall(function()
		instance:PivotTo(rig.baseCFrame * CFrame.Angles(0, math.rad(rig.angle), 0))
	end)
	if not ok then
		PickupVisuals.Clear(instance)
	end
end

function PickupVisuals.Clear(instance: Instance)
	local rig = rigs[instance]
	if not rig then
		return
	end
	rigs[instance] = nil

	rig.trove:Clean()

	pcall(function()
		instance:PivotTo(rig.baseCFrame)
	end)
end

return PickupVisuals
