--!strict

local Players =
	game:GetService("Players")

local Workspace =
	game:GetService("Workspace")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Shared =
	ReplicatedStorage.Shared

local CombatTypes =
	require(Shared.Combat.CombatTypes)

local MoveDefinitions =
	require(Shared.Combat.MoveDefinitions)

local CharacterService =
	require(
		script.Parent.Parent.Character.CharacterService
	)

type AttackAction =
	CombatTypes.AttackAction

type CharacterApi =
	CharacterService.Service

local HitboxSystem = {}

-- =========================================================
-- TYPES
-- =========================================================

export type HitCandidate = {
	attackerUserId: number,
	targetUserId: number,

	action: AttackAction,

	sequence: number,

	damage: number,
	combatPriority: number,
}

export type System = {
	tryHit: (
		attackerUserId: number,
		action: AttackAction,
		sequence: number
	) -> HitCandidate?,

	wasConsumed: (
		userId: number,
		sequence: number
	) -> boolean,

	clear: (
		userId: number
	) -> (),
}

-- =========================================================
-- FACTORY
-- =========================================================

function HitboxSystem.new(
	characters: CharacterApi,
	fighterAUserId: number,
	fighterBUserId: number
): System

	-- Sequence que já acertou ou colidiu.
	--
	-- Uma mesma ação não pode aplicar dano novamente
	-- nos próximos active frames.
	local consumedSequenceByUser:
		{[number]: number} = {}

	-- =====================================================
	-- OPPONENT
	-- =====================================================

	local function getOpponentUserId(
		userId: number
	): number?

		if userId == fighterAUserId then
			return fighterBUserId
		end

		if userId == fighterBUserId then
			return fighterAUserId
		end

		return nil
	end

	-- =====================================================
	-- ROOT
	-- =====================================================

	local function getRoot(
		character: Model
	): BasePart?

		local instance =
			character:FindFirstChild(
				"HumanoidRootPart"
			)

		if instance == nil
			or not instance:IsA("BasePart")
		then
			return nil
		end

		return instance
	end

	-- =====================================================
	-- BODY PART
	-- =====================================================

	local function isBodyPart(
		part: BasePart,
		character: Model
	): boolean

		-- R6/R15 body parts são filhos diretos
		-- do Character.
		--
		-- Isso evita acessórios grandes gerando hits.
		return part.Parent == character
	end

	-- =====================================================
	-- LINE OF SIGHT
	-- =====================================================

	local function hasLineOfSight(
		attackerRoot: BasePart,
		targetRoot: BasePart
	): boolean

		local origin =
			attackerRoot.Position

		local direction =
			targetRoot.Position - origin

		if direction.Magnitude <= 0.001 then
			return true
		end

		local params =
			RaycastParams.new()

		params.FilterType =
			Enum.RaycastFilterType.Exclude

		local excluded: {Instance} = {}

		-- Outros personagens não devem fazer um duelo
		-- atravessar/errar por estarem passando no meio.
		-- O raycast serve principalmente para cenário.
		for _, player in ipairs(
			Players:GetPlayers()
			) do
			local character =
				player.Character

			if character ~= nil then
				table.insert(
					excluded,
					character
				)
			end
		end

		params.FilterDescendantsInstances =
			excluded

		params.IgnoreWater = true

		local obstruction =
			Workspace:Raycast(
				origin,
				direction,
				params
			)

		return obstruction == nil
	end

	-- =====================================================
	-- OVERLAP
	-- =====================================================

	local function overlapsTarget(
		attackerRoot: BasePart,
		targetCharacter: Model,
		action: AttackAction
	): boolean

		local hitbox =
			MoveDefinitions.getHitbox(
				action
			)

		local hitboxCFrame =
			attackerRoot.CFrame
			* hitbox.offset

		local params =
			OverlapParams.new()

		params.FilterType =
			Enum.RaycastFilterType.Include

		params.FilterDescendantsInstances = {
			targetCharacter,
		}

		params.MaxParts = 32

		params.RespectCanCollide = false

		local parts =
			Workspace:GetPartBoundsInBox(
				hitboxCFrame,
				hitbox.size,
				params
			)

		for _, part in ipairs(parts) do
			if isBodyPart(
				part,
				targetCharacter
				) then
				return true
			end
		end

		return false
	end

	-- =====================================================
	-- TRY HIT
	-- =====================================================

	local function tryHit(
		attackerUserId: number,
		action: AttackAction,
		sequence: number
	): HitCandidate?

		if consumedSequenceByUser[
			attackerUserId
			] == sequence then
			return nil
		end

		local targetUserId =
			getOpponentUserId(
				attackerUserId
			)

		if targetUserId == nil then
			return nil
		end

		local attackerCharacter =
			characters.getCharacter(
				attackerUserId
			)

		local targetCharacter =
			characters.getCharacter(
				targetUserId
			)

		if attackerCharacter == nil
			or targetCharacter == nil
		then
			return nil
		end

		local attackerRoot =
			getRoot(attackerCharacter)

		local targetRoot =
			getRoot(targetCharacter)

		if attackerRoot == nil
			or targetRoot == nil
		then
			return nil
		end

		if not overlapsTarget(
			attackerRoot,
			targetCharacter,
			action
			) then
			return nil
		end

		if not hasLineOfSight(
			attackerRoot,
			targetRoot
			) then
			return nil
		end

		-- A partir daqui a ação já conectou.
		-- Mesmo que resulte em Clash, ela foi consumida.
		consumedSequenceByUser[attackerUserId] = sequence

		return {
			attackerUserId =
				attackerUserId,

			targetUserId =
				targetUserId,

			action = action,

			sequence = sequence,

			damage =
				MoveDefinitions.getDamage(
					action
				),

			combatPriority =
				MoveDefinitions.getCombatPriority(
					action
				),
		}
	end

	-- =====================================================
	-- QUERY
	-- =====================================================

	local function wasConsumed(
		userId: number,
		sequence: number
	): boolean

		return consumedSequenceByUser[userId] == sequence
	end

	-- =====================================================
	-- CLEAR
	-- =====================================================

	local function clear(
		userId: number
	)
		consumedSequenceByUser[userId] = nil
	end

	return {
		tryHit = tryHit,

		wasConsumed = wasConsumed,

		clear = clear,
	}
end

return HitboxSystem