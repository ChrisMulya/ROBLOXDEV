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
--
-- Backpack and Chat are ADDITIONALLY disabled only while MatchState ==
-- "Loading" -- the match loading curtain already covers the screen visually,
-- but both remain separately interactive CoreGuis a keypress could still
-- open through it. Reacts to the MatchInfo.MatchState attribute directly
-- rather than a callback from LoadingController -- same nil-tolerant
-- "read MatchInfo straight off ReplicatedStorage, with a ChildAdded fallback"
-- convention as MissionHudController/ExitClient, which keeps this a
-- self-contained script needing no coordination with a separately-booted
-- LocalScript. On the Lobby, MatchInfo never exists (MatchReplicator only
-- ever boots on a Game Server), so this half is simply always inert there.

local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DISABLED_CORE_GUIS = { Enum.CoreGuiType.Health, Enum.CoreGuiType.PlayerList }
local LOADING_CORE_GUIS = { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Chat }

local function setCoreGuisEnabled(coreGuiTypes: { Enum.CoreGuiType }, enabled: boolean)
	-- Can throw if CoreGui hasn't finished initializing yet; retry rather
	-- than assume the first call lands.
	for _ = 1, 5 do
		local ok = pcall(function()
			for _, coreGuiType in ipairs(coreGuiTypes) do
				StarterGui:SetCoreGuiEnabled(coreGuiType, enabled)
			end
		end)
		if ok then
			return
		end
		task.wait(0.5)
	end
	warn("CoreGuiController: could not set CoreGui enabled state")
end

local function disableCoreGuis()
	setCoreGuisEnabled(DISABLED_CORE_GUIS, false)
end

disableCoreGuis()

local player = Players.LocalPlayer
player.CharacterAdded:Connect(disableCoreGuis)

local function refreshLoadingGuis(matchInfo: Instance)
	local isLoading = matchInfo:GetAttribute("MatchState") == "Loading"
	setCoreGuisEnabled(LOADING_CORE_GUIS, not isLoading)
end

local function watchMatchInfo(matchInfo: Instance)
	matchInfo:GetAttributeChangedSignal("MatchState"):Connect(function()
		refreshLoadingGuis(matchInfo)
	end)
	refreshLoadingGuis(matchInfo)
end

local matchInfo = ReplicatedStorage:FindFirstChild("MatchInfo")
if matchInfo then
	watchMatchInfo(matchInfo)
else
	-- MatchReplicator creates MatchInfo at boot, well before any client
	-- finishes loading in practice, but this guards the ordering rather than
	-- assuming it -- same fallback MissionHudController uses.
	ReplicatedStorage.ChildAdded:Connect(function(child)
		if child.Name == "MatchInfo" then
			watchMatchInfo(child)
		end
	end)
end
