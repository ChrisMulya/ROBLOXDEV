-- PlayerEffects
-- The one timer system for every temporary per-player stat buff (Energy
-- Drink, Pills, Adrenaline Shot, Brighter Flashlight). Modelled on
-- Reward/RewardModifiers.luau's registry shape.
--
-- Stores DELTAS against PlayerStats' immutable base, never captured-and-
-- restored absolute values. With additive stacking and independent timers,
-- capturing "the value before this effect" is the classic way to permanently
-- bake in a buff -- two overlapping effects would each capture the other's
-- already-inflated value on restore. A delta needs nothing captured and
-- nothing restored: expiry just removes one row, and GetStat recomputes from
-- scratch, correct for any interleaving of any number of effects.
--
-- PlayerStats itself must never be written by an effect (PlayerStats.Set is
-- one value shared by every player on the server -- see its own header).
-- Every consumer of a buffable stat must read PlayerEffects.GetStat instead
-- of PlayerStats.Get directly.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStats = require(ReplicatedStorage.Modules.PlayerStats)
local Signal = require(ReplicatedStorage.Modules.Shared.Signal)
local EffectAttributes = require(ReplicatedStorage.Modules.Player.EffectAttributes)

local PlayerEffects = {}

export type Modifier = {
	Stat: string,
	Delta: number,
	Duration: number?, -- seconds; nil = no expiry (cleared by death/match end only)
	SourceId: string,
}

type Record = {
	id: number,
	stat: string,
	delta: number,
	expiresAt: number?,
	sourceId: string,
}

-- Fires (player: Player, stat: string) whenever a modifier for that stat is
-- applied, expires, or is cleared. No consumer currently subscribes -- every
-- existing reader (CharacterMovementService) re-derives GetStat on its own
-- tick -- but this matches RewardModifiers' shape for anything that later
-- wants to react rather than poll.
PlayerEffects.Changed = Signal.new()

local nextId = 0
-- [player] = { Record }
local activeByPlayer: { [Player]: { Record } } = {}

local function hasSource(player: Player, sourceId: string): boolean
	local list = activeByPlayer[player]
	if not list then
		return false
	end
	for _, record in ipairs(list) do
		if record.sourceId == sourceId then
			return true
		end
	end
	return false
end

-- Latest expiresAt among live records from this source, or nil if none are
-- live or the live one(s) never expire. ShopFillSlot blocks re-buying while
-- HasSource is true, so in practice there is at most one record per source --
-- max() is just the defensive choice if that ever changes.
local function latestExpiry(player: Player, sourceId: string): number?
	local list = activeByPlayer[player]
	if not list then
		return nil
	end
	local latest: number? = nil
	for _, record in ipairs(list) do
		if record.sourceId == sourceId then
			if not record.expiresAt then
				return nil
			end
			latest = math.max(latest or 0, record.expiresAt)
		end
	end
	return latest
end

-- Mirrors "is any effect from this source live?" onto the Player as a
-- replicated attribute, plus its expiry timestamp for timed effects. Called
-- from EVERY path that adds or drops a record -- apply, the unsubscribe
-- closure, expiry sweep, ClearAll -- because the whole point is that the
-- attribute is never stale. Derived from the table each time rather than
-- counted, so overlapping effects from one source (two stacked applies, one
-- expiring) can't leave it set to the wrong value.
local function syncSourceAttribute(player: Player, sourceId: string)
	local name = EffectAttributes.NameFor(sourceId)
	local expiryName = EffectAttributes.ExpiryNameFor(sourceId)
	if hasSource(player, sourceId) then
		player:SetAttribute(name, true)
		player:SetAttribute(expiryName, latestExpiry(player, sourceId))
	else
		player:SetAttribute(name, nil)
		player:SetAttribute(expiryName, nil)
	end
end

function PlayerEffects.Apply(player: Player, modifier: Modifier): () -> ()
	local list = activeByPlayer[player]
	if not list then
		list = {}
		activeByPlayer[player] = list
	end

	nextId += 1
	local record: Record = {
		id = nextId,
		stat = modifier.Stat,
		delta = modifier.Delta,
		-- workspace:GetServerTimeNow(), not os.clock(): this timestamp is
		-- mirrored to the client (EffectAttributes expiry attribute) for the
		-- HUD countdown, and only the server-time clock is shared across the
		-- boundary.
		expiresAt = modifier.Duration and (workspace:GetServerTimeNow() + modifier.Duration) or nil,
		sourceId = modifier.SourceId,
	}
	table.insert(list, record)
	syncSourceAttribute(player, record.sourceId)
	PlayerEffects.Changed:Fire(player, modifier.Stat)

	local removed = false
	return function()
		if removed then
			return
		end
		removed = true
		local current = activeByPlayer[player]
		if not current then
			return
		end
		local index = table.find(current, record)
		if index then
			table.remove(current, index)
			syncSourceAttribute(player, record.sourceId)
			PlayerEffects.Changed:Fire(player, record.stat)
		end
	end
end

-- Base + the sum of every live delta for that stat. Falls back to the
-- PlayerStats base for a player with no entry yet (e.g. queried before
-- CharacterAdded has run) rather than erroring, so a boot-order slip degrades
-- to vanilla stats instead of breaking movement outright.
function PlayerEffects.GetStat(player: Player, stat: string): number
	local base = PlayerStats.Get(stat) or 0
	local list = activeByPlayer[player]
	if not list then
		return base
	end

	local total = base
	for _, record in ipairs(list) do
		if record.stat == stat then
			total += record.delta
		end
	end
	return total
end

-- Whether this player already carries a live effect from that source. Exists
-- for the Shop's one-per-life instant items (Brighter Flashlight), which have
-- no Tool in a slot for the duplicate check to look at -- the live effect row
-- IS the record of ownership. Cleared with everything else on death/match end,
-- so "already bought" lasts exactly one life.
function PlayerEffects.HasSource(player: Player, sourceId: string): boolean
	return hasSource(player, sourceId)
end

function PlayerEffects.ClearAll(player: Player)
	local list = activeByPlayer[player]
	if not list or #list == 0 then
		activeByPlayer[player] = nil
		return
	end

	local stats = {}
	local sources = {}
	for _, record in ipairs(list) do
		stats[record.stat] = true
		sources[record.sourceId] = true
	end
	activeByPlayer[player] = nil
	for sourceId in pairs(sources) do
		syncSourceAttribute(player, sourceId)
	end
	for stat in pairs(stats) do
		PlayerEffects.Changed:Fire(player, stat)
	end
end

-- One shared sweep for every player's every effect, rather than a
-- task.delay per effect -- a torn-down player (death mid-effect, disconnect)
-- can't leave an orphan timer firing into a session that no longer exists,
-- because there is no per-effect timer to leak.
local function sweep()
	local now = workspace:GetServerTimeNow()
	for player, list in pairs(activeByPlayer) do
		local expiredStats = nil
		local expiredSources = nil
		for index = #list, 1, -1 do
			local record = list[index]
			if record.expiresAt and now >= record.expiresAt then
				table.remove(list, index)
				expiredStats = expiredStats or {}
				expiredStats[record.stat] = true
				expiredSources = expiredSources or {}
				expiredSources[record.sourceId] = true
			end
		end
		if expiredSources then
			for sourceId in pairs(expiredSources) do
				syncSourceAttribute(player, sourceId)
			end
		end
		if expiredStats then
			for stat in pairs(expiredStats) do
				PlayerEffects.Changed:Fire(player, stat)
			end
		end
	end
end

local started = false

function PlayerEffects.Start()
	if started then
		return
	end
	started = true

	Players.PlayerRemoving:Connect(function(player)
		activeByPlayer[player] = nil
	end)

	-- Death clears every effect immediately rather than waiting out each
	-- one's own timer -- a respawned player starts clean, same "per-life"
	-- convention EndGame already follows for Cash and tools.
	local DeathService = require(script.Parent.Parent.Death.DeathService)
	DeathService.Died:Connect(function(payload)
		PlayerEffects.ClearAll(payload.player)
	end)

	-- Match-end teardown for anyone still holding an effect when Cleanup is
	-- reached (a buff that outlived the match itself). Registry before
	-- registrant, same rule every other MatchCleanup registrant in GameBoot
	-- follows.
	local MatchCleanup = require(script.Parent.Parent.Match.MatchCleanup)
	local MatchParticipants = require(script.Parent.Parent.Match.MatchParticipants)
	MatchCleanup.RegisterTeardownStep("PlayerEffectsTeardown", function()
		for _, player in ipairs(MatchParticipants.GetPresent()) do
			PlayerEffects.ClearAll(player)
		end
	end)

	RunService.Heartbeat:Connect(sweep)
end

return PlayerEffects
