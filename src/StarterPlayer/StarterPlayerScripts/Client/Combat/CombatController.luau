--!strict

local CombatTypes =
	require(
		game:GetService("ReplicatedStorage")
		.Shared.Combat.CombatTypes
	)

local ClientNetwork =
	require(
		script.Parent.Parent.Network.ClientNetwork
	)

local PredictionController =
	require(
		script.Parent.Parent.State.PredictionController
	)

local ActionBuffer =
	require(
		script.Parent.Parent.Input.ActionBuffer
	)

type BufferedAttackKind =
	CombatTypes.BufferedAttackKind

type Network =
	ClientNetwork.Service

type Prediction =
	PredictionController.Controller

type Buffer =
	ActionBuffer.Buffer

local CombatController = {}

export type Controller = {
	requestLight: () -> (),
	requestStrong: () -> (),
}

function CombatController.new(
	network: Network,
	prediction: Prediction,
	buffer: Buffer
): Controller

	local function request(
		kind: BufferedAttackKind
	)
		local before =
			prediction.get()

		local sequence =
			network.sendIntent(
				kind
			)

		-- Se já existe ataque no chão, o servidor
		-- tratará como buffer.
		if before ~= nil
			and before.action ~= nil
			and before.air == "Grounded"
		then
			buffer.put(
				kind,
				sequence
			)
		end

		prediction.predict(
			sequence,
			kind,
			nil
		)
	end

	return {
		requestLight =
			function()
				request("Light")
			end,

		requestStrong =
			function()
				request("Strong")
			end,
	}
end

return CombatController