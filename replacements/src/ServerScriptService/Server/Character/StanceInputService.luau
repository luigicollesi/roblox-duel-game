--!strict

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local CombatConfig =
	require(
		ReplicatedStorage.Shared.Combat.CombatConfig
	)

local CharacterStateStore =
	require(script.Parent.CharacterStateStore)

local StanceService =
	require(script.Parent.StanceService)

local EventBus =
	require(
		script.Parent.Parent.Events.EventBus
	)

type Store =
	CharacterStateStore.Store

type StanceApi =
	StanceService.Service

type Bus =
	EventBus.Bus

type Disconnect =
	EventBus.Disconnect

local StanceInputService = {}

export type Service = {
	start: () -> (),
	stop: () -> (),
}

function StanceInputService.new(
	store: Store,
	bus: Bus,
	stance: StanceApi
): Service
	local started = false

	local stanceDisconnect:
		Disconnect? = nil

	local removedDisconnect:
		Disconnect? = nil

	-- Token por usuário para invalidar uma ativação agendada
	-- caso o jogador aperte 1 novamente durante o Start.
	local activationTokenByUser:
		{[number]: number} = {}

	local function invalidateActivation(
		userId: number
	)
		activationTokenByUser[userId] =
			(activationTokenByUser[userId] or 0)
			+ 1
	end

	local function scheduleActivation(
		userId: number
	)
		invalidateActivation(
			userId
		)

		local token =
			activationTokenByUser[userId]

		local duration =
			CombatConfig.STANCE_START_TICKS
			* CombatConfig.FIXED_DT

		task.delay(
			duration,

			function()
				if activationTokenByUser[userId]
					~= token
				then
					return
				end

				local current =
					store.get(userId)

				if current == nil then
					return
				end

				if current.stance
					~= "Starting"
				then
					return
				end

				stance.activate(
					userId
				)
			end
		)
	end

	local function toggle(
		userId: number
	)
		local current =
			store.get(userId)

		if current == nil then
			return
		end

		if current.status
			~= "Normal"
		then
			return
		end

		if current.stance
			== "Inactive"
		then
			local startedStance =
				stance.start(
					userId
				)

			if startedStance then
				scheduleActivation(
					userId
				)
			end

			return
		end

		-- Starting ou Active:
		-- segundo toque em 1 sai da stance.
		invalidateActivation(
			userId
		)

		stance.deactivate(
			userId
		)
	end

	local function start()
		if started then
			return
		end

		started = true

		stanceDisconnect =
			bus.subscribe(
				"StanceToggleRequested",
				function(event)
					local userId =
						event.actorUserId

					if userId == nil then
						return
					end

					toggle(
						userId
					)
				end
			)

		removedDisconnect =
			bus.subscribe(
				"CharacterStateRemoved",
				function(event)
					local userId =
						event.actorUserId

					if userId == nil then
						return
					end

					activationTokenByUser[userId] =
						nil
				end
			)
	end

	local function stop()
		if not started then
			return
		end

		started = false

		if stanceDisconnect ~= nil then
			stanceDisconnect()
			stanceDisconnect = nil
		end

		if removedDisconnect ~= nil then
			removedDisconnect()
			removedDisconnect = nil
		end

		table.clear(
			activationTokenByUser
		)
	end

	return {
		start = start,
		stop = stop,
	}
end

return StanceInputService
