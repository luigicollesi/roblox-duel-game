--!strict

local UserInputService =
	game:GetService("UserInputService")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local CombatTypes =
	require(
		ReplicatedStorage.Shared.Combat.CombatTypes
	)

local DashConfig =
	require(
		ReplicatedStorage.Shared.Movement.DashConfig
	)

type DashAction =
	CombatTypes.DashAction

type DashDirection =
	CombatTypes.DashDirection

local LocomotionController = {}

export type Controller = {
	resolveDashAction: () -> DashAction,
}

function LocomotionController.new(
	player: Player
): Controller

	local function getSingleKeyboardDirection():
		DashDirection?

		local w =
			UserInputService:IsKeyDown(
				Enum.KeyCode.W
			)

		local a =
			UserInputService:IsKeyDown(
				Enum.KeyCode.A
			)

		local s =
			UserInputService:IsKeyDown(
				Enum.KeyCode.S
			)

		local d =
			UserInputService:IsKeyDown(
				Enum.KeyCode.D
			)

		local count = 0

		if w then
			count += 1
		end

		if a then
			count += 1
		end

		if s then
			count += 1
		end

		if d then
			count += 1
		end

		-- Para Q+W/A/S/D, a direção precisa ser
		-- instantânea e não depender do Humanoid.Running.
		if count ~= 1 then
			return nil
		end

		if w then
			return "Forward"
		end

		if s then
			return "Back"
		end

		if a then
			return "Left"
		end

		return "Right"
	end

	local function resolveDirection():
		DashDirection

		local keyboardDirection =
			getSingleKeyboardDirection()

		if keyboardDirection ~= nil then
			return keyboardDirection
		end

		local character =
			player.Character

		if character == nil then
			return DashConfig.DEFAULT_DIRECTION
		end

		local humanoidInstance =
			character:FindFirstChild(
				"Humanoid"
			)

		if humanoidInstance == nil
			or not humanoidInstance:IsA(
				"Humanoid"
			)
		then
			return DashConfig.DEFAULT_DIRECTION
		end

		local rootInstance =
			character:FindFirstChild(
				"HumanoidRootPart"
			)

		if rootInstance == nil
			or not rootInstance:IsA(
				"BasePart"
			)
		then
			return DashConfig.DEFAULT_DIRECTION
		end

		local moveDirection =
			humanoidInstance.MoveDirection

		local horizontal =
			Vector3.new(
				moveDirection.X,
				0,
				moveDirection.Z
			)

		if horizontal.Magnitude
			< DashConfig.MOVE_DIRECTION_THRESHOLD
		then
			return DashConfig.DEFAULT_DIRECTION
		end

		local move =
			horizontal.Unit

		local look =
			Vector3.new(
				rootInstance.CFrame.LookVector.X,
				0,
				rootInstance.CFrame.LookVector.Z
			)

		local right =
			Vector3.new(
				rootInstance.CFrame.RightVector.X,
				0,
				rootInstance.CFrame.RightVector.Z
			)

		if look.Magnitude <= 0.001
			or right.Magnitude <= 0.001
		then
			return DashConfig.DEFAULT_DIRECTION
		end

		look = look.Unit
		right = right.Unit

		local forwardDot =
			move:Dot(look)

		local rightDot =
			move:Dot(right)

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

	local function resolveDashAction():
		DashAction

		return DashConfig.getAction(
			resolveDirection()
		)
	end

	return {
		resolveDashAction =
			resolveDashAction,
	}
end

return LocomotionController
