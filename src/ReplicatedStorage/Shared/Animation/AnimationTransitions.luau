--!strict

local AnimationStates = require(script.Parent.AnimationStates)

type AnimationState = AnimationStates.AnimationState

local AnimationTransitions = {}

AnimationTransitions.DEFAULT_FADE = 0.04

local SPECIFIC: {[string]: number} = {
	["Idle>Walk"] = 0.12,
	["Walk>Idle"] = 0.12,

	["Jump>Fall"] = 0.08,

	["Fall>LandNormal"] = 0.04,
	["Fall>LandAttack"] = 0.025,

	["Q1>Q2"] = 0.025,
	["Q2>Q3"] = 0.025,
	["Q3>Q3Reverse"] = 0.02,
	["Q3Reverse>Q2"] = 0.025,
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

	local configured = SPECIFIC[makeKey(from, to)]

	if configured ~= nil then
		return configured
	end

	return AnimationTransitions.DEFAULT_FADE
end

return table.freeze(AnimationTransitions)