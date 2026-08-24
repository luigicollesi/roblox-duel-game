--!strict

local EventTypes = {}

export type EventName =
	"CharacterStateCreated"
| "CharacterStateChanged"
| "CharacterStateRemoved"
| "CharacterSpawned"
| "CharacterDespawning"

| "StanceToggleRequested"
| "StanceStarted"
| "StanceActivated"
| "StanceDeactivated"

| "DuelCreated"
| "DuelEnded"

| "PlayerIntentReceived"
| "PlayerIntentRejected"

| "CombatActionRejected"
| "CombatActionBuffered"

| "AttackStarted"
| "AttackPhaseChanged"
| "AttackFinished"

| "CombatResolved"
| "CombatInterrupted"

| "DamageApplied"
| "CharacterKilled"

| "HitstunStarted"
| "HitstunEnded"
| "KnockbackApplied"

| "JumpStarted"
| "AirStateChanged"
| "LandAttackArmed"
| "NormalLandingStarted"

| "DashStarted"
| "DashFinished"

export type ServerEvent = {
	id: number,

	name: EventName,

	createdAt: number,

	tick: number?,

	duelId: string?,

	actorUserId: number?,
	targetUserId: number?,

	data: any?,
}

export type CreateOptions = {
	tick: number?,

	duelId: string?,

	actorUserId: number?,
	targetUserId: number?,

	data: any?,
}

local nextEventId = 0

function EventTypes.create(
	name: EventName,
	options: CreateOptions?
): ServerEvent
	nextEventId += 1

	local tick: number? = nil
	local duelId: string? = nil

	local actorUserId: number? = nil
	local targetUserId: number? = nil

	local data: any? = nil

	if options ~= nil then
		tick = options.tick
		duelId = options.duelId

		actorUserId = options.actorUserId
		targetUserId = options.targetUserId

		data = options.data
	end

	return {
		id = nextEventId,

		name = name,

		createdAt = os.clock(),

		tick = tick,

		duelId = duelId,

		actorUserId = actorUserId,
		targetUserId = targetUserId,

		data = data,
	}
end

function EventTypes.isKnownName(
	name: string
): boolean
	return name == "CharacterStateCreated"
		or name == "CharacterStateChanged"
		or name == "CharacterStateRemoved"
		or name == "CharacterSpawned"
		or name == "CharacterDespawning"

		or name == "StanceToggleRequested"
		or name == "StanceStarted"
		or name == "StanceActivated"
		or name == "StanceDeactivated"

		or name == "DuelCreated"
		or name == "DuelEnded"

		or name == "PlayerIntentReceived"
		or name == "PlayerIntentRejected"

		or name == "CombatActionRejected"
		or name == "CombatActionBuffered"

		or name == "AttackStarted"
		or name == "AttackPhaseChanged"
		or name == "AttackFinished"

		or name == "CombatResolved"
		or name == "CombatInterrupted"

		or name == "DamageApplied"
		or name == "CharacterKilled"

		or name == "HitstunStarted"
		or name == "HitstunEnded"
		or name == "KnockbackApplied"

		or name == "JumpStarted"
		or name == "AirStateChanged"
		or name == "LandAttackArmed"
		or name == "NormalLandingStarted"

		or name == "DashStarted"
		or name == "DashFinished"
end

return EventTypes
