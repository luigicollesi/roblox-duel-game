--!strict

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Shared =
	ReplicatedStorage.Shared

local CombatTypes =
	require(Shared.Combat.CombatTypes)

local LightCombo =
	require(Shared.Combat.LightCombo)

type BufferedAttackKind =
	CombatTypes.BufferedAttackKind

type GroundAttack =
	CombatTypes.GroundAttack

local ComboSystem = {}

export type PendingAttack = {
	kind: BufferedAttackKind,
	sequence: number,
}

export type ResolvedAttack = {
	action: GroundAttack,
	nextComboStep: number,
}

export type System = {
	buffer: (
		userId: number,
		kind: BufferedAttackKind,
		sequence: number
	) -> PendingAttack,

	take: (
		userId: number
	) -> PendingAttack?,

	clear: (
		userId: number
	) -> (),

	resolve: (
		kind: BufferedAttackKind,
		comboStep: number
	) -> ResolvedAttack,
}

function ComboSystem.new(): System
	local pendingByUser:
		{[number]: PendingAttack} = {}

	-- =====================================================
	-- BUFFER
	-- =====================================================

	local function buffer(
		userId: number,
		kind: BufferedAttackKind,
		sequence: number
	): PendingAttack

		local pending: PendingAttack = {
			kind = kind,
			sequence = sequence,
		}

		-- Um único slot.
		-- O clique mais recente substitui o anterior.
		pendingByUser[userId] = pending

		return {
			kind = pending.kind,
			sequence = pending.sequence,
		}
	end

	-- =====================================================
	-- TAKE
	-- =====================================================

	local function take(
		userId: number
	): PendingAttack?

		local pending =
			pendingByUser[userId]

		if pending == nil then
			return nil
		end

		pendingByUser[userId] = nil

		return {
			kind = pending.kind,
			sequence = pending.sequence,
		}
	end

	-- =====================================================
	-- CLEAR
	-- =====================================================

	local function clear(
		userId: number
	)
		pendingByUser[userId] = nil
	end

	-- =====================================================
	-- RESOLVE
	-- =====================================================

	local function resolve(
		kind: BufferedAttackKind,
		comboStep: number
	): ResolvedAttack

		if kind == "Strong" then
			return {
				action = "Strong",
				nextComboStep =
					LightCombo.getResetStep(),
			}
		end

		local action =
			LightCombo.getAction(
				comboStep
			)

		local nextComboStep =
			LightCombo.getNextStep(
				comboStep
			)

		return {
			action = action,
			nextComboStep = nextComboStep,
		}
	end

	return {
		buffer = buffer,
		take = take,

		clear = clear,

		resolve = resolve,
	}
end

return ComboSystem