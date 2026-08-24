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

local LocalBoxController =
	require(
		clientFolder.Animation.LocalBoxController
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

local StanceCameraController =
	require(
		clientFolder.Camera.StanceCameraController
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

-- Preview local usado somente quando ainda não existe duelo.
-- Ele serve para validar animações/movimento sem criar uma
-- segunda implementação de dano.
local localBox =
	LocalBoxController.new(
		player,
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

local stanceCamera =
	StanceCameraController.new(
		player,
		PredictionController
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

	if state.stance ~= "Active" then
		return false
	end

	if state.status ~= "Normal" then
		return false
	end

	-- Animação/movimento podem ser testados em stance
	-- mesmo antes de um duelo existir.
	return true
end

local function isInDuel():
	boolean

	local state =
		PredictionController.get()

	return state ~= nil
		and state.duelId ~= nil
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

	-- Fora de duelo, um ataque/dash local comprometido
	-- precisa terminar antes de permitir sair da stance.
	if state.duelId == nil
		and localBox.isBusy()
	then
		return
	end

	-- Em duelo, a mesma regra vem do estado autoritativo.
	if state.action ~= nil then
		return
	end

	network.sendIntent(
		"Stance"
	)
end

local function requestLight()
	if isInDuel() then
		combat.requestLight()
		return
	end

	localBox.requestLight()
end

local function requestStrong()
	if isInDuel() then
		combat.requestStrong()
		return
	end

	localBox.requestStrong()
end

local function requestDash()
	if isInDuel() then
		dash.requestDash()
		return
	end

	-- Só avisa o servidor se o dash local realmente começou.
	-- O servidor usa esse aviso exclusivamente para VFX.
	if localBox.requestDash() then
		network.sendIntent(
			"Dash"
		)
	end
end

local function requestJump()
	if isInDuel() then
		air.requestJump()
		return
	end

	localBox.requestJump()
end

local input =
	InputController.new(
		shouldCaptureGameplay,

		{
			stance =
				requestStance,

			light =
				requestLight,

			strong =
				requestStrong,

			dash =
				requestDash,

			jump =
				requestJump,
		}
	)

-- =========================================================
-- START ORDER
-- =========================================================

reconciliation.start()

vfx.start()
sound.start()
camera.start()
stanceCamera.start()

network.start()

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

		localBox.destroy()

		network.stop()

		reconciliation.stop()

		stanceCamera.stop()
		camera.stop()
		sound.stop()
		vfx.stop()

		actionBuffer.clear()

		PredictionController.clear()
	end
)
