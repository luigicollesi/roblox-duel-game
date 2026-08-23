--!strict

local EventTypes = require(script.Parent.EventTypes)

type EventName = EventTypes.EventName
type ServerEvent = EventTypes.ServerEvent

local EventBus = {}

export type EventHandler = (ServerEvent) -> ()
export type Disconnect = () -> ()

export type Bus = {
	subscribe: (
		eventName: EventName,
		handler: EventHandler
	) -> Disconnect,

	publish: (
		event: ServerEvent
	) -> (),

	listenerCount: (
		eventName: EventName
	) -> number,

	clear: () -> (),
}

type Listener = {
	id: number,
	handler: EventHandler,
	connected: boolean,
}

-- =========================================================
-- FACTORY
-- =========================================================

function EventBus.new(): Bus
	local listeners: {[string]: {Listener}} = {}

	local nextListenerId = 0

	-- -----------------------------------------------------
	-- Internal
	-- -----------------------------------------------------

	local function compact(eventName: EventName)
		local bucket = listeners[eventName]

		if bucket == nil then
			return
		end

		local compacted: {Listener} = {}

		for _, listener in bucket do
			if listener.connected then
				table.insert(compacted, listener)
			end
		end

		listeners[eventName] = compacted
	end

	-- -----------------------------------------------------
	-- Subscribe
	-- -----------------------------------------------------

	local function subscribe(
		eventName: EventName,
		handler: EventHandler
	): Disconnect

		nextListenerId += 1

		local listener: Listener = {
			id = nextListenerId,
			handler = handler,
			connected = true,
		}

		local bucket = listeners[eventName]

		if bucket == nil then
			bucket = {}
			listeners[eventName] = bucket
		end

		table.insert(bucket, listener)

		local disconnected = false

		return function()
			if disconnected then
				return
			end

			disconnected = true
			listener.connected = false
		end
	end

	-- -----------------------------------------------------
	-- Publish
	-- -----------------------------------------------------

	local function publish(event: ServerEvent)
		local bucket = listeners[event.name]

		if bucket == nil then
			return
		end

		-- Snapshot evita que um subscribe() feito dentro
		-- de um handler altere a iteração atual.
		local snapshot: {Listener} = {}

		for _, listener in bucket do
			table.insert(snapshot, listener)
		end

		for _, listener in snapshot do
			if not listener.connected then
				continue
			end

			local success, err = pcall(
				listener.handler,
				event
			)

			if not success then
				warn(
					`[EventBus] Listener failed for {event.name}: {tostring(err)}`
				)
			end
		end

		compact(event.name)
	end

	-- -----------------------------------------------------
	-- Debug
	-- -----------------------------------------------------

	local function listenerCount(eventName: EventName): number
		local bucket = listeners[eventName]

		if bucket == nil then
			return 0
		end

		local count = 0

		for _, listener in bucket do
			if listener.connected then
				count += 1
			end
		end

		return count
	end

	-- -----------------------------------------------------
	-- Lifecycle
	-- -----------------------------------------------------

	local function clear()
		table.clear(listeners)
	end

	return {
		subscribe = subscribe,
		publish = publish,

		listenerCount = listenerCount,

		clear = clear,
	}
end

return EventBus