--!strict

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Shared =
	ReplicatedStorage.Shared

local CombatTypes =
	require(Shared.Combat.CombatTypes)

local DashConfig =
	require(Shared.Movement.DashConfig)

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

type DashDirection =
	CombatTypes.DashDirection

type DashAction =
	CombatTypes.DashAction

type Store =
	CharacterStateStore.Store

type CharacterApi =
	CharacterService.Service

type Bus =
	EventBus.Bus

local DashSystem = {}

type RuntimeDash = {
	action: DashAction,
	direction: DashDirection,

	sequence: number,

	endTick: number,
}

export type System = {
	start: (
		userId: number,
		sequence: number,
		currentTick: number
	) -> (boolean, string?),

	step: (
		currentTick: number
	) -> (),

	cancel: (
		userId: number
	) -> (),

	hasActive: (
		userId: number
	) -> boolean,
}

-- =========================================================
-- FACTORY
-- =========================================================

function DashSystem.new(
	store: Store,
	bus: Bus,
	characters: CharacterApi,
	duelId: string
): System

	local runtimeByUser:
		{[number]: RuntimeDash} = {}

	local nextReadyTickByUser:
		{[number]: number} = {}

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
	-- DIRECTION
	-- =====================================================

	local function resolveDirection(
		userId: number,
		root: BasePart
	): DashDirection

		local humanoid =
			characters.getHumanoid(userId)

		if humanoid == nil then
			return DashConfig.DEFAULT_DIRECTION
		end

		local moveDirection =
			humanoid.MoveDirection

		local horizontalMove =
			Vector3.new(
				moveDirection.X,
				0,
				moveDirection.Z
			)

		if horizontalMove.Magnitude
			< DashConfig.MOVE_DIRECTION_THRESHOLD
		then
			return DashConfig.DEFAULT_DIRECTION
		end

		local movement =
			horizontalMove.Unit

		local look =
			Vector3.new(
				root.CFrame.LookVector.X,
				0,
				root.CFrame.LookVector.Z
			)

		local right =
			Vector3.new(
				root.CFrame.RightVector.X,
				0,
				root.CFrame.RightVector.Z
			)

		if look.Magnitude <= 0.001
			or right.Magnitude <= 0.001
		then
			return DashConfig.DEFAULT_DIRECTION
		end

		look = look.Unit
		right = right.Unit

		local forwardDot =
			movement:Dot(look)

		local rightDot =
			movement:Dot(right)

		if math.abs(forwardDot)
			>= math.abs(rightDot)
		then
			if forwardDot >= 0 then
				return "Forward"
			end

			return "Back"
		end

		if rightDot >= 0 then
			return "Right"
		end

		return "Left"
	end

	-- =====================================================
	-- WORLD VECTOR
	-- =====================================================

	local function getWorldDirection(
		root: BasePart,
		direction: DashDirection
	): Vector3

		local look =
			Vector3.new(
				root.CFrame.LookVector.X,
				0,
				root.CFrame.LookVector.Z
			).Unit

		local right =
			Vector3.new(
				root.CFrame.RightVector.X,
				0,
				root.CFrame.RightVector.Z
			).Unit

		if direction == "Forward" then
			return look
		end

		if direction == "Back" then
			return -look
		end

		if direction == "Left" then
			return -right
		end

		return right
	end

	-- =====================================================
	-- IMPULSE
	-- =====================================================

	local function applyDashImpulse(
		root: BasePart,
		worldDirection: Vector3
	)
		local velocity =
			root.AssemblyLinearVelocity

		local currentHorizontal =
			Vector3.new(
				velocity.X,
				0,
				velocity.Z
			)

		local desiredHorizontal =
			worldDirection
			* DashConfig.HORIZONTAL_SPEED

		local deltaVelocity =
			desiredHorizontal
		- currentHorizontal

		-- Impulse = massa * Δv.
		--
		-- Isso faz personagens de massas diferentes
		-- receberem aproximadamente a mesma velocidade
		-- horizontal alvo.
		local impulse =
			deltaVelocity
			* root.AssemblyMass

		root:ApplyImpulse(impulse)
	end

	-- =====================================================
	-- START
	-- =====================================================

	local function start(
		userId: number,
		sequence: number,
		currentTick: number
	): (boolean, string?)

		if runtimeByUser[userId] ~= nil then
			return false, "DashAlreadyActive"
		end

		local state =
			store.get(userId)

		if state == nil then
			return false, "MissingState"
		end

		if state.status ~= "Normal" then
			return false, "InvalidStatus"
		end

		if state.stance ~= "Active" then
			return false, "StanceNotActive"
		end

		if state.air ~= "Grounded" then
			return false, "NotGrounded"
		end

		if state.action ~= nil then
			return false, "ActionActive"
		end

		if state.movementLocked then
			return false, "MovementLocked"
		end

		local readyTick =
			nextReadyTickByUser[userId]

		if readyTick ~= nil
			and currentTick < readyTick
		then
			return false, "DashCooldown"
		end

		local root =
			getRoot(userId)

		if root == nil then
			return false, "MissingRootPart"
		end

		if root.Anchored then
			return false, "RootAnchored"
		end

		local direction =
			resolveDirection(
				userId,
				root
			)

		local action =
			DashConfig.getAction(
				direction
			)

		local runtime: RuntimeDash = {
			action = action,
			direction = direction,

			sequence = sequence,

			endTick =
				currentTick
				+ DashConfig.DURATION_TICKS,
		}

		runtimeByUser[userId] =
			runtime

		nextReadyTickByUser[userId] =
			currentTick
			+ DashConfig.COOLDOWN_TICKS

		store.update(
			userId,
			"DashStarted",
			function(nextState)
				nextState.action = action
				nextState.actionPhase = "Active"
				nextState.actionSequence = sequence

				nextState.movementLocked = true

				nextState.comboStep =
					LightCombo.getResetStep()

				nextState.locomotion = "Idle"
			end
		)

		local worldDirection =
			getWorldDirection(
				root,
				direction
			)

		applyDashImpulse(
			root,
			worldDirection
		)

		bus.publish(
			EventTypes.create(
				"DashStarted",
				{
					tick = currentTick,
					duelId = duelId,

					actorUserId = userId,

					data = {
						action = action,
						direction = direction,
						sequence = sequence,

						worldDirection =
							worldDirection,
					},
				}
			)
		)

		return true, nil
	end

	-- =====================================================
	-- FINISH
	-- =====================================================

	local function finishDash(
		userId: number,
		runtime: RuntimeDash,
		currentTick: number
	)
		runtimeByUser[userId] = nil

		local state =
			store.get(userId)

		if state ~= nil
			and state.action == runtime.action
			and state.actionSequence == runtime.sequence
		then
			store.update(
				userId,
				"DashFinished",
				function(nextState)
					nextState.action = nil
					nextState.actionPhase = nil
					nextState.actionSequence = nil

					nextState.movementLocked = false
				end
			)
		end

		bus.publish(
			EventTypes.create(
				"DashFinished",
				{
					tick = currentTick,
					duelId = duelId,

					actorUserId = userId,

					data = {
						action = runtime.action,
						direction = runtime.direction,
						sequence = runtime.sequence,
					},
				}
			)
		)
	end

	-- =====================================================
	-- STEP
	-- =====================================================

	local function step(
		currentTick: number
	)
		local finishedUsers: {number} = {}

		for userId, runtime in pairs(
			runtimeByUser
			) do
			if currentTick >= runtime.endTick then
				table.insert(
					finishedUsers,
					userId
				)
			end
		end

		for _, userId in ipairs(
			finishedUsers
			) do
			local runtime =
				runtimeByUser[userId]

			if runtime ~= nil then
				finishDash(
					userId,
					runtime,
					currentTick
				)
			end
		end
	end

	-- =====================================================
	-- CANCEL
	-- =====================================================

	local function cancel(
		userId: number
	)
		runtimeByUser[userId] = nil
	end

	local function hasActive(
		userId: number
	): boolean

		return runtimeByUser[userId] ~= nil
	end

	return {
		start = start,

		step = step,

		cancel = cancel,

		hasActive = hasActive,
	}
end

return DashSystem