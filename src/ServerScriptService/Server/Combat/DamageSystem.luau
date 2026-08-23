--!strict

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

local CombatResolver =
	require(script.Parent.CombatResolver)

type Store =
	CharacterStateStore.Store

type CharacterApi =
	CharacterService.Service

type Bus =
	EventBus.Bus

type Outcome =
	CombatResolver.Outcome

local DamageSystem = {}

-- =========================================================
-- TYPES
-- =========================================================

export type DamageResult = {
	requested: number,
	applied: number,

	killed: boolean,
}

export type System = {
	apply: (
		outcome: Outcome,
		currentTick: number
	) -> DamageResult?,
}

-- =========================================================
-- FACTORY
-- =========================================================

function DamageSystem.new(
	store: Store,
	bus: Bus,
	characters: CharacterApi,
	duelId: string,
	fighterAUserId: number,
	fighterBUserId: number
): System

	-- =====================================================
	-- VALID PAIR
	-- =====================================================

	local function isValidPair(
		attackerUserId: number,
		targetUserId: number
	): boolean

		return (
			attackerUserId == fighterAUserId
				and targetUserId == fighterBUserId
		)
			or (
				attackerUserId == fighterBUserId
				and targetUserId == fighterAUserId
			)
	end

	-- =====================================================
	-- APPLY
	-- =====================================================

	local function apply(
		outcome: Outcome,
		currentTick: number
	): DamageResult?

		if outcome.result ~= "Hit" then
			return nil
		end

		if not isValidPair(
			outcome.attackerUserId,
			outcome.targetUserId
			) then
			return nil
		end

		local amount =
			outcome.damage

		-- Proteção contra valores inválidos.
		if amount <= 0 then
			return nil
		end

		if amount ~= amount then
			return nil
		end

		if amount == math.huge then
			return nil
		end

		local attackerState =
			store.get(
				outcome.attackerUserId
			)

		local targetState =
			store.get(
				outcome.targetUserId
			)

		if attackerState == nil
			or targetState == nil
		then
			return nil
		end

		if attackerState.duelId ~= duelId
			or targetState.duelId ~= duelId
		then
			return nil
		end

		if targetState.status == "Dead" then
			return nil
		end

		local humanoid =
			characters.getHumanoid(
				outcome.targetUserId
			)

		if humanoid == nil then
			return nil
		end

		if humanoid.Health <= 0 then
			return nil
		end

		local healthBefore =
			humanoid.Health

		humanoid:TakeDamage(
			amount
		)

		local healthAfter =
			humanoid.Health

		local applied =
			math.max(
				0,
				healthBefore - healthAfter
			)

		local killed =
			healthBefore > 0
			and healthAfter <= 0

		-- =================================================
		-- DEATH STATE
		-- =================================================

		if killed then
			store.update(
				outcome.targetUserId,
				"CharacterKilled",
				function(state)
					state.status = "Dead"

					state.action = nil
					state.actionPhase = nil
					state.actionSequence = nil

					state.movementLocked = true

					state.airAttackArmed = false
					state.locomotion = "Idle"
				end
			)
		end

		-- =================================================
		-- DAMAGE EVENT
		-- =================================================

		bus.publish(
			EventTypes.create(
				"DamageApplied",
				{
					tick = currentTick,
					duelId = duelId,

					actorUserId =
						outcome.attackerUserId,

					targetUserId =
						outcome.targetUserId,

					data = {
						action =
							outcome.action,

						sequence =
							outcome.sequence,

						requested =
							amount,

						applied =
							applied,

						healthBefore =
							healthBefore,

						healthAfter =
							healthAfter,

						killed =
							killed,
					},
				}
			)
		)

		-- =================================================
		-- KILLED EVENT
		-- =================================================

		if killed then
			bus.publish(
				EventTypes.create(
					"CharacterKilled",
					{
						tick = currentTick,
						duelId = duelId,

						actorUserId =
							outcome.attackerUserId,

						targetUserId =
							outcome.targetUserId,

						data = {
							action =
								outcome.action,

							sequence =
								outcome.sequence,
						},
					}
				)
			)
		end

		return {
			requested = amount,
			applied = applied,

			killed = killed,
		}
	end

	return {
		apply = apply,
	}
end

return DamageSystem