--!strict

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Shared =
	ReplicatedStorage.Shared

local CombatTypes =
	require(Shared.Combat.CombatTypes)

local LightCombo =
	require(Shared.Combat.LightCombo)

local MoveDefinitions =
	require(Shared.Combat.MoveDefinitions)

local CharacterStateStore =
	require(
		script.Parent.Parent.Character.CharacterStateStore
	)

local EventBus =
	require(
		script.Parent.Parent.Events.EventBus
	)

local EventTypes =
	require(
		script.Parent.Parent.Events.EventTypes
	)

type AttackAction =
	CombatTypes.AttackAction

type ActionPhase =
	CombatTypes.ActionPhase

type Store =
	CharacterStateStore.Store

type Bus =
	EventBus.Bus

local AttackSystem = {}

-- =========================================================
-- TYPES
-- =========================================================

type RuntimeAttack = {
	action: AttackAction,

	sequence: number,

	phase: ActionPhase,

	phaseEndTick: number,

	awaitingResolution: boolean,
}

export type ActiveAttack = {
	userId: number,

	action: AttackAction,

	sequence: number,
}

export type FinishedAttack = {
	userId: number,

	action: AttackAction,

	sequence: number,
}

export type StepResult = {
	active: {ActiveAttack},
	finished: {FinishedAttack},
}

export type System = {
	start: (
		userId: number,
		action: AttackAction,
		sequence: number,
		nextComboStep: number,
		currentTick: number
	) -> (),

	chain: (
		userId: number,
		action: AttackAction,
		sequence: number,
		nextComboStep: number,
		currentTick: number
	) -> (),

	finish: (
		userId: number,
		currentTick: number
	) -> (),

	step: (
		currentTick: number
	) -> StepResult,

	cancel: (
		userId: number
	) -> (),

	hasActive: (
		userId: number
	) -> boolean,
}

-- =========================================================
-- FACTORY
-- =========================================================

function AttackSystem.new(
	store: Store,
	bus: Bus,
	duelId: string
): System

	local runtimeByUser:
		{[number]: RuntimeAttack} = {}

	-- =====================================================
	-- EVENTS
	-- =====================================================

	local function publishStarted(
		userId: number,
		action: AttackAction,
		sequence: number,
		tick: number
	)
		bus.publish(
			EventTypes.create(
				"AttackStarted",
				{
					tick = tick,
					duelId = duelId,

					actorUserId = userId,

					data = {
						action = action,
						sequence = sequence,
					},
				}
			)
		)
	end

	local function publishPhase(
		userId: number,
		action: AttackAction,
		phase: ActionPhase,
		tick: number
	)
		bus.publish(
			EventTypes.create(
				"AttackPhaseChanged",
				{
					tick = tick,
					duelId = duelId,

					actorUserId = userId,

					data = {
						action = action,
						phase = phase,
					},
				}
			)
		)
	end

	local function publishFinished(
		userId: number,
		action: AttackAction,
		sequence: number,
		tick: number
	)
		bus.publish(
			EventTypes.create(
				"AttackFinished",
				{
					tick = tick,
					duelId = duelId,

					actorUserId = userId,

					data = {
						action = action,
						sequence = sequence,
					},
				}
			)
		)
	end

	-- =====================================================
	-- BEGIN
	-- =====================================================

	local function beginAttack(
		userId: number,
		action: AttackAction,
		sequence: number,
		nextComboStep: number,
		currentTick: number,
		replacingFinishedAttack: boolean
	)
		local currentRuntime =
			runtimeByUser[userId]

		if replacingFinishedAttack then
			assert(
				currentRuntime ~= nil,
				"Cannot chain without current attack"
			)

			assert(
				currentRuntime.awaitingResolution,
				"Current attack is not ready to chain"
			)

			publishFinished(
				userId,
				currentRuntime.action,
				currentRuntime.sequence,
				currentTick
			)
		else
			assert(
				currentRuntime == nil,
				"Player already has an active attack"
			)
		end

		local timing =
			MoveDefinitions.getAttackTiming(
				action
			)

		local runtime: RuntimeAttack = {
			action = action,

			sequence = sequence,

			phase = "Startup",

			phaseEndTick =
				currentTick
				+ timing.startupTicks,

			awaitingResolution = false,
		}

		runtimeByUser[userId] = runtime

		store.update(
			userId,
			"AttackStarted",
			function(state)
				state.action = action
				state.actionPhase = "Startup"
				state.actionSequence = sequence

				state.movementLocked = true

				state.comboStep =
					nextComboStep
			end
		)

		publishStarted(
			userId,
			action,
			sequence,
			currentTick
		)
	end

	local function start(
		userId: number,
		action: AttackAction,
		sequence: number,
		nextComboStep: number,
		currentTick: number
	)
		beginAttack(
			userId,
			action,
			sequence,
			nextComboStep,
			currentTick,
			false
		)
	end

	local function chain(
		userId: number,
		action: AttackAction,
		sequence: number,
		nextComboStep: number,
		currentTick: number
	)
		beginAttack(
			userId,
			action,
			sequence,
			nextComboStep,
			currentTick,
			true
		)
	end

	-- =====================================================
	-- FINISH
	-- =====================================================

	local function finish(
		userId: number,
		currentTick: number
	)
		local runtime =
			runtimeByUser[userId]

		assert(
			runtime ~= nil,
			"Cannot finish missing attack"
		)

		assert(
			runtime.awaitingResolution,
			"Attack is not ready to finish"
		)

		runtimeByUser[userId] = nil

		store.update(
			userId,
			"AttackFinished",
			function(state)
				state.action = nil
				state.actionPhase = nil
				state.actionSequence = nil

				state.movementLocked = false

				state.comboStep =
					LightCombo.getResetStep()
			end
		)

		publishFinished(
			userId,
			runtime.action,
			runtime.sequence,
			currentTick
		)
	end

	-- =====================================================
	-- PHASE
	-- =====================================================

	local function setPhase(
		userId: number,
		runtime: RuntimeAttack,
		phase: ActionPhase,
		tick: number
	)
		runtime.phase = phase

		store.update(
			userId,
			"AttackPhaseChanged",
			function(state)
				state.actionPhase = phase
			end
		)

		publishPhase(
			userId,
			runtime.action,
			phase,
			tick
		)
	end

	-- =====================================================
	-- STEP
	-- =====================================================

	local function step(
		currentTick: number
	): StepResult

		local active: {ActiveAttack} = {}
		local finished: {FinishedAttack} = {}

		for userId, runtime in pairs(
			runtimeByUser
			) do
			if runtime.awaitingResolution then
				continue
			end

			local safety = 0

			while currentTick >= runtime.phaseEndTick do
				safety += 1

				assert(
					safety <= 4,
					"Attack phase transition overflow"
				)

				local timing =
					MoveDefinitions.getAttackTiming(
						runtime.action
					)

				if runtime.phase == "Startup" then
					local transitionTick =
						runtime.phaseEndTick

					setPhase(
						userId,
						runtime,
						"Active",
						transitionTick
					)

					runtime.phaseEndTick +=
						timing.activeTicks

					continue
				end

				if runtime.phase == "Active" then
					local transitionTick =
						runtime.phaseEndTick

					setPhase(
						userId,
						runtime,
						"Recovery",
						transitionTick
					)

					runtime.phaseEndTick +=
						timing.recoveryTicks

					continue
				end

				runtime.awaitingResolution = true

				table.insert(
					finished,
					{
						userId = userId,

						action = runtime.action,

						sequence =
							runtime.sequence,
					}
				)

				break
			end

			if not runtime.awaitingResolution
				and runtime.phase == "Active"
			then
				table.insert(
					active,
					{
						userId = userId,

						action = runtime.action,

						sequence =
							runtime.sequence,
					}
				)
			end
		end

		-- pairs() não possui ordem de gameplay.
		-- Ordenamos para manter resultados determinísticos.
		table.sort(
			active,
			function(
				a: ActiveAttack,
				b: ActiveAttack
			): boolean

				return a.userId < b.userId
			end
		)

		table.sort(
			finished,
			function(
				a: FinishedAttack,
				b: FinishedAttack
			): boolean

				return a.userId < b.userId
			end
		)

		return {
			active = active,
			finished = finished,
		}
	end

	-- =====================================================
	-- CANCEL
	-- =====================================================

	local function cancel(
		userId: number
	)
		runtimeByUser[userId] = nil
	end

	local function hasActive(
		userId: number
	): boolean

		return runtimeByUser[userId] ~= nil
	end

	return {
		start = start,
		chain = chain,

		finish = finish,

		step = step,

		cancel = cancel,

		hasActive = hasActive,
	}
end

return AttackSystem