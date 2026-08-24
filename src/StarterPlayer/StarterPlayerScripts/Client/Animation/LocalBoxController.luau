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
	requestDash: () -> (),
	requestJump: () -> (),

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
		if not canUseLocalBox() then
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

		if isAirborne(humanoid) then
			landingAttackArmed = true
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

		-- Ataques em modo de preview usam a velocidade
		-- natural do asset. O timing de combate continua
		-- reservado ao pipeline autoritativo do duelo.
		preview(
			action,
			nil
		)
	end

	-- =====================================================
	-- STRONG
	-- =====================================================

	local function requestStrong()
		if not canUseLocalBox() then
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
			landingAttackArmed = true
			return
		end

		preview(
			"Strong",
			nil
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

	local function requestDash()
		if not canUseLocalBox() then
			return
		end

		local now =
			os.clock()

		if now < dashReadyAt then
			return
		end

		local humanoid, root =
			getHumanoidAndRoot()

		if humanoid == nil
			or root == nil
		then
			return
		end

		if isAirborne(humanoid) then
			return
		end

		if root.Anchored then
			return
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

		preview(
			action,
			duration
		)
	end

	-- =====================================================
	-- JUMP
	-- =====================================================

	local function requestJump()
		if not canUseLocalBox() then
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

		-- Como o InputController consome Space em stance,
		-- o salto precisa ser iniciado explicitamente.
		humanoid.Jump = true
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
					landingAttackArmed = false
					wasAirborne = false
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
					landingAttackArmed =
						false

					resetCombo()

					preview(
						"LandAttack",
						nil
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

		landingAttackArmed = false
		wasAirborne = false
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

		reset = reset,
		destroy = destroy,
	}
end

return LocalBoxController
