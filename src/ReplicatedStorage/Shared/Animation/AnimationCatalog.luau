--!strict

local AnimationStates = require(script.Parent.AnimationStates)

type AnimationState = AnimationStates.AnimationState

local AnimationCatalog = {}

export type AnimationDefinition = {
	objectName: string,

	priority: Enum.AnimationPriority,

	looped: boolean,

	speed: number,

	startAtEnd: boolean,
}

local DEFINITIONS: {[AnimationState]: AnimationDefinition} = {
	Idle = {
		objectName = "Idle",

		priority = Enum.AnimationPriority.Idle,

		looped = true,

		speed = 1,
		startAtEnd = false,
	},

	Walk = {
		objectName = "Walk",

		priority = Enum.AnimationPriority.Movement,

		looped = true,

		speed = 1,
		startAtEnd = false,
	},

	Start = {
		objectName = "Start",

		priority = Enum.AnimationPriority.Action,

		looped = false,

		speed = 1,
		startAtEnd = false,
	},

	Jump = {
		objectName = "Jump",

		priority = Enum.AnimationPriority.Action,

		looped = false,

		speed = 1,
		startAtEnd = false,
	},

	Fall = {
		objectName = "Fall",

		priority = Enum.AnimationPriority.Action,

		looped = true,

		speed = 1,
		startAtEnd = false,
	},

	LandNormal = {
		objectName = "Jump",

		priority = Enum.AnimationPriority.Action,

		looped = false,

		speed = -1,
		startAtEnd = true,
	},

	LandAttack = {
		-- O objeto chamado "Land" é o ataque.
		objectName = "Land",

		priority = Enum.AnimationPriority.Action3,

		looped = false,

		speed = 1,
		startAtEnd = false,
	},

	DashF = {
		objectName = "DashF",

		priority = Enum.AnimationPriority.Action2,

		looped = false,

		speed = 1,
		startAtEnd = false,
	},

	DashB = {
		objectName = "DashB",

		priority = Enum.AnimationPriority.Action2,

		looped = false,

		speed = 1,
		startAtEnd = false,
	},

	DashL = {
		objectName = "DashL",

		priority = Enum.AnimationPriority.Action2,

		looped = false,

		speed = 1,
		startAtEnd = false,
	},

	DashR = {
		objectName = "DashR",

		priority = Enum.AnimationPriority.Action2,

		looped = false,

		speed = 1,
		startAtEnd = false,
	},

	Q1 = {
		objectName = "Q1",

		priority = Enum.AnimationPriority.Action2,

		looped = false,

		speed = 1,
		startAtEnd = false,
	},

	Q2 = {
		objectName = "Q2",

		priority = Enum.AnimationPriority.Action2,

		looped = false,

		speed = 1,
		startAtEnd = false,
	},

	Q3 = {
		objectName = "Q3",

		priority = Enum.AnimationPriority.Action2,

		looped = false,

		speed = 1,
		startAtEnd = false,
	},

	Q3Reverse = {
		objectName = "Q3",

		priority = Enum.AnimationPriority.Action2,

		looped = false,

		speed = -1,
		startAtEnd = true,
	},

	Strong = {
		objectName = "Strong",

		priority = Enum.AnimationPriority.Action3,

		looped = false,

		speed = 1,
		startAtEnd = false,
	},
}

for _, definition in DEFINITIONS do
	table.freeze(definition)
end

table.freeze(DEFINITIONS)

function AnimationCatalog.get(
	state: AnimationState
): AnimationDefinition
	local definition = DEFINITIONS[state]

	assert(
		definition ~= nil,
		`Unknown animation state: {state}`
	)

	return definition
end

return table.freeze(AnimationCatalog)