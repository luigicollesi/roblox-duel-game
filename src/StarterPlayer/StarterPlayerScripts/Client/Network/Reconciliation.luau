--!strict

local ClientStateStore =
	require(
		script.Parent.Parent.State.ClientStateStore
	)

local PredictionController =
	require(
		script.Parent.Parent.State.PredictionController
	)

local ClientEventBus =
	require(
		script.Parent.Parent.Events.ClientEventBus
	)

local ActionBuffer =
	require(
		script.Parent.Parent.Input.ActionBuffer
	)

type Store =
	ClientStateStore.Store

type PredictionApi =
	PredictionController.Controller

type Buffer =
	ActionBuffer.Buffer

type Disconnect =
	() -> ()

local Reconciliation = {}

export type Service = {
	start: () -> (),
	stop: () -> (),
}

function Reconciliation.new(
	localUserId: number,
	store: Store,
	prediction: PredictionApi,
	buffer: Buffer
): Service

	local started = false

	local stateDisconnect:
		Disconnect? = nil

	local rejectionDisconnect:
		Disconnect? = nil

	local function start()
		if started then
			return
		end

		started = true

		stateDisconnect =
			store.subscribe(
				function(
					userId,
					_previous,
					current
				)
					if userId
						~= localUserId
					then
						return
					end

					prediction.reconcile(
						current
					)

					if current.actionSequence
						~= nil
					then
						buffer.clearSequence(
							current.actionSequence
						)
					end

					if current.duelId == nil
						or current.status
						~= "Normal"
					then
						buffer.clear()
					end
				end
			)

		rejectionDisconnect =
			ClientEventBus.subscribe(
				"IntentRejected",
				function(data)
					if type(data)
						~= "table"
					then
						return
					end

					local sequence =
						data.sequence

					if type(sequence)
						~= "number"
					then
						return
					end

					prediction.reject(
						sequence
					)

					buffer.clearSequence(
						sequence
					)
				end
			)
	end

	local function stop()
		if not started then
			return
		end

		started = false

		if stateDisconnect ~= nil then
			stateDisconnect()
			stateDisconnect = nil
		end

		if rejectionDisconnect ~= nil then
			rejectionDisconnect()
			rejectionDisconnect = nil
		end
	end

	return {
		start = start,
		stop = stop,
	}
end

return Reconciliation