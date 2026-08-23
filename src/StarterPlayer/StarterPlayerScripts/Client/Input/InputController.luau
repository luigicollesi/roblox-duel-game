--!strict

local ContextActionService =
	game:GetService("ContextActionService")

local UserInputService =
	game:GetService("UserInputService")

local InputController = {}

export type Callbacks = {
	light: () -> (),
	strong: () -> (),
	dash: () -> (),
	jump: () -> (),
}

export type Controller = {
	start: () -> (),
	stop: () -> (),
}

local PRIORITY = 3000

local ACTION_LIGHT =
	"DuelLight"

local ACTION_STRONG =
	"DuelStrong"

local ACTION_DASH =
	"DuelDash"

local ACTION_JUMP =
	"DuelJump"

function InputController.new(
	shouldCapture: () -> boolean,
	callbacks: Callbacks
): Controller

	local started = false

	local function canCapture():
		boolean

		if UserInputService:GetFocusedTextBox()
			~= nil
		then
			return false
		end

		return shouldCapture()
	end

	local function createHandler(
		callback: () -> ()
	)
		return function(
			_actionName: string,
			inputState: Enum.UserInputState,
			_inputObject: InputObject
		)
			if not canCapture() then
				return Enum.ContextActionResult.Pass
			end

			if inputState
				== Enum.UserInputState.Begin
			then
				callback()
			end

			return Enum.ContextActionResult.Sink
		end
	end

	local lightHandler =
		createHandler(
			callbacks.light
		)

	local strongHandler =
		createHandler(
			callbacks.strong
		)

	local dashHandler =
		createHandler(
			callbacks.dash
		)

	local jumpHandler =
		createHandler(
			callbacks.jump
		)

	local function start()
		if started then
			return
		end

		started = true

		ContextActionService:BindActionAtPriority(
			ACTION_LIGHT,
			lightHandler,
			false,
			PRIORITY,
			Enum.UserInputType.MouseButton1
		)

		ContextActionService:BindActionAtPriority(
			ACTION_STRONG,
			strongHandler,
			false,
			PRIORITY,
			Enum.UserInputType.MouseButton2
		)

		ContextActionService:BindActionAtPriority(
			ACTION_DASH,
			dashHandler,
			false,
			PRIORITY,
			Enum.KeyCode.Q
		)

		ContextActionService:BindActionAtPriority(
			ACTION_JUMP,
			jumpHandler,
			false,
			PRIORITY,
			Enum.KeyCode.Space
		)
	end

	local function stop()
		if not started then
			return
		end

		started = false

		ContextActionService:UnbindAction(
			ACTION_LIGHT
		)

		ContextActionService:UnbindAction(
			ACTION_STRONG
		)

		ContextActionService:UnbindAction(
			ACTION_DASH
		)

		ContextActionService:UnbindAction(
			ACTION_JUMP
		)
	end

	return {
		start = start,
		stop = stop,
	}
end

return InputController