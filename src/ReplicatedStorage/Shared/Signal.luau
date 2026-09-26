-- NEON CITY: minimal signal. Handlers run in connection order; one failing handler
-- does not stop the others.

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(handler)
	table.insert(self._handlers, handler)
	local connection = {}
	function connection.Disconnect()
		local index = table.find(self._handlers, handler)
		if index then
			table.remove(self._handlers, index)
		end
	end
	return connection
end

function Signal:Fire(...)
	for _, handler in ipairs(table.clone(self._handlers)) do
		local ok, err = xpcall(handler, debug.traceback, ...)
		if not ok then
			warn("[Signal] handler error: " .. tostring(err))
		end
	end
end

return Signal
