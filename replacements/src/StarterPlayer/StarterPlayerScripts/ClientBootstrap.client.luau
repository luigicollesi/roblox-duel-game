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

local clientFolder =
	script.Parent:WaitForChild(
		"Client"
	)

-- =========================================================
-- MODULES
-- =========================================================

local ClientStateStore =
	require(
		clientFolder.State.ClientStateStore
	)

local PredictionController =
	require(
		clientFolder.State.PredictionController
	)

local ClientNetwork =
	require(
		clientFolder.Network.ClientNetwork
	)

local Reconciliation =
	require(
		clientFolder.Network.Reconciliation
	)

local ActionBuffer =
	require(
		clientFolder.Input.ActionBuffer
	)

local InputController =
	require(
		clientFolder.Input.InputController
	)

local CombatController =
	require(
		clientFolder.Combat.CombatController
	)

local LocomotionController =
	require(
		clientFolder.Movement.LocomotionController
	)

local DashController =
	require(
		clientFolder.Movement.DashController
	)

local AirController =
	require(
		clientFolder.Movement.AirController
	)

local VFXController =
	require(
		clientFolder.Effects.VFXController
	)

local SoundController =
	require(
		clientFolder.Effects.SoundController
	)

local CameraController =
	require(
		clientFolder.Effects.CameraController
	)

-- =========================================================
-- REMOTES
-- =========================================================

local networkFolder =
	ReplicatedStorage:WaitForChild(
		"Network"
	)

local intentRemoteInstance =
	networkFolder:WaitForChild(
		"IntentRemote"
	)

assert(
	intentRemoteInstance:IsA("RemoteEvent"),
	"IntentRemote must be RemoteEvent"
)

local intentRemote: RemoteEvent =
	intentRemoteInstance

local stateRemoteInstance =
	networkFolder:WaitForChild(
		"StateRemote"
	)

assert(
	stateRemoteInstance:IsA("RemoteEvent"),
	"StateRemote must be RemoteEvent"
)

local stateRemote: RemoteEvent =
	stateRemoteInstance

local effectRemoteInstance =
	networkFolder:WaitForChild(
		"EffectRemote"
	)

assert(
	effectRemoteInstance:IsA(
		"UnreliableRemoteEvent"
	),
	"EffectRemote must be UnreliableRemoteEvent"
)

local effectRemote:
	UnreliableRemoteEvent =
	effectRemoteInstance

-- =========================================================
-- STATE / NETWORK
-- =========================================================

local localUserId =
	player.UserId

PredictionController.initialize(
	localUserId,
	ClientStateStore
)

local actionBuffer =
	ActionBuffer.new()

local network =
	ClientNetwork.new(
		intentRemote,
		stateRemote,
		effectRemote,
		ClientStateStore
	)

local reconciliation =
	Reconciliation.new(
		localUserId,
		ClientStateStore,
		PredictionController,
		actionBuffer
	)

-- =========================================================
-- GAMEPLAY CONTROLLERS
-- =========================================================

local locomotion =
	LocomotionController.new(
		player
	)

local combat =
	CombatController.new(
		network,
		PredictionController,
		actionBuffer
	)

local air =
	AirController.new(
		network,
		PredictionController
	)

local dash =
	DashController.new(
		network,
		PredictionController,
		locomotion
	)

-- =========================================================
-- EFFECTS
-- =========================================================

local vfx =
	VFXController.new()

local sound =
	SoundController.new()

local camera =
	CameraController.new(
		localUserId
	)

-- =========================================================
-- INPUT
-- =========================================================

local function shouldCaptureGameplay():
	boolean
	local state =
		PredictionController.get()

	if state == nil then
		return false
	end

	if state.duelId == nil then
		return false
	end

	if state.stance ~= "Active" then
		return false
	end

	if state.status == "Dead" then
		return false
	end

	return true
end

local function requestStance()
	local state =
		PredictionController.get()

	if state == nil then
		return
	end

	if state.status == "Dead" then
		return
	end

	network.sendIntent(
		"Stance"
	)
end

local input =
	InputController.new(
		shouldCaptureGameplay,

		{
			stance =
				requestStance,

			light =
				combat.requestLight,

			strong =
				combat.requestStrong,

			dash =
				dash.requestDash,

			jump =
				air.requestJump,
		}
	)

-- =========================================================
-- START ORDER
-- =========================================================

reconciliation.start()

vfx.start()
sound.start()
camera.start()

network.start()

-- Input por último para não enviar nada antes
-- de toda a infraestrutura estar pronta.
input.start()

print(
	"[ClientBootstrap] Client started"
)

-- =========================================================
-- CLEANUP
-- =========================================================

script.Destroying:Connect(
	function()
		input.stop()

		network.stop()

		reconciliation.stop()

		camera.stop()
		sound.stop()
		vfx.stop()

		actionBuffer.clear()

		PredictionController.clear()
	end
)
