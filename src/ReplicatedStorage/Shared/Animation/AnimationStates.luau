--!strict

local AnimationStates = {}

export type AnimationState =
	"Idle"
| "Walk"
| "Start"
| "Jump"
| "Fall"
| "LandNormal"
| "LandAttack"
| "DashF"
| "DashB"
| "DashL"
| "DashR"
| "Q1"
| "Q2"
| "Q3"
| "Q3Reverse"
| "Strong"

AnimationStates.Values = table.freeze({
	Idle = "Idle",
	Walk = "Walk",
	Start = "Start",

	Jump = "Jump",
	Fall = "Fall",

	LandNormal = "LandNormal",
	LandAttack = "LandAttack",

	DashF = "DashF",
	DashB = "DashB",
	DashL = "DashL",
	DashR = "DashR",

	Q1 = "Q1",
	Q2 = "Q2",
	Q3 = "Q3",
	Q3Reverse = "Q3Reverse",

	Strong = "Strong",
})

return table.freeze(AnimationStates)