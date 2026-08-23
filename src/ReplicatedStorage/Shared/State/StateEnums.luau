--!strict

local StateEnums = {}

export type StanceState =
	"Inactive"
| "Starting"
| "Active"

export type LocomotionState =
	"Idle"
| "Walking"

export type AirState =
	"Grounded"
| "Jumping"
| "Falling"
| "Landing"

export type CharacterStatus =
	"Normal"
| "Hitstun"
| "Stunned"
| "Dead"

StateEnums.Stance = table.freeze({
	Inactive = "Inactive",
	Starting = "Starting",
	Active = "Active",
})

StateEnums.Locomotion = table.freeze({
	Idle = "Idle",
	Walking = "Walking",
})

StateEnums.Air = table.freeze({
	Grounded = "Grounded",
	Jumping = "Jumping",
	Falling = "Falling",
	Landing = "Landing",
})

StateEnums.Status = table.freeze({
	Normal = "Normal",
	Hitstun = "Hitstun",
	Stunned = "Stunned",
	Dead = "Dead",
})

return table.freeze(StateEnums)