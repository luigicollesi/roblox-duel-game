--!strict

local Players =
	game:GetService("Players")

local player: Player =
	assert(
		Players.LocalPlayer,
		"LocalPlayer is unavailable"
	)

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")



local characterInstance =
	script.Parent

assert(
	characterInstance:IsA("Model"),
	"CharacterPresentation must be inside Character"
)

local character: Model =
	characterInstance

-- =========================================================
-- SHARED
-- =========================================================

local Shared =
	ReplicatedStorage:WaitForChild(
		"Shared"
	)

local CharacterStateTypes =
	require(
		Shared.State.CharacterStateTypes
	)

local AnimationStates =
	require(
		Shared.Animation.AnimationStates
	)

local CombatConfig =
	require(
		Shared.Combat.CombatConfig
	)

local MoveDefinitions =
	require(
		Shared.Combat.MoveDefinitions
	)

local DashConfig =
	require(
		Shared.Movement.DashConfig
	)

local MovementConfig =
	require(
		Shared.Movement.MovementConfig
	)

type CharacterState =
	CharacterStateTypes.CharacterState

type AnimationState =
	AnimationStates.AnimationState

-- =========================================================
-- ANIMATION MODULES
-- =========================================================

local animationFolder =
	script.Parent:WaitForChild(
		"Animation"
	)

local AnimationRegistry =
	require(
		animationFolder.AnimationRegistry
	)

local AnimationResolver =
	require(
		animationFolder.AnimationResolver
	)

local AnimationDirector =
	require(
		animationFolder.AnimationDirector
	)

local AnimationDebug =
	require(
		animationFolder.AnimationDebug
	)

-- =========================================================
-- PREDICTION CONTROLLER
-- =========================================================

local playerScripts =
	player:WaitForChild(
		"PlayerScripts"
	)

local predictionModule =
	playerScripts
	:WaitForChild("Client")
	:WaitForChild("State")
	:WaitForChild(
		"PredictionController"
	)

assert(
	predictionModule:IsA("ModuleScript"),
	"PredictionController must be ModuleScript"
)

local PredictionController =
	require(
		predictionModule
	)

-- =========================================================
-- HUMANOID / ANIMATOR
-- =========================================================

local humanoidInstance =
	character:WaitForChild(
		"Humanoid"
	)

assert(
	humanoidInstance:IsA("Humanoid"),
	"Humanoid missing"
)

local humanoid: Humanoid =
	humanoidInstance

local animatorInstance =
	humanoid:WaitForChild(
		"Animator"
	)

assert(
	animatorInstance:IsA("Animator"),
	"Animator missing"
)

local animator: Animator =
	animatorInstance

-- =========================================================
-- ASSETS
-- =========================================================

local boxInstance =
	ReplicatedStorage
	:WaitForChild("Assets")
	:WaitForChild("Animations")
	:WaitForChild("Box")

assert(
	boxInstance:IsA("Folder"),
	"Assets/Animations/Box must be Folder"
)

local boxFolder: Folder =
	boxInstance

-- =========================================================
-- DEFAULT ANIMATE
-- =========================================================

local function setDefaultAnimateEnabled(
	enabled: boolean
)
	local animateInstance =
		character:FindFirstChild(
			"Animate"
		)

	if animateInstance == nil then
		return
	end

	if not animateInstance:IsA(
		"BaseScript"
		) then
		return
	end

	animateInstance.Enabled =
		enabled
end

-- =========================================================
-- STACK
-- =========================================================

local registry =
	AnimationRegistry.new(
		animator,
		boxFolder
	)

local director =
	AnimationDirector.new(
		animator,
		registry
	)

local debugger =
	AnimationDebug.new(
		animator,
		registry,

		function(
			track: AnimationTrack
		)
			director.stopExternal(
				track,
				0.03
			)
		end
	)

-- =========================================================
-- TIMING
-- =========================================================

local function timingToSeconds(
	timing: any
): number

	return (
		timing.startupTicks
			+ timing.activeTicks
			+ timing.recoveryTicks
	) * CombatConfig.FIXED_DT
end

local function getAttackDuration(
	state: AnimationState
): number?

	if state == "Q1" then
		return timingToSeconds(
			MoveDefinitions.getAttackTiming(
				"Q1"
			)
		)
	end

	if state == "Q2" then
		return timingToSeconds(
			MoveDefinitions.getAttackTiming(
				"Q2"
			)
		)
	end

	if state == "Q3" then
		return timingToSeconds(
			MoveDefinitions.getAttackTiming(
				"Q3"
			)
		)
	end

	if state == "Q3Reverse" then
		return timingToSeconds(
			MoveDefinitions.getAttackTiming(
				"Q3Reverse"
			)
		)
	end

	if state == "Strong" then
		return timingToSeconds(
			MoveDefinitions.getAttackTiming(
				"Strong"
			)
		)
	end

	if state == "LandAttack" then
		return timingToSeconds(
			MoveDefinitions.getAttackTiming(
				"LandAttack"
			)
		)
	end

	return nil
end

local function getDesiredDuration(
	state: AnimationState
): number?

	local attackDuration =
		getAttackDuration(
			state
		)

	if attackDuration ~= nil then
		return attackDuration
	end

	if state == "Start" then
		return CombatConfig.STANCE_START_TICKS
			* CombatConfig.FIXED_DT
	end

	if state == "LandNormal" then
		return MovementConfig.NORMAL_LANDING_TICKS
			* CombatConfig.FIXED_DT
	end

	if state == "DashF"
		or state == "DashB"
		or state == "DashL"
		or state == "DashR"
	then
		return DashConfig.DURATION_TICKS
			* CombatConfig.FIXED_DT
	end

	return nil
end

-- =========================================================
-- CUSTOM MODE
-- =========================================================

local customMode = false

local function setCustomMode(
	enabled: boolean
)
	if customMode == enabled then
		return
	end

	customMode = enabled

	if enabled then
		setDefaultAnimateEnabled(
			false
		)

		director.stopUnmanaged(
			0.03
		)

		debugger.setEnabled(
			true
		)

		debugger.scan()

		return
	end

	debugger.setEnabled(
		false
	)

	director.stopAll(
		0.08
	)

	setDefaultAnimateEnabled(
		true
	)
end

-- =========================================================
-- PRESENTATION STATE
-- =========================================================

local previousActionSequence:
	number? = nil

local previousStance:
	string? = nil

local function applyState(
	state: CharacterState
)
	if state.stance == "Inactive" then
		setCustomMode(
			false
		)

		previousActionSequence =
			nil

		previousStance =
			state.stance

		return
	end

	setCustomMode(
		true
	)

	local animationState =
		AnimationResolver.resolve(
			state
		)

	if animationState == nil then
		director.stopAll(
			0.05
		)

		previousActionSequence =
			state.actionSequence

		previousStance =
			state.stance

		return
	end

	local restart = false

	if state.actionSequence ~= nil
		and state.actionSequence
		~= previousActionSequence
	then
		restart = true
	end

	if state.stance == "Starting"
		and previousStance
		~= "Starting"
	then
		restart = true
	end

	director.play(
		animationState,

		getDesiredDuration(
			animationState
		),

		restart
	)

	previousActionSequence =
		state.actionSequence

	previousStance =
		state.stance
end

-- =========================================================
-- EFFECTIVE STATE
-- =========================================================

local disconnect =
	PredictionController.subscribe(
		function(
			current: CharacterState
		)
			applyState(
				current
			)
		end
	)

local initial =
	PredictionController.get()

if initial ~= nil then
	applyState(
		initial
	)
end

-- =========================================================
-- CLEANUP
-- =========================================================

local cleaned = false

local function cleanup()
	if cleaned then
		return
	end

	cleaned = true

	disconnect()

	debugger.destroy()
	director.destroy()
	registry.destroy()
end

script.Destroying:Connect(
	cleanup
)