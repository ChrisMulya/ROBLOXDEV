-- Trove: small cleanup-tracking helper.
-- Register connections/instances/functions as you acquire them; Clean() undoes
-- everything in reverse order. Fixes the "teardown drifts from setup" bug
-- class (leaked Equipped/Unequipped connections, GUIs destroyed by name
-- lookup instead of by reference, etc).

local Trove = {}
Trove.__index = Trove

function Trove.new()
	return setmetatable({ _items = {} }, Trove)
end

-- Accepts an RBXScriptConnection, an Instance, or a plain function.
-- Returns the same item so it can be used inline: local conn = trove:Add(x.Event:Connect(f))
function Trove:Add(item)
	table.insert(self._items, item)
	return item
end

function Trove:Clean()
	for i = #self._items, 1, -1 do
		local item = self._items[i]
		self._items[i] = nil

		if typeof(item) == "RBXScriptConnection" then
			item:Disconnect()
		elseif typeof(item) == "Instance" then
			item:Destroy()
		elseif typeof(item) == "function" then
			item()
		end
	end
end

return Trove
