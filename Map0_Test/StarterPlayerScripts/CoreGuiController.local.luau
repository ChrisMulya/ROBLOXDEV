-- Disables the default Roblox Health CoreGui, which renders top-right and
-- overlaps the custom Stamina bar (HudController, also top-right). Lives in
-- StarterPlayerScripts (not StarterGui) specifically because StarterGui
-- LocalScripts re-copy and re-run on every respawn -- this only needs to run
-- once per player. CoreGui state is client-global and survives respawn on
-- its own, so the CharacterAdded reapply below is belt-and-braces, not load
-- bearing.

local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")

local function disableHealthGui()
	-- Can throw if CoreGui hasn't finished initializing yet; retry rather
	-- than assume the first call lands.
	for _ = 1, 5 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		end)
		if ok then
			return
		end
		task.wait(0.5)
	end
	warn("CoreGuiController: could not disable the default Health CoreGui")
end

disableHealthGui()

local player = Players.LocalPlayer
player.CharacterAdded:Connect(disableHealthGui)
