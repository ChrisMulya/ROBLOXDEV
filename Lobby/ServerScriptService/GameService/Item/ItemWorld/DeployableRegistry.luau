-- Owner-tracked records for every placed support-item world object (Motion
-- Sensor, Compact Speaker, Portable CCTV). One registry for all three kinds,
-- same "registry the feature services register into" shape PickupRegistry
-- uses -- MotionSensorService/SpeakerService/CCTVService each Track() their
-- own kind's extra state keyed off the record they get back here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Modules.Shared.Trove)

local DeployableRegistry = {}

export type Record = {
	model: Instance,
	owner: Player,
	kind: string,
	trove: any,
}

local recordsByModel: { [Instance]: Record } = {}
local recordsByOwner: { [Player]: { Record } } = {}

function DeployableRegistry.Register(model: Instance, owner: Player, kind: string): Record
	local trove = Trove.new()
	local record: Record = { model = model, owner = owner, kind = kind, trove = trove }

	trove:Add(model)
	-- Catches a model destroyed by something other than Unregister (e.g. a
	-- Studio-side cleanup) so recordsByModel/recordsByOwner never leak an
	-- entry for an instance that's already gone.
	trove:Add(model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			DeployableRegistry.Unregister(model)
		end
	end))

	recordsByModel[model] = record
	local ownerList = recordsByOwner[owner]
	if not ownerList then
		ownerList = {}
		recordsByOwner[owner] = ownerList
	end
	table.insert(ownerList, record)

	return record
end

-- Idempotent: the model's own AncestryChanged and an explicit caller-side
-- teardown (lifetime expiry, monster contact, owner death) both route here,
-- whichever fires first wins and the other no-ops.
function DeployableRegistry.Unregister(model: Instance)
	local record = recordsByModel[model]
	if not record then
		return
	end
	recordsByModel[model] = nil

	local ownerList = recordsByOwner[record.owner]
	if ownerList then
		local index = table.find(ownerList, record)
		if index then
			table.remove(ownerList, index)
		end
	end

	record.trove:Clean()
end

function DeployableRegistry.Get(model: Instance): Record?
	return recordsByModel[model]
end

function DeployableRegistry.ForOwner(owner: Player): { Record }
	return recordsByOwner[owner] or {}
end

-- Snapshot iteration, same reasoning as MonsterRegistry.ForEach -- a callback
-- may unregister the record it's handed (or any other) without invalidating
-- the loop.
function DeployableRegistry.ForEach(fn: (Record) -> ())
	local snapshot = {}
	for _, record in pairs(recordsByModel) do
		table.insert(snapshot, record)
	end
	for _, record in ipairs(snapshot) do
		if recordsByModel[record.model] then
			fn(record)
		end
	end
end

local function unregisterAllFor(owner: Player)
	local ownerList = recordsByOwner[owner]
	if not ownerList then
		return
	end
	for _, record in ipairs(table.clone(ownerList)) do
		DeployableRegistry.Unregister(record.model)
	end
end

local started = false

function DeployableRegistry.Start()
	if started then
		return
	end
	started = true

	Players.PlayerRemoving:Connect(unregisterAllFor)

	local MatchCleanup = require(script.Parent.Parent.Parent.Match.MatchCleanup)
	MatchCleanup.RegisterTeardownStep("DeployableTeardown", function()
		DeployableRegistry.ForEach(function(record)
			DeployableRegistry.Unregister(record.model)
		end)
	end)
end

return DeployableRegistry
