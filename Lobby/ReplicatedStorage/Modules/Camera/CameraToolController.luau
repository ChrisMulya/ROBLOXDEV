-- Input binding only. Resolves what MouseButton1/2 mean while a camera tool
-- is equipped and delegates everything else to CameraSession. Also the
-- single source of truth for "which camera tool is currently equipped" --
-- CameraTouchHud reads this instead of running a second equip watcher.

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Modules.Shared.Trove)
local CameraSession = require(ReplicatedStorage.Modules.Camera.CameraSession)

local CameraToolController = {}

-- Weak-keyed so double-Init on the same tool instance is a safe no-op
-- instead of stacking a second set of Equipped/Unequipped connections.
local initializedTools = setmetatable({}, { __mode = "k" })

local equippedTool: Tool? = nil
local equippedListeners = {}

local function fireEquippedChanged(tool: Tool?)
	for _, callback in ipairs(equippedListeners) do
		task.spawn(callback, tool)
	end
end

function CameraToolController.GetEquipped(): Tool?
	return equippedTool
end

-- callback(tool: Tool?) -- fires with the tool on equip, nil on unequip.
-- Returns a disconnect function.
function CameraToolController.OnEquippedChanged(callback): () -> ()
	table.insert(equippedListeners, callback)
	return function()
		local index = table.find(equippedListeners, callback)
		if index then
			table.remove(equippedListeners, index)
		end
	end
end

-- Returns a destructor that fully unbinds this tool.
function CameraToolController.Init(tool: Tool): () -> ()
	if initializedTools[tool] then
		return function() end
	end
	initializedTools[tool] = true

	local trove = Trove.new()
	local inputConn = nil

	local function onInputBegan(input, gameProcessed)
		if gameProcessed then return end

		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			CameraSession.Toggle(tool)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			if CameraSession.IsActive() then
				CameraSession.Capture()
			end
		end
	end

	trove:Add(tool.Equipped:Connect(function()
		inputConn = UserInputService.InputBegan:Connect(onInputBegan)
		equippedTool = tool
		fireEquippedChanged(tool)
	end))

	trove:Add(tool.Unequipped:Connect(function()
		if CameraSession.IsActive() then
			CameraSession.Exit()
		end
		if inputConn then
			inputConn:Disconnect()
			inputConn = nil
		end
		if equippedTool == tool then
			equippedTool = nil
			fireEquippedChanged(nil)
		end
	end))

	return function()
		if inputConn then
			inputConn:Disconnect()
			inputConn = nil
		end
		trove:Clean()
		initializedTools[tool] = nil
		if equippedTool == tool then
			equippedTool = nil
			fireEquippedChanged(nil)
		end
	end
end

return CameraToolController
