-- The global stimulus distribution point. World systems PUBLISH without
-- knowing monsters exist; monsters SUBSCRIBE by kind, driven entirely by
-- their declared capabilities. Neither side requires the other.
--
-- Deliberately NOT under Monster/ -- see the blueprint's D3 note. A publisher
-- (FootstepEmitter, a player-movement system) requiring into Monster/ would
-- be the exact coupling this design exists to remove. Both a publisher and a
-- monster depend on Stimulus/; Stimulus/ depends on neither.
--
-- One Shared/Signal per kind, created on first use. This is the cross-service
-- case Monster/MonsterBus's own header calls out as correct for Signal:
-- one signal total per kind (not per monster), and the one-frame deferred
-- fire is harmless here -- Perception ticks at 0.1s, so a deferred fire costs
-- a fraction of that, not a game-visible delay.
--
-- StimulusBus is NOT a security boundary. It transports records that are
-- already trustworthy because of where they were built (see FootstepEmitter's
-- and FlashStimulusAdapter's own headers) -- nothing here re-validates a
-- Stimulus, and nothing downstream may start assuming it does.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Modules.Shared.Signal)

local StimulusBus = {}

export type Stimulus = {
	Kind: string,
	Position: Vector3,
	Timestamp: number,
	Strength: number,
	Source: Player?,
}

-- Diagnostic for "the monster never reacts". The stimulus path crosses four
-- modules (emitter -> bus -> sensor -> Perception), and a silent failure in
-- any of them looks identical from the game: a monster that ignores you. This
-- traces publish and subscriber count so one playtest says WHICH link is dead
-- rather than requiring a guess per run.
--
-- Off: publish/receive was confirmed working end to end in playtest, so the
-- tracing has done its job. Flip to true if a monster ever appears to ignore
-- a stimulus again -- it reports publishes, subscriber counts and per-sensor
-- range decisions, which localises the break to one of the four modules the
-- path crosses. Genuinely spammy while on: a footstep publishes several times
-- a second per moving player.
StimulusBus.Debug = false

local signals: { [string]: any } = {}
local subscriberCounts: { [string]: number } = {}

local function signalFor(kind: string)
	local signal = signals[kind]
	if not signal then
		signal = Signal.new()
		signals[kind] = signal
	end
	return signal
end

function StimulusBus.Publish(stimulus: Stimulus)
	if StimulusBus.Debug then
		warn(("[StimulusBus] publish %s at %s strength %.2f -- %d subscriber(s)")
			:format(tostring(stimulus.Kind), tostring(stimulus.Position),
				stimulus.Strength or -1, subscriberCounts[stimulus.Kind] or 0))
	end
	signalFor(stimulus.Kind):Fire(stimulus)
end

-- Returns an unsubscribe function, which Trove accepts directly -- same shape
-- as MonsterBus:On, so a sensor's construction-time subscription reads
-- identically to a component's bus:On() call.
function StimulusBus.Subscribe(kind: string, fn: (Stimulus) -> ()): () -> ()
	local connection = signalFor(kind):Connect(fn)
	subscriberCounts[kind] = (subscriberCounts[kind] or 0) + 1

	if StimulusBus.Debug then
		warn(("[StimulusBus] subscribe %s -- now %d"):format(kind, subscriberCounts[kind]))
	end

	local disconnected = false
	return function()
		if disconnected then
			return
		end
		disconnected = true
		subscriberCounts[kind] = math.max((subscriberCounts[kind] or 1) - 1, 0)
		connection:Disconnect()
	end
end

return StimulusBus
