--!strict

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local CharacterStateTypes =
	require(
		ReplicatedStorage.Shared.State.CharacterStateTypes
	)

local AnimationStates =
	require(
		ReplicatedStorage.Shared.Animation.AnimationStates
	)

type CharacterState =
	CharacterStateTypes.CharacterState

type AnimationState =
	AnimationStates.AnimationState

local AnimationResolver = {}

function AnimationResolver.resolve(
	state: CharacterState
): AnimationState?

	-- =====================================================
	-- DEAD
	-- =====================================================

	if state.status == "Dead" then
		return nil
	end

	-- =====================================================
	-- OUTSIDE CUSTOM STANCE
	-- =====================================================

	if state.stance == "Inactive" then
		return nil
	end

	-- =====================================================
	-- ACTION
	-- =====================================================

	local action =
		state.action

	if action == "Q1" then
		return "Q1"
	end

	if action == "Q2" then
		return "Q2"
	end

	if action == "Q3" then
		return "Q3"
	end

	if action == "Q3Reverse" then
		return "Q3Reverse"
	end

	if action == "Strong" then
		return "Strong"
	end

	if action == "LandAttack" then
		return "LandAttack"
	end

	if action == "DashF" then
		return "DashF"
	end

	if action == "DashB" then
		return "DashB"
	end

	if action == "DashL" then
		return "DashL"
	end

	if action == "DashR" then
		return "DashR"
	end

	-- =====================================================
	-- AIR
	-- =====================================================

	if state.air == "Jumping" then
		return "Jump"
	end

	if state.air == "Falling" then
		return "Fall"
	end

	if state.air == "Landing" then
		return "LandNormal"
	end

	-- =====================================================
	-- STANCE ENTRY
	-- =====================================================

	if state.stance == "Starting" then
		return "Start"
	end

	-- =====================================================
	-- LOCOMOTION
	-- =====================================================

	if state.locomotion == "Walking" then
		return "Walk"
	end

	return "Idle"
end

return AnimationResolver