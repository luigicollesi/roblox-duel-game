--!strict

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local CharacterStateTypes =
	require(
		ReplicatedStorage.Shared.State.CharacterStateTypes
	)

type CharacterState =
	CharacterStateTypes.CharacterState

local ClientStateStore = {}

export type ChangeHandler = (
	userId: number,
	previous: CharacterState?,
	current: CharacterState
) -> ()

export type Disconnect = () -> ()

export type Store = {
	setSnapshot: (
		userId: number,
		state: CharacterState
	) -> boolean,

	get: (
		userId: number
	) -> CharacterState?,

	subscribe: (
		handler: ChangeHandler
	) -> Disconnect,

	clear: (
		userId: number
	) -> (),
}

type Listener = {
	handler: ChangeHandler,
	connected: boolean,
}

local states:
	{[number]: CharacterState} = {}

local listeners:
	{Listener} = {}

-- =========================================================
-- CLONE
-- =========================================================

local function cloneState(
	state: CharacterState
): CharacterState

	return {
		stance = state.stance,
		status = state.status,

		locomotion = state.locomotion,
		air = state.air,

		action = state.action,
		actionPhase = state.actionPhase,
		actionSequence = state.actionSequence,

		movementLocked = state.movementLocked,

		comboStep = state.comboStep,

		airAttackArmed =
			state.airAttackArmed,

		duelId = state.duelId,

		revision = state.revision,
	}
end

-- =========================================================
-- NOTIFY
-- =========================================================

local function notify(
	userId: number,
	previous: CharacterState?,
	current: CharacterState
)
	local snapshot: {Listener} = {}

	for _, listener in ipairs(
		listeners
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

				userId,

				if previous ~= nil
				then cloneState(previous)
				else nil,

				cloneState(current)
			)

		if not success then
			warn(
				`[ClientStateStore] listener failed: {tostring(err)}`
			)
		end
	end
end

-- =========================================================
-- SET
-- =========================================================

function ClientStateStore.setSnapshot(
	userId: number,
	state: CharacterState
): boolean

	local previous =
		states[userId]

	-- Snapshot velho nunca substitui novo.
	if previous ~= nil
		and state.revision
		<= previous.revision
	then
		return false
	end

	local nextState =
		cloneState(state)

	states[userId] =
		nextState

	notify(
		userId,
		previous,
		nextState
	)

	return true
end

-- =========================================================
-- GET
-- =========================================================

function ClientStateStore.get(
	userId: number
): CharacterState?

	local state =
		states[userId]

	if state == nil then
		return nil
	end

	return cloneState(state)
end

-- =========================================================
-- SUBSCRIBE
-- =========================================================

function ClientStateStore.subscribe(
	handler: ChangeHandler
): Disconnect

	local listener: Listener = {
		handler = handler,
		connected = true,
	}

	table.insert(
		listeners,
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

-- =========================================================
-- CLEAR
-- =========================================================

function ClientStateStore.clear(
	userId: number
)
	states[userId] = nil
end

return ClientStateStore