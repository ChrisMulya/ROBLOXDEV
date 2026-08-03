-- Small shared constructors for the boilerplate every client UI file
-- currently repeats on its own (ScreenGui setup, PlayerGui lookup). Add to
-- this as more files migrate -- see UITheme for why that migration is
-- deliberately incremental.

local Players = game:GetService("Players")

local UIBuilder = {}

function UIBuilder.GetPlayerGui(): PlayerGui
	local player = Players.LocalPlayer
	return player:WaitForChild("PlayerGui") :: PlayerGui
end

-- ResetOnSpawn = false, Enabled = false: the convention every ScreenGui in
-- this repo that toggles visibility already follows individually.
function UIBuilder.CreateScreenGui(name: string, parent: Instance): ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = name
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.Parent = parent
	return screenGui
end

return UIBuilder
