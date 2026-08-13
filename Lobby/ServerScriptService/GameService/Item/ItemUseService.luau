-- Generic hold-to-use item lifecycle. The one owner of the 3-second hold,
-- the movement lock, and item consumption -- individual handlers
-- (ItemHandlers/*) only ever see a successful completion and decide what the
-- item's effect is and how it's cleaned up. See ShopCatalog's Effect field
-- for the per-item data this reads.
--
-- HoldSeconds is server-owned throughout: the client sends Begin/Cancel and
-- renders a progress bar off the DEADLINE this pushes back, never off its
-- own timer. Deadline, not duration, crosses the wire, per the project's
-- countdown invariant (workspace:GetServerTimeNow(), same as QueuePadEndsAt).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local Trove = require(ReplicatedStorage.Modules.Shared.Trove)
local Cooldown = require(ReplicatedStorage.Modules.Shared.Cooldown)

local ItemUseGuard = require(script.Parent.ItemUseGuard)
local ItemConsumption = require(script.Parent.ItemConsumption)
local ItemHandlers = require(script.Parent.ItemHandlers)
local CharacterMovementService = require(script.Parent.Parent.Player.CharacterMovementService)
local DeathService = require(ServerScriptService.GameService.Death.DeathService)

local ItemUseService = {}

type Session = {
	player: Player,
	tool: Tool,
	itemId: string,
	item: any,
	endsAt: number,
	anchorPos: Vector3,
	trove: any,
}

local sessions: { [Player]: Session } = {}
local beginCooldown = Cooldown.new(0.25)

local itemUseRequest: RemoteEvent
local itemUseState: RemoteEvent
local itemUseResult: RemoteEvent

local function endSession(player: Player, status: string, code: string?)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	session.trove:Clean() -- releases the movement lock unconditionally
	itemUseState:FireClient(player, { status = status })
	if code then
		itemUseResult:FireClient(player, { code = code })
	end
end

local function cancelSession(player: Player, code: string)
	endSession(player, "Cancelled", code)
end

local function completeSession(player: Player)
	local session = sessions[player]
	if not session then
		return
	end

	local handler = ItemHandlers.Get(session.itemId)
	local ok, code = false, "Failed"
	if handler and handler.Apply then
		ok, code = handler.Apply(player, { tool = session.tool, item = session.item })
	end

	-- Consumption happens only after a successful Apply, never before, and
	-- never on a cancelled or failed use. ReplaceWith wins over Consume: the
	-- deployables swap the held Tool for their controller (Compact Speaker ->
	-- remotes, Portable CCTV -> tablet) instead of emptying the slot.
	if ok then
		local effect = session.item.Effect
		if effect.ReplaceWith then
			ItemConsumption.ReplaceTool(player, session.tool, effect.ReplaceWith)
		elseif effect.Consume ~= false then
			ItemConsumption.ConsumeTool(player, session.tool)
		end
	end

	sessions[player] = nil
	session.trove:Clean()
	itemUseState:FireClient(player, { status = "Complete" })
	itemUseResult:FireClient(player, { code = ok and "Success" or code })
end

local function beginSession(player: Player, tool: Tool, itemId: string, item)
	local character = player.Character :: Model
	local rootPart = character.HumanoidRootPart :: BasePart

	local holdSeconds = item.Effect.HoldSeconds or 3
	local endsAt = workspace:GetServerTimeNow() + holdSeconds

	local trove = Trove.new()
	local session: Session = {
		player = player,
		tool = tool,
		itemId = itemId,
		item = item,
		endsAt = endsAt,
		anchorPos = rootPart.Position,
		trove = trove,
	}
	sessions[player] = session

	CharacterMovementService.SetMovementLocked(player, true)
	trove:Add(function()
		CharacterMovementService.SetMovementLocked(player, false)
	end)

	itemUseState:FireClient(player, {
		status = "Active",
		itemId = itemId,
		endsAt = endsAt,
		holdSeconds = holdSeconds,
	})
end

local function onRequest(player: Player, action: string)
	if action == "Begin" then
		if sessions[player] then
			-- One session per player, ever. A repeat Begin during an active
			-- hold is silently ignored rather than restarting or cancelling
			-- it, so spamming Begin can't be used to grief the player's own
			-- hold.
			return
		end
		if not beginCooldown:Check(player.UserId) then
			return
		end

		local ok, code, tool, itemId, item = ItemUseGuard.CanBegin(player)
		if not ok then
			itemUseResult:FireClient(player, { code = code })
			return
		end

		-- Control-kind items are instant: no hold, no movement lock, no
		-- session. The Portable CCTV tablet is the only one today -- a
		-- 3-second hold to glance at a camera, and another to look away,
		-- would be a usability defect. Dispatched here rather than as a
		-- special case inside beginSession so the hold lifecycle below stays
		-- entirely generic.
		if item.Effect.Kind == "Control" then
			local handler = ItemHandlers.Get(itemId :: string)
			local applied, applyCode = false, "Failed"
			if handler and handler.Apply then
				applied, applyCode = handler.Apply(player, { tool = tool, item = item })
			end
			itemUseResult:FireClient(player, { code = applied and "Success" or applyCode })
			return
		end

		beginSession(player, tool :: Tool, itemId :: string, item)
	elseif action == "Cancel" then
		if sessions[player] then
			cancelSession(player, "Cancelled")
		end
	end
end

local function step()
	local now = workspace:GetServerTimeNow()
	for player, session in pairs(sessions) do
		local invalidCode = ItemUseGuard.StillValid(session)
		if invalidCode then
			cancelSession(player, invalidCode)
		elseif now >= session.endsAt then
			completeSession(player)
		end
	end
end

-- Force-cancels an in-progress hold. Exposed for callers outside the normal
-- Begin/Cancel/Heartbeat flow that need an immediate exit (none currently
-- call this directly -- death and disconnect both already flow through
-- StillValid/PlayerRemoving below -- but kept as the one sanctioned external
-- entry point rather than another module reaching into `sessions`).
function ItemUseService.CancelFor(player: Player, code: string)
	if sessions[player] then
		cancelSession(player, code)
	end
end

local started = false

function ItemUseService.Start()
	if started then
		return
	end
	started = true

	itemUseRequest = Remotes.Get("ItemUseRequest")
	itemUseState = Remotes.Get("ItemUseState")
	itemUseResult = Remotes.Get("ItemUseResult")

	itemUseRequest.OnServerEvent:Connect(function(player, action)
		if typeof(action) ~= "string" then
			return
		end
		onRequest(player, action)
	end)

	DeathService.Died:Connect(function(payload)
		if sessions[payload.player] then
			cancelSession(payload.player, "NotAlive")
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		if sessions[player] then
			cancelSession(player, "Disconnected")
		end
	end)

	RunService.Heartbeat:Connect(step)
end

return ItemUseService
