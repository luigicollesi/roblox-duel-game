--!strict

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local serverFolder =
	script.Parent:WaitForChild(
		"Server"
	)

local EventBus =
	require(
		serverFolder.Events.EventBus
	)

local CharacterStateStore =
	require(
		serverFolder.Character.CharacterStateStore
	)

local CharacterService =
	require(
		serverFolder.Character.CharacterService
	)

local StanceService =
	require(
		serverFolder.Character.StanceService
	)

local StanceInputService =
	require(
		serverFolder.Character.StanceInputService
	)

local MovementSystem =
	require(
		serverFolder.Movement.MovementSystem
	)

local DuelService =
	require(
		serverFolder.Duels.DuelService
	)

local DuelEngine =
	require(
		serverFolder.Duels.DuelEngine
	)

local RateLimiter =
	require(
		serverFolder.Network.RateLimiter
	)

local InputGateway =
	require(
		serverFolder.Network.InputGateway
	)

local ReplicationService =
	require(
		serverFolder.Network.ReplicationService
	)

-- =========================================================
-- NETWORK
-- =========================================================

local networkFolder =
	ReplicatedStorage:WaitForChild(
		"Network"
	)

local intentInstance =
	networkFolder:WaitForChild(
		"IntentRemote"
	)

assert(
	intentInstance:IsA("RemoteEvent")
)

local intentRemote: RemoteEvent =
	intentInstance

local stateInstance =
	networkFolder:WaitForChild(
		"StateRemote"
	)

assert(
	stateInstance:IsA("RemoteEvent")
)

local stateRemote: RemoteEvent =
	stateInstance

local effectInstance =
	networkFolder:WaitForChild(
		"EffectRemote"
	)

assert(
	effectInstance:IsA(
		"UnreliableRemoteEvent"
	)
)

local effectRemote:
	UnreliableRemoteEvent =
	effectInstance

-- =========================================================
-- CORE
-- =========================================================

local bus =
	EventBus.new()

local store =
	CharacterStateStore.new(
		bus
	)

local characters =
	CharacterService.new(
		store,
		bus
	)

local stance =
	StanceService.new(
		store,
		bus
	)

local stanceInput =
	StanceInputService.new(
		store,
		bus,
		stance
	)

local movement =
	MovementSystem.new(
		store,
		bus,
		characters
	)

local duels =
	DuelService.new(
		store,
		bus,
		characters,
		stance
	)

local engine =
	DuelEngine.new(
		store,
		bus,
		stance,
		characters
	)

local limiter =
	RateLimiter.new()

local gateway =
	InputGateway.new(
		bus,
		duels,
		limiter,
		intentRemote
	)

local replication =
	ReplicationService.new(
		store,
		bus,
		stateRemote,
		effectRemote
	)

-- =========================================================
-- START
-- =========================================================

replication.start()

stanceInput.start()
movement.start()
engine.start()

characters.start()
duels.start()
gateway.start()

print(
	"[ServerBootstrap] Server started"
)

-- =========================================================
-- SHUTDOWN
-- =========================================================

game:BindToClose(
	function()
		gateway.stop()

		duels.stop()
		engine.stop()

		movement.stop()
		stanceInput.stop()

		characters.stop()

		replication.stop()
	end
)
