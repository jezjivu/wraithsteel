--!strict
-- Signal: tiny synchronous-safe event object used across server and client.

local Signal = {}
Signal.__index = Signal

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	DisconnectAll: (self: Signal<T...>) -> (),
}

local function spawnFn(fn: (...any) -> (), ...: any)
	task.spawn(fn, ...)
end

type Handler = { Connected: boolean, _fn: (...any) -> (), Disconnect: (Handler) -> () }

function Signal.new(): any
	return setmetatable({ _handlers = {} :: { Handler } }, Signal)
end

function Signal:Connect(fn)
	local conn = { Connected = true }
	local handlers = self._handlers
	function conn.Disconnect(c)
		if not c.Connected then
			return
		end
		c.Connected = false
		local i = table.find(handlers, c)
		if i then
			table.remove(handlers, i)
		end
	end
	conn._fn = fn
	table.insert(handlers, conn)
	return conn
end

function Signal:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

function Signal:Fire(...)
	-- Copy so handlers may disconnect during iteration.
	local snapshot: { Handler } = table.clone(self._handlers)
	for _, conn in snapshot do
		if conn.Connected then
			spawnFn(conn._fn, ...)
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:DisconnectAll()
	local snapshot: { Handler } = table.clone(self._handlers)
	for _, conn in snapshot do
		conn:Disconnect()
	end
end

return Signal
