--!strict

local Protocol =
	require(
		game:GetService("ReplicatedStorage")
		.Shared.Network.Protocol
	)

local EventBus =
	require(
		script.Parent.Parent.Events.EventBus
	)

local EventTypes =
	require(
		script.Parent.Parent.Events.EventTypes
	)

local DuelService =
	require(
		script.Parent.Parent.Duels.DuelService
	)

local RateLimiter =
	require(script.Parent.RateLimiter)

type ClientIntent =
	Protocol.ClientIntent

type Bus =
	EventBus.Bus

type Disconnect =
	EventBus.Disconnect

type DuelApi =
	DuelService.Service

type Limiter =
	RateLimiter.Limiter

local InputGateway = {}

export type Service = {
	start: () -> (),
	stop: () -> (),

	receive: (
		player: Player,
		payload: any
	) -> boolean,

	getAcceptedCount: () -> number,
	getRejectedCount: () -> number,
}

function InputGateway.new(
	bus: Bus,
	duels: DuelApi,
	limiter: Limiter,
	intentRemote: RemoteEvent
): Service
	local started = false

	local remoteConnection:
		RBXScriptConnection? = nil

	local removedDisconnect:
		Disconnect? = nil

	local lastSequenceByUser:
		{[number]: number} = {}

	local acceptedCount = 0
	local rejectedCount = 0

	-- =====================================================
	-- EXTRACT SEQUENCE
	-- =====================================================

	local function extractSequence(
		payload: any
	): number?
		if type(payload) ~= "table" then
			return nil
		end

		local value =
			payload.sequence

		if type(value) ~= "number" then
			return nil
		end

		if value < 0
			or value % 1 ~= 0
		then
			return nil
		end

		return value
	end

	-- =====================================================
	-- REJECT
	-- =====================================================

	local function reject(
		player: Player,
		reason: string,
		duelId: string?,
		sequence: number?
	): boolean
		rejectedCount += 1

		bus.publish(
			EventTypes.create(
				"PlayerIntentRejected",
				{
					duelId = duelId,

					actorUserId =
						player.UserId,

					data = {
						reason = reason,
						sequence = sequence,
					},
				}
			)
		)

		return false
	end

	-- =====================================================
	-- RECEIVE
	-- =====================================================

	local function receive(
		player: Player,
		payload: any
	): boolean
		local userId =
			player.UserId

		local rawSequence =
			extractSequence(
				payload
			)

		if not limiter.allow(
			userId,
			1
		) then
			return reject(
				player,
				"RateLimited",
				nil,
				rawSequence
			)
		end

		if not Protocol.isClientIntent(
			payload
		) then
			return reject(
				player,
				"MalformedIntent",
				nil,
				rawSequence
			)
		end

		local intent =
			payload :: ClientIntent

		local previousSequence =
			lastSequenceByUser[userId]

		if previousSequence ~= nil
			and intent.sequence
			<= previousSequence
		then
			return reject(
				player,
				"SequenceOutOfOrder",
				nil,
				intent.sequence
			)
		end

		lastSequenceByUser[userId] =
			intent.sequence

		-- Stance é uma intenção de personagem, não de duelo.
		-- Portanto precisa funcionar mesmo com duelId == nil.
		if intent.kind == "Stance" then
			acceptedCount += 1

			bus.publish(
				EventTypes.create(
					"StanceToggleRequested",
					{
						actorUserId = userId,

						data = {
							sequence =
								intent.sequence,
						},
					}
				)
			)

			return true
		end

		local duel =
			duels.getDuelForUser(
				userId
			)

		if duel == nil then
			return reject(
				player,
				"NotInDuel",
				nil,
				intent.sequence
			)
		end

		acceptedCount += 1

		bus.publish(
			EventTypes.create(
				"PlayerIntentReceived",
				{
					duelId = duel.id,
					actorUserId = userId,

					data = {
						sequence =
							intent.sequence,

						kind =
							intent.kind,
					},
				}
			)
		)

		return true
	end

	-- =====================================================
	-- START
	-- =====================================================

	local function start()
		if started then
			return
		end

		started = true

		remoteConnection =
			intentRemote.OnServerEvent:Connect(
				function(
					player: Player,
					payload: any
				)
					receive(
						player,
						payload
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

					lastSequenceByUser[userId] =
						nil

					limiter.reset(
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

		if remoteConnection ~= nil then
			remoteConnection:Disconnect()
			remoteConnection = nil
		end

		if removedDisconnect ~= nil then
			removedDisconnect()
			removedDisconnect = nil
		end

		table.clear(
			lastSequenceByUser
		)

		limiter.clear()
	end

	return {
		start = start,
		stop = stop,

		receive = receive,

		getAcceptedCount =
			function()
				return acceptedCount
			end,

		getRejectedCount =
			function()
				return rejectedCount
			end,
	}
end

return InputGateway
