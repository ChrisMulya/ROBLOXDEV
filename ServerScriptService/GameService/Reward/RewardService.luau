-- The single sink every reward source calls through. AwardFromCapture is the
-- capture-shaped convenience wrapper for CameraShotHandler; Grant is the raw
-- entry point future sources (missions, achievements, events) use directly
-- with flat amounts. No remote accepts a reward amount -- this module is
-- only reachable from other server scripts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Signal = require(ReplicatedStorage.Modules.Shared.Signal)
local CaptureTargets = require(ReplicatedStorage.Modules.Reward.CaptureTargets)
local CaptureRules = require(ReplicatedStorage.Modules.Reward.CaptureRules)
local RewardCalculator = require(ReplicatedStorage.Modules.Reward.RewardCalculator)
local RewardLedger = require(script.Parent.RewardLedger)
local CaptureGuard = require(script.Parent.CaptureGuard)

local RewardService = {}

-- (player: Player, context: table, result: RewardResult) -- fired after a
-- successful Grant from AwardFromCapture. Generic: this module never learns
-- what an objective is. ObjectiveService subscribes to mark completion.
RewardService.Awarded = Signal.new()

-- fn(player, subject, context) -> table? -- merged into the reward context
-- before CaptureRules.Check runs. A provider that has nothing to add for this
-- subject returns nil. Order is registration order; providers must be
-- side-effect-free and non-yielding (AwardFromCapture stays atomic).
local contextProviders = {}

function RewardService.RegisterContextProvider(fn: (Player, Instance, any) -> any?)
	table.insert(contextProviders, fn)
end

local ANOMALY_XP_PER_MINUTE = 20000
local recentXP = {} -- [userId] = { amount, windowStart }

Players.PlayerRemoving:Connect(function(player)
	recentXP[player.UserId] = nil
end)

local function flagIfAnomalous(player: Player, xpAmount: number)
	if xpAmount <= 0 then return end

	local now = os.clock()
	local record = recentXP[player.UserId]
	if not record or now - record.windowStart > 60 then
		record = { amount = 0, windowStart = now }
		recentXP[player.UserId] = record
	end

	record.amount += xpAmount
	if record.amount > ANOMALY_XP_PER_MINUTE then
		warn(("RewardService: %s earned %d XP in the last minute (threshold %d)"):format(
			player.Name, record.amount, ANOMALY_XP_PER_MINUTE))
	end
end

-- amounts: { [rewardTypeName]: number }. meta: { Source, SourceId }, threaded
-- through for future logging/analytics -- not persisted anywhere yet.
function RewardService.Grant(player: Player, amounts: { [string]: number }, meta): boolean
	if not player or not player.Parent then
		return false
	end

	for rewardType, amount in pairs(amounts) do
		if amount ~= 0 then
			RewardLedger.Add(player, rewardType, amount)
		end
	end

	if amounts.XP then
		flagIfAnomalous(player, amounts.XP)
	end

	return true
end

-- context: { player, subject, shotQuality, distanceStuds, cameraId }
-- (context.subject is whatever PhotoCapture resolved -- re-resolved here
-- rather than trusted, closing the raycast-to-award race where a subject is
-- destroyed or detagged in between.)
--
-- ALWAYS returns a RewardResult carrying a resultCode ("Awarded", "TooFar",
-- "WrongShotQuality", "OnRepeatCooldown", "UnknownTarget", ...) -- amounts is
-- nil for every code except "Awarded". Never returns a bare "no reward" with
-- no explanation; see ShotResultCodes for the display strings.
function RewardService.AwardFromCapture(player: Player, context)
	local meters, bandLabel = RewardCalculator.Describe(context.distanceStuds)

	local subject, typeName = CaptureTargets.Resolve(context.subject)
	if not subject or not typeName or not subject:IsDescendantOf(workspace) then
		return { resultCode = "UnknownTarget", meters = meters, bandLabel = bandLabel, amounts = nil }
	end

	local typeDef = CaptureTargets.Get(typeName)
	local fullContext = table.clone(context)
	fullContext.subject = subject
	fullContext.targetType = typeName

	for _, provider in ipairs(contextProviders) do
		local extra = provider(player, subject, fullContext)
		if extra then
			for key, value in pairs(extra) do
				fullContext[key] = value
			end
		end
	end

	local rulesOk, ruleCode = CaptureRules.Check(typeDef, fullContext)
	if not rulesOk then
		return { resultCode = ruleCode, targetType = typeName, meters = meters, bandLabel = bandLabel, amounts = nil }
	end

	if not CaptureGuard.CheckRepeatPolicy(player, subject, typeDef) then
		return { resultCode = "OnRepeatCooldown", targetType = typeName, meters = meters, bandLabel = bandLabel, amounts = nil }
	end

	local result = RewardCalculator.Calculate(fullContext, typeDef)
	RewardService.Grant(player, result.amounts, { Source = "Camera", SourceId = context.cameraId, TargetType = typeName })

	result.resultCode = "Awarded"
	result.targetType = typeName

	RewardService.Awarded:Fire(player, fullContext, result)

	return result
end

return RewardService
