--[[
	FireItem4Shot -- paste into Studio's command bar, CLIENT datamodel, while
	Tools/InstallItem4Harness.luau's server half has already printed
	"Item4Harness: READY -- fire the client shot now." Run this ONCE.

	No real Script needed here (unlike the server half) -- FireServer crosses
	the actual client/server boundary and lands on the real
	CameraShotHandler.legacy OnServerEvent connection regardless of which
	require() cache this command-bar copy of `Remotes` came from. RemoteEvent
	identity is a shared Instance, not per-cache Lua state.

	This deliberately bypasses CameraSession/CameraToolController (the real
	aiming client code) and fires the raw remote directly with a valid
	origin/direction pair, because the thing under test is the server-side
	remote pipeline, not the client aiming UX.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Bypass Remotes.Get here -- it calls WaitForChild with no timeout, which
-- just hangs forever (the "Infinite yield possible" warning) if the folder
-- hasn't replicated for some other reason. Time-box it and report why.
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
if not remotesFolder then
	local names = {}
	for _, child in ipairs(ReplicatedStorage:GetChildren()) do
		table.insert(names, child.Name)
	end
	print("FireItem4Shot ABORT: ReplicatedStorage.Remotes did not replicate within 10s.")
	print("ReplicatedStorage children seen by this client: " .. table.concat(names, ", "))
	print("This means the server's Bootstrap -> Remotes.Init() has not run yet (or this client connected to a different place/server). Check the SERVER console for Bootstrap/GameBoot output.")
	return
end

local WeakCameraShot = remotesFolder:WaitForChild("WeakCameraShot", 5)
local ShotFeedback = remotesFolder:WaitForChild("ShotFeedback", 5)
if not WeakCameraShot or not ShotFeedback then
	local names = {}
	for _, child in ipairs(remotesFolder:GetChildren()) do
		table.insert(names, child.Name)
	end
	print("FireItem4Shot ABORT: WeakCameraShot/ShotFeedback missing from Remotes folder.")
	print("Remotes children seen by this client: " .. table.concat(names, ", "))
	return
end

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local head = character:WaitForChild("Head", 10)
if not head then
	print("FireItem4Shot ABORT: no Head on local character")
	return
end

local target = Workspace:WaitForChild("Phase7_5MonsterTarget", 10)
if not target then
	print("FireItem4Shot ABORT: Phase7_5MonsterTarget missing from Workspace")
	return
end
local targetPart = target:IsA("BasePart") and target or target:FindFirstChildWhichIsA("BasePart")
if not targetPart then
	print("FireItem4Shot ABORT: Phase7_5MonsterTarget has no BasePart")
	return
end

-- origin must be within CaptureGuard's MAX_ORIGIN_DEVIATION_STUDS (10) of the
-- server-observed Head position -- using Head.Position itself is 0 deviation.
local origin = head.Position
local direction = (targetPart.Position - origin)

local gotFeedback = false
local conn
conn = ShotFeedback.OnClientEvent:Connect(function(data)
	gotFeedback = true
	print(("FireItem4Shot: ShotFeedback -- hit=%s resultCode=%s amounts=%s"):format(
		tostring(data.hit), tostring(data.resultCode), game:GetService("HttpService"):JSONEncode(data.amounts or {})))
	conn:Disconnect()
end)

WeakCameraShot:FireServer(origin, direction)
print("FireItem4Shot: fired WeakCameraShot. Waiting up to 5s for ShotFeedback...")

task.delay(5, function()
	if not gotFeedback then
		print("FireItem4Shot: no ShotFeedback received within 5s.")
		if conn.Connected then
			conn:Disconnect()
		end
	end
end)
