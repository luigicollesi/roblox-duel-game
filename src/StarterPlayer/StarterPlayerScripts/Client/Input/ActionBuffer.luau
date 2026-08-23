--!strict

local CombatTypes =
	require(
		game:GetService("ReplicatedStorage")
		.Shared.Combat.CombatTypes
	)

type BufferedAttackKind =
	CombatTypes.BufferedAttackKind

local ActionBuffer = {}

export type Pending = {
	kind: BufferedAttackKind,
	sequence: number,
}

export type Buffer = {
	put: (
		kind: BufferedAttackKind,
		sequence: number
	) -> (),

	peek: () -> Pending?,

	clearSequence: (
		sequence: number
	) -> (),

	clear: () -> (),
}

function ActionBuffer.new(): Buffer
	local pending: Pending? = nil

	local function put(
		kind: BufferedAttackKind,
		sequence: number
	)
		-- Mesmo comportamento do servidor:
		-- último clique vence.
		pending = {
			kind = kind,
			sequence = sequence,
		}
	end

	local function peek(): Pending?
		local value =
			pending

		if value == nil then
			return nil
		end

		return {
			kind = value.kind,
			sequence = value.sequence,
		}
	end

	local function clearSequence(
		sequence: number
	)
		local value =
			pending

		if value == nil then
			return
		end

		if value.sequence == sequence then
			pending = nil
		end
	end

	local function clear()
		pending = nil
	end

	return {
		put = put,
		peek = peek,

		clearSequence = clearSequence,
		clear = clear,
	}
end

return ActionBuffer