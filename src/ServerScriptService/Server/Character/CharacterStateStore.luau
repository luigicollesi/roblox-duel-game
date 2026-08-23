--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local CharacterStateTypes = require(
	Shared.State.CharacterStateTypes
)

local LightCombo = require(
	Shared.Combat.LightCombo
)

local EventBus = require(
	script.Parent.Parent.Events.EventBus
)

local EventTypes = require(
	script.Parent.Parent.Events.EventTypes
)

type CharacterState = CharacterStateTypes.CharacterState
type Bus = EventBus.Bus

local CharacterStateStore = {}

export type StateUpdater = (
	state: CharacterState
) -> ()

export type Store = {
	register: (
		userId: number
	) -> CharacterState,

	remove: (
		userId: number
	) -> boolean,

	reset: (
		userId: number,
		reason: string
	) -> CharacterState,

	has: (
		userId: number
	) -> boolean,

	get: (
		userId: number
	) -> CharacterState?,

	getRequired: (
		userId: number
	) -> CharacterState,

	update: (
		userId: number,
		reason: string,
		updater: StateUpdater
	) -> CharacterState,

	count: () -> number,

	clear: () -> (),
}

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

		airAttackArmed = state.airAttackArmed,

		duelId = state.duelId,

		revision = state.revision,
	}
end

-- =========================================================
-- VALIDATION
-- =========================================================

local function validateState(
	state: CharacterState
)
	assert(
		LightCombo.isValidStep(state.comboStep),
		`Invalid comboStep: {state.comboStep}`
	)

	assert(
		state.revision >= 0
			and state.revision % 1 == 0,
		`Invalid revision: {state.revision}`
	)

	-- Se não existe ação, também não pode existir
	-- fase nem sequence associada.
	if state.action == nil then
		assert(
			state.actionPhase == nil,
			"actionPhase cannot exist without action"
		)

		assert(
			state.actionSequence == nil,
			"actionSequence cannot exist without action"
		)

		return
	end

	-- Se existe uma ação, ela precisa possuir
	-- fase e sequence.
	assert(
		state.actionPhase ~= nil,
		"action must have an actionPhase"
	)

	assert(
		state.actionSequence ~= nil,
		"action must have an actionSequence"
	)
end

-- =========================================================
-- FACTORY
-- =========================================================

function CharacterStateStore.new(
	bus: Bus
): Store

	local states: {[number]: CharacterState} = {}

	-- =====================================================
	-- REGISTER
	-- =====================================================

	local function register(
		userId: number
	): CharacterState

		assert(
			states[userId] == nil,
			`CharacterState already exists for user {userId}`
		)

		local state =
			CharacterStateTypes.new()

		validateState(state)

		states[userId] = state

		local exposedState =
			cloneState(state)

		bus.publish(
			EventTypes.create(
				"CharacterStateCreated",
				{
					actorUserId = userId,

					data = {
						state = exposedState,
					},
				}
			)
		)

		return cloneState(state)
	end

	-- =====================================================
	-- REMOVE
	-- =====================================================

	local function remove(
		userId: number
	): boolean

		local existing =
			states[userId]

		if existing == nil then
			return false
		end

		local previous =
			cloneState(existing)

		states[userId] = nil

		bus.publish(
			EventTypes.create(
				"CharacterStateRemoved",
				{
					actorUserId = userId,

					data = {
						previous = previous,
					},
				}
			)
		)

		return true
	end

	-- =====================================================
	-- RESET
	-- =====================================================

	local function reset(
		userId: number,
		reason: string
	): CharacterState

		local current =
			states[userId]

		assert(
			current ~= nil,
			`CharacterState does not exist for user {userId}`
		)

		assert(
			reason ~= "",
			"CharacterState reset requires a reason"
		)

		local previous =
			cloneState(current)

		-- Cria um estado completamente novo.
		local nextState =
			CharacterStateTypes.new()

		-- Revision não volta para zero.
		-- Ela continua crescendo mesmo após reset.
		nextState.revision =
			current.revision + 1

		validateState(nextState)

		states[userId] = nextState

		local exposedState =
			cloneState(nextState)

		bus.publish(
			EventTypes.create(
				"CharacterStateChanged",
				{
					actorUserId = userId,

					data = {
						reason = reason,

						previous = previous,
						current = exposedState,
					},
				}
			)
		)

		return cloneState(nextState)
	end

	-- =====================================================
	-- HAS
	-- =====================================================

	local function has(
		userId: number
	): boolean
		return states[userId] ~= nil
	end

	-- =====================================================
	-- GET
	-- =====================================================

	local function get(
		userId: number
	): CharacterState?

		local state =
			states[userId]

		if state == nil then
			return nil
		end

		return cloneState(state)
	end

	-- =====================================================
	-- GET REQUIRED
	-- =====================================================

	local function getRequired(
		userId: number
	): CharacterState

		local state =
			states[userId]

		assert(
			state ~= nil,
			`CharacterState does not exist for user {userId}`
		)

		return cloneState(state)
	end

	-- =====================================================
	-- UPDATE
	-- =====================================================

	local function update(
		userId: number,
		reason: string,
		updater: StateUpdater
	): CharacterState

		local current =
			states[userId]

		assert(
			current ~= nil,
			`CharacterState does not exist for user {userId}`
		)

		assert(
			reason ~= "",
			"CharacterState update requires a reason"
		)

		-- Nunca modificamos o estado oficial diretamente.
		local previous =
			cloneState(current)

		local nextState =
			cloneState(current)

		-- O sistema externo modifica somente a cópia.
		updater(nextState)

		-- O Store é o único responsável pela revision.
		nextState.revision =
			current.revision + 1

		validateState(nextState)

		-- Só substituímos o estado oficial após
		-- passar pela validação.
		states[userId] = nextState

		local exposedState =
			cloneState(nextState)

		bus.publish(
			EventTypes.create(
				"CharacterStateChanged",
				{
					actorUserId = userId,

					data = {
						reason = reason,

						previous = previous,
						current = exposedState,
					},
				}
			)
		)

		return cloneState(nextState)
	end

	-- =====================================================
	-- COUNT
	-- =====================================================

	local function count(): number
		local total = 0

		for _userId, _state in pairs(states) do
			total += 1
		end

		return total
	end

	-- =====================================================
	-- CLEAR
	-- =====================================================

	local function clear()
		table.clear(states)
	end

	-- =====================================================
	-- PUBLIC API
	-- =====================================================

	return {
		register = register,
		remove = remove,
		reset = reset,

		has = has,

		get = get,
		getRequired = getRequired,

		update = update,

		count = count,
		clear = clear,
	}
end

return CharacterStateStore