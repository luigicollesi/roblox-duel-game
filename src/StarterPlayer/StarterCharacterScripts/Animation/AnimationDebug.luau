--!strict

local AnimationRegistry =
	require(
		script.Parent.AnimationRegistry
	)

type Registry =
	AnimationRegistry.Registry

local AnimationDebug = {}

export type UnauthorizedHandler =
	(AnimationTrack) -> ()

export type Debugger = {
	setEnabled: (
		enabled: boolean
	) -> (),

	scan: () -> (),

	destroy: () -> (),
}

-- =========================================================
-- FACTORY
-- =========================================================

function AnimationDebug.new(
	animator: Animator,
	registry: Registry,
	onUnauthorized: UnauthorizedHandler
): Debugger

	local enabled = false

	-- =====================================================
	-- TRACK NAME
	-- =====================================================

	local function getTrackName(
		track: AnimationTrack
	): string

		-- A documentação atual apresenta
		-- AnimationTrack.Animation como Animation,
		-- mas algumas versões do analyzer do Studio
		-- ainda expõem Animation? ao typechecker.
		local animation =
			track.Animation

		if animation == nil then
			return "<unknown>"
		end

		return animation.Name
	end

	-- =====================================================
	-- CHECK TRACK
	-- =====================================================

	local function checkTrack(
		track: AnimationTrack
	)
		if not enabled then
			return
		end

		if registry.owns(
			track
			) then
			return
		end

		local animationName =
			getTrackName(
				track
			)

		warn(
			`[AnimationDebug] Unauthorized track playing: {animationName}`
		)

		onUnauthorized(
			track
		)
	end

	-- =====================================================
	-- ANIMATION PLAYED
	-- =====================================================

	local playedConnection =
		animator.AnimationPlayed:Connect(
			function(
				track: AnimationTrack
			)
				checkTrack(
					track
				)
			end
		)

	-- =====================================================
	-- ENABLE
	-- =====================================================

	local function setEnabled(
		value: boolean
	)
		enabled = value
	end

	-- =====================================================
	-- SCAN
	-- =====================================================

	local function scan()
		if not enabled then
			return
		end

		local playingTracks =
			animator:GetPlayingAnimationTracks()

		for _, track in ipairs(
			playingTracks
			) do
			checkTrack(
				track
			)
		end
	end

	-- =====================================================
	-- DESTROY
	-- =====================================================

	local function destroy()
		enabled = false

		playedConnection:Disconnect()
	end

	return {
		setEnabled = setEnabled,

		scan = scan,

		destroy = destroy,
	}
end

return AnimationDebug