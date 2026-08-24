--!strict

local Players =
	game:GetService("Players")

local RunService =
	game:GetService("RunService")

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

local AnimationCatalog =
	require(
		Shared.Animation.AnimationCatalog
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
-- PLAYER SCRIPTS
-- =========================================================

local playerScripts =
	player:WaitForChild(
		"PlayerScripts"
	)

local clientFolder =
	playerScripts:WaitForChild(
		"Client"
	)

local predictionModule =
	clientFolder
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

local eventBusModule =
	clientFolder
	:WaitForChild("Events")
	:WaitForChild(
		"ClientEventBus"
	)

assert(
	eventBusModule:IsA("ModuleScript"),
	"ClientEventBus must be ModuleScript"
)

local ClientEventBus =
	require(
		eventBusModule
	)

-- =========================================================
-- HUMANOID / ROOT / ANIMATOR
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

local rootInstance =
	character:WaitForChild(
		"HumanoidRootPart"
	)

assert(
	rootInstance:IsA("BasePart"),
	"HumanoidRootPart missing"
)

local root: BasePart =
	rootInstance

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

local function getNaturalDuration(
	state: AnimationState
): number

	local track =
		registry.get(
			state
		)

	local definition =
		AnimationCatalog.get(
			state
		)

	local speed =
		math.abs(
			definition.speed
		)

	if speed <= 0 then
		speed = 1
	end

	if track.Length > 0 then
		return track.Length
			/ speed
	end

	-- Segurança para o raro caso de Length ainda estar 0
	-- no primeiro frame depois do preload.
	return getDesiredDuration(state)
		or 0.5
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
			0.02
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
		0.06
	)

	setDefaultAnimateEnabled(
		true
	)
end

-- =========================================================
-- LOCAL PHYSICAL PRESENTATION
-- =========================================================

local LANDING_MIN_AIR_TIME = 0.06

local normalLandingDuration =
	MovementConfig.NORMAL_LANDING_TICKS
	* CombatConfig.FIXED_DT

local wasGrounded =
	humanoid.FloorMaterial
	~= Enum.Material.Air

local airborneStartedAt:
	number? = nil

local landingUntil = 0

-- Quando um clique foi feito no ar, o pouso deve usar
-- exclusivamente LandAttack. O pouso normal (Jump reverso)
-- fica suprimido para esse contato com o chão.
local localLandingAttackArmed = false

local function updateGroundContact(
	now: number
)
	local grounded =
		humanoid.FloorMaterial
		~= Enum.Material.Air

	if grounded == wasGrounded then
		return
	end

	if grounded then
		local airborneDuration = 0

		if airborneStartedAt ~= nil then
			airborneDuration =
				now
				- airborneStartedAt
		end

		if airborneDuration
			>= LANDING_MIN_AIR_TIME
			and not localLandingAttackArmed
		then
			landingUntil =
				now
				+ normalLandingDuration
		else
			-- LandAttack substitui completamente o
			-- pouso normal neste contato com o chão.
			landingUntil = 0
		end

		airborneStartedAt = nil
	else
		airborneStartedAt =
			now

		landingUntil = 0
	end

	wasGrounded =
		grounded
end

local function resolvePhysicalAnimation(
	now: number
): (AnimationState, number?)

	local humanoidState =
		humanoid:GetState()

	if humanoidState
		== Enum.HumanoidStateType.Jumping
	then
		return "Jump", nil
	end

	local grounded =
		humanoid.FloorMaterial
		~= Enum.Material.Air

	if not grounded then
		local verticalVelocity =
			root.AssemblyLinearVelocity.Y

		if verticalVelocity > 0.5 then
			return "Jump", nil
		end

		return "Fall", nil
	end

	if now < landingUntil then
		return "LandNormal",
			normalLandingDuration
	end

	if humanoid.MoveDirection.Magnitude
		> MovementConfig.WALKING_SPEED_THRESHOLD
	then
		return "Walk", nil
	end

	return "Idle", nil
end

-- =========================================================
-- LOCAL ANIMATION PREVIEW
-- =========================================================

local previewState:
	AnimationState? = nil

local previewRequestedDuration:
	number? = nil

local previewUntil = 0
local previewGeneration = 0
local previewRestartPending = false

local PREVIEWABLE:
	{[string]: boolean} = {
	Q1 = true,
	Q2 = true,
	Q3 = true,
	Q3Reverse = true,

	Strong = true,
	LandAttack = true,

	DashF = true,
	DashB = true,
	DashL = true,
	DashR = true,
}

local function clearPreview()
	previewGeneration += 1

	previewState = nil
	previewRequestedDuration = nil
	previewUntil = 0
	previewRestartPending = false
end

-- =========================================================
-- PRESENTATION STATE
-- =========================================================

local latestState:
	CharacterState? = nil

local previousActionSequence:
	number? = nil

local previousStance:
	string? = nil

local function resolvePresentation(
	state: CharacterState,
	now: number
): (AnimationState?, number?)

	if state.status == "Dead" then
		return nil, nil
	end

	if state.stance == "Inactive" then
		return nil, nil
	end

	-- Start nunca deve ser atropelado por preview local.
	if state.stance == "Starting" then
		return "Start",
			getDesiredDuration(
				"Start"
			)
	end

	-- Ação autoritativa de duelo tem prioridade máxima.
	if state.action ~= nil then
		local resolved =
			AnimationResolver.resolve(
				state
			)

		if resolved == nil then
			return nil, nil
		end

		return resolved,
			getDesiredDuration(
				resolved
			)
	end

	-- Preview local existe somente fora de duelo.
	if state.duelId == nil
		and previewState ~= nil
		and now < previewUntil
	then
		return previewState,
			previewRequestedDuration
	end

	return resolvePhysicalAnimation(
		now
	)
end

local function refreshPresentation()
	local state =
		latestState

	if state == nil then
		return
	end

	if state.stance == "Inactive" then
		clearPreview()

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

	local now =
		os.clock()

	updateGroundContact(
		now
	)

	if previewState ~= nil
		and now >= previewUntil
	then
		clearPreview()
	end

	local animationState,
		duration =
		resolvePresentation(
			state,
			now
		)

	if animationState == nil then
		director.stopAll(
			0.04
		)

		previousActionSequence =
			state.actionSequence

		previousStance =
			state.stance

		return
	end

	local restart =
		previewRestartPending

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
		duration,
		restart
	)

	previewRestartPending =
		false

	previousActionSequence =
		state.actionSequence

	previousStance =
		state.stance
end

-- =========================================================
-- EFFECTIVE STATE
-- =========================================================

local predictionDisconnect =
	PredictionController.subscribe(
		function(
			current: CharacterState
		)
			latestState =
				current

			refreshPresentation()
		end
	)

local initial =
	PredictionController.get()

if initial ~= nil then
	latestState =
		initial

	refreshPresentation()
end

-- =========================================================
-- LAND ATTACK ARM EVENT
-- =========================================================

local landingAttackDisconnect =
	ClientEventBus.subscribe(
		"LandingAttackArmed",

		function(data: any)
			if type(data) ~= "boolean" then
				return
			end

			localLandingAttackArmed =
				data

			if data then
				-- Evita qualquer frame de LandNormal antes
				-- do preview de LandAttack começar.
				landingUntil = 0
			end
		end
	)

-- =========================================================
-- PREVIEW EVENT
-- =========================================================

local previewDisconnect =
	ClientEventBus.subscribe(
		"AnimationPreview",

		function(data: any)
			if type(data) ~= "table" then
				return
			end

			local stateName =
				data.state

			if type(stateName) ~= "string" then
				return
			end

			if PREVIEWABLE[stateName]
				~= true
			then
				return
			end

			local requestedDuration:
				number? = nil

			if type(data.durationSeconds)
				== "number"
				and data.durationSeconds > 0
			then
				requestedDuration =
					data.durationSeconds
			end

			local state =
				stateName :: AnimationState

			if state == "LandAttack" then
				localLandingAttackArmed =
					false

				landingUntil = 0
			end

			previewGeneration += 1

			local token =
				previewGeneration

			previewState =
				state

			previewRequestedDuration =
				requestedDuration

			local holdDuration =
				requestedDuration
				or getNaturalDuration(
					state
				)

			previewUntil =
				os.clock()
				+ holdDuration

			previewRestartPending =
				true

			refreshPresentation()

			task.delay(
				holdDuration,

				function()
					if previewGeneration
						~= token
					then
						return
					end

					previewState = nil
					previewRequestedDuration = nil
					previewUntil = 0

					refreshPresentation()
				end
			)
		end
	)

-- =========================================================
-- FRAME-LOCAL LOCOMOTION / AIR
-- =========================================================

local renderConnection =
	RunService.RenderStepped:Connect(
		function()
			if latestState == nil then
				return
			end

			refreshPresentation()
		end
	)

-- =========================================================
-- CLEANUP
-- =========================================================

local cleaned = false

local function cleanup()
	if cleaned then
		return
	end

	cleaned = true

	predictionDisconnect()
	landingAttackDisconnect()
	previewDisconnect()

	renderConnection:Disconnect()

	debugger.destroy()
	director.destroy()
	registry.destroy()
end

script.Destroying:Connect(
	cleanup
)
