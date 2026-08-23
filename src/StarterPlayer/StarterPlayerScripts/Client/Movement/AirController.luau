--!strict

local ClientNetwork =
	require(
		script.Parent.Parent.Network.ClientNetwork
	)

local PredictionController =
	require(
		script.Parent.Parent.State.PredictionController
	)

type Network =
	ClientNetwork.Service

type Prediction =
	PredictionController.Controller

local AirController = {}

export type Controller = {
	requestJump: () -> (),
}

function AirController.new(
	network: Network,
	prediction: Prediction
): Controller

	local function requestJump()
		local sequence =
			network.sendIntent(
				"Jump"
			)

		prediction.predict(
			sequence,
			"Jump",
			nil
		)
	end

	return {
		requestJump = requestJump,
	}
end

return AirController