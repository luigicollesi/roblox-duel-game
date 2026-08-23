--!strict

local CombatTypes =
	require(script.Parent.CombatTypes)

type AttackAction =
	CombatTypes.AttackAction

local HitReactionConfig = {}

export type ReactionDefinition = {
	hitstunTicks: number,

	horizontalSpeed: number,
	verticalSpeed: number,
}

function HitReactionConfig.get(
	action: AttackAction
): ReactionDefinition

	if action == "Q1" then
		return {
			hitstunTicks = 10,

			horizontalSpeed = 18,
			verticalSpeed = 0,
		}
	end

	if action == "Q2" then
		return {
			hitstunTicks = 10,

			horizontalSpeed = 18,
			verticalSpeed = 0,
		}
	end

	if action == "Q3" then
		return {
			hitstunTicks = 13,

			horizontalSpeed = 24,
			verticalSpeed = 2,
		}
	end

	if action == "Q3Reverse" then
		return {
			hitstunTicks = 13,

			horizontalSpeed = 22,
			verticalSpeed = 2,
		}
	end

	if action == "Strong" then
		return {
			hitstunTicks = 24,

			horizontalSpeed = 34,
			verticalSpeed = 5,
		}
	end

	if action == "LandAttack" then
		return {
			hitstunTicks = 20,

			horizontalSpeed = 28,
			verticalSpeed = 7,
		}
	end

	error(`Missing hit reaction config for {action}`)
end

return HitReactionConfig