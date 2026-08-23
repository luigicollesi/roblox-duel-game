--!strict

local CombatTypes = {}

-- =========================================================
-- ACTIONS
-- =========================================================

export type LightAction =
	"Q1"
| "Q2"
| "Q3"
| "Q3Reverse"

export type GroundAttack =
	LightAction
| "Strong"

export type AttackAction =
	GroundAttack
| "LandAttack"

export type DashAction =
	"DashF"
| "DashB"
| "DashL"
| "DashR"

export type ActionName =
	AttackAction
| DashAction

-- =========================================================
-- PHASES
-- =========================================================

export type ActionPhase =
	"Startup"
| "Active"
| "Recovery"

-- =========================================================
-- INPUT
-- =========================================================

export type IntentKind =
	"Light"
| "Strong"
| "Dash"
| "Jump"

export type BufferedAttackKind =
	"Light"
| "Strong"

-- =========================================================
-- DASH
-- =========================================================

export type DashDirection =
	"Forward"
| "Back"
| "Left"
| "Right"

-- =========================================================
-- RESULTS
-- =========================================================

export type HitResult =
	"Hit"
| "Blocked"
| "Dodged"
| "Clash"
| "Miss"

export type ActionRejectReason =
	"InvalidState"
| "MovementLocked"
| "Stunned"
| "Dead"
| "NotInDuel"
| "Cooldown"
| "AlreadyQueued"
| "InvalidIntent"

export type MoveCategory =
	"Light"
| "Strong"
| "LandAttack"
| "Dash"

-- =========================================================
-- RUNTIME HELPERS
-- =========================================================

function CombatTypes.isLightAction(
	value: string
): boolean
	return value == "Q1"
		or value == "Q2"
		or value == "Q3"
		or value == "Q3Reverse"
end

function CombatTypes.isGroundAttack(
	value: string
): boolean
	return CombatTypes.isLightAction(value)
		or value == "Strong"
end

function CombatTypes.isBufferedAttackKind(
	value: string
): boolean
	return value == "Light"
		or value == "Strong"
end

return CombatTypes