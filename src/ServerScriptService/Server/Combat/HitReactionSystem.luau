--!strict

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Shared =
	ReplicatedStorage.Shared

local CombatTypes =
	require(Shared.Combat.CombatTypes)

local HitReactionConfig =
	require(Shared.Combat.HitReactionConfig)

local LightCombo =
	require(Shared.Combat.LightCombo)

local CharacterStateStore =
	require(
		script.Parent.Parent.Character.CharacterStateStore
	)

local CharacterService =
	require(
		script.Parent.Parent.Character.CharacterService
	)

local EventBus =
	require(
		script.Parent.Parent.Events.EventBus
	)

local EventTypes =
	require(
		script.Parent.Parent.Events.EventTypes
	)

type AttackAction =
	CombatTypes.AttackAction

type Store =
	CharacterStateStore.Store

type CharacterApi =
	CharacterService.Service

type Bus =
	EventBus.Bus

local HitReactionSystem = {}

export type System = {
	apply: (
		attackerUserId: number,
		targetUserId: number,
		action: AttackAction,
		currentTick: number
	) -> boolean,

	step: (
		currentTick: number
	) -> (),

	clear: (
		userId: number
	) -> (),
}

function HitReactionSystem.new(
	store: Store,
	bus: Bus,
	characters: CharacterApi,
	duelId: string,
	fighterAUserId: number,
	fighterBUserId: number
): System

	local endTickByUser:
		{[number]: number} = {}

	-- =====================================================
	-- VALID PAIR
	-- =====================================================

	local function isValidPair(
		attackerUserId: number,
		targetUserId: number
	): boolean

		return (
			attackerUserId == fighterAUserId
				and targetUserId == fighterBUserId
		)
			or (
				attackerUserId == fighterBUserId
				and targetUserId == fighterAUserId
			)
	end

	-- =====================================================
	-- ROOT
	-- =====================================================

	local function getRoot(
		userId: number
	): BasePart?

		local character =
			characters.getCharacter(userId)

		if character == nil then
			return nil
		end

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
	-- KNOCKBACK DIRECTION
	-- =====================================================

	local function getKnockbackDirection(
		attackerRoot: BasePart,
		targetRoot: BasePart
	): Vector3

		local displacement =
			targetRoot.Position
		- attackerRoot.Position

		local horizontal =
			Vector3.new(
				displacement.X,
				0,
				displacement.Z
			)

		if horizontal.Magnitude > 0.001 then
			return horizontal.Unit
		end

		local look =
			attackerRoot.CFrame.LookVector

		local horizontalLook =
			Vector3.new(
				look.X,
				0,
				look.Z
			)

		if horizontalLook.Magnitude > 0.001 then
			return horizontalLook.Unit
		end

		return Vector3.new(0, 0, -1)
	end

	-- =====================================================
	-- KNOCKBACK
	-- =====================================================

	local function applyKnockback(
		attackerUserId: number,
		targetUserId: number,
		action: AttackAction,
		currentTick: number
	)
		local attackerRoot =
			getRoot(attackerUserId)

		local targetRoot =
			getRoot(targetUserId)

		if attackerRoot == nil
			or targetRoot == nil
		then
			return
		end

		if targetRoot.Anchored then
			return
		end

		local reaction =
			HitReactionConfig.get(
				action
			)

		local direction =
			getKnockbackDirection(
				attackerRoot,
				targetRoot
			)

		local velocity =
			targetRoot.AssemblyLinearVelocity

		local currentHorizontal =
			Vector3.new(
				velocity.X,
				0,
				velocity.Z
			)

		local desiredHorizontal =
			direction
			* reaction.horizontalSpeed

		local horizontalDelta =
			desiredHorizontal
		- currentHorizontal

		local verticalDelta = 0

		if reaction.verticalSpeed > 0 then
			verticalDelta =
				math.max(
					0,
					reaction.verticalSpeed
					- velocity.Y
				)
		end

		local deltaVelocity =
			Vector3.new(
				horizontalDelta.X,
				verticalDelta,
				horizontalDelta.Z
			)

		local mass =
			targetRoot.AssemblyMass

		if mass <= 0
			or mass ~= mass
			or mass == math.huge
		then
			return
		end

		local impulse =
			deltaVelocity * mass

		targetRoot:ApplyImpulse(
			impulse
		)

		bus.publish(
			EventTypes.create(
				"KnockbackApplied",
				{
					tick = currentTick,
					duelId = duelId,

					actorUserId =
						attackerUserId,

					targetUserId =
						targetUserId,

					data = {
						action = action,

						direction = direction,

						horizontalSpeed =
							reaction.horizontalSpeed,

						verticalSpeed =
							reaction.verticalSpeed,
					},
				}
			)
		)
	end

	-- =====================================================
	-- APPLY HITSTUN
	-- =====================================================

	local function apply(
		attackerUserId: number,
		targetUserId: number,
		action: AttackAction,
		currentTick: number
	): boolean

		if not isValidPair(
			attackerUserId,
			targetUserId
			) then
			return false
		end

		local state =
			store.get(targetUserId)

		if state == nil then
			return false
		end

		if state.status == "Dead" then
			return false
		end

		if state.duelId ~= duelId then
			return false
		end

		local reaction =
			HitReactionConfig.get(
				action
			)

		local endTick =
			currentTick
			+ reaction.hitstunTicks

		local previousEndTick =
			endTickByUser[targetUserId]

		if previousEndTick ~= nil
			and previousEndTick > endTick
		then
			endTick =
				previousEndTick
		end

		endTickByUser[targetUserId] =
			endTick

		store.update(
			targetUserId,
			"HitstunStarted",
			function(nextState)
				nextState.status = "Hitstun"

				nextState.action = nil
				nextState.actionPhase = nil
				nextState.actionSequence = nil

				nextState.movementLocked = true

				nextState.comboStep =
					LightCombo.getResetStep()

				nextState.airAttackArmed = false

				nextState.locomotion = "Idle"
			end
		)

		applyKnockback(
			attackerUserId,
			targetUserId,
			action,
			currentTick
		)

		bus.publish(
			EventTypes.create(
				"HitstunStarted",
				{
					tick = currentTick,
					duelId = duelId,

					actorUserId =
						attackerUserId,

					targetUserId =
						targetUserId,

					data = {
						action = action,

						durationTicks =
							reaction.hitstunTicks,

						endTick = endTick,
					},
				}
			)
		)

		return true
	end

	-- =====================================================
	-- STEP
	-- =====================================================

	local function step(
		currentTick: number
	)
		local completed: {number} = {}

		for userId, endTick in pairs(
			endTickByUser
			) do
			if currentTick >= endTick then
				table.insert(
					completed,
					userId
				)
			end
		end

		for _, userId in ipairs(
			completed
			) do
			endTickByUser[userId] = nil

			local state =
				store.get(userId)

			if state == nil then
				continue
			end

			-- Outro sistema pode ter mudado o status,
			-- por exemplo Dead.
			if state.status ~= "Hitstun" then
				continue
			end

			local nextState =
				store.update(
					userId,
					"HitstunEnded",
					function(value)
						value.status = "Normal"

						value.movementLocked =
							false
					end
				)

			bus.publish(
				EventTypes.create(
					"HitstunEnded",
					{
						tick = currentTick,
						duelId = duelId,

						actorUserId =
							userId,

						data = {
							revision =
								nextState.revision,
						},
					}
				)
			)
		end
	end

	-- =====================================================
	-- CLEAR
	-- =====================================================

	local function clear(
		userId: number
	)
		endTickByUser[userId] = nil
	end

	return {
		apply = apply,

		step = step,

		clear = clear,
	}
end

return HitReactionSystem