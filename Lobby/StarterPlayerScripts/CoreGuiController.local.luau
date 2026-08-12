-- Disables default Roblox CoreGuis that duplicate or clutter the custom HUD:
--   Health -- renders top-right and overlaps the custom Stamina bar
--            (HudController, also top-right).
--   PlayerList -- the default leaderboard panel. CurrencyUI already shows
--            Cash in its own top-left HUD element, so the built-in panel is
--            redundant. leaderstats.Cash itself (PlayerCurrency.legacy.luau)
--            is untouched -- CashWallet, CurrencyUI, ShopFillSlot, and
--            RewardLedger all still read/write it; this only hides Roblox's
--            own display of it.
-- Lives in StarterPlayerScripts (not StarterGui) specifically because
-- StarterGui LocalScripts re-copy and re-run on every respawn -- this only
-- needs to run once per player. CoreGui state is client-global and survives
-- respawn on its own, so the CharacterAdded reapply below is belt-and-braces,
-- not load bearing.

local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")

local DISABLED_CORE_GUIS = { Enum.CoreGuiType.Health, Enum.CoreGuiType.PlayerList }

local function disableCoreGuis()
	-- Can throw if CoreGui hasn't finished initializing yet; retry rather
	-- than assume the first call lands.
	for _ = 1, 5 do
		local ok = pcall(function()
			for _, coreGuiType in ipairs(DISABLED_CORE_GUIS) do
				StarterGui:SetCoreGuiEnabled(coreGuiType, false)
			end
		end)
		if ok then
			return
		end
		task.wait(0.5)
	end
	warn("CoreGuiController: could not disable the default Health/PlayerList CoreGuis")
end

disableCoreGuis()

local player = Players.LocalPlayer
player.CharacterAdded:Connect(disableCoreGuis)
