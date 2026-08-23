--!strict

local CombatTypes = require(script.Parent.CombatTypes)

type LightAction = CombatTypes.LightAction

local LightCombo = {}

LightCombo.RESET_STEP = 1
LightCombo.MAX_STEP = 4

function LightCombo.getAction(step: number): LightAction
	if step == 1 then
		return "Q1"
	end

	if step == 2 then
		return "Q2"
	end

	if step == 3 then
		return "Q3"
	end

	if step == 4 then
		return "Q3Reverse"
	end

	error(`Invalid light combo step: {step}`)
end

function LightCombo.getNextStep(step: number): number
	if step == 1 then
		return 2
	end

	if step == 2 then
		return 3
	end

	if step == 3 then
		return 4
	end

	if step == 4 then
		-- Q3Reverse volta para Q2, não Q1.
		return 2
	end

	error(`Invalid light combo step: {step}`)
end

function LightCombo.getResetStep(): number
	return LightCombo.RESET_STEP
end

function LightCombo.isValidStep(step: number): boolean
	return step >= 1
		and step <= LightCombo.MAX_STEP
		and step % 1 == 0
end

return table.freeze(LightCombo)