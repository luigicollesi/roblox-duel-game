--!strict

local ClientNetwork =
	require(
		script.Parent.Parent.Network.ClientNetwork
	)

local PredictionController =
	require(
		script.Parent.Parent.State.PredictionController
	)

local LocomotionController =
	require(
		script.Parent.LocomotionController
	)

type Network =
	ClientNetwork.Service

type Prediction =
	PredictionController.Controller

type Locomotion =
	LocomotionController.Controller

local DashController = {}

export type Controller = {
	requestDash: () -> (),
}

function DashController.new(
	network: Network,
	prediction: Prediction,
	locomotion: Locomotion
): Controller

	local function requestDash()
		local predictedAction =
			locomotion.resolveDashAction()

		local sequence =
			network.sendIntent(
				"Dash"
			)

		prediction.predict(
			sequence,
			"Dash",
			predictedAction
		)
	end

	return {
		requestDash = requestDash,
	}
end

return DashController