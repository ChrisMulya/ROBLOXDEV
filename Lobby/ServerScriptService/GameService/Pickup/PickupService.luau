-- Orchestrator: ProximityPromptService.PromptTriggered -> validate -> CLAIM
-- -> delegate to a PickupHandlers module -> destroy. Owns the claim set,
-- which is the race answer -- see the note above the claim below.
--
-- HARD CONTRACT for every PickupHandlers module: CanCollect and Collect must
-- both be non-yielding. Luau on Roblox is cooperatively scheduled -- a
-- function runs to completion unless it yields. The entire validation chain
-- plus the claim below contains no yield, so two players triggering the same
-- prompt in the same frame are serialized: the second one hits the
-- already-claimed check and returns. That serialization IS the mutex, and
-- the no-yield rule is what makes it one. A handler that must yield (a
-- DataStore write, an async call) has to claim first, yield, then report
-- back -- never the reverse, or two claims can interleave.
--
-- Both handler entry points are invoked through pcall. That does NOT relax
-- the no-yield contract above -- pcall doesn't yield, so the mutex still
-- holds. It exists because a handler that ERRORS (rather than returning
-- false) would otherwise skip the un-claim path below, leaving the pickup
-- permanently claimed and prompt-disabled for the rest of the match. A
-- raised error is treated exactly like a returned failure.
--
-- No remote is involved anywhere in this flow: PromptTriggered fires
-- server-side with the triggering player, so there is nothing here for a
-- client to forge.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local Signal = require(ReplicatedStorage.Modules.Shared.Signal)
local Cooldown = require(ReplicatedStorage.Modules.Shared.Cooldown)
local PickupTypes = require(ReplicatedStorage.Modules.Pickup.PickupTypes)
local PickupResultCodes = require(ReplicatedStorage.Modules.Pickup.PickupResultCodes)
local PlayerStateService = require(ServerScriptService.GameService.PlayerState.PlayerStateService)

local PickupRegistry = require(script.Parent.PickupRegistry)
local PickupPrompt = require(script.Parent.PickupPrompt)
local PickupHandlers = require(script.Parent.PickupHandlers)

local PickupService = {}

-- [instance] = true while a collect is in flight or has already succeeded
-- for this instance. Cleared on PickupRegistry.Unregistered so the table
-- can't leak across a match, and re-opened on a failed handler (see below)
-- so a transient CurrencyNotReady doesn't permanently brick a pickup.
local claimed = {}

local collectCooldown = Cooldown.new(0.25)

-- Fires (player, { instance, typeName, amount, position }) AFTER the
-- instance has been destroyed -- Signal:Fire is deferred (BindableEvent
-- semantics), so subscribers must not assume `instance` is still parented.
-- `position` is captured before the destroy for exactly this reason.
PickupService.Collected = Signal.new()

local function pivotOf(instance: Instance): Vector3?
	if instance:IsA("Model") then
		return instance:GetPivot().Position
	elseif instance:IsA("BasePart") then
		return instance.Position
	end
	return nil
end

local function rootPartOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function onPromptTriggered(prompt: ProximityPrompt, player: Player)
	-- O(1) first -- PromptTriggered fires for every prompt in the game
	-- (including the camera shelf's), not just pickups.
	local instance = PickupPrompt.OwnerOf(prompt)
	if not instance then
		return
	end

	if claimed[instance] then
		return
	end

	if not instance.Parent or not PickupRegistry.IsRegistered(instance) then
		return
	end

	local typeName = PickupTypes.TypeOf(instance)
	local typeDef = typeName and PickupTypes.Get(typeName)
	if not typeDef then
		warn(("PickupService: %s has no resolvable PickupType at trigger time"):format(instance:GetFullName()))
		return
	end

	if not collectCooldown:Check(player.UserId) then
		return
	end

	if not PlayerStateService.Is(player, "Alive") then
		return
	end

	local rootPart = rootPartOf(player)
	local pivot = pivotOf(instance)
	if not rootPart or not pivot or (rootPart.Position - pivot).Magnitude > typeDef.MaxInteractDistance then
		return
	end

	local handler = PickupHandlers.Get(typeDef.Handler)
	if not handler then
		warn(("PickupService: no handler registered for '%s' (PickupType '%s')"):format(typeDef.Handler, typeName))
		return
	end

	-- Nothing has been mutated yet at this point, so an error here strands no
	-- state -- but it would still propagate out of the PromptTriggered
	-- handler. Refusing the collect is the same outcome as CanCollect
	-- returning false, and keeps the failure to this one trigger.
	local gateOk, canCollect = pcall(handler.CanCollect, player, instance, typeDef)
	if not gateOk then
		warn(("PickupService: handler '%s' errored in CanCollect for %s -- %s"):format(
			typeDef.Handler, instance:GetFullName(), tostring(canCollect)))
		return
	end
	if not canCollect then
		return
	end

	-- Everything above this line ran without a single yield -- see the
	-- header contract. This claim is what makes a same-frame double-trigger
	-- from two players resolve to exactly one grant.
	claimed[instance] = true
	PickupPrompt.Disable(instance)

	-- Past the claim: an escaping error here would brick the instance (see the
	-- header). `ok` carries the error message when invokeOk is false.
	local invokeOk, ok, code, amount = pcall(handler.Collect, player, instance, typeDef)

	if not invokeOk then
		warn(("PickupService: handler '%s' errored collecting %s -- %s"):format(
			typeDef.Handler, instance:GetFullName(), tostring(ok)))
	elseif not ok then
		warn(("PickupService: %s failed to collect %s (%s)"):format(
			player.Name, instance:GetFullName(), PickupResultCodes.GetMessage(code)))
	end

	if not invokeOk or not ok then
		claimed[instance] = nil
		PickupPrompt.Enable(instance)
		return
	end

	local position = pivot
	PickupService.Collected:Fire(player, {
		instance = instance,
		typeName = typeName,
		amount = amount,
		position = position,
	})

	if typeDef.ClaimPolicy ~= "Consume" then
		warn(("PickupService: unknown ClaimPolicy %q on '%s' -- treating as Consume"):format(
			tostring(typeDef.ClaimPolicy), typeName))
	end
	instance:Destroy()
end

local started = false

function PickupService.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)

	PickupRegistry.Unregistered:Connect(function(instance)
		claimed[instance] = nil
	end)
end

return PickupService
