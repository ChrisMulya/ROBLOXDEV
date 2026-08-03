-- Binds CameraToolController to any Tool tagged IsCameraTool as soon as it
-- appears in the Backpack or Character, instead of requiring every camera
-- template to carry its own copy of a 5-line equip script. Adding a new
-- camera is now a pure CameraStats + model change.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraToolController = require(ReplicatedStorage.Modules.Camera.CameraToolController)

local player = Players.LocalPlayer

local function tryInit(instance: Instance)
	if instance:IsA("Tool") and instance:GetAttribute("IsCameraTool") == true then
		CameraToolController.Init(instance)
	end
end

local function watchContainer(container: Instance)
	for _, child in ipairs(container:GetChildren()) do
		tryInit(child)
	end
	container.ChildAdded:Connect(tryInit)
end

watchContainer(player:WaitForChild("Backpack"))

local function onCharacterAdded(character: Model)
	watchContainer(character)
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)
