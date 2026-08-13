-- The one place the effect-mirror attribute naming lives, so the server that
-- writes it and the client that reads it can never drift apart.
--
-- PlayerEffects (server) mirrors every live effect source onto the Player as a
-- boolean attribute. Attributes replicate; the effect table does not -- and the
-- Shop UI needs to know whether an Instant item (Brighter Flashlight: bought,
-- not carried) is already active, which no slot scan can tell it because there
-- is no Tool in a slot to find.
--
-- Read-only on the client. PlayerEffects owns the write, including clearing on
-- expiry, death, and match end.

local EffectAttributes = {}

EffectAttributes.PREFIX = "Effect_"

function EffectAttributes.NameFor(sourceId: string): string
	return EffectAttributes.PREFIX .. sourceId
end

function EffectAttributes.IsActive(player: Player, sourceId: string): boolean
	return player:GetAttribute(EffectAttributes.NameFor(sourceId)) == true
end

-- Mirrors the record's expiresAt (workspace:GetServerTimeNow() timestamp) for
-- timed effects, so a countdown can be rendered client-side. Unset for
-- Duration = nil effects (Brighter Flashlight) -- there is nothing to count
-- down to.
EffectAttributes.EXPIRY_PREFIX = "EffectExpiry_"

function EffectAttributes.ExpiryNameFor(sourceId: string): string
	return EffectAttributes.EXPIRY_PREFIX .. sourceId
end

function EffectAttributes.GetExpiry(player: Player, sourceId: string): number?
	return player:GetAttribute(EffectAttributes.ExpiryNameFor(sourceId))
end

return EffectAttributes
