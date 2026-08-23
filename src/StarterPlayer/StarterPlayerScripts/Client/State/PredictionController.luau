--!strict

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local CombatTypes =
	require(
		ReplicatedStorage.Shared.Combat.CombatTypes
	)

local LightCombo =
	require(
		ReplicatedStorage.Shared.Combat.LightCombo
	)

local CharacterStateTypes =
	require(
		ReplicatedStorage.Shared.State.CharacterStateTypes
	)

local ClientStateStore =
	require(
		script.Parent.ClientStateStore
	)

type CharacterState =
	CharacterStateTypes.CharacterState

type IntentKind =
	CombatTypes.IntentKind

type DashAction =
	CombatTypes.DashAction

type Store =
	ClientStateStore.Store

local PredictionController = {}

-- =========================================================
-- TYPES
-- =========================================================

export type ChangeHandler =
	(CharacterState) -> ()

export type Disconnect =
	() -> ()

export type Controller = {
	initialize: (
		userId: number,
		store: Store
	) -> (),

	predict: (
		sequence: number,
		kind: IntentKind,
		dashAction: DashAction?
	) -> boolean,

	reconcile: (
		authoritative: CharacterState
	) -> (),

	reject: (
		sequence: number
	) -> (),

	get: () -> CharacterState?,

	subscribe: (
		handler: ChangeHandler
	) -> Disconnect,

	clear: () -> (),
}

type PredictionMode =
	"Action"
| "Jump"
| "AirAttack"

-- =========================================================
-- EXPLICIT SINGLETON CONSTANTS
-- =========================================================

-- Explicitamos os tipos porque algumas versões do
-- analyzer fazem widening de literais atribuídos a
-- variáveis mutáveis.

local MODE_ACTION: PredictionMode =
	"Action"

local MODE_JUMP: PredictionMode =
	"Jump"

local MODE_AIR_ATTACK: PredictionMode =
	"AirAttack"

-- =========================================================
-- LISTENER
-- =========================================================

type Listener = {
	handler: ChangeHandler,
	connected: boolean,
}

-- =========================================================
-- STATE
-- =========================================================

local authoritativeStore:
	Store? = nil

local localUserId:
	number? = nil

local predictedState:
	CharacterState? = nil

local predictedSequence:
	number? = nil

local predictedKind:
	IntentKind? = nil

local predictionMode:
	PredictionMode? = nil

local generation: number = 0

local listeners:
	{Listener} = {}

local PREDICTION_TIMEOUT: number =
	0.9

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

		movementLocked =
			state.movementLocked,

		comboStep =
			state.comboStep,

		airAttackArmed =
			state.airAttackArmed,

		duelId =
			state.duelId,

		revision =
			state.revision,
	}
end

-- =========================================================
-- NOTIFY
-- =========================================================

local function notify(
	state: CharacterState
)
	local snapshot:
		{Listener} = {}

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
				cloneState(state)
			)

		if not success then
			warn(
				`[PredictionController] listener failed: {tostring(err)}`
			)
		end
	end
end

-- =========================================================
-- AUTHORITATIVE STATE
-- =========================================================

local function getAuthoritative():
	CharacterState?

	local store =
		authoritativeStore

	local userId =
		localUserId

	if store == nil then
		return nil
	end

	if userId == nil then
		return nil
	end

	return store.get(
		userId
	)
end

-- =========================================================
-- CLEAR INTERNAL PREDICTION
-- =========================================================

local function clearPrediction(
	notifyAuthoritative: boolean
)
	generation += 1

	predictedState = nil
	predictedSequence = nil
	predictedKind = nil
	predictionMode = nil

	if not notifyAuthoritative then
		return
	end

	local authoritative =
		getAuthoritative()

	if authoritative ~= nil then
		notify(
			authoritative
		)
	end
end

-- =========================================================
-- INITIALIZE
-- =========================================================

function PredictionController.initialize(
	userId: number,
	store: Store
)
	localUserId =
		userId

	authoritativeStore =
		store

	clearPrediction(
		false
	)

	local authoritative =
		getAuthoritative()

	if authoritative ~= nil then
		notify(
			authoritative
		)
	end
end

-- =========================================================
-- GET EFFECTIVE STATE
-- =========================================================

function PredictionController.get():
	CharacterState?

	local predicted =
		predictedState

	if predicted ~= nil then
		return cloneState(
			predicted
		)
	end

	return getAuthoritative()
end

-- =========================================================
-- PREDICT
-- =========================================================

function PredictionController.predict(
	sequence: number,
	kind: IntentKind,
	dashAction: DashAction?
): boolean

	local base =
		PredictionController.get()

	if base == nil then
		return false
	end

	-- =====================================================
	-- BASIC VALIDATION
	-- =====================================================

	if base.duelId == nil then
		return false
	end

	if base.status ~= "Normal" then
		return false
	end

	if base.stance ~= "Active" then
		return false
	end

	local nextState =
		cloneState(base)

	local mode:
		PredictionMode? = nil

	-- =====================================================
	-- LIGHT
	-- =====================================================

	if kind == "Light" then

		-- -----------------------------------------------
		-- AIR ATTACK
		-- -----------------------------------------------

		if base.air == "Jumping"
			or base.air == "Falling"
		then
			nextState.airAttackArmed =
				true

			mode =
				MODE_AIR_ATTACK

			-- -----------------------------------------------
			-- GROUND LIGHT
			-- -----------------------------------------------

		else
			-- Ataque já ativo significa buffer.
			-- Não tentamos prever visualmente a
			-- próxima animação ainda.
			if base.action ~= nil then
				return false
			end

			if base.air ~= "Grounded" then
				return false
			end

			if base.movementLocked then
				return false
			end

			local action =
				LightCombo.getAction(
					base.comboStep
				)

			nextState.action =
				action

			nextState.actionPhase =
				"Startup"

			nextState.actionSequence =
				sequence

			nextState.movementLocked =
				true

			nextState.comboStep =
				LightCombo.getNextStep(
					base.comboStep
				)

			nextState.locomotion =
				"Idle"

			mode =
				MODE_ACTION
		end

		-- =====================================================
		-- STRONG
		-- =====================================================

	elseif kind == "Strong" then

		-- -----------------------------------------------
		-- AIR ATTACK
		-- -----------------------------------------------

		if base.air == "Jumping"
			or base.air == "Falling"
		then
			nextState.airAttackArmed =
				true

			mode =
				MODE_AIR_ATTACK

			-- -----------------------------------------------
			-- GROUND STRONG
			-- -----------------------------------------------

		else
			if base.action ~= nil then
				return false
			end

			if base.air ~= "Grounded" then
				return false
			end

			if base.movementLocked then
				return false
			end

			nextState.action =
				"Strong"

			nextState.actionPhase =
				"Startup"

			nextState.actionSequence =
				sequence

			nextState.movementLocked =
				true

			nextState.comboStep =
				LightCombo.getResetStep()

			nextState.locomotion =
				"Idle"

			mode =
				MODE_ACTION
		end

		-- =====================================================
		-- JUMP
		-- =====================================================

	elseif kind == "Jump" then

		if base.air ~= "Grounded" then
			return false
		end

		if base.action ~= nil then
			return false
		end

		if base.movementLocked then
			return false
		end

		nextState.air =
			"Jumping"

		nextState.locomotion =
			"Idle"

		mode =
			MODE_JUMP

		-- =====================================================
		-- DASH
		-- =====================================================

	elseif kind == "Dash" then

		if dashAction == nil then
			return false
		end

		if base.air ~= "Grounded" then
			return false
		end

		if base.action ~= nil then
			return false
		end

		if base.movementLocked then
			return false
		end

		nextState.action =
			dashAction

		nextState.actionPhase =
			"Active"

		nextState.actionSequence =
			sequence

		nextState.movementLocked =
			true

		nextState.comboStep =
			LightCombo.getResetStep()

		nextState.locomotion =
			"Idle"

		mode =
			MODE_ACTION
	end

	-- =====================================================
	-- NO PREDICTION
	-- =====================================================

	if mode == nil then
		return false
	end

	-- =====================================================
	-- COMMIT LOCAL PREDICTION
	-- =====================================================

	generation += 1

	local token: number =
		generation

	predictedState =
		nextState

	predictedSequence =
		sequence

	predictedKind =
		kind

	predictionMode =
		mode

	notify(
		nextState
	)

	-- =====================================================
	-- SAFETY TIMEOUT
	-- =====================================================

	task.delay(
		PREDICTION_TIMEOUT,

		function()
			if generation
				~= token
			then
				return
			end

			if predictedSequence
				~= sequence
			then
				return
			end

			clearPrediction(
				true
			)
		end
	)

	return true
end

-- =========================================================
-- RECONCILE
-- =========================================================

function PredictionController.reconcile(
	authoritative: CharacterState
)
	-- Nenhuma prediction ativa.
	if predictedState == nil then
		notify(
			authoritative
		)

		return
	end

	-- =====================================================
	-- CRITICAL SERVER STATE
	-- =====================================================

	if authoritative.status
		== "Dead"
	then
		clearPrediction(
			false
		)

		notify(
			authoritative
		)

		return
	end

	if authoritative.duelId == nil then
		clearPrediction(
			false
		)

		notify(
			authoritative
		)

		return
	end

	if authoritative.stance
		== "Inactive"
	then
		clearPrediction(
			false
		)

		notify(
			authoritative
		)

		return
	end

	-- =====================================================
	-- MATCH PREDICTION
	-- =====================================================

	local mode:
		PredictionMode? =
		predictionMode

	local sequence =
		predictedSequence

	local matched = false

	-- -----------------------------------------------
	-- ACTION
	-- -----------------------------------------------

	if mode == MODE_ACTION
		and sequence ~= nil
	then
		matched =
			authoritative.actionSequence
			== sequence

		-- -----------------------------------------------
		-- JUMP
		-- -----------------------------------------------

	elseif mode == MODE_JUMP then
		matched =
			authoritative.air == "Jumping"
			or authoritative.air == "Falling"
			or authoritative.air == "Landing"

		-- -----------------------------------------------
		-- AIR ATTACK
		-- -----------------------------------------------

	elseif mode == MODE_AIR_ATTACK then
		matched =
			authoritative.airAttackArmed
	end

	-- =====================================================
	-- CONFIRMED
	-- =====================================================

	if matched then
		clearPrediction(
			false
		)

		notify(
			authoritative
		)
	end
end

-- =========================================================
-- REJECT
-- =========================================================

function PredictionController.reject(
	sequence: number
)
	if predictedSequence
		~= sequence
	then
		return
	end

	clearPrediction(
		true
	)
end

-- =========================================================
-- SUBSCRIBE
-- =========================================================

function PredictionController.subscribe(
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

		listener.connected =
			false
	end
end

-- =========================================================
-- CLEAR
-- =========================================================

function PredictionController.clear()
	clearPrediction(
		true
	)
end

return PredictionController