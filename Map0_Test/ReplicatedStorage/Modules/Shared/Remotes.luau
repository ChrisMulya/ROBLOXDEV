-- Single provisioning + lookup path for every RemoteEvent in the game.
-- Previously 25 call sites did their own `ReplicatedStorage.Remotes:WaitForChild(name)`,
-- six of them indexing `.Remotes` raw (no WaitForChild on the folder itself) --
-- a hard client error if that folder hadn't replicated yet. Remotes.Get always
-- waits for both the folder and the remote, so that failure mode is gone.
--
-- Remotes.Init() (server-only, called once from Bootstrap) creates whatever's
-- missing from ALL_NAMES. FindFirstChild wins over creation, so a
-- Studio-placed remote is never touched or duplicated.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

-- Every RemoteEvent the game uses. Add a new one here and Init() provisions it.
Remotes.ALL_NAMES = {
	"OpenCameraShelf",
	"CloseCameraShelf",
	"CameraShelfResult",
	"TakeCameraRequest",
	"WeakCameraShot",
	"StrongCameraShot",
	"ShotFeedback",
	"CameraSessionChanged",
	"ObjectiveStateSync",
	"ShowCurrencyUI",
	"HideCurrencyUI",
	"OpenShop",
	"BuyItem",
	"PurchaseResult",
	"SpectateRequest",
	"SpectateResult",
	"SpectateStateSync",
	"MatchResultSync",
	-- Queueing is entered by standing on a lobby pad, not by a client request:
	-- there is no QueueRequest, and pad state reaches every client as replicated
	-- pad attributes rather than a per-player sync. QueueResult remains for the
	-- one thing attributes can't carry -- a message aimed at one player.
	"QueueResult",
	-- Fired by the Match Ended receipt's Return To Lobby button (Game place
	-- only) -- see Match/ReturnToLobbyService.luau. Listed on both places so
	-- the two trees stay byte-identical and `diff -rq Lobby Map0_Test` stays a
	-- clean check; the Lobby simply provisions it and never connects to it.
	"ReturnToLobbyRequest",
	-- Sprint is a request, not a command: the client fires SprintRequest(bool)
	-- on Shift down/up and CharacterMovementService grants it only if the
	-- stamina IT owns allows. StaminaSync(stamina) pushes that authoritative
	-- value out on a timer -- the client renders it and never simulates it.
	"SprintRequest",
	"StaminaSync",
	-- Flashlight is a toggle, not a state sync: the client fires
	-- FlashlightRequest on F down (desktop) or a mobile button tap, and
	-- FlashlightService creates/destroys the SpotLight emitter server-side so
	-- every client sees it, not just the one who toggled it.
	"FlashlightRequest",
	-- The holder's camera look vector, sent at FlashlightAim.SEND_RATE (30Hz).
	-- Server-authoritative and posed for every client including the holder --
	-- see FlashlightAim.
	"FlashlightAim",
	-- Per-player escape dwell progress, pushed while that player stands in an
	-- open exit. Server->client only: the countdown is a render of a timer
	-- ExitService owns, never a client-reported one. A remote rather than a
	-- MatchInfo attribute because this is genuinely per-player -- two players
	-- in two different exits have two different countdowns.
	"ExitDwellSync",
	-- One-shot match event announcements for the HUD's event announcer line.
	-- Server->client broadcast, and the payload is an ID from
	-- MatchTime/MatchEvents rather than a string -- the client resolves the
	-- wording and colour, so the wire can't carry arbitrary on-screen text.
	-- Identical for everyone, but a remote rather than a MatchInfo attribute
	-- because this is an EVENT (fired once, shown for 10s) and not state --
	-- an attribute would replay to late joiners minutes after the fact.
	"MatchEventAnnounce",
}

function Remotes.Get(name: string): RemoteEvent
	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
	return remotesFolder:WaitForChild(name)
end

-- Server-only. Idempotent -- safe to call more than once, and safe alongside
-- remotes hand-placed in Studio under the same names.
function Remotes.Init()
	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = ReplicatedStorage
	end

	for _, name in ipairs(Remotes.ALL_NAMES) do
		if not remotesFolder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = remotesFolder
		end
	end
end

return Remotes
