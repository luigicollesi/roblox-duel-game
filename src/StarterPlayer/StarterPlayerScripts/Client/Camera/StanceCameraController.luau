--!strict

local RunService =
	game:GetService("RunService")

local UserInputService =
	game:GetService("UserInputService")

local Workspace =
	game:GetService("Workspace")

local PredictionController =
	require(
		script.Parent.Parent.State.PredictionController
	)

type Prediction =
	PredictionController.Controller

local StanceCameraController = {}

export type Controller = {
	start: () -> (),
	stop: () -> (),
}

-- Third-person combat camera.
local CAMERA_DISTANCE = 7.5
local FOCUS_HEIGHT = 2.25

local YAW_SENSITIVITY = 0.0026
local PITCH_SENSITIVITY = 0.0022

local MIN_PITCH = math.rad(-55)
local MAX_PITCH = math.rad(35)

local WALL_PADDING = 0.35

function StanceCameraController.new(
	player: Player,
	prediction: Prediction
): Controller

	local started = false
	local active = false

	local disconnect:
		(() -> ())? = nil

	local renderName =
		`StanceCamera_{player.UserId}`

	local yaw = 0
	local pitch = 0

	local savedMouseBehavior:
		Enum.MouseBehavior? = nil

	local savedMouseIconEnabled:
		boolean? = nil

	local savedCameraType:
		Enum.CameraType? = nil

	local savedCameraSubject:
		Instance? = nil

	local controlledHumanoid:
		Humanoid? = nil

	local savedAutoRotate:
		boolean? = nil

	-- =====================================================
	-- CHARACTER
	-- =====================================================

	local function getCharacterParts():
		(Model?, Humanoid?, BasePart?)

		local character =
			player.Character

		if character == nil then
			return nil, nil, nil
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
			return character, nil, nil
		end

		if rootInstance == nil
			or not rootInstance:IsA(
				"BasePart"
			)
		then
			return character, humanoidInstance, nil
		end

		return character,
			humanoidInstance,
			rootInstance
	end

	local function restoreHumanoid()
		local humanoid =
			controlledHumanoid

		local autoRotate =
			savedAutoRotate

		controlledHumanoid = nil
		savedAutoRotate = nil

		if humanoid == nil
			or autoRotate == nil
		then
			return
		end

		if humanoid.Parent ~= nil then
			humanoid.AutoRotate =
				autoRotate
		end
	end

	local function controlHumanoid(
		humanoid: Humanoid
	)
		if controlledHumanoid
			== humanoid
		then
			humanoid.AutoRotate =
				false

			return
		end

		restoreHumanoid()

		controlledHumanoid =
			humanoid

		savedAutoRotate =
			humanoid.AutoRotate

		humanoid.AutoRotate =
			false
	end

	-- =====================================================
	-- ANGLES
	-- =====================================================

	local function initializeAngles(
		camera: Camera
	)
		local look =
			camera.CFrame.LookVector

		yaw =
			math.atan2(
				-look.X,
				-look.Z
			)

		pitch =
			math.asin(
				math.clamp(
					look.Y,
					-1,
					1
				)
			)
	end

	-- =====================================================
	-- ACTIVE MODE
	-- =====================================================

	local function enable()
		if active then
			return
		end

		local camera =
			Workspace.CurrentCamera

		if camera == nil then
			return
		end

		active = true

		savedMouseBehavior =
			UserInputService.MouseBehavior

		savedMouseIconEnabled =
			UserInputService.MouseIconEnabled

		savedCameraType =
			camera.CameraType

		savedCameraSubject =
			camera.CameraSubject

		initializeAngles(
			camera
		)

		UserInputService.MouseBehavior =
			Enum.MouseBehavior.LockCenter

		UserInputService.MouseIconEnabled =
			false

		camera.CameraType =
			Enum.CameraType.Scriptable
	end

	local function disable()
		if not active then
			return
		end

		active = false

		restoreHumanoid()

		if savedMouseBehavior ~= nil then
			UserInputService.MouseBehavior =
				savedMouseBehavior
		else
			UserInputService.MouseBehavior =
				Enum.MouseBehavior.Default
		end

		if savedMouseIconEnabled ~= nil then
			UserInputService.MouseIconEnabled =
				savedMouseIconEnabled
		else
			UserInputService.MouseIconEnabled =
				true
		end

		local camera =
			Workspace.CurrentCamera

		if camera ~= nil then
			if savedCameraSubject ~= nil then
				camera.CameraSubject =
					savedCameraSubject
			end

			camera.CameraType =
				savedCameraType
				or Enum.CameraType.Custom
		end

		savedMouseBehavior = nil
		savedMouseIconEnabled = nil
		savedCameraType = nil
		savedCameraSubject = nil
	end

	local function refreshFromState()
		local state =
			prediction.get()

		local shouldBeActive =
			state ~= nil
			and state.stance ~= "Inactive"
			and state.status ~= "Dead"

		if shouldBeActive then
			enable()
		else
			disable()
		end
	end

	-- =====================================================
	-- RENDER
	-- =====================================================

	local function onRenderStep()
		if not active then
			return
		end

		local camera =
			Workspace.CurrentCamera

		if camera == nil then
			return
		end

		-- Outros scripts do Roblox podem tentar devolver o
		-- mouse ao modo normal. Reforçamos apenas em stance.
		UserInputService.MouseBehavior =
			Enum.MouseBehavior.LockCenter

		UserInputService.MouseIconEnabled =
			false

		camera.CameraType =
			Enum.CameraType.Scriptable

		local character,
			humanoid,
			root =
			getCharacterParts()

		if character == nil
			or humanoid == nil
			or root == nil
		then
			return
		end

		controlHumanoid(
			humanoid
		)

		local delta =
			UserInputService:GetMouseDelta()

		yaw -=
			delta.X
			* YAW_SENSITIVITY

		pitch =
			math.clamp(
				pitch
					- delta.Y
					* PITCH_SENSITIVITY,
				MIN_PITCH,
				MAX_PITCH
			)

		local rotation =
			CFrame.fromOrientation(
				pitch,
				yaw,
				0
			)

		local forward =
			rotation.LookVector

		local horizontalForward =
			Vector3.new(
				forward.X,
				0,
				forward.Z
			)

		if horizontalForward.Magnitude
			> 0.001
		then
			horizontalForward =
				horizontalForward.Unit

			-- R15 sempre encara a mesma direção horizontal
			-- da câmera. A câmera fica atrás, portanto as
			-- costas do personagem ficam voltadas para ela.
			root.CFrame =
				CFrame.lookAt(
					root.Position,
					root.Position
						+ horizontalForward,
					Vector3.yAxis
				)
		end

		local focusPosition =
			root.Position
			+ Vector3.new(
				0,
				FOCUS_HEIGHT,
				0
			)

		local desiredPosition =
			focusPosition
			- forward
				* CAMERA_DISTANCE

		local raycastParams =
			RaycastParams.new()

		raycastParams.FilterType =
			Enum.RaycastFilterType.Exclude

		raycastParams.FilterDescendantsInstances = {
			character,
		}

		raycastParams.IgnoreWater =
			true

		local direction =
			desiredPosition
			- focusPosition

		local hit =
			Workspace:Raycast(
				focusPosition,
				direction,
				raycastParams
			)

		local cameraPosition =
			desiredPosition

		if hit ~= nil then
			cameraPosition =
				hit.Position
				+ hit.Normal
					* WALL_PADDING
		end

		camera.CFrame =
			CFrame.lookAt(
				cameraPosition,
				focusPosition,
				Vector3.yAxis
			)
	end

	-- =====================================================
	-- START / STOP
	-- =====================================================

	local function start()
		if started then
			return
		end

		started = true

		disconnect =
			prediction.subscribe(
				function()
					refreshFromState()
				end
			)

		RunService:BindToRenderStep(
			renderName,

			Enum.RenderPriority.Camera.Value,

			onRenderStep
		)

		refreshFromState()
	end

	local function stop()
		if not started then
			return
		end

		started = false

		RunService:UnbindFromRenderStep(
			renderName
		)

		if disconnect ~= nil then
			disconnect()
			disconnect = nil
		end

		disable()
	end

	return {
		start = start,
		stop = stop,
	}
end

return StanceCameraController
