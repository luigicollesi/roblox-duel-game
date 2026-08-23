--!strict

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Shared =
	ReplicatedStorage.Shared

local CombatTypes =
	require(Shared.Combat.CombatTypes)

local MoveDefinitions =
	require(Shared.Combat.MoveDefinitions)

local CharacterStateTypes =
	require(Shared.State.CharacterStateTypes)

type IntentKind =
	CombatTypes.IntentKind

type CharacterState =
	CharacterStateTypes.CharacterState

local ActionResolver = {}

export type StartResolution = {
	kind: "Start",
}

export type BufferResolution = {
	kind: "Buffer",
}

export type RejectResolution = {
	kind: "Reject",
	reason: string,
}

export type Resolution =
	StartResolution
| BufferResolution
| RejectResolution

-- =========================================================
-- HELPERS
-- =========================================================

local function reject(
	reason: string
): RejectResolution

	return {
		kind = "Reject",
		reason = reason,
	}
end

-- =========================================================
-- RESOLVE
-- =========================================================

function ActionResolver.resolve(
	state: CharacterState,
	intentKind: IntentKind
): Resolution

	-- Nesta fase, somente ataques.
	if intentKind ~= "Light"
		and intentKind ~= "Strong"
	then
		return reject(
			"NotHandledInPhase4"
		)
	end

	if state.status == "Dead" then
		return reject("Dead")
	end

	if state.status ~= "Normal" then
		return reject("InvalidStatus")
	end

	if state.stance ~= "Active" then
		return reject("StanceNotActive")
	end

	if state.air ~= "Grounded" then
		return reject("NotGrounded")
	end

	-- =====================================================
	-- CURRENT ACTION
	-- =====================================================

	if state.action ~= nil then
		local actionName =
			state.action

		if not CombatTypes.isGroundAttack(
			actionName
			) then
			return reject(
				"CurrentActionDoesNotAcceptAttackBuffer"
			)
		end

		local definition =
			MoveDefinitions.get(
				actionName
			)

		if intentKind == "Light" then
			if not definition.canBufferLight then
				return reject(
					"LightBufferNotAllowed"
				)
			end

			return {
				kind = "Buffer",
			}
		end

		if not definition.canBufferStrong then
			return reject(
				"StrongBufferNotAllowed"
			)
		end

		return {
			kind = "Buffer",
		}
	end

	-- =====================================================
	-- NEW ATTACK
	-- =====================================================

	if state.movementLocked then
		return reject(
			"MovementLocked"
		)
	end

	return {
		kind = "Start",
	}
end

return ActionResolver