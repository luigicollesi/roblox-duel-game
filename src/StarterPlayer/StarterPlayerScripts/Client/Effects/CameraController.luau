--!strict

local RunService =
	game:GetService("RunService")

local ClientEventBus =
	require(
		script.Parent.Parent.Events.ClientEventBus
	)

local CameraController = {}

export type Controller = {
	start: () -> (),
	stop: () -> (),
}

function CameraController.new(
	localUserId: number
): Controller

	local trauma: number = 0

	local disconnect:
		(() -> ())? = nil

	local started = false

	local bindName =
		`DuelCameraEffects_{localUserId}`

	-- =====================================================
	-- TRAUMA
	-- =====================================================

	local function addTrauma(
		value: number
	)
		trauma =
			math.clamp(
				math.max(
					trauma,
					value
				),
				0,
				1
			)
	end

	-- =====================================================
	-- EFFECT
	-- =====================================================

	local function onEffect(
		payload: any
	)
		if type(payload) ~= "table" then
			return
		end

		if payload.eventName
			== "CombatResolved"
		then
			if type(payload.data)
				~= "table"
			then
				return
			end

			local result =
				payload.data.result

			if result == "Hit" then
				if payload.targetUserId
					== localUserId
				then
					addTrauma(
						0.65
					)

				elseif payload.actorUserId
					== localUserId
				then
					addTrauma(
						0.30
					)
				end

				return
			end

			if result == "Clash" then
				addTrauma(
					0.45
				)

				return
			end
		end

		if payload.eventName
			== "DashStarted"
			and payload.actorUserId
			== localUserId
		then
			addTrauma(
				0.12
			)
		end
	end

	-- =====================================================
	-- RENDER
	-- =====================================================

	local function onRenderStep(
		deltaTime: number
	)
		if trauma <= 0 then
			return
		end

		local camera =
			workspace.CurrentCamera

		if camera == nil then
			return
		end

		trauma =
			math.max(
				0,
				trauma
				- deltaTime * 4.5
			)

		local strength =
			trauma * trauma

		local time =
			os.clock() * 35

		local x =
			math.noise(
				time,
				0,
				0
			)
			* 0.08
			* strength

		local y =
			math.noise(
				0,
				time,
				0
			)
			* 0.06
			* strength

		local roll =
			math.noise(
				0,
				0,
				time
			)
			* 0.018
			* strength

		camera.CFrame =
			camera.CFrame
			* CFrame.new(
				x,
				y,
				0
			)
			* CFrame.Angles(
				0,
				0,
				roll
			)
	end

	-- =====================================================
	-- START
	-- =====================================================

	local function start()
		if started then
			return
		end

		started = true

		disconnect =
			ClientEventBus.subscribe(
				"Effect",
				onEffect
			)

		RunService:BindToRenderStep(
			bindName,

			Enum.RenderPriority.Camera.Value
				+ 1,

			onRenderStep
		)
	end

	-- =====================================================
	-- STOP
	-- =====================================================

	local function stop()
		if not started then
			return
		end

		started = false

		RunService:UnbindFromRenderStep(
			bindName
		)

		if disconnect ~= nil then
			disconnect()
			disconnect = nil
		end

		trauma = 0
	end

	return {
		start = start,
		stop = stop,
	}
end

return CameraController