-- Wires SpectateCameraController + SpectateHud to the server's
-- SpectateStateSync remote and to PlayerStateClient. Game Server only --
-- required from ClientBootstrap's GameServer branch for its side effects,
-- the same pattern already used there for FlashRenderers/
-- ObjectiveVisualsController/DeathScreenController.
--
-- Also the one place target cycling is REQUESTED: Q/E on keyboard and the
-- HUD's own buttons on touch both land on the same requestCycle(), which
-- fires SpectateRequest and lets the server decide. The client never picks the
-- next target itself -- SpectateService owns the valid-target list, the
-- ordering, and the rate limit, and a client-side guess would just disagree
-- with the sync that comes back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")

local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local PlayerStates = require(ReplicatedStorage.Modules.Shared.PlayerStates)
local PlayerStateClient = require(ReplicatedStorage.Modules.Shared.PlayerStateClient)
local SpectateCameraController = require(script.Parent.SpectateCameraController)
local SpectateHud = require(script.Parent.SpectateHud)

local PREV_ACTION = "SpectatePrev"
local NEXT_ACTION = "SpectateNext"

PlayerStateClient.Start()

local spectateRequest = Remotes.Get("SpectateRequest")

local function requestCycle(action: string)
	spectateRequest:FireServer({ action = action })
end

-- Bound only while a spectate session is live, and unbound the moment it
-- ends: Q and E belong to whatever else claims them the rest of the time, and
-- ContextActionService's stack is what keeps that honest rather than a
-- global UserInputService handler with an `if spectating` inside it.
--
-- ContextActionService rather than UserInputService for the same reason: it
-- respects text-box focus, so pressing E while typing in chat doesn't switch
-- targets. Begin only -- one press, one switch, no key-repeat storm against
-- the server's 0.25s cooldown.
local actionsBound = false

local function onAction(actionName: string, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	requestCycle(actionName == NEXT_ACTION and "Next" or "Prev")
	return Enum.ContextActionResult.Sink
end

local function bindCycleKeys()
	if actionsBound then
		return
	end
	actionsBound = true
	-- createTouchButton = false: touch players get the HUD's own buttons,
	-- which sit with the rest of the spectate UI instead of in CAS's own
	-- bottom-right cluster.
	ContextActionService:BindAction(PREV_ACTION, onAction, false, Enum.KeyCode.Q)
	ContextActionService:BindAction(NEXT_ACTION, onAction, false, Enum.KeyCode.E)
end

local function unbindCycleKeys()
	if not actionsBound then
		return
	end
	actionsBound = false
	ContextActionService:UnbindAction(PREV_ACTION)
	ContextActionService:UnbindAction(NEXT_ACTION)
end

SpectateHud.SetHandlers(function()
	requestCycle("Prev")
end, function()
	requestCycle("Next")
end)

Remotes.Get("SpectateStateSync").OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local targetPlayer = payload.targetUserId and Players:GetPlayerByUserId(payload.targetUserId)
	SpectateCameraController.SetTarget(targetPlayer)
	SpectateHud.Update(targetPlayer and targetPlayer.Name, payload.index or 0, payload.total or 0)

	-- Bound off the sync rather than off the state change, so the keys go live
	-- on exactly the same event that puts the HUD on screen. Deliberately
	-- bound even for a FreeCamera (no-target) sync: the roster refills when
	-- someone else dies, and cycling is how the spectator finds them.
	bindCycleKeys()
end)

-- Gated on the CanSpectate FLAG, not the literal "Spectating" -- the same rule
-- PlayerStates' header sets and SpectateService.onPlayerStateChanged already
-- follows. Escaped is CanSpectate too, so a name comparison here left an
-- escapee's session standing forever after: camera stuck on someone else's
-- humanoid, HUD up, mouse locked, and Q/E still bound, straight through the
-- lobby teleport. Any future spectating state gets its teardown for free.
PlayerStateClient.Changed:Connect(function(newState: string, oldState: string?)
	if oldState and PlayerStates.CanSpectate(oldState) and not PlayerStates.CanSpectate(newState) then
		SpectateCameraController.Stop()
		SpectateHud.Hide()
		unbindCycleKeys()
	end
end)

return {}
