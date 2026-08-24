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
	local strongReadyAt = 0

	local landingAttackArmed = false
	local wasAirborne = false

	local busyUntil = 0
	local busyGeneration = 0
	local busyKind: string? = nil

	-- Apenas UM clique futuro fica preparado.
	local lightBuffered = false

	-- Começamos a próxima animação ligeiramente antes do fim
	-- da atual para o crossfade acontecer sem um frame de Idle.
	local LIGHT_CHAIN_OVERLAP = 0.035

	local STRONG_COOLDOWN_SECONDS =
		CombatConfig.STRONG_COOLDOWN_TICKS
		* CombatConfig.FIXED_DT

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
		busyKind = nil

		restoreMovement()
	end

	local function beginBusy(
		durationSeconds: number,
		lockMovement: boolean,
		kind: string,
		onFinished: (() -> ())?
	): number
		busyGeneration += 1

		local token =
			busyGeneration

		busyKind =
			kind

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
				busyKind = nil

				restoreMovement()

				if onFinished ~= nil then
					onFinished()
				end
			end
		)

		return token
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

\t-- =====================================================
\t-- COMBO
\t-- =====================================================

\tlocal function resetCombo()
\t\tcomboStep =
\t\t\tLightCombo.getResetStep()

\t\tlightBuffered =
\t\t\tfalse
\tend

\tlocal function startLightAttack()
\t\tlocal action =
\t\t\tLightCombo.getAction(
\t\t\t\tcomboStep
\t\t\t)

\t\tcomboStep =
\t\t\tLightCombo.getNextStep(
\t\t\t\tcomboStep
\t\t\t)

\t\tlocal duration =
\t\t\tgetAttackDuration(
\t\t\t\taction
\t\t\t)

\t\tlightBuffered =
\t\t\tfalse

\t\tlocal token: number = 0

\t\ttoken =
\t\t\tbeginBusy(
\t\t\t\tduration,
\t\t\t\ttrue,
\t\t\t\t"Light",

\t\t\t\tfunction()
\t\t\t\t\t-- A cadeia terminou sem um próximo golpe.
\t\t\t\t\t-- O próximo clique deve começar novamente em Q1.
\t\t\t\t\tresetCombo()
\t\t\t\tend
\t\t\t)

\t\tpreview(
\t\t\taction,
\t\t\tduration
\t\t)

\t\tlocal chainDelay =
\t\t\tmath.max(
\t\t\t\t0,
\t\t\t\tduration
\t\t\t\t\t- LIGHT_CHAIN_OVERLAP
\t\t\t)

\t\ttask.delay(
\t\t\tchainDelay,

\t\t\tfunction()
\t\t\t\tif destroyed then
\t\t\t\t\treturn
\t\t\t\tend

\t\t\t\tif busyGeneration
\t\t\t\t\t~= token
\t\t\t\tthen
\t\t\t\t\treturn
\t\t\t\tend

\t\t\t\tif busyKind ~= "Light"
\t\t\t\t\tor not lightBuffered
\t\t\t\tthen
\t\t\t\t\treturn
\t\t\t\tend

\t\t\t\t-- Troca direta de animação, sem passar por Idle.
\t\t\t\tstartLightAttack()
\t\t\tend
\t\t)
\tend

\t-- =====================================================
\t-- LIGHT
\t-- =====================================================

\tlocal function requestLight()
\t\tif not canUseLocalBox() then
\t\t\treturn
\t\tend

\t\tlocal humanoid =
\t\t\tselect(
\t\t\t\t1,
\t\t\t\tgetHumanoidAndRoot()
\t\t\t)

\t\tif humanoid == nil then
\t\t\treturn
\t\tend

\t\t-- Mouse1 durante um ataque Light não cancela o atual.
\t\t-- Ele ocupa um único slot de buffer para o próximo.
\t\tif isBusy() then
\t\t\tif busyKind == "Light" then
\t\t\t\tlightBuffered =
\t\t\t\t\ttrue

\t\t\t\tlocal remaining =
\t\t\t\t\tbusyUntil
\t\t\t\t\t- os.clock()

\t\t\t\tif remaining
\t\t\t\t\t<= LIGHT_CHAIN_OVERLAP
\t\t\t\tthen
\t\t\t\t\tstartLightAttack()
\t\t\t\tend
\t\t\tend

\t\t\treturn
\t\tend

\t\tif isAirborne(humanoid) then
\t\t\tsetLandingAttackArmed(
\t\t\t\ttrue
\t\t\t)

\t\t\treturn
\t\tend

\t\tstartLightAttack()
\tend

	-- =====================================================
	-- STRONG
	-- =====================================================

\tlocal function requestStrong()
\t\tif not canUseLocalBox()
\t\t\tor isBusy()
\t\tthen
\t\t\treturn
\t\tend

\t\tlocal humanoid =
\t\t\tselect(
\t\t\t\t1,
\t\t\t\tgetHumanoidAndRoot()
\t\t\t)

\t\tif humanoid == nil then
\t\t\treturn
\t\tend

\t\t-- RMB no ar continua armando LandAttack e não
\t\t-- consome o cooldown do Strong.
\t\tif isAirborne(humanoid) then
\t\t\tsetLandingAttackArmed(
\t\t\t\ttrue
\t\t\t)

\t\t\treturn
\t\tend

\t\tlocal now =
\t\t\tos.clock()

\t\tif now < strongReadyAt then
\t\t\treturn
\t\tend

\t\tstrongReadyAt =
\t\t\tnow
\t\t\t+ STRONG_COOLDOWN_SECONDS

\t\tresetCombo()

\t\tlocal duration =
\t\t\tgetAttackDuration(
\t\t\t\t"Strong"
\t\t\t)

\t\tbeginBusy(
\t\t\tduration,
\t\t\ttrue,
\t\t\t"Strong",
\t\t\tnil
\t\t)

\t\tpreview(
\t\t\t"Strong",
\t\t\tduration
\t\t)
\tend

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
			false,
			"Dash",
			nil
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
						true,
						"LandAttack",
						nil
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
		strongReadyAt = 0

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
