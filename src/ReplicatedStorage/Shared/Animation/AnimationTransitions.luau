--!strict

local AnimationStates =
	require(
		script.Parent.AnimationStates
	)

type AnimationState =
	AnimationStates.AnimationState

local AnimationTransitions = {}

AnimationTransitions.DEFAULT_FADE = 0.035

local SPECIFIC:
	{[string]: number} = {
	["Idle>Walk"] = 0.05,
	["Walk>Idle"] = 0.05,

	["Jump>Fall"] = 0.05,

	["Fall>LandNormal"] = 0.035,
	["Fall>LandAttack"] = 0.02,

	["Q1>Q2"] = 0.02,
	["Q2>Q3"] = 0.02,
	["Q3>Q3Reverse"] = 0.015,
	["Q3Reverse>Q2"] = 0.02,
}

local function makeKey(
	from: AnimationState,
	to: AnimationState
): string

	return `{from}>{to}`
end

function AnimationTransitions.getFade(
	from: AnimationState?,
	to: AnimationState
): number

	if from == nil then
		return 0
	end

	local configured =
		SPECIFIC[
			makeKey(
				from,
				to
			)
		]

	if configured ~= nil then
		return configured
	end

	return AnimationTransitions.DEFAULT_FADE
end

return table.freeze(
	AnimationTransitions
)
