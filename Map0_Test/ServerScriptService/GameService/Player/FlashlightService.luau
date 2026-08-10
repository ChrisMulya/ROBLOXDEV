-- FlashlightService
-- Server authority for the player-held flashlight. Replaces the old
-- GiveFlashLight LocalScript, which created the light on the client --
-- objects a LocalScript instantiates never replicate, so nobody but the
-- toggling player could ever see their own light.
--
-- The beam is a SpotLight on an anchored emitter Part rather than a
-- SurfaceLight on the Head. Two reasons the original never visibly worked:
-- a SurfaceLight emits off a chosen Face (default Top, i.e. straight up out
-- of the skull), and it has no aimable direction at all. A SpotLight on a
-- part the server poses is a real directed beam.
--
-- Server-authoritative only: this is the sole writer of the emitter's CFrame,
-- for every client including the holder, at FlashlightAim.SEND_RATE (30Hz) --
-- see that module for why 30Hz has headroom to spare even at four concurrent
-- holders. An earlier version had the holder's own client re-pose a local
-- copy every frame for zero-latency aim; dropped since the replicated cost
-- was never the bottleneck that trick was solving for.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local PlayerStats = require(ReplicatedStorage.Modules.PlayerStats)
local FlashlightAim = require(ReplicatedStorage.Modules.Player.FlashlightAim)

local FlashlightService = {}

-- Not in PlayerStats: that table is numbers only (Get/Set/Add are typed
-- `number`), and tint is not a thing an upgrade tier is expected to change.
local COLOR = Color3.fromRGB(255, 250, 230)

-- The one seam a "Better Flashlight" upgrade plugs into. Reads the PlayerStats
-- base every time the beam is built rather than caching at require time, so a
-- tuning change takes effect on the next toggle instead of the next server
-- boot.
--
-- `player` is deliberately in the signature even though nothing branches on it
-- yet -- when the upgrade lands, the per-player lookup (attribute / reward
-- profile, falling back to the PlayerStats base) goes HERE and every caller
-- below is already correct. Do not reach for PlayerStats.Set to do it: that
-- table is shared by every player on the server, so it would upgrade the whole
-- lobby. See the PlayerStats flashlight block.
local function getBeamStats(player: Player): (number, number, number)
	return PlayerStats.FlashlightRange, PlayerStats.FlashlightAngle, PlayerStats.FlashlightBrightness
end

-- Last look vector each holder reported. Cleared with the emitter, so a
-- player who toggles off and on again never gets one frame of stale aim.
local aimByPlayer: { [Player]: Vector3 } = {}

local function getEmitter(character: Model?): BasePart?
	local emitter = character and character:FindFirstChild("FlashlightEmitter")
	return (emitter and emitter:IsA("BasePart")) and emitter or nil
end

local function poseEmitter(player: Player, emitter: BasePart)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local aim = aimByPlayer[player]
	if not head or not head:IsA("BasePart") or not aim then
		return
	end
	emitter.CFrame = FlashlightAim.GetPose(head.CFrame, aim)
end

local function toggleFlashlight(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end

	local existing = getEmitter(character)
	if existing then
		existing:Destroy()
		aimByPlayer[player] = nil
		return
	end

	local emitter = Instance.new("Part")
	emitter.Name = "FlashlightEmitter"
	emitter.Size = Vector3.new(0.2, 0.2, 0.2)
	emitter.Transparency = 1
	emitter.CanCollide = false
	emitter.CanQuery = false
	emitter.CanTouch = false
	emitter.Massless = true
	-- Anchored so the server's CFrame writes stick. An unanchored part would
	-- need a weld, and a weld reintroduces the head-orientation problem
	-- FlashlightAim exists to avoid.
	emitter.Anchored = true
	emitter.CFrame = head.CFrame

	local range, angle, brightness = getBeamStats(player)

	local light = Instance.new("SpotLight")
	light.Name = "Light"
	light.Range = range
	light.Angle = angle
	light.Brightness = brightness
	light.Color = COLOR
	-- Shadows OFF on purpose. With them on, the beam was occluded per-part and
	-- stopped dead at part seams -- shine it at a building and the part beside
	-- the lit one stayed black, so the light read as clipped rather than as a
	-- cone. Off, it fills its whole radius regardless of geometry.
	--
	-- The tradeoff is real and accepted: the beam now passes THROUGH walls, so
	-- it will faintly light rooms the holder cannot see into. Revisit only
	-- alongside Lighting.Technology (Future gives per-pixel local-light shadows
	-- and would fix the seams without this) -- that is a global, perf-sensitive
	-- call, not one this module should make on its own.
	light.Shadows = false
	-- The emitter is posed by CFrame.lookAt, whose -Z is forward -- which is
	-- exactly the Front face.
	light.Face = Enum.NormalId.Front
	light.Parent = emitter

	-- Seeded so the very first pose (before any aim report arrives) points
	-- where the character is already facing rather than at the world origin.
	aimByPlayer[player] = head.CFrame.LookVector
	emitter.Parent = character
	poseEmitter(player, emitter)
end

local function onAimReport(player: Player, lookDirection: any)
	if typeof(lookDirection) ~= "Vector3" then
		return
	end
	-- A non-finite or zero vector would make CFrame.lookAt throw and kill the
	-- handler for everyone.
	local magnitude = lookDirection.Magnitude
	if magnitude ~= magnitude or magnitude < 0.001 then
		return
	end

	local emitter = getEmitter(player.Character)
	if not emitter then
		return
	end

	aimByPlayer[player] = lookDirection.Unit
	poseEmitter(player, emitter)
end

local started = false

function FlashlightService.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	local toggleRemote = Remotes.Get("FlashlightRequest")
	local aimRemote = Remotes.Get("FlashlightAim")

	toggleRemote.OnServerEvent:Connect(toggleFlashlight)
	aimRemote.OnServerEvent:Connect(onAimReport)

	-- The emitter is parented to the Character, so a respawn destroys it with
	-- the rest of the old model. Only the aim table needs explicit clearing.
	Players.PlayerRemoving:Connect(function(player)
		aimByPlayer[player] = nil
	end)
end

return FlashlightService
