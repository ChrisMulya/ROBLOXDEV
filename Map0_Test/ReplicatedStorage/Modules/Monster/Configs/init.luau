-- Auto-discovers every sibling ModuleScript as a monster config, so adding a
-- monster is one new file here and no edit anywhere else. This is the seam
-- MonsterAgent's hardcoded `Behaviors = { GreyCube = require(...) }` table
-- blocked -- that table made every new monster an edit to a shared file.
--
-- Deliberately NOT the explicit-require-table shape of Pickup/PickupHandlers
-- and Flash/FlashRenderers. Those accept a one-line edit per entry; the whole
-- point of the Monster Framework is that adding a monster edits nothing, so
-- the registry has to discover rather than enumerate. Everywhere else in the
-- repo, prefer the explicit table -- it's greppable and this isn't.
--
-- A malformed config warns and is skipped rather than failing the require:
-- one bad monster shouldn't take the whole framework (and the match) down.
-- MonsterConfig.Validate turns it into a loud boot failure instead.

local Configs = {}

for _, child in ipairs(script:GetChildren()) do
	if child:IsA("ModuleScript") then
		local ok, config = pcall(require, child)

		if not ok then
			warn(("Monster Configs: '%s' failed to load -- %s"):format(child.Name, tostring(config)))
		elseif type(config) ~= "table" then
			warn(("Monster Configs: '%s' did not return a table"):format(child.Name))
		else
			-- Id wins over file name so a config can't silently register under
			-- the wrong key after a rename.
			local id = config.Id or child.Name
			if Configs[id] then
				warn(("Monster Configs: duplicate monster id '%s' -- keeping the first"):format(id))
			else
				Configs[id] = config
			end
		end
	end
end

return Configs
