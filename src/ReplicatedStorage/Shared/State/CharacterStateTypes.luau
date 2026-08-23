--!strict

local StateEnums = require(script.Parent.StateEnums)
local CombatTypes = require(script.Parent.Parent.Combat.CombatTypes)

type StanceState = StateEnums.StanceState
type LocomotionState = StateEnums.LocomotionState
type AirState = StateEnums.AirState
type CharacterStatus = StateEnums.CharacterStatus

type ActionName = CombatTypes.ActionName
type ActionPhase = CombatTypes.ActionPhase

local CharacterStateTypes = {}

export type CharacterState = {
	-- Estado geral
	stance: StanceState,
	status: CharacterStatus,

	-- Locomoção
	locomotion: LocomotionState,
	air: AirState,

	-- Ação dominante
	action: ActionName?,
	actionPhase: ActionPhase?,
	actionSequence: number?,

	-- Controle
	movementLocked: boolean,

	-- Combo Light
	comboStep: number,

	-- Clique feito enquanto estava no ar
	airAttackArmed: boolean,

	-- Duelo
	duelId: string?,

	-- Incrementado pelo servidor sempre que
	-- o estado autoritativo muda.
	revision: number,
}

function CharacterStateTypes.new(): CharacterState
	return {
		stance = "Inactive",
		status = "Normal",

		locomotion = "Idle",
		air = "Grounded",

		action = nil,
		actionPhase = nil,
		actionSequence = nil,

		movementLocked = false,

		comboStep = 1,

		airAttackArmed = false,

		duelId = nil,

		revision = 0,
	}
end

return table.freeze(CharacterStateTypes)