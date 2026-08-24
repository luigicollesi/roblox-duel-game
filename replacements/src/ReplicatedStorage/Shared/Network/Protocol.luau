--!strict

local CombatTypes =
	require(script.Parent.Parent.Combat.CombatTypes)

type IntentKind =
	CombatTypes.IntentKind

local Protocol = {}

Protocol.VERSION = 1

export type ClientIntent = {
	version: number,
	sequence: number,
	kind: IntentKind,
}

export type IntentRejected = {
	type: "IntentRejected",
	sequence: number,
	reason: string,
}

-- =========================================================
-- INTENT KIND
-- =========================================================

function Protocol.isIntentKind(
	value: string
): boolean
	return value == "Stance"
		or value == "Light"
		or value == "Strong"
		or value == "Dash"
		or value == "Jump"
end

-- =========================================================
-- CLIENT INTENT
-- =========================================================

function Protocol.isClientIntent(
	value: any
): boolean
	if type(value) ~= "table" then
		return false
	end

	if value.version ~= Protocol.VERSION then
		return false
	end

	if type(value.sequence) ~= "number" then
		return false
	end

	if value.sequence < 0
		or value.sequence % 1 ~= 0
	then
		return false
	end

	if type(value.kind) ~= "string" then
		return false
	end

	if not Protocol.isIntentKind(
		value.kind
	) then
		return false
	end

	return true
end

-- =========================================================
-- CREATE INTENT
-- =========================================================

function Protocol.createClientIntent(
	sequence: number,
	kind: IntentKind
): ClientIntent
	assert(
		sequence >= 0
			and sequence % 1 == 0,
		"Intent sequence must be non-negative integer"
	)

	return {
		version = Protocol.VERSION,
		sequence = sequence,
		kind = kind,
	}
end

return Protocol
