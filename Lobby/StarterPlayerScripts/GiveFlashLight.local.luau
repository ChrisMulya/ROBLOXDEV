-- Desktop flashlight toggle: F fires the toggle remote, and FlashlightService
-- (server) creates/destroys the actual beam. The light used to be created
-- here, client-side, which meant only the toggling player could ever see it
-- -- LocalScript-created instances don't replicate.
--
-- Requires nothing on purpose: this script runs sandboxed, and a sandboxed
-- thread cannot require an unsandboxed ModuleScript. WaitForChild is what
-- Remotes.Get would have done anyway.
--
-- Aiming and the 30Hz report live in FlashlightAimLoop.local.luau, so they
-- exist once regardless of which input toggled the beam.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local toggleRemote = remotesFolder:WaitForChild("FlashlightRequest")

local flashlightSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Tool"):WaitForChild("FlashLightSound")

local function onToggleFlashlight(_actionName, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	toggleRemote:FireServer()
	flashlightSound:Play()
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction("ToggleFlashlight", onToggleFlashlight, false, Enum.KeyCode.F)
