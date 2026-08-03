local SoundIds = {}

SoundIds.Sounds = {
	KaChing = nil, -- TODO: paste asset id, e.g. "rbxassetid://1234567890"
}

function SoundIds.GetSoundId(soundName)
	return SoundIds.Sounds[soundName]
end

return SoundIds