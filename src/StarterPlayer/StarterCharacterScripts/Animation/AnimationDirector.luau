--!strict

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local AnimationCatalog =
	require(
		ReplicatedStorage.Shared.Animation.AnimationCatalog
	)

local AnimationTransitions =
	require(
		ReplicatedStorage.Shared.Animation.AnimationTransitions
	)

local AnimationStates =
	require(
		ReplicatedStorage.Shared.Animation.AnimationStates
	)

local AnimationRegistry =
	require(
		script.Parent.AnimationRegistry
	)

type AnimationState =
	AnimationStates.AnimationState

type Registry =
	AnimationRegistry.Registry

local AnimationDirector = {}

export type Director = {
	play: (
		state: AnimationState,
		durationSeconds: number?,
		restart: boolean?
	) -> boolean,

	stopAll: (
		fadeTime: number?
	) -> (),

	stopUnmanaged: (
		fadeTime: number?
	) -> (),

	stopExternal: (
		track: AnimationTrack,
		fadeTime: number?
	) -> (),

	getCurrentState: () -> AnimationState?,

	destroy: () -> (),
}

function AnimationDirector.new(
	animator: Animator,
	registry: Registry
): Director

	local currentState:
		AnimationState? = nil

	local currentTrack:
		AnimationTrack? = nil

	-- Token para futuras operações assíncronas.
	local generation = 0

	-- =====================================================
	-- SPEED
	-- =====================================================

	local function calculateSpeed(
		track: AnimationTrack,
		baseSpeed: number,
		durationSeconds: number?
	): number

		local sign =
			if baseSpeed < 0
			then -1
			else 1

		local defaultMagnitude =
			math.abs(baseSpeed)

		if defaultMagnitude <= 0 then
			defaultMagnitude = 1
		end

		if durationSeconds == nil
			or durationSeconds <= 0
			or track.Length <= 0
		then
			return sign
				* defaultMagnitude
		end

		return sign
			* (
				track.Length
				/ durationSeconds
			)
	end

	-- =====================================================
	-- PLAY
	-- =====================================================

	local function play(
		state: AnimationState,
		durationSeconds: number?,
		restart: boolean?
	): boolean

		local shouldRestart =
			restart == true

		if currentState == state
			and not shouldRestart
		then
			return false
		end

		generation += 1

		local definition =
			AnimationCatalog.get(
				state
			)

		local nextTrack =
			registry.get(state)

		local fade =
			AnimationTransitions.getFade(
				currentState,
				state
			)

		-- -----------------------------------------------
		-- STOP OLD
		-- -----------------------------------------------

		if currentTrack ~= nil then
			if currentTrack
				== nextTrack
			then
				-- Recomeçando o mesmo track.
				currentTrack:Stop(0)
			else
				currentTrack:Stop(
					fade
				)
			end
		end

		currentState =
			state

		currentTrack =
			nextTrack

		-- -----------------------------------------------
		-- CONFIG
		-- -----------------------------------------------

		nextTrack.Priority =
			definition.priority

		nextTrack.Looped =
			definition.looped

		local speed =
			calculateSpeed(
				nextTrack,
				definition.speed,
				durationSeconds
			)

		-- -----------------------------------------------
		-- REVERSE
		-- -----------------------------------------------

		if definition.startAtEnd then
			-- Primeiro iniciamos congelada para termos
			-- um track ativo antes de mudar TimePosition.
			nextTrack:Play(
				fade,
				1,
				0
			)

			if nextTrack.Length > 0 then
				nextTrack.TimePosition =
					math.max(
						0,
						nextTrack.Length
						- 0.001
					)
			else
				warn(
					`[AnimationDirector] Track {state} has Length 0`
				)
			end

			nextTrack:AdjustSpeed(
				speed
			)

			return true
		end

		-- -----------------------------------------------
		-- FORWARD
		-- -----------------------------------------------

		nextTrack:Play(
			fade,
			1,
			speed
		)

		return true
	end

	-- =====================================================
	-- STOP ALL MANAGED
	-- =====================================================

	local function stopAll(
		fadeTime: number?
	)
		generation += 1

		local fade =
			fadeTime or 0

		for _, track in ipairs(
			registry.getAllTracks()
			) do
			if track.IsPlaying
				or track.WeightCurrent > 0.001
			then
				track:Stop(
					fade
				)
			end
		end

		currentState = nil
		currentTrack = nil
	end

	-- =====================================================
	-- STOP UNMANAGED
	-- =====================================================

	local function stopUnmanaged(
		fadeTime: number?
	)
		local fade =
			fadeTime or 0

		for _, track in ipairs(
			animator:GetPlayingAnimationTracks()
			) do
			if registry.owns(track) then
				continue
			end

			track:Stop(
				fade
			)
		end
	end

	-- =====================================================
	-- EXTERNAL TRACK
	-- =====================================================

	local function stopExternal(
		track: AnimationTrack,
		fadeTime: number?
	)
		if registry.owns(track) then
			return
		end

		track:Stop(
			fadeTime or 0
		)
	end

	-- =====================================================
	-- GET
	-- =====================================================

	local function getCurrentState():
		AnimationState?

		return currentState
	end

	-- =====================================================
	-- DESTROY
	-- =====================================================

	local function destroy()
		stopAll(0)
	end

	return {
		play = play,

		stopAll = stopAll,
		stopUnmanaged = stopUnmanaged,

		stopExternal = stopExternal,

		getCurrentState =
			getCurrentState,

		destroy = destroy,
	}
end

return AnimationDirector