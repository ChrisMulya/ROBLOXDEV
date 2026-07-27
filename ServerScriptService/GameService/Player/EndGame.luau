local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HideCurrencyUI = ReplicatedStorage.Remotes:WaitForChild("HideCurrencyUI")

local RemoveAllSlot = {}

function RemoveAllSlot.ClearPlayerTools(player)
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character

	for _, container in ipairs({backpack, character}) do
		if container then
			for _, item in ipairs(container:GetChildren()) do
				if item:IsA("Tool") then
					item:Destroy()
				end
			end
		end
	end

	player:SetAttribute("KitGiven", false)

	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash then
		cash.Value = 0
	end

	HideCurrencyUI:FireClient(player)
end

return RemoveAllSlot