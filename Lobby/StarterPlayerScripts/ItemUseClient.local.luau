-- ItemUseClient
-- Place in: StarterPlayer.StarterPlayerScripts (runs as a LocalScript)
--
-- Input/presentation half of the generic hold-to-use lifecycle. Watches
-- Backpack/Character for a Tool carrying a usable ItemId, binds LMB (and a
-- touch button) while one is equipped, and renders ItemUseHud off whatever
-- ItemUseState the server pushes -- it never decides completion itself, only
-- sends Begin/Cancel and renders the deadline it's told.
--
-- Same equip-watch shape as CameraToolController/CameraToolWatcher: a
-- destructor per Tool, rebound on Equipped, unbound on Unequipped.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopCatalog = require(ReplicatedStorage.Modules.Shop.ShopCatalog)
local CameraState = require(ReplicatedStorage.Modules.Camera.CameraState)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local Trove = require(ReplicatedStorage.Modules.Shared.Trove)
local TouchSession = require(ReplicatedStorage.Modules.Shared.TouchSession)
local ControlLock = require(ReplicatedStorage.Modules.Shared.ControlLock)
local ItemUseHud = require(ReplicatedStorage.Modules.Item.ItemUseHud)
local CCTVViewController = require(ReplicatedStorage.Modules.Item.CCTVViewController)

local itemUseRequest = Remotes.Get("ItemUseRequest")
local itemUseState = Remotes.Get("ItemUseState")
local motionSensorAlert = Remotes.Get("MotionSensorAlert")
local cctvViewState = Remotes.Get("CCTVViewState")

local player = Players.LocalPlayer

-- Rough hotbar cell pitch. There is no addressable hotbar to measure --
-- Roblox's default Backpack CoreGui can't be parented to or queried -- so
-- this is a fixed approximation, dropped entirely on touch (see
-- ItemUseHud's own header).
local SLOT_OFFSET_PX = {
	["Slot 1"] = -40,
	["Slot 2"] = 40,
}

local initializedTools = setmetatable({}, { __mode = "k" })
local equippedTool: Tool? = nil

-- Two separate flags on purpose, and conflating them was a real bug:
--
--   holdRequested -- the mouse is down and a Begin has been sent. Purely a
--                    re-entrancy guard on the input side; says nothing about
--                    what the server did with it.
--   holding       -- the SERVER confirmed an active hold session, via
--                    ItemUseState. The only thing that may gate movement.
--
-- Control-kind items (the CCTV tablet) complete instantly and never produce
-- an ItemUseState at all, so a single flag set optimistically on LMB-down
-- stayed true through the whole click. Clicking the tablet to CLOSE the feed
-- used to re-derive one shared, unrefcounted PlayerModule switch from a
-- flag that still read "holding" -- ControlLock replaces that switch with a
-- reason-keyed lock, so a use-hold and an open CCTV feed compose safely
-- without either needing to know about the other.
local holdRequested = false
local holding = false
local viewingCCTV = false

local function setHoldLocked(locked: boolean)
	if locked then
		ControlLock.Acquire("ItemUseHold")
	elseif ControlLock.IsHeld("ItemUseHold") then
		ControlLock.Release("ItemUseHold")
	end
end

local function setCCTVLocked(locked: boolean)
	if locked then
		ControlLock.Acquire("CCTVView")
	elseif ControlLock.IsHeld("CCTVView") then
		ControlLock.Release("CCTVView")
	end
end

local touchButton: TextButton? = nil
local touchScreenGui: ScreenGui? = nil

local function offsetForTool(tool: Tool): number
	return SLOT_OFFSET_PX[tool.Name] or 0
end

-- No use while scoped into a photo camera -- UX rule, client-side only, same
-- reasoning as the existing camera-mode sprint block: the only server-visible
-- camera signal (CameraSessionTracker's InCamera flag) is client-reported and
-- must never back a server-authoritative check. A modified client could still
-- fire Begin while scoped; accepted, same as the sprint case.
-- Neither of these touches `holding` or the control switch. Movement is gated
-- only by what the server confirms over ItemUseState, so an item that never
-- opens a session (the instant CCTV tablet) can't leave the player frozen.
local function beginHold()
	if holdRequested or CameraState.Get() then
		return
	end
	holdRequested = true
	itemUseRequest:FireServer("Begin")
end

local function cancelHold()
	if not holdRequested then
		return
	end
	holdRequested = false
	itemUseRequest:FireServer("Cancel")
end

local function ensureTouchButton()
	if touchScreenGui then
		return
	end
	if not TouchSession.IsActive() then
		return
	end

	touchScreenGui = Instance.new("ScreenGui")
	touchScreenGui.Name = "ItemUseTouchGui"
	touchScreenGui.ResetOnSpawn = false
	touchScreenGui.Enabled = false
	touchScreenGui.DisplayOrder = 100 -- alongside CameraTouchHud

	touchButton = Instance.new("TextButton")
	touchButton.Name = "UseButton"
	touchButton.Size = UDim2.new(0, 72, 0, 72)
	-- Beside MobileFlashlightButton's "LIGHT" button: same anchor/Y (1, -24,
	-- 0.5, -63 -- CAMERA_BUTTON_OFFSET_X, CAMERA_BUTTON_OFFSET_Y - FLASHLIGHT_RISE
	-- there), pushed left by one button width plus a gap.
	touchButton.AnchorPoint = Vector2.new(1, 0.5)
	touchButton.Position = UDim2.new(1, -112, 0.5, -63)
	touchButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	touchButton.BackgroundTransparency = 0.25
	touchButton.Font = Enum.Font.GothamBold
	touchButton.TextSize = 14
	touchButton.TextColor3 = Color3.new(1, 1, 1)
	touchButton.Text = "Use"
	touchButton.Parent = touchScreenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = touchButton

	touchButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			beginHold()
		end
	end)
	touchButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			cancelHold()
		end
	end)

	touchScreenGui.Parent = player:WaitForChild("PlayerGui")
end

local function initTool(tool: Tool): () -> ()
	if initializedTools[tool] then
		return function() end
	end
	initializedTools[tool] = true

	local trove = Trove.new()
	local inputConn: RBXScriptConnection? = nil

	local function onInputBegan(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			beginHold()
		end
	end

	local function onInputEnded(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			cancelHold()
		end
	end

	-- Idempotent: called from Equipped AND directly below for a tool that is
	-- already equipped by the time we get here. Without the inputConn guard
	-- that would stack two InputBegan connections and fire Begin twice.
	local function onEquipped()
		if inputConn then
			return
		end

		local itemId = tool:GetAttribute("ItemId")
		local item = typeof(itemId) == "string" and ShopCatalog.Get(itemId)
		if not item or not item.Effect then
			return
		end

		equippedTool = tool
		inputConn = UserInputService.InputBegan:Connect(onInputBegan)
		trove:Add(inputConn)
		trove:Add(UserInputService.InputEnded:Connect(onInputEnded))

		ensureTouchButton()
		if touchScreenGui then
			touchScreenGui.Enabled = true
		end
	end

	trove:Add(tool.Equipped:Connect(onEquipped))

	-- A tool swapped in mid-use (CompactSpeaker -> CompactSpeakerRemotes,
	-- PortableCCTV -> PortableCCTVTablet) is parented straight into the
	-- Character, which fires ChildAdded (bringing us here) and Equipped from
	-- the same write -- and Roblox does not order two handlers of separate
	-- events against each other (G20). If Equipped won that race it fired
	-- before this Tool was ever initialised, leaving the swapped-in tablet
	-- dead in the player's hand until they manually re-equipped it.
	if player.Character and tool.Parent == player.Character then
		onEquipped()
	end

	trove:Add(tool.Unequipped:Connect(function()
		if equippedTool == tool then
			equippedTool = nil
			cancelHold()
		end
		if inputConn then
			inputConn:Disconnect()
			inputConn = nil
		end
		if touchScreenGui then
			touchScreenGui.Enabled = false
		end
	end))

	return function()
		trove:Clean()
		initializedTools[tool] = nil
		if equippedTool == tool then
			equippedTool = nil
		end
	end
end

local function watchContainer(container: Instance)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Tool") then
			initTool(child)
		end
	end
	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			initTool(child)
		end
	end)
end

local function onCharacterAdded(character: Model)
	watchContainer(character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid then
		humanoid.Died:Connect(function()
			-- Defensive local cleanup: the server's own Cancelled/death path
			-- already unlocks controls, drops the CCTV feed and hides the HUD;
			-- this just covers the gap before those remotes arrive.
			holdRequested = false
			holding = false
			viewingCCTV = false
			setHoldLocked(false)
			setCCTVLocked(false)
			CCTVViewController.Exit()
			ItemUseHud.Cancel()
		end)
	end
end

local backpack = player:WaitForChild("Backpack")
watchContainer(backpack)
if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

itemUseState.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	if payload.status == "Active" then
		holding = true
		setHoldLocked(true)
		local offset = TouchSession.IsActive() and 0 or (equippedTool and offsetForTool(equippedTool) or 0)
		ItemUseHud.Begin(offset, payload.endsAt, payload.holdSeconds)
	elseif payload.status == "Cancelled" then
		holding = false
		setHoldLocked(false)
		ItemUseHud.Cancel()
	elseif payload.status == "Complete" then
		holding = false
		setHoldLocked(false)
		ItemUseHud.Complete()
	end
end)

motionSensorAlert.OnClientEvent:Connect(function(active: boolean)
	ItemUseHud.SetMotionDetected(active == true)
end)

cctvViewState.OnClientEvent:Connect(function(lens: BasePart?, model: Instance?)
	if lens then
		viewingCCTV = true
		CCTVViewController.Enter(lens, model)
	else
		viewingCCTV = false
		CCTVViewController.Exit()
	end
	-- The server holds the authoritative lock (its WalkSpeed budget); this is
	-- the local half, so the stick doesn't fight a zero budget and read as
	-- rubber-banding instead of as standing still.
	setCCTVLocked(viewingCCTV)
end)
