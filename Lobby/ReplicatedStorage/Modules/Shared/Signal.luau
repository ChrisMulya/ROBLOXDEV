-- Thin BindableEvent wrapper. The repo's established pub-sub pattern was a
-- BindableEvent hidden inside a module exposing only .Event (PlayerStats,
-- RewardStore) -- this is that pattern factored out so it's written once.
-- :Connect returns a real RBXScriptConnection, so Trove:Add(signal:Connect(fn))
-- works exactly like any other connection.
--
-- BindableEvent deep-copies non-Instance arguments across Fire(); table
-- identity is not preserved between publisher and subscriber. Payloads should
-- be flat and read-only.

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _bindable = Instance.new("BindableEvent") }, Signal)
end

function Signal:Fire(...)
	self._bindable:Fire(...)
end

function Signal:Connect(fn: (...any) -> ()): RBXScriptConnection
	return self._bindable.Event:Connect(fn)
end

function Signal:Once(fn: (...any) -> ()): RBXScriptConnection
	return self._bindable.Event:Once(fn)
end

function Signal:Wait(): ...any
	return self._bindable.Event:Wait()
end

function Signal:Destroy()
	self._bindable:Destroy()
end

return Signal
