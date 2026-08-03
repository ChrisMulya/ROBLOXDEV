-- Target selection policy: which participants are valid to spectate right
-- now, and how to cycle between them. Swappable -- Team/Killer variants
-- implement the same GetValidTargets + SelectNext/SelectPrevious interface
-- without SpectateService changing at all.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerStates = require(ReplicatedStorage.Modules.Shared.PlayerStates)
local MatchParticipants = require(script.Parent.Parent.Match.MatchParticipants)
local PlayerStateService = require(script.Parent.Parent.PlayerState.PlayerStateService)

local SpectateTargets = {}

function SpectateTargets.GetValidTargets(): { Player }
	local valid = {}
	for _, player in ipairs(MatchParticipants.GetPresent()) do
		local state = PlayerStateService.Get(player)
		if state and PlayerStates.CanControlCharacter(state) then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if character and humanoid and humanoid.Health > 0 then
				table.insert(valid, player)
			end
		end
	end
	return valid
end

local function indexOf(validTargets: { Player }, current: Player?): number
	if not current then
		return 0
	end
	for i, p in ipairs(validTargets) do
		if p == current then
			return i
		end
	end
	return 0
end

function SpectateTargets.SelectNext(current: Player?, validTargets: { Player }): Player?
	if #validTargets == 0 then
		return nil
	end
	local currentIndex = indexOf(validTargets, current)
	local nextIndex = (currentIndex % #validTargets) + 1
	return validTargets[nextIndex]
end

function SpectateTargets.SelectPrevious(current: Player?, validTargets: { Player }): Player?
	if #validTargets == 0 then
		return nil
	end
	local currentIndex = indexOf(validTargets, current)
	if currentIndex == 0 then
		currentIndex = 1
	end
	local prevIndex = ((currentIndex - 2) % #validTargets) + 1
	return validTargets[prevIndex]
end

return SpectateTargets
