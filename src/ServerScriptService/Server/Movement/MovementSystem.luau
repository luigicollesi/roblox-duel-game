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

type Store =
	CharacterStateStore.Store

type CharacterApi =
	CharacterService.Service

type Bus =
	EventBus.Bus

type Disconnect =
	EventBus.Disconnect

local MovementSystem = {}

type CharacterRuntime = {
	baseWalkSpeed: number,

	runningConnection: RBXScriptConnection?,
}

export type Service = {
	start: () -> (),
	stop: () -> (),

	refresh: (
		userId: number
	) -> (),
}

-- =========================================================
-- FACTORY
-- =========================================================

function MovementSystem.new(
	store: Store,
	bus: Bus,
	characters: CharacterApi
): Service

	local runtimeByUser:
		{[number]: CharacterRuntime} = {}

	local started = false

	local spawnedDisconnect:
		Disconnect? = nil

	local despawningDisconnect:
		Disconnect? = nil

	local stateChangedDisconnect:
		Disconnect? = nil

	-- =====================================================
	-- WALK SPEED
	-- =====================================================

	local function calculateWalkSpeed(
		userId: number,
		baseWalkSpeed: number
	): number

		local state =
			store.get(userId)

		if state == nil then
			return baseWalkSpeed
		end

		if state.movementLocked then
			return MovementConfig.LOCKED_WALK_SPEED
		end

		if state.stance == "Active" then
			return baseWalkSpeed
				* MovementConfig.STANCE_WALK_SPEED_MULTIPLIER
		end

		return baseWalkSpeed
	end

	local function refresh(
		userId: number
	)
		local runtime =
			runtimeByUser[userId]

		if runtime == nil then
			return
		end

		local humanoid =
			characters.getHumanoid(userId)

		if humanoid == nil then
			return
		end

		local targetSpeed =
			calculateWalkSpeed(
				userId,
				runtime.baseWalkSpeed
			)

		if math.abs(
			humanoid.WalkSpeed - targetSpeed
			) > 0.001 then
			humanoid.WalkSpeed =
				targetSpeed
		end
	end

	-- =====================================================
	-- LOCOMOTION
	-- =====================================================

	local function updateLocomotion(
		userId: number,
		speed: number
	)
		local state =
			store.get(userId)

		if state == nil then
			return
		end

		local shouldWalk =
			speed
			> MovementConfig.WALKING_SPEED_THRESHOLD
			and not state.movementLocked
			and state.air == "Grounded"

		local desired =
			if shouldWalk
			then "Walking"
			else "Idle"

		if state.locomotion == desired then
			return
		end

		store.update(
			userId,
			"LocomotionChanged",
			function(nextState)
				nextState.locomotion =
					desired
			end
		)
	end

	-- =====================================================
	-- SPAWN
	-- =====================================================

	local function onSpawned(
		userId: number
	)
		local humanoid =
			characters.getHumanoid(userId)

		if humanoid == nil then
			return
		end

		local previous =
			runtimeByUser[userId]

		if previous ~= nil
			and previous.runningConnection ~= nil
		then
			previous.runningConnection:Disconnect()
		end

		local runtime: CharacterRuntime = {
			baseWalkSpeed =
				humanoid.WalkSpeed,

			runningConnection = nil,
		}

		runtimeByUser[userId] = runtime

		runtime.runningConnection =
			humanoid.Running:Connect(
				function(speed: number)
					updateLocomotion(
						userId,
						speed
					)
				end
			)

		refresh(userId)
	end

	-- =====================================================
	-- DESPAWN
	-- =====================================================

	local function onDespawning(
		userId: number
	)
		local runtime =
			runtimeByUser[userId]

		if runtime == nil then
			return
		end

		if runtime.runningConnection ~= nil then
			runtime.runningConnection:Disconnect()
		end

		runtimeByUser[userId] = nil
	end

	-- =====================================================
	-- START
	-- =====================================================

	local function start()
		if started then
			return
		end

		started = true

		spawnedDisconnect =
			bus.subscribe(
				"CharacterSpawned",
				function(event)
					local userId =
						event.actorUserId

					if userId ~= nil then
						onSpawned(userId)
					end
				end
			)

		despawningDisconnect =
			bus.subscribe(
				"CharacterDespawning",
				function(event)
					local userId =
						event.actorUserId

					if userId ~= nil then
						onDespawning(userId)
					end
				end
			)

		stateChangedDisconnect =
			bus.subscribe(
				"CharacterStateChanged",
				function(event)
					local userId =
						event.actorUserId

					if userId ~= nil then
						refresh(userId)
					end
				end
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

		if spawnedDisconnect ~= nil then
			spawnedDisconnect()
			spawnedDisconnect = nil
		end

		if despawningDisconnect ~= nil then
			despawningDisconnect()
			despawningDisconnect = nil
		end

		if stateChangedDisconnect ~= nil then
			stateChangedDisconnect()
			stateChangedDisconnect = nil
		end

		for _, runtime in pairs(
			runtimeByUser
			) do
			if runtime.runningConnection ~= nil then
				runtime.runningConnection:Disconnect()
			end
		end

		table.clear(runtimeByUser)
	end

	return {
		start = start,
		stop = stop,

		refresh = refresh,
	}
end

return MovementSystem