-- Death handling only. The only Humanoid.Died listener on this place (Game
-- Server) -- LobbyDeathPolicy binds Humanoid.Died itself on the Lobby,
-- entirely separately, and doesn't use this module. Owns no UI, no camera,
-- no teleport.
--
-- Existing ServerScriptService/GameService/Player/PlayerStateHandler.legacy.luau
-- also binds Humanoid.Died on both places (-> StartGameService.ResetKit) and
-- is untouched here per the plan's "existing self-wiring scripts are not
-- migrated" rule -- the two listeners coexist without conflict (ResetKit
-- only touches the KitGiven attribute), though the name collision with this
-- module is confusing and still worth a rename/absorb later (see
-- MAINHANDOFF).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchStates = require(ReplicatedStorage.Modules.Shared.MatchStates)
local Signal = require(ReplicatedStorage.Modules.Shared.Signal)
local MatchManager = require(script.Parent.Parent.Match.MatchManager)
local PlayerStateService = require(script.Parent.Parent.PlayerState.PlayerStateService)
local DeathPolicy = require(script.Parent.DeathPolicy)

local DeathService = {}

local currentModeId = "Default"

DeathService.Died = Signal.new() -- fires ({player, killerUserId?, position, timestamp})

function DeathService.SetPolicy(modeId: string)
	currentModeId = modeId
end

local function onHumanoidDied(player: Player, humanoid: Humanoid)
	-- A death outside Playing (Loading/WaitingForPlayers/Countdown/Ending/
	-- Cleanup) must not strand a player waiting on a match that never
	-- properly started -- respawn immediately instead of entering
	-- Dead/Spectating, mirroring the Lobby's own Dead -> (new character) ->
	-- Alive sequence rather than skipping Dead entirely.
	if not MatchStates.IsGameplayActive(MatchManager.Get()) then
		PlayerStateService.Set(player, "Dead", "DeathOutsideGameplay")
		player:LoadCharacter()
		return
	end

	local ok = PlayerStateService.Set(player, "Dead", "HumanoidDied")
	if not ok then
		return
	end

	local rootPart = humanoid.RootPart
	DeathService.Died:Fire({
		player = player,
		killerUserId = nil, -- no attacker attribution exists yet -- MonsterDamage doesn't report a killer today
		position = rootPart and rootPart.Position or nil,
		timestamp = os.time(),
	})

	local policy = DeathPolicy.Get(currentModeId)
	if policy.RespawnPolicy == "Immediate" then
		return
	end

	task.delay(policy.SpectateDelay, function()
		-- Only advance if still Dead -- the player may have disconnected,
		-- or the match may have moved past Playing, during the delay.
		if PlayerStateService.Is(player, "Dead") then
			PlayerStateService.Set(player, "Spectating", "SpectateDelayElapsed")
		end
	end)
end

local function bindCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then
		return
	end
	humanoid.Died:Connect(function()
		onHumanoidDied(player, humanoid)
	end)
end

local function onCharacterAdded(player: Player, character: Model)
	if PlayerStateService.Is(player, "Dead") then
		PlayerStateService.Set(player, "Alive", "CharacterAdded")
	end
	bindCharacter(player, character)
end

local started = false

function DeathService.Start()
	if started then
		return
	end
	started = true

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end)

	-- Backfill players/characters that already exist before Start() ran.
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			bindCharacter(player, player.Character)
		end
	end
end

return DeathService
