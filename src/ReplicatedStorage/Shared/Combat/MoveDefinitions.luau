--!strict

local CombatTypes =
	require(script.Parent.CombatTypes)

type ActionName =
	CombatTypes.ActionName

type GroundAttack =
	CombatTypes.GroundAttack

type AttackAction =
	CombatTypes.AttackAction

type MoveCategory =
	CombatTypes.MoveCategory

local MoveDefinitions = {}

-- =========================================================
-- TYPES
-- =========================================================

export type MoveTiming = {
	startupTicks: number,
	activeTicks: number,
	recoveryTicks: number,
}

export type HitboxDefinition = {
	size: Vector3,

	-- Offset local em relação ao HumanoidRootPart.
	--
	-- Z negativo = para frente.
	offset: CFrame,
}

export type MoveDefinition = {
	id: ActionName,

	category: MoveCategory,

	animationState: string,

	locksMovement: boolean,

	canBufferLight: boolean,
	canBufferStrong: boolean,

	resetsLightCombo: boolean,

	timing: MoveTiming?,

	damage: number?,
	combatPriority: number?,
	hitbox: HitboxDefinition?,
}

-- =========================================================
-- Q1
-- =========================================================

local Q1: MoveDefinition = {
	id = "Q1",
	category = "Light",

	animationState = "Q1",

	locksMovement = true,

	canBufferLight = true,
	canBufferStrong = true,

	resetsLightCombo = false,

	timing = {
		startupTicks = 5,
		activeTicks = 3,
		recoveryTicks = 8,
	},

	damage = 8,
	combatPriority = 1,

	hitbox = {
		size = Vector3.new(5, 5, 5),

		offset =
			CFrame.new(0, 0, -3),
	},
}

-- =========================================================
-- Q2
-- =========================================================

local Q2: MoveDefinition = {
	id = "Q2",
	category = "Light",

	animationState = "Q2",

	locksMovement = true,

	canBufferLight = true,
	canBufferStrong = true,

	resetsLightCombo = false,

	timing = {
		startupTicks = 5,
		activeTicks = 3,
		recoveryTicks = 8,
	},

	damage = 8,
	combatPriority = 1,

	hitbox = {
		size = Vector3.new(5, 5, 5),

		offset =
			CFrame.new(0, 0, -3),
	},
}

-- =========================================================
-- Q3
-- =========================================================

local Q3: MoveDefinition = {
	id = "Q3",
	category = "Light",

	animationState = "Q3",

	locksMovement = true,

	canBufferLight = true,
	canBufferStrong = true,

	resetsLightCombo = false,

	timing = {
		startupTicks = 6,
		activeTicks = 4,
		recoveryTicks = 9,
	},

	damage = 11,
	combatPriority = 1,

	hitbox = {
		size = Vector3.new(5.5, 5, 5.5),

		offset =
			CFrame.new(0, 0, -3.25),
	},
}

-- =========================================================
-- Q3 REVERSE
-- =========================================================

local Q3Reverse: MoveDefinition = {
	id = "Q3Reverse",
	category = "Light",

	animationState = "Q3Reverse",

	locksMovement = true,

	canBufferLight = true,
	canBufferStrong = true,

	resetsLightCombo = false,

	timing = {
		startupTicks = 6,
		activeTicks = 4,
		recoveryTicks = 9,
	},

	damage = 10,
	combatPriority = 1,

	hitbox = {
		size = Vector3.new(5.5, 5, 5.5),

		offset =
			CFrame.new(0, 0, -3.25),
	},
}

-- =========================================================
-- STRONG
-- =========================================================

local Strong: MoveDefinition = {
	id = "Strong",
	category = "Strong",

	animationState = "Strong",

	locksMovement = true,

	canBufferLight = true,
	canBufferStrong = true,

	resetsLightCombo = true,

	timing = {
		startupTicks = 12,
		activeTicks = 5,
		recoveryTicks = 15,
	},

	damage = 18,
	combatPriority = 2,

	hitbox = {
		size = Vector3.new(6, 5.5, 6),

		offset =
			CFrame.new(0, 0, -3.5),
	},
}

-- =========================================================
-- LAND ATTACK
-- =========================================================

local LandAttack: MoveDefinition = {
	id = "LandAttack",
	category = "LandAttack",

	animationState = "LandAttack",

	locksMovement = true,

	canBufferLight = true,
	canBufferStrong = true,

	resetsLightCombo = true,

	timing = {
		startupTicks = 7,
		activeTicks = 5,
		recoveryTicks = 12,
	},

	damage = 16,
	combatPriority = 3,

	hitbox = {
		size = Vector3.new(7, 4.5, 7),

		offset =
			CFrame.new(0, -0.5, -1),
	},
}

-- =========================================================
-- DASHES
-- =========================================================

local DashF: MoveDefinition = {
	id = "DashF",
	category = "Dash",

	animationState = "DashF",

	locksMovement = true,

	canBufferLight = false,
	canBufferStrong = false,

	resetsLightCombo = true,

	timing = nil,

	damage = nil,
	combatPriority = nil,
	hitbox = nil,
}

local DashB: MoveDefinition = {
	id = "DashB",
	category = "Dash",

	animationState = "DashB",

	locksMovement = true,

	canBufferLight = false,
	canBufferStrong = false,

	resetsLightCombo = true,

	timing = nil,

	damage = nil,
	combatPriority = nil,
	hitbox = nil,
}

local DashL: MoveDefinition = {
	id = "DashL",
	category = "Dash",

	animationState = "DashL",

	locksMovement = true,

	canBufferLight = false,
	canBufferStrong = false,

	resetsLightCombo = true,

	timing = nil,

	damage = nil,
	combatPriority = nil,
	hitbox = nil,
}

local DashR: MoveDefinition = {
	id = "DashR",
	category = "Dash",

	animationState = "DashR",

	locksMovement = true,

	canBufferLight = false,
	canBufferStrong = false,

	resetsLightCombo = true,

	timing = nil,

	damage = nil,
	combatPriority = nil,
	hitbox = nil,
}

-- =========================================================
-- GET
-- =========================================================

function MoveDefinitions.get(
	action: ActionName
): MoveDefinition

	if action == "Q1" then
		return Q1
	end

	if action == "Q2" then
		return Q2
	end

	if action == "Q3" then
		return Q3
	end

	if action == "Q3Reverse" then
		return Q3Reverse
	end

	if action == "Strong" then
		return Strong
	end

	if action == "LandAttack" then
		return LandAttack
	end

	if action == "DashF" then
		return DashF
	end

	if action == "DashB" then
		return DashB
	end

	if action == "DashL" then
		return DashL
	end

	if action == "DashR" then
		return DashR
	end

	error(`Unknown move: {action}`)
end

-- =========================================================
-- ATTACK HELPERS
-- =========================================================

function MoveDefinitions.getAttackTiming(
	action: AttackAction
): MoveTiming

	local definition =
		MoveDefinitions.get(action)

	local timing =
		definition.timing

	assert(
		timing ~= nil,
		`Attack {action} has no timing`
	)

	return timing
end

function MoveDefinitions.getGroundAttackTiming(
	action: GroundAttack
): MoveTiming

	return MoveDefinitions.getAttackTiming(action)
end

function MoveDefinitions.getDamage(
	action: AttackAction
): number

	local definition =
		MoveDefinitions.get(action)

	local damage =
		definition.damage

	assert(
		damage ~= nil,
		`Attack {action} has no damage`
	)

	return damage
end

function MoveDefinitions.getCombatPriority(
	action: AttackAction
): number

	local definition =
		MoveDefinitions.get(action)

	local priority =
		definition.combatPriority

	assert(
		priority ~= nil,
		`Attack {action} has no combat priority`
	)

	return priority
end

function MoveDefinitions.getHitbox(
	action: AttackAction
): HitboxDefinition

	local definition =
		MoveDefinitions.get(action)

	local hitbox =
		definition.hitbox

	assert(
		hitbox ~= nil,
		`Attack {action} has no hitbox`
	)

	return hitbox
end

return MoveDefinitions