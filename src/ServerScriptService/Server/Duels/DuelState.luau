--!strict

local DuelState = {}

export type DuelStatus =
	"Active"
| "Ended"

export type DuelEndReason =
	"Distance"
| "CharacterMissing"
| "CharacterDead"
| "PlayerLeft"
| "InvalidState"
| "ServiceStopped"

export type Duel = {
	id: string,

	fighterAUserId: number,
	fighterBUserId: number,

	status: DuelStatus,

	createdAt: number,

	endedAt: number?,
	endReason: DuelEndReason?,

	revision: number,
}

-- =========================================================
-- CREATE
-- =========================================================

function DuelState.new(
	id: string,
	fighterAUserId: number,
	fighterBUserId: number
): Duel

	assert(
		id ~= "",
		"Duel id cannot be empty"
	)

	assert(
		fighterAUserId ~= fighterBUserId,
		"A player cannot duel itself"
	)

	return {
		id = id,

		fighterAUserId = fighterAUserId,
		fighterBUserId = fighterBUserId,

		status = "Active",

		createdAt = os.clock(),

		endedAt = nil,
		endReason = nil,

		revision = 0,
	}
end

-- =========================================================
-- CLONE
-- =========================================================

function DuelState.clone(
	duel: Duel
): Duel

	return {
		id = duel.id,

		fighterAUserId = duel.fighterAUserId,
		fighterBUserId = duel.fighterBUserId,

		status = duel.status,

		createdAt = duel.createdAt,

		endedAt = duel.endedAt,
		endReason = duel.endReason,

		revision = duel.revision,
	}
end

-- =========================================================
-- QUERIES
-- =========================================================

function DuelState.contains(
	duel: Duel,
	userId: number
): boolean

	return duel.fighterAUserId == userId
		or duel.fighterBUserId == userId
end

function DuelState.getOpponentUserId(
	duel: Duel,
	userId: number
): number?

	if duel.fighterAUserId == userId then
		return duel.fighterBUserId
	end

	if duel.fighterBUserId == userId then
		return duel.fighterAUserId
	end

	return nil
end

-- =========================================================
-- FINISH
-- =========================================================

function DuelState.finish(
	duel: Duel,
	reason: DuelEndReason
): Duel

	assert(
		duel.status == "Active",
		`Duel {duel.id} is already ended`
	)

	local nextState =
		DuelState.clone(duel)

	nextState.status = "Ended"

	nextState.endedAt = os.clock()
	nextState.endReason = reason

	nextState.revision += 1

	return nextState
end

return DuelState