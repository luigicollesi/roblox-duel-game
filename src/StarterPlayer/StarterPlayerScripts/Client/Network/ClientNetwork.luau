--!strict

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local CombatTypes =
	require(
		ReplicatedStorage.Shared.Combat.CombatTypes
	)

local Protocol =
	require(
		ReplicatedStorage.Shared.Network.Protocol
	)

local CharacterStateTypes =
	require(
		ReplicatedStorage.Shared.State.CharacterStateTypes
	)

local ClientStateStore =
	require(
		script.Parent.Parent.State.ClientStateStore
	)

local ClientEventBus =
	require(
		script.Parent.Parent.Events.ClientEventBus
	)

type IntentKind =
	CombatTypes.IntentKind

type CharacterState =
	CharacterStateTypes.CharacterState

type Store =
	ClientStateStore.Store

local ClientNetwork = {}

export type Service = {
	start: () -> (),
	stop: () -> (),

	sendIntent: (
		kind: IntentKind
	) -> number,
}

-- =========================================================
-- SNAPSHOT VALIDATION
-- =========================================================

local function isStateSnapshot(
	payload: any
): boolean

	if type(payload) ~= "table" then
		return false
	end

	if payload.type ~= "StateSnapshot" then
		return false
	end

	if type(payload.userId)
		~= "number"
	then
		return false
	end

	if type(payload.state)
		~= "table"
	then
		return false
	end

	local state =
		payload.state

	if type(state.revision)
		~= "number"
	then
		return false
	end

	if type(state.stance)
		~= "string"
	then
		return false
	end

	if type(state.status)
		~= "string"
	then
		return false
	end

	if type(state.locomotion)
		~= "string"
	then
		return false
	end

	if type(state.air)
		~= "string"
	then
		return false
	end

	if type(state.movementLocked)
		~= "boolean"
	then
		return false
	end

	if type(state.comboStep)
		~= "number"
	then
		return false
	end

	if type(state.airAttackArmed)
		~= "boolean"
	then
		return false
	end

	return true
end

-- =========================================================
-- FACTORY
-- =========================================================

function ClientNetwork.new(
	intentRemote: RemoteEvent,
	stateRemote: RemoteEvent,
	effectRemote: UnreliableRemoteEvent,
	store: Store
): Service

	local started = false

	local stateConnection:
		RBXScriptConnection? = nil

	local effectConnection:
		RBXScriptConnection? = nil

	local nextSequence = 0

	-- =====================================================
	-- STATE MESSAGE
	-- =====================================================

	local function handleStateMessage(
		payload: any
	)
		if type(payload) ~= "table" then
			return
		end

		if payload.type
			== "StateSnapshot"
		then
			if not isStateSnapshot(
				payload
				) then
				warn(
					"[ClientNetwork] Invalid StateSnapshot"
				)

				return
			end

			local state =
				payload.state
			:: CharacterState

			store.setSnapshot(
				payload.userId,
				state
			)

			return
		end

		if payload.type
			== "IntentRejected"
		then
			local sequence =
				payload.sequence

			local reason =
				payload.reason

			if type(sequence)
				~= "number"
				or type(reason)
				~= "string"
			then
				return
			end

			ClientEventBus.publish(
				"IntentRejected",
				{
					sequence = sequence,
					reason = reason,
				}
			)
		end
	end

	-- =====================================================
	-- SEND
	-- =====================================================

	local function sendIntent(
		kind: IntentKind
	): number

		nextSequence += 1

		local sequence =
			nextSequence

		local intent =
			Protocol.createClientIntent(
				sequence,
				kind
			)

		intentRemote:FireServer(
			intent
		)

		return sequence
	end

	-- =====================================================
	-- START
	-- =====================================================

	local function start()
		if started then
			return
		end

		started = true

		stateConnection =
			stateRemote.OnClientEvent:Connect(
				handleStateMessage
			)

		effectConnection =
			effectRemote.OnClientEvent:Connect(
				function(payload: any)
					if type(payload)
						~= "table"
					then
						return
					end

					ClientEventBus.publish(
						"Effect",
						payload
					)
				end
			)

		stateRemote:FireServer(
			"RequestStateSync"
		)
	end

	-- =====================================================
	-- STOP
	-- =====================================================

	local function stop()
		if not started then
			return
		end

		started = false

		if stateConnection ~= nil then
			stateConnection:Disconnect()
			stateConnection = nil
		end

		if effectConnection ~= nil then
			effectConnection:Disconnect()
			effectConnection = nil
		end
	end

	return {
		start = start,
		stop = stop,

		sendIntent = sendIntent,
	}
end

return ClientNetwork