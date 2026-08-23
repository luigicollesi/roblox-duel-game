--!strict

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Shared =
	ReplicatedStorage.Shared

local LightCombo =
	require(Shared.Combat.LightCombo)

local CharacterStateStore =
	require(script.Parent.CharacterStateStore)

local EventBus =
	require(script.Parent.Parent.Events.EventBus)

local EventTypes =
	require(script.Parent.Parent.Events.EventTypes)

type Store = CharacterStateStore.Store
type Bus = EventBus.Bus

local StanceService = {}

export type Service = {
	start: (
		userId: number
	) -> boolean,

	activate: (
		userId: number
	) -> boolean,

	deactivate: (
		userId: number
	) -> boolean,
}

-- =========================================================
-- FACTORY
-- =========================================================

function StanceService.new(
	store: Store,
	bus: Bus
): Service

	-- =====================================================
	-- START
	-- =====================================================

	local function start(
		userId: number
	): boolean

		local current =
			store.get(userId)

		if current == nil then
			return false
		end

		if current.status ~= "Normal" then
			return false
		end

		if current.stance ~= "Inactive" then
			return false
		end

		if current.action ~= nil then
			return false
		end

		local nextState =
			store.update(
				userId,
				"StanceStarted",
				function(state)
					state.stance = "Starting"

					-- Start é uma animação de entrada
					-- e não permite movimentação.
					state.movementLocked = true

					state.comboStep =
						LightCombo.getResetStep()

					state.airAttackArmed = false
				end
			)

		bus.publish(
			EventTypes.create(
				"StanceStarted",
				{
					actorUserId = userId,

					data = {
						revision =
							nextState.revision,
					},
				}
			)
		)

		return true
	end

	-- =====================================================
	-- ACTIVATE
	-- =====================================================

	local function activate(
		userId: number
	): boolean

		local current =
			store.get(userId)

		if current == nil then
			return false
		end

		if current.status ~= "Normal" then
			return false
		end

		if current.stance ~= "Starting" then
			return false
		end

		local nextState =
			store.update(
				userId,
				"StanceActivated",
				function(state)
					state.stance = "Active"

					-- A velocidade reduzida da stance
					-- será aplicada posteriormente
					-- pelo MovementSystem.
					state.movementLocked = false
				end
			)

		bus.publish(
			EventTypes.create(
				"StanceActivated",
				{
					actorUserId = userId,

					data = {
						revision =
							nextState.revision,
					},
				}
			)
		)

		return true
	end

	-- =====================================================
	-- DEACTIVATE
	-- =====================================================

	local function deactivate(
		userId: number
	): boolean

		local current =
			store.get(userId)

		if current == nil then
			return false
		end

		if current.stance == "Inactive" then
			return false
		end

		local nextState =
			store.update(
				userId,
				"StanceDeactivated",
				function(state)
					state.stance = "Inactive"

					state.movementLocked = false

					-- Sair da stance encerra qualquer
					-- sequência de combate.
					state.action = nil
					state.actionPhase = nil
					state.actionSequence = nil

					state.comboStep =
						LightCombo.getResetStep()

					state.airAttackArmed = false
				end
			)

		bus.publish(
			EventTypes.create(
				"StanceDeactivated",
				{
					actorUserId = userId,

					data = {
						revision =
							nextState.revision,
					},
				}
			)
		)

		return true
	end

	return {
		start = start,
		activate = activate,
		deactivate = deactivate,
	}
end

return StanceService