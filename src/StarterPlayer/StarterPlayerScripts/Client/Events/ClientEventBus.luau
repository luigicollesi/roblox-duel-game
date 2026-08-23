--!strict

local ClientEventBus = {}

export type EventName =
	"IntentRejected"
| "Effect"

export type Handler =
	(any) -> ()

export type Disconnect =
	() -> ()

type Listener = {
	handler: Handler,
	connected: boolean,
}

local listeners:
	{[string]: {Listener}} = {}

function ClientEventBus.subscribe(
	eventName: EventName,
	handler: Handler
): Disconnect

	local bucket =
		listeners[eventName]

	if bucket == nil then
		bucket = {}
		listeners[eventName] = bucket
	end

	local listener: Listener = {
		handler = handler,
		connected = true,
	}

	table.insert(
		bucket,
		listener
	)

	local disconnected = false

	return function()
		if disconnected then
			return
		end

		disconnected = true
		listener.connected = false
	end
end

function ClientEventBus.publish(
	eventName: EventName,
	data: any
)
	local bucket =
		listeners[eventName]

	if bucket == nil then
		return
	end

	local snapshot: {Listener} = {}

	for _, listener in ipairs(
		bucket
		) do
		table.insert(
			snapshot,
			listener
		)
	end

	for _, listener in ipairs(
		snapshot
		) do
		if not listener.connected then
			continue
		end

		local success, err =
			pcall(
				listener.handler,
				data
			)

		if not success then
			warn(
				`[ClientEventBus] listener failed: {tostring(err)}`
			)
		end
	end
end

function ClientEventBus.clear()
	table.clear(listeners)
end

return ClientEventBus