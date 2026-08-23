--!strict

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Shared =
	ReplicatedStorage.Shared

local MovementConfig =
	require(Shared.Movement.MovementConfig)

local CharacterStateStore =
	require(
		script.Parent.Parent.Character.CharacterStateStore
	)

local CharacterService =
	require(
		script.Parent.Parent.Character.CharacterService
	)

local EventBus =
	require(
		script.Parent.Parent.Events.EventBus
	)

local EventTypes =
	require(
		script.Parent.Parent.Events.EventTypes
	)

type Store =
	CharacterStateStore.Store

type CharacterApi =
	CharacterService.Service

type Bus =
	EventBus.Bus

local AirSystem = {}

-- =========================================================
-- TYPES
-- =========================================================

type AirRuntime = {
	armedSequence: number?,
	normalLandingEndTick: number?,
}

export type LandingAttackRequest = {
	userId: number,
	sequence: number,
}

export type System = {
	requestJump: (
		userId: number,
		sequence: number,
		currentTick: number
	) -> (boolean, string?),

	armLandingAttack: (
		userId: number,
		sequence: number,
		currentTick: number
	) -> (boolean, string?),

	disarmLandingAttack: (
		userId: number
	) -> boolean,

	step: (
		currentTick: number
	) -> {LandingAttackRequest},

	clear: (
		userId: number
	) -> (),
}

-- =========================================================
-- FACTORY
-- =========================================================

function AirSystem.new(
	store: Store,
	bus: Bus,
	characters: CharacterApi,
	duelId: string,
	fighterAUserId: number,
	fighterBUserId: number
): System

	local runtimeByUser:
		{[number]: AirRuntime} = {}

	runtimeByUser[fighterAUserId] = {
		armedSequence = nil,
		normalLandingEndTick = nil,
	}

	runtimeByUser[fighterBUserId] = {
		armedSequence = nil,
		normalLandingEndTick = nil,
	}

	-- =====================================================
	-- EVENT
	-- =====================================================

	local function publishAirState(
		userId: number,
		airState: string,
		tick: number
	)
		bus.publish(
			EventTypes.create(
				"AirStateChanged",
				{
					tick = tick,
					duelId = duelId,

					actorUserId = userId,

					data = {
						air = airState,
					},
				}
			)
		)
	end

	-- =====================================================
	-- SET AIR STATE
	-- =====================================================

	local function setAirState(
		userId: number,
		airState:
			"Grounded"
		| "Jumping"
		| "Falling"
		| "Landing",
		tick: number
	)
		local current =
			store.get(userId)

		if current == nil then
			return
		end

		if current.air == airState then
			return
		end

		store.update(
			userId,
			"AirStateChanged",
			function(state)
				state.air = airState

				if airState ~= "Grounded" then
					state.locomotion = "Idle"
				end
			end
		)

		publishAirState(
			userId,
			airState,
			tick
		)
	end

	-- =====================================================
	-- JUMP
	-- =====================================================

	local function requestJump(
		userId: number,
		_sequence: number,
		currentTick: number
	): (boolean, string?)

		local state =
			store.get(userId)

		if state == nil then
			return false, "MissingState"
		end

		if state.status ~= "Normal" then
			return false, "InvalidStatus"
		end

		if state.stance ~= "Active" then
			return false, "StanceNotActive"
		end

		if state.air ~= "Grounded" then
			return false, "NotGrounded"
		end

		if state.action ~= nil then
			return false, "ActionActive"
		end

		if state.movementLocked then
			return false, "MovementLocked"
		end

		local humanoid =
			characters.getHumanoid(userId)

		if humanoid == nil then
			return false, "MissingHumanoid"
		end

		if humanoid.Health <= 0 then
			return false, "Dead"
		end

		if not humanoid:GetStateEnabled(
			Enum.HumanoidStateType.Jumping
			) then
			return false, "JumpDisabled"
		end

		if humanoid.FloorMaterial
			== Enum.Material.Air
		then
			return false, "NotGrounded"
		end

		humanoid.Jump = true

		setAirState(
			userId,
			"Jumping",
			currentTick
		)

		bus.publish(
			EventTypes.create(
				"JumpStarted",
				{
					tick = currentTick,
					duelId = duelId,

					actorUserId = userId,
				}
			)
		)

		return true, nil
	end

	-- =====================================================
	-- ARM LAND ATTACK
	-- =====================================================

	local function armLandingAttack(
		userId: number,
		sequence: number,
		currentTick: number
	): (boolean, string?)

		local state =
			store.get(userId)

		if state == nil then
			return false, "MissingState"
		end

		if state.status ~= "Normal" then
			return false, "InvalidStatus"
		end

		if state.air ~= "Jumping"
			and state.air ~= "Falling"
		then
			return false, "NotAirborne"
		end

		local runtime =
			runtimeByUser[userId]

		if runtime == nil then
			return false, "MissingAirRuntime"
		end

		-- Um único ataque de aterrissagem fica armado.
		-- O clique mais recente atualiza a sequence.
		runtime.armedSequence =
			sequence

		if not state.airAttackArmed then
			store.update(
				userId,
				"LandAttackArmed",
				function(nextState)
					nextState.airAttackArmed = true
				end
			)
		end

		bus.publish(
			EventTypes.create(
				"LandAttackArmed",
				{
					tick = currentTick,
					duelId = duelId,

					actorUserId = userId,

					data = {
						sequence = sequence,
					},
				}
			)
		)

		return true, nil
	end

	-- =====================================================
	-- DISARM LAND ATTACK
	-- =====================================================

	local function disarmLandingAttack(
		userId: number
	): boolean

		local runtime =
			runtimeByUser[userId]

		if runtime == nil then
			return false
		end

		local hadArmedAttack =
			runtime.armedSequence ~= nil

		runtime.armedSequence = nil

		local state =
			store.get(userId)

		if state ~= nil
			and state.airAttackArmed
		then
			store.update(
				userId,
				"LandAttackDisarmed",
				function(nextState)
					nextState.airAttackArmed = false
				end
			)

			hadArmedAttack = true
		end

		return hadArmedAttack
	end

	-- =====================================================
	-- NORMAL LANDING
	-- =====================================================

	local function startNormalLanding(
		userId: number,
		runtime: AirRuntime,
		currentTick: number
	)
		runtime.armedSequence = nil

		runtime.normalLandingEndTick =
			currentTick
			+ MovementConfig.NORMAL_LANDING_TICKS

		store.update(
			userId,
			"NormalLandingStarted",
			function(state)
				state.air = "Landing"

				state.airAttackArmed = false
				state.locomotion = "Idle"
			end
		)

		bus.publish(
			EventTypes.create(
				"NormalLandingStarted",
				{
					tick = currentTick,
					duelId = duelId,

					actorUserId = userId,
				}
			)
		)
	end

	-- =====================================================
	-- OFFENSIVE LANDING
	-- =====================================================

	local function createLandingAttack(
		userId: number,
		runtime: AirRuntime,
		currentTick: number
	): LandingAttackRequest?

		local sequence =
			runtime.armedSequence

		if sequence == nil then
			return nil
		end

		runtime.armedSequence = nil
		runtime.normalLandingEndTick = nil

		store.update(
			userId,
			"LandAttackLanding",
			function(state)
				state.air = "Grounded"

				state.airAttackArmed = false
				state.locomotion = "Idle"
			end
		)

		publishAirState(
			userId,
			"Grounded",
			currentTick
		)

		return {
			userId = userId,
			sequence = sequence,
		}
	end

	-- =====================================================
	-- STEP USER
	-- =====================================================

	local function stepUser(
		userId: number,
		currentTick: number
	): LandingAttackRequest?

		local runtime =
			runtimeByUser[userId]

		if runtime == nil then
			return nil
		end

		local state =
			store.get(userId)

		if state == nil then
			return nil
		end

		local humanoid =
			characters.getHumanoid(userId)

		if humanoid == nil then
			return nil
		end

		-- -----------------------------------------------
		-- NORMAL LANDING TIMER
		-- -----------------------------------------------

		if state.air == "Landing" then
			local endTick =
				runtime.normalLandingEndTick

			if endTick ~= nil
				and currentTick >= endTick
			then
				runtime.normalLandingEndTick = nil

				setAirState(
					userId,
					"Grounded",
					currentTick
				)
			end

			return nil
		end

		-- -----------------------------------------------
		-- PHYSICAL STATE
		-- -----------------------------------------------

		local physicalState =
			humanoid:GetState()

		if physicalState
			== Enum.HumanoidStateType.Jumping
		then
			setAirState(
				userId,
				"Jumping",
				currentTick
			)

			return nil
		end

		if physicalState
			== Enum.HumanoidStateType.Freefall
		then
			setAirState(
				userId,
				"Falling",
				currentTick
			)

			return nil
		end

		local physicallyGrounded =
			humanoid.FloorMaterial
			~= Enum.Material.Air

		if not physicallyGrounded then
			if state.air == "Grounded" then
				setAirState(
					userId,
					"Falling",
					currentTick
				)
			end

			return nil
		end

		-- -----------------------------------------------
		-- LANDING
		-- -----------------------------------------------

		if state.air == "Jumping"
			or state.air == "Falling"
		then
			if state.airAttackArmed then
				local landingAttack =
					createLandingAttack(
						userId,
						runtime,
						currentTick
					)

				if landingAttack ~= nil then
					return landingAttack
				end
			end

			startNormalLanding(
				userId,
				runtime,
				currentTick
			)
		end

		return nil
	end

	-- =====================================================
	-- STEP
	-- =====================================================

	local function step(
		currentTick: number
	): {LandingAttackRequest}

		local requests:
			{LandingAttackRequest} = {}

		local requestA =
			stepUser(
				fighterAUserId,
				currentTick
			)

		if requestA ~= nil then
			table.insert(
				requests,
				requestA
			)
		end

		local requestB =
			stepUser(
				fighterBUserId,
				currentTick
			)

		if requestB ~= nil then
			table.insert(
				requests,
				requestB
			)
		end

		return requests
	end

	-- =====================================================
	-- CLEAR
	-- =====================================================

	local function clear(
		userId: number
	)
		runtimeByUser[userId] = nil
	end

	return {
		requestJump = requestJump,

		armLandingAttack =
			armLandingAttack,

		disarmLandingAttack =
			disarmLandingAttack,

		step = step,

		clear = clear,
	}
end

return AirSystem