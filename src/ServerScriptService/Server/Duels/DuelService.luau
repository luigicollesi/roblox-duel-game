--!strict

local Players =
	game:GetService("Players")

local RunService =
	game:GetService("RunService")

local CharacterStateStore =
	require(
		script.Parent.Parent.Character.CharacterStateStore
	)

local CharacterService =
	require(
		script.Parent.Parent.Character.CharacterService
	)

local StanceService =
	require(
		script.Parent.Parent.Character.StanceService
	)

local EventBus =
	require(
		script.Parent.Parent.Events.EventBus
	)

local EventTypes =
	require(
		script.Parent.Parent.Events.EventTypes
	)

local DuelState =
	require(script.Parent.DuelState)

local DuelHistory =
	require(script.Parent.DuelHistory)

type Store =
	CharacterStateStore.Store

type CharacterServiceApi =
	CharacterService.Service

type StanceServiceApi =
	StanceService.Service

type Bus =
	EventBus.Bus

type Disconnect =
	EventBus.Disconnect

type Duel =
	DuelState.Duel

type DuelEndReason =
	DuelState.DuelEndReason

type History =
	DuelHistory.History

type HistoryEntry =
	DuelHistory.HistoryEntry

local DuelService = {}

-- =========================================================
-- TEMPORARY TUNING
-- =========================================================

-- Entram em duelo quando chegam a esta distância.
local START_DISTANCE = 14

-- Histerese:
-- o duelo só termina por distância quando passam daqui.
local BREAK_DISTANCE = 24

-- Matchmaking não precisa rodar 60 vezes por segundo.
local SCAN_INTERVAL = 0.15

-- Mantém alguns duelos terminados para debug.
local MAX_RETAINED_DUELS = 32

local HISTORY_CAPACITY = 256

-- =========================================================
-- TYPES
-- =========================================================

type DuelRecord = {
	state: Duel,
	history: History,
}

type CandidatePair = {
	aUserId: number,
	bUserId: number,

	distance: number,
}

type EndRequest = {
	duelId: string,
	reason: DuelEndReason,
}

export type Service = {
	start: () -> (),
	stop: () -> (),

	scanNow: () -> (),

	getDuelForUser: (
		userId: number
	) -> Duel?,

	getById: (
		duelId: string
	) -> Duel?,

	getOpponentUserId: (
		userId: number
	) -> number?,

	getHistory: (
		duelId: string
	) -> {HistoryEntry}?,

	isInDuel: (
		userId: number
	) -> boolean,

	activeCount: () -> number,
}

-- =========================================================
-- FACTORY
-- =========================================================

function DuelService.new(
	store: Store,
	bus: Bus,
	characters: CharacterServiceApi,
	stance: StanceServiceApi
): Service

	local recordsById: {[string]: DuelRecord} = {}

	local activeByUser: {[number]: string} = {}

	local endedOrder: {string} = {}

	local nextDuelNumber = 0

	local started = false

	local heartbeatConnection: RBXScriptConnection? = nil

	local characterDespawningDisconnect: Disconnect? = nil
	local stateRemovedDisconnect: Disconnect? = nil

	local scanAccumulator = 0

	-- =====================================================
	-- CHARACTER POSITION
	-- =====================================================

	local function getRootPart(
		userId: number
	): BasePart?

		local character =
			characters.getCharacter(userId)

		if character == nil then
			return nil
		end

		local instance =
			character:FindFirstChild(
				"HumanoidRootPart"
			)

		if instance == nil then
			return nil
		end

		if not instance:IsA("BasePart") then
			return nil
		end

		return instance
	end

	local function getDistance(
		aUserId: number,
		bUserId: number
	): number?

		local rootA =
			getRootPart(aUserId)

		local rootB =
			getRootPart(bUserId)

		if rootA == nil or rootB == nil then
			return nil
		end

		return (
			rootA.Position
			- rootB.Position
		).Magnitude
	end

	-- =====================================================
	-- ELIGIBILITY
	-- =====================================================

	local function isEligible(
		userId: number
	): boolean

		if activeByUser[userId] ~= nil then
			return false
		end

		if not characters.isCharacterAlive(userId) then
			return false
		end

		if getRootPart(userId) == nil then
			return false
		end

		local state =
			store.get(userId)

		if state == nil then
			return false
		end

		if state.status ~= "Normal" then
			return false
		end

		if state.duelId ~= nil then
			return false
		end

		if state.stance ~= "Inactive" then
			return false
		end

		if state.action ~= nil then
			return false
		end

		if state.air ~= "Grounded" then
			return false
		end

		if state.movementLocked then
			return false
		end

		return true
	end

	-- =====================================================
	-- RETENTION
	-- =====================================================

	local function retainEnded(
		duelId: string
	)
		table.insert(
			endedOrder,
			duelId
		)

		while #endedOrder > MAX_RETAINED_DUELS do
			local oldestId =
				table.remove(
					endedOrder,
					1
				)

			if oldestId ~= nil then
				local record =
					recordsById[oldestId]

				if record ~= nil
					and record.state.status == "Ended"
				then
					recordsById[oldestId] = nil
				end
			end
		end
	end

	-- =====================================================
	-- CLEAR CHARACTER DUEL
	-- =====================================================

	local function clearCharacterDuel(
		userId: number,
		duelId: string
	)
		local state =
			store.get(userId)

		if state == nil then
			return
		end

		if state.duelId ~= duelId then
			return
		end

		store.update(
			userId,
			"DuelEnded",
			function(nextState)
				nextState.duelId = nil
			end
		)
	end

	-- =====================================================
	-- END DUEL
	-- =====================================================

	local function endDuelById(
		duelId: string,
		reason: DuelEndReason
	): boolean

		local record =
			recordsById[duelId]

		if record == nil then
			return false
		end

		if record.state.status ~= "Active" then
			return false
		end

		local finished =
			DuelState.finish(
				record.state,
				reason
			)

		record.state = finished

		local fighterA =
			finished.fighterAUserId

		local fighterB =
			finished.fighterBUserId

		if activeByUser[fighterA] == duelId then
			activeByUser[fighterA] = nil
		end

		if activeByUser[fighterB] == duelId then
			activeByUser[fighterB] = nil
		end

		clearCharacterDuel(
			fighterA,
			duelId
		)

		clearCharacterDuel(
			fighterB,
			duelId
		)

		local stateA =
			store.get(fighterA)

		if stateA ~= nil
			and stateA.stance ~= "Inactive"
		then
			stance.deactivate(fighterA)
		end

		local stateB =
			store.get(fighterB)

		if stateB ~= nil
			and stateB.stance ~= "Inactive"
		then
			stance.deactivate(fighterB)
		end

		record.history.add(
			"DuelEnded",
			nil,
			{
				reason = reason,
			}
		)

		bus.publish(
			EventTypes.create(
				"DuelEnded",
				{
					duelId = duelId,

					actorUserId = fighterA,
					targetUserId = fighterB,

					data = {
						reason = reason,
					},
				}
			)
		)

		retainEnded(duelId)

		return true
	end

	-- =====================================================
	-- CREATE DUEL
	-- =====================================================

	local function createDuel(
		aUserId: number,
		bUserId: number,
		distance: number
	): Duel?

		if not isEligible(aUserId) then
			return nil
		end

		if not isEligible(bUserId) then
			return nil
		end

		nextDuelNumber += 1

		local duelId =
			`duel-{nextDuelNumber}`

		local duel =
			DuelState.new(
				duelId,
				aUserId,
				bUserId
			)

		local history =
			DuelHistory.new(
				HISTORY_CAPACITY
			)

		local record: DuelRecord = {
			state = duel,
			history = history,
		}

		recordsById[duelId] = record

		activeByUser[aUserId] = duelId
		activeByUser[bUserId] = duelId

		store.update(
			aUserId,
			"DuelCreated",
			function(state)
				state.duelId = duelId
			end
		)

		store.update(
			bUserId,
			"DuelCreated",
			function(state)
				state.duelId = duelId
			end
		)

		history.add(
			"DuelCreated",
			nil,
			{
				fighterAUserId = aUserId,
				fighterBUserId = bUserId,

				distance = distance,
			}
		)

		local stanceAStarted =
			stance.start(aUserId)

		local stanceBStarted =
			stance.start(bUserId)

		if not stanceAStarted
			or not stanceBStarted
		then
			endDuelById(
				duelId,
				"InvalidState"
			)

			return nil
		end

		bus.publish(
			EventTypes.create(
				"DuelCreated",
				{
					duelId = duelId,

					actorUserId = aUserId,
					targetUserId = bUserId,

					data = {
						distance = distance,
					},
				}
			)
		)

		return DuelState.clone(duel)
	end

	-- =====================================================
	-- ACTIVE DUEL VALIDATION
	-- =====================================================

	local function getEndReason(
		duel: Duel
	): DuelEndReason?

		local aUserId =
			duel.fighterAUserId

		local bUserId =
			duel.fighterBUserId

		if characters.getPlayer(aUserId) == nil
			or characters.getPlayer(bUserId) == nil
		then
			return "PlayerLeft"
		end

		local stateA =
			store.get(aUserId)

		local stateB =
			store.get(bUserId)

		if stateA == nil or stateB == nil then
			return "InvalidState"
		end

		if stateA.duelId ~= duel.id
			or stateB.duelId ~= duel.id
		then
			return "InvalidState"
		end

		if not characters.isCharacterAlive(aUserId)
			or not characters.isCharacterAlive(bUserId)
		then
			return "CharacterDead"
		end

		local distance =
			getDistance(
				aUserId,
				bUserId
			)

		if distance == nil then
			return "CharacterMissing"
		end

		if distance > BREAK_DISTANCE then
			return "Distance"
		end

		return nil
	end

	local function validateActiveDuels()
		local requests: {EndRequest} = {}

		for duelId, record in pairs(recordsById) do
			if record.state.status ~= "Active" then
				continue
			end

			local reason =
				getEndReason(
					record.state
				)

			if reason ~= nil then
				table.insert(
					requests,
					{
						duelId = duelId,
						reason = reason,
					}
				)
			end
		end

		for _, request in ipairs(requests) do
			endDuelById(
				request.duelId,
				request.reason
			)
		end
	end

	-- =====================================================
	-- MATCHMAKING
	-- =====================================================

	local function findCandidatePairs(): {CandidatePair}
		local eligibleUsers: {number} = {}

		for _, player in ipairs(
			Players:GetPlayers()
			) do
			if isEligible(player.UserId) then
				table.insert(
					eligibleUsers,
					player.UserId
				)
			end
		end

		local candidates: {CandidatePair} = {}

		for i = 1, #eligibleUsers - 1 do
			for j = i + 1, #eligibleUsers do
				local first =
					eligibleUsers[i]

				local second =
					eligibleUsers[j]

				local distance =
					getDistance(
						first,
						second
					)

				if distance == nil then
					continue
				end

				if distance > START_DISTANCE then
					continue
				end

				local aUserId =
					math.min(first, second)

				local bUserId =
					math.max(first, second)

				table.insert(
					candidates,
					{
						aUserId = aUserId,
						bUserId = bUserId,

						distance = distance,
					}
				)
			end
		end

		table.sort(
			candidates,
			function(
				a: CandidatePair,
				b: CandidatePair
			): boolean

				if a.distance ~= b.distance then
					return a.distance < b.distance
				end

				if a.aUserId ~= b.aUserId then
					return a.aUserId < b.aUserId
				end

				return a.bUserId < b.bUserId
			end
		)

		return candidates
	end

	local function matchAvailablePlayers()
		local candidates =
			findCandidatePairs()

		local claimed: {[number]: boolean} = {}

		for _, candidate in ipairs(candidates) do
			if claimed[candidate.aUserId] then
				continue
			end

			if claimed[candidate.bUserId] then
				continue
			end

			if not isEligible(candidate.aUserId)
				or not isEligible(candidate.bUserId)
			then
				continue
			end

			local duel =
				createDuel(
					candidate.aUserId,
					candidate.bUserId,
					candidate.distance
				)

			if duel ~= nil then
				claimed[candidate.aUserId] = true
				claimed[candidate.bUserId] = true
			end
		end
	end

	-- =====================================================
	-- SCAN
	-- =====================================================

	local function scanNow()
		validateActiveDuels()
		matchAvailablePlayers()
	end

	-- =====================================================
	-- END USER DUEL
	-- =====================================================

	local function endUserDuel(
		userId: number,
		reason: DuelEndReason
	)
		local duelId =
			activeByUser[userId]

		if duelId == nil then
			return
		end

		endDuelById(
			duelId,
			reason
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

		characterDespawningDisconnect =
			bus.subscribe(
				"CharacterDespawning",
				function(event)
					local userId =
						event.actorUserId

					if userId ~= nil then
						endUserDuel(
							userId,
							"CharacterMissing"
						)
					end
				end
			)

		stateRemovedDisconnect =
			bus.subscribe(
				"CharacterStateRemoved",
				function(event)
					local userId =
						event.actorUserId

					if userId ~= nil then
						endUserDuel(
							userId,
							"PlayerLeft"
						)
					end
				end
			)

		heartbeatConnection =
			RunService.Heartbeat:Connect(
				function(deltaTime: number)
					scanAccumulator += deltaTime

					if scanAccumulator < SCAN_INTERVAL then
						return
					end

					scanAccumulator = 0

					scanNow()
				end
			)

		scanNow()
	end

	-- =====================================================
	-- STOP
	-- =====================================================

	local function stop()
		if not started then
			return
		end

		started = false

		if heartbeatConnection ~= nil then
			heartbeatConnection:Disconnect()
			heartbeatConnection = nil
		end

		if characterDespawningDisconnect ~= nil then
			characterDespawningDisconnect()
			characterDespawningDisconnect = nil
		end

		if stateRemovedDisconnect ~= nil then
			stateRemovedDisconnect()
			stateRemovedDisconnect = nil
		end

		local activeIds: {string} = {}

		for duelId, record in pairs(recordsById) do
			if record.state.status == "Active" then
				table.insert(
					activeIds,
					duelId
				)
			end
		end

		for _, duelId in ipairs(activeIds) do
			endDuelById(
				duelId,
				"ServiceStopped"
			)
		end

		table.clear(activeByUser)
		table.clear(recordsById)
		table.clear(endedOrder)

		scanAccumulator = 0
	end

	-- =====================================================
	-- QUERIES
	-- =====================================================

	local function getDuelForUser(
		userId: number
	): Duel?

		local duelId =
			activeByUser[userId]

		if duelId == nil then
			return nil
		end

		local record =
			recordsById[duelId]

		if record == nil then
			return nil
		end

		if record.state.status ~= "Active" then
			return nil
		end

		return DuelState.clone(
			record.state
		)
	end

	local function getById(
		duelId: string
	): Duel?

		local record =
			recordsById[duelId]

		if record == nil then
			return nil
		end

		return DuelState.clone(
			record.state
		)
	end

	local function getOpponentUserId(
		userId: number
	): number?

		local duel =
			getDuelForUser(userId)

		if duel == nil then
			return nil
		end

		return DuelState.getOpponentUserId(
			duel,
			userId
		)
	end

	local function getHistory(
		duelId: string
	): {HistoryEntry}?

		local record =
			recordsById[duelId]

		if record == nil then
			return nil
		end

		return record.history.getEntries()
	end

	local function isInDuel(
		userId: number
	): boolean

		return getDuelForUser(userId) ~= nil
	end

	local function activeCount(): number
		local count = 0

		for _, record in pairs(recordsById) do
			if record.state.status == "Active" then
				count += 1
			end
		end

		return count
	end

	return {
		start = start,
		stop = stop,

		scanNow = scanNow,

		getDuelForUser = getDuelForUser,
		getById = getById,

		getOpponentUserId = getOpponentUserId,

		getHistory = getHistory,

		isInDuel = isInDuel,

		activeCount = activeCount,
	}
end

return DuelService