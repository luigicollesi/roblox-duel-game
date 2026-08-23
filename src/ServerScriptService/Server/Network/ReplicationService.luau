--!strict

local Players =
	game:GetService("Players")

local CharacterStateStore =
	require(
		script.Parent.Parent.Character.CharacterStateStore
	)

local EventBus =
	require(
		script.Parent.Parent.Events.EventBus
	)

type Store =
	CharacterStateStore.Store

type Bus =
	EventBus.Bus

type Disconnect =
	EventBus.Disconnect

local ReplicationService = {}

export type Service = {
	start: () -> (),
	stop: () -> (),

	sendSnapshot: (
		userId: number
	) -> boolean,
}

function ReplicationService.new(
	store: Store,
	bus: Bus,
	stateRemote: RemoteEvent,
	effectRemote: UnreliableRemoteEvent
): Service

	local started = false

	local disconnects:
		{Disconnect} = {}

	local syncConnection:
		RBXScriptConnection? = nil

	local lastSyncByUser:
		{[number]: number} = {}

	-- =====================================================
	-- FIND PLAYER BY NUMERIC USER ID
	-- =====================================================

	local function getPlayer(
		userId: number
	): Player?

		for _, player in ipairs(
			Players:GetPlayers()
			) do
			if player.UserId
				== userId
			then
				return player
			end
		end

		return nil
	end

	-- =====================================================
	-- SNAPSHOT
	-- =====================================================

	local function sendSnapshot(
		userId: number
	): boolean

		local player =
			getPlayer(
				userId
			)

		if player == nil then
			return false
		end

		local state =
			store.get(
				userId
			)

		if state == nil then
			return false
		end

		stateRemote:FireClient(
			player,
			{
				type =
					"StateSnapshot",

				userId =
					userId,

				state =
					state,
			}
		)

		return true
	end

	-- =====================================================
	-- STATE
	-- =====================================================

	local function replicateState(
		event: any
	)
		local userId =
			event.actorUserId

		if type(userId)
			~= "number"
		then
			return
		end

		sendSnapshot(
			userId
		)
	end

	-- =====================================================
	-- REJECTION
	-- =====================================================

	local function replicateRejection(
		event: any
	)
		local userId =
			event.actorUserId

		if type(userId)
			~= "number"
		then
			return
		end

		if type(event.data)
			~= "table"
		then
			return
		end

		local sequence =
			event.data.sequence

		local reason =
			event.data.reason

		if type(sequence)
			~= "number"
		then
			return
		end

		if type(reason)
			~= "string"
		then
			return
		end

		local player =
			getPlayer(
				userId
			)

		if player == nil then
			return
		end

		stateRemote:FireClient(
			player,
			{
				type =
					"IntentRejected",

				sequence =
					sequence,

				reason =
					reason,
			}
		)
	end

	-- =====================================================
	-- EFFECT TO PLAYER
	-- =====================================================

	local function sendEffectToUser(
		userId: number,
		payload: any
	)
		local player =
			getPlayer(
				userId
			)

		if player == nil then
			return
		end

		effectRemote:FireClient(
			player,
			payload
		)
	end

	-- =====================================================
	-- EFFECT
	-- =====================================================

	local function replicateEffect(
		event: any
	)
		local payload = {
			eventName =
				event.name,

			tick =
				event.tick,

			duelId =
				event.duelId,

			actorUserId =
				event.actorUserId,

			targetUserId =
				event.targetUserId,

			data =
				event.data,
		}

		local actorUserId =
			event.actorUserId

		local targetUserId =
			event.targetUserId

		if type(actorUserId)
			== "number"
		then
			sendEffectToUser(
				actorUserId,
				payload
			)
		end

		if type(targetUserId)
			== "number"
			and targetUserId
			~= actorUserId
		then
			sendEffectToUser(
				targetUserId,
				payload
			)
		end
	end

	-- =====================================================
	-- SUBSCRIPTION
	-- =====================================================

	local function addSubscription(
		eventName: any,
		handler: (any) -> ()
	)
		local disconnect =
			bus.subscribe(
				eventName,
				handler
			)

		table.insert(
			disconnects,
			disconnect
		)
	end

	-- =====================================================
	-- START
	-- =====================================================

	local function start()
		if started then
			return
		end

		started = true

		addSubscription(
			"CharacterStateCreated",
			replicateState
		)

		addSubscription(
			"CharacterStateChanged",
			replicateState
		)

		addSubscription(
			"PlayerIntentRejected",
			replicateRejection
		)

		addSubscription(
			"CombatActionRejected",
			replicateRejection
		)

		addSubscription(
			"CombatResolved",
			replicateEffect
		)

		addSubscription(
			"DashStarted",
			replicateEffect
		)

		addSubscription(
			"AttackStarted",
			replicateEffect
		)

		addSubscription(
			"HitstunStarted",
			replicateEffect
		)

		addSubscription(
			"KnockbackApplied",
			replicateEffect
		)

		addSubscription(
			"CharacterKilled",
			replicateEffect
		)

		syncConnection =
			stateRemote.OnServerEvent:Connect(
				function(
					player: Player,
					request: any
				)
					if request
						~= "RequestStateSync"
					then
						return
					end

					local now =
						os.clock()

					local userId: number =
						player.UserId

					local last =
						lastSyncByUser[
						userId
						]

					-- Limita pedidos manuais de sync.
					if last ~= nil
						and now - last
						< 0.25
					then
						return
					end

					lastSyncByUser[
						userId
						] = now

					sendSnapshot(
						userId
					)
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

		for _, disconnect in ipairs(
			disconnects
			) do
			disconnect()
		end

		table.clear(
			disconnects
		)

		if syncConnection ~= nil then
			syncConnection:Disconnect()
			syncConnection = nil
		end

		table.clear(
			lastSyncByUser
		)
	end

	return {
		start = start,
		stop = stop,

		sendSnapshot =
			sendSnapshot,
	}
end

return ReplicationService