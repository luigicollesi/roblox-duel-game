--!strict

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local CombatTypes =
	require(
		ReplicatedStorage.Shared.Combat.CombatTypes
	)

local HitboxSystem =
	require(script.Parent.HitboxSystem)

type AttackAction =
	CombatTypes.AttackAction

type HitResult =
	CombatTypes.HitResult

type HitCandidate =
	HitboxSystem.HitCandidate

local CombatResolver = {}

export type Outcome = {
	attackerUserId: number,
	targetUserId: number,

	action: AttackAction,

	sequence: number,

	result: HitResult,

	damage: number,
}

-- =========================================================
-- OUTCOME
-- =========================================================

local function createOutcome(
	candidate: HitCandidate,
	result: HitResult,
	damage: number
): Outcome

	return {
		attackerUserId =
			candidate.attackerUserId,

		targetUserId =
			candidate.targetUserId,

		action =
			candidate.action,

		sequence =
			candidate.sequence,

		result =
			result,

		damage =
			damage,
	}
end

-- =========================================================
-- MIRRORED
-- =========================================================

local function areOpposingHits(
	a: HitCandidate,
	b: HitCandidate
): boolean

	return a.attackerUserId
		== b.targetUserId
		and b.attackerUserId
		== a.targetUserId
end

-- =========================================================
-- RESOLVE
-- =========================================================

function CombatResolver.resolve(
	candidates: {HitCandidate}
): {Outcome}

	if #candidates == 0 then
		return {}
	end

	if #candidates == 1 then
		local candidate =
			candidates[1]

		return {
			createOutcome(
				candidate,
				"Hit",
				candidate.damage
			),
		}
	end

	-- Um duelo é estritamente 1v1.
	-- Portanto nunca devemos receber mais que dois
	-- ataques conectando no mesmo tick.
	assert(
		#candidates <= 2,
		"CombatResolver received more than two hit candidates"
	)

	local first =
		candidates[1]

	local second =
		candidates[2]

	-- Situação inesperada, mas ainda resolvemos
	-- deterministicamente.
	if not areOpposingHits(
		first,
		second
		) then
		return {
			createOutcome(
				first,
				"Hit",
				first.damage
			),

			createOutcome(
				second,
				"Hit",
				second.damage
			),
		}
	end

	-- =====================================================
	-- SAME PRIORITY
	-- =====================================================

	if first.combatPriority
		== second.combatPriority
	then
		return {
			createOutcome(
				first,
				"Clash",
				0
			),

			createOutcome(
				second,
				"Clash",
				0
			),
		}
	end

	-- =====================================================
	-- FIRST WINS
	-- =====================================================

	if first.combatPriority
		> second.combatPriority
	then
		return {
			createOutcome(
				first,
				"Hit",
				first.damage
			),

			createOutcome(
				second,
				"Clash",
				0
			),
		}
	end

	-- =====================================================
	-- SECOND WINS
	-- =====================================================

	return {
		createOutcome(
			first,
			"Clash",
			0
		),

		createOutcome(
			second,
			"Hit",
			second.damage
		),
	}
end

return CombatResolver