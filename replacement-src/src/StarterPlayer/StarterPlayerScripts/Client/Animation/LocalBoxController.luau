--!strict

local RunService =
	game:GetService("RunService")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Shared =
	ReplicatedStorage.Shared

local CombatConfig =
	require(
		Shared.Combat.CombatConfig
	)

local CombatTypes =
	require(
		Shared.Combat.CombatTypes
	)

local LightCombo =
	require(
		Shared.Combat.LightCombo
	)

local MoveDefinitions =
	require(
		Shared.Combat.MoveDefinitions
	)

local DashConfig =
	require(
		Shared.Movement.DashConfig
	)

local CharacterStateTypes =
	require(
		Shared.State.CharacterStateTypes
	)

local AnimationStates =
	require(
		Shared.Animation.AnimationStates
	)

local ClientEventBus =
	require(
		script.Parent.Parent.Events.ClientEventBus
	)

local PredictionController =
	require(
		script.Parent.Parent.State.PredictionController
	)

local LocomotionController =
	require(
		script.Parent.Parent.Movement.LocomotionController
	)

type CharacterState =
	CharacterStateTypes.CharacterState

type AnimationState =
	AnimationStates.AnimationState

type AttackAction =
	CombatTypes.AttackAction

type DashAction =
	CombatTypes.DashAction

type Prediction =
	PredictionController.Controller

type Locomotion =
	LocomotionController.Controller

local LocalBoxController = {}

export type Controller = {
	requestLight: () -> (),
	requestStrong: () -> (),
	requestDash: () -> boolean,
	requestJump: () -> (),

	isBusy: () -> boolean,

	reset: () -> (),
	destroy: () -> (),
}

function LocalBoxController.new(
	player: Player,
	prediction: Prediction,
	locomotion: Locomotion
): Controller

	local comboStep =
		LightCombo.getResetStep()

	local dashReadyAt = 0

	local landingAttackArmed = false
	local wasAirborne = false

	local busyUntil = 0
	local busyGeneration = 0

	local movementLockedHumanoid:
		Humanoid? = nil

	local movementLockedWalkSpeed:
		number? = nil

	local destroyed = false

	-- =====================================================
	-- STATE
	-- =====================================================

	local function getState():
		CharacterState?

		return prediction.get()
	end

	local function canUseLocalBox():
		boolean

		local state =
			getState()

		if state == nil then
			return false
		end

		if state.duelId ~= nil then
			return false
		end

		if state.stance ~= "Active" then
			return false
		end

		if state.status ~= "Normal" then
			return false
		end

		return true
	end

	local function isBusy():
		boolean

		return os.clock()
			< busyUntil
	end

	-- =====================================================
	-- CHARACTER
	-- =====================================================

	local function getHumanoidAndRoot():
		(Humanoid?, BasePart?)

		local character =
			player.Character

		if character == nil then
			return nil, nil
		end

		local humanoidInstance =
			character:FindFirstChild(
				"Humanoid"
			)

		local rootInstance =
			character:FindFirstChild(
				"HumanoidRootPart"
			)

		if humanoidInstance == nil
			or not humanoidInstance:IsA(
				"Humanoid"
			)
		then
			return nil, nil
		end

		if rootInstance == nil
			or not rootInstance:IsA(
				"BasePart"
			)
		then
			return humanoidInstance, nil
		end

		return humanoidInstance, rootInstance
	end

	local function isAirborne(
		humanoid: Humanoid
	): boolean

		return humanoid.FloorMaterial
			== Enum.Material.Air
	end

	-- =====================================================
	-- PREVIEW
	-- =====================================================

	local function preview(
		state: AnimationState,
		durationSeconds: number?
	)
		ClientEventBus.publish(
			"AnimationPreview",
			{
				state = state,
				durationSeconds =
					durationSeconds,
			}
		)
	end

	local function setLandingAttackArmed(
		armed: boolean
	)
		if landingAttackArmed == armed then
			return
		end

		landingAttackArmed =
			armed

		ClientEventBus.publish(
			"LandingAttackArmed",
			armed
		)
	end

	-- =====================================================
	-- ACTION LOCK
	-- =====================================================

	local function restoreMovement()
		local humanoid =
			movementLockedHumanoid

		local walkSpeed =
			movementLockedWalkSpeed

		movementLockedHumanoid = nil
		movementLockedWalkSpeed = nil

		if humanoid == nil
			or walkSpeed == nil
		then
			return
		end

		if humanoid.Parent == nil then
			return
		end

		humanoid.WalkSpeed =
			walkSpeed
	end

	local function clearBusy()
		busyGeneration += 1
		busyUntil = 0

		restoreMovement()
	end

	local function beginBusy(
		durationSeconds: number,
		lockMovement: boolean
	)
		busyGeneration += 1

		local token =
			busyGeneration

		busyUntil =
			os.clock()
			+ durationSeconds

		if lockMovement then
			local humanoid =
				select(
					1,
					getHumanoidAndRoot()
				)

			if humanoid ~= nil then
				restoreMovement()

				movementLockedHumanoid =
					humanoid

				movementLockedWalkSpeed =
					humanoid.WalkSpeed

				humanoid.WalkSpeed = 0
			end
		end

		task.delay(
			durationSeconds,

			function()
				if destroyed then
					return
				end

				if busyGeneration ~= token then
					return
				end

				busyUntil = 0
				restoreMovement()
			end
		)
	end

	-- =====================================================
	-- TIMING
	-- =====================================================

	local function getAttackDuration(
		action: AttackAction
	): number

		local timing =
			MoveDefinitions.getAttackTiming(
				action
			)

		return (
			timing.startupTicks
				+ timing.activeTicks
				+ timing.recoveryTicks
		) * CombatConfig.FIXED_DT
	end

	-- =====================================================
	-- COMBO
	-- =====================================================

	local function resetCombo()
		comboStep =
			LightCombo.getResetStep()
	end

	-- =====================================================
	-- LIGHT
	-- =====================================================

	local function requestLight()
		if not canUseLocalBox()
			or isBusy()
		then
			return
		end

		local humanoid =
			select(
				1,
				getHumanoidAndRoot()
			)

		if humanoid == nil then
			return
		end

		-- Clique durante Jump/Fall não inicia Q1/Q2/Q3:
		-- arma o ataque Land para quando tocar o chão.
		if isAirborne(humanoid) then
			setLandingAttackArmed(
				true
			)

			return
		end

		local action =
			LightCombo.getAction(
				comboStep
			)

		comboStep =
			LightCombo.getNextStep(
				comboStep
			)

		local duration =
			getAttackDuration(
				action
			)

		-- Ataques não podem ser cancelados por outro ataque,
		-- dash ou jump. Movimento voluntário também fica
		-- travado até o término da animação.
		beginBusy(
			duration,
			true
		)

		preview(
			action,
			duration
		)
	end

	-- =====================================================
	-- STRONG
	-- =====================================================

	local function requestStrong()
		if not canUseLocalBox()
			or isBusy()
		then
			return
		end

		local humanoid =
			select(
				1,
				getHumanoidAndRoot()
			)

		if humanoid == nil then
			return
		end

		resetCombo()

		if isAirborne(humanoid) then
			setLandingAttackArmed(
				true
			)

			return
		end

		local duration =
			getAttackDuration(
				"Strong"
			)

		beginBusy(
			duration,
			true
		)

		preview(
			"Strong",
			duration
		)
	end

	-- =====================================================
	-- DASH
	-- =====================================================

	local function getDashWorldDirection(
		root: BasePart,
		action: DashAction
	): Vector3

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
			return Vector3.zero
		end

		look = look.Unit
		right = right.Unit

		if action == "DashF" then
			return look
		end

		if action == "DashB" then
			return -look
		end

		if action == "DashL" then
			return -right
		end

		return right
	end

	local function applyDashImpulse(
		root: BasePart,
		direction: Vector3
	)
		if direction.Magnitude <= 0.001 then
			return
		end

		local velocity =
			root.AssemblyLinearVelocity

		local currentHorizontal =
			Vector3.new(
				velocity.X,
				0,
				velocity.Z
			)

		local desiredHorizontal =
			direction
			* DashConfig.HORIZONTAL_SPEED

		local deltaVelocity =
			desiredHorizontal
			- currentHorizontal

		root:ApplyImpulse(
			deltaVelocity
				* root.AssemblyMass
		)
	end

	local function requestDash():
		boolean

		if not canUseLocalBox()
			or isBusy()
		then
			return false
		end

		local now =
			os.clock()

		if now < dashReadyAt then
			return false
		end

		local humanoid, root =
			getHumanoidAndRoot()

		if humanoid == nil
			or root == nil
		then
			return false
		end

		if isAirborne(humanoid) then
			return false
		end

		if root.Anchored then
			return false
		end

		local action =
			locomotion.resolveDashAction()

		local worldDirection =
			getDashWorldDirection(
				root,
				action
			)

		applyDashImpulse(
			root,
			worldDirection
		)

		resetCombo()

		local duration =
			DashConfig.DURATION_TICKS
			* CombatConfig.FIXED_DT

		dashReadyAt =
			now
			+ (
				DashConfig.COOLDOWN_TICKS
				* CombatConfig.FIXED_DT
			)

		beginBusy(
			duration,
			false
		)

		preview(
			action,
			duration
		)

		return true
	end

	-- =====================================================
	-- JUMP
	-- =====================================================

	local function requestJump()
		if not canUseLocalBox()
			or isBusy()
		then
			return
		end

		local humanoid =
			select(
				1,
				getHumanoidAndRoot()
			)

		if humanoid == nil then
			return
		end

		if humanoid.Health <= 0 then
			return
		end

		if isAirborne(humanoid) then
			return
		end

		if not humanoid:GetStateEnabled(
			Enum.HumanoidStateType.Jumping
		) then
			return
		end

		-- O ContextActionService consome Space em stance.
		-- Forçamos explicitamente o estado Jumping para que
		-- o salto continue funcionando mesmo assim.
		humanoid.Jump = true

		humanoid:ChangeState(
			Enum.HumanoidStateType.Jumping
		)
	end

	-- =====================================================
	-- LAND ATTACK PREVIEW
	-- =====================================================

	local heartbeatConnection =
		RunService.Heartbeat:Connect(
			function()
				if destroyed then
					return
				end

				if not canUseLocalBox() then
					if landingAttackArmed then
						setLandingAttackArmed(
							false
						)
					end

					wasAirborne = false

					if isBusy() then
						clearBusy()
					end

					return
				end

				local humanoid =
					select(
						1,
						getHumanoidAndRoot()
					)

				if humanoid == nil then
					return
				end

				local airborne =
					isAirborne(
						humanoid
					)

				if wasAirborne
					and not airborne
					and landingAttackArmed
				then
					setLandingAttackArmed(
						false
					)

					resetCombo()

					local duration =
						getAttackDuration(
							"LandAttack"
						)

					beginBusy(
						duration,
						true
					)

					preview(
						"LandAttack",
						duration
					)
				end

				wasAirborne =
					airborne
			end
		)

	-- =====================================================
	-- RESET / DESTROY
	-- =====================================================

	local function reset()
		resetCombo()

		dashReadyAt = 0

		if landingAttackArmed then
			setLandingAttackArmed(
				false
			)
		end

		wasAirborne = false

		clearBusy()
	end

	local function destroy()
		if destroyed then
			return
		end

		destroyed = true

		heartbeatConnection:Disconnect()

		reset()
	end

	return {
		requestLight =
			requestLight,

		requestStrong =
			requestStrong,

		requestDash =
			requestDash,

		requestJump =
			requestJump,

		isBusy =
			isBusy,

		reset = reset,
		destroy = destroy,
	}
end

return LocalBoxController
