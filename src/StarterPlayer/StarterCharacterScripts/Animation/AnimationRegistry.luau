--!strict

local ContentProvider =
	game:GetService("ContentProvider")

local AnimationCatalog =
	require(
		game:GetService("ReplicatedStorage")
		.Shared.Animation.AnimationCatalog
	)

local AnimationStates =
	require(
		game:GetService("ReplicatedStorage")
		.Shared.Animation.AnimationStates
	)

type AnimationState =
	AnimationStates.AnimationState

local AnimationRegistry = {}

export type Registry = {
	get: (
		state: AnimationState
	) -> AnimationTrack,

	getAllTracks: () -> {AnimationTrack},

	owns: (
		track: AnimationTrack
	) -> boolean,

	destroy: () -> (),
}

function AnimationRegistry.new(
	animator: Animator,
	assetsFolder: Folder
): Registry

	local animationsByName:
		{[string]: Animation} = {}

	local tracksByState:
		{[string]: AnimationTrack} = {}

	local ownedTracks:
		{[AnimationTrack]: boolean} = {}

	-- =====================================================
	-- ASSET
	-- =====================================================

	local function requireAnimation(
		name: string
	): Animation

		local instance =
			assetsFolder:FindFirstChild(
				name
			)

		assert(
			instance ~= nil,
			`Missing Animation object: {name}`
		)

		assert(
			instance:IsA("Animation"),
			`{name} must be an Animation`
		)

		assert(
			instance.AnimationId ~= "",
			`Animation {name} has empty AnimationId`
		)

		animationsByName[name] =
			instance

		return instance
	end

	-- Carregamos apenas os assets realmente usados.
	requireAnimation("Idle")
	requireAnimation("Walk")
	requireAnimation("Start")
	requireAnimation("Jump")
	requireAnimation("Fall")
	requireAnimation("Land")

	requireAnimation("DashF")
	requireAnimation("DashB")
	requireAnimation("DashL")
	requireAnimation("DashR")

	requireAnimation("Q1")
	requireAnimation("Q2")
	requireAnimation("Q3")

	requireAnimation("Strong")

	-- =====================================================
	-- PRELOAD
	-- =====================================================

	local preloadAssets: {Instance} = {}

	for _, animation in pairs(
		animationsByName
		) do
		table.insert(
			preloadAssets,
			animation
		)
	end

	local preloadSuccess,
		preloadError =
		pcall(
			function()
				ContentProvider:PreloadAsync(
					preloadAssets
				)
			end
		)

	if not preloadSuccess then
		warn(
			`[AnimationRegistry] Preload failed: {tostring(preloadError)}`
		)
	end

	-- =====================================================
	-- LOAD STATE
	-- =====================================================

	local function loadState(
		state: AnimationState
	)
		local definition =
			AnimationCatalog.get(
				state
			)

		local animation =
			animationsByName[
		definition.objectName
		]

		assert(
			animation ~= nil,
			`Animation asset missing for {state}`
		)

		-- LoadAnimation acontece UMA vez para
		-- este estado durante o spawn.
		local track =
			animator:LoadAnimation(
				animation
			)

		tracksByState[state] =
			track

		ownedTracks[track] =
			true
	end

	-- Mesmo quando dois estados usam o mesmo Animation
	-- asset, cada estado lógico recebe seu próprio track.
	--
	-- Isso permite crossfade Q3 -> Q3Reverse e
	-- Jump -> LandNormal.
	loadState("Idle")
	loadState("Walk")
	loadState("Start")

	loadState("Jump")
	loadState("Fall")
	loadState("LandNormal")
	loadState("LandAttack")

	loadState("DashF")
	loadState("DashB")
	loadState("DashL")
	loadState("DashR")

	loadState("Q1")
	loadState("Q2")
	loadState("Q3")
	loadState("Q3Reverse")

	loadState("Strong")

	-- =====================================================
	-- GET
	-- =====================================================

	local function get(
		state: AnimationState
	): AnimationTrack

		local track =
			tracksByState[state]

		assert(
			track ~= nil,
			`Animation track missing: {state}`
		)

		return track
	end

	-- =====================================================
	-- ALL TRACKS
	-- =====================================================

	local function getAllTracks():
		{AnimationTrack}

		local result:
			{AnimationTrack} = {}

		for _, track in pairs(
			tracksByState
			) do
			table.insert(
				result,
				track
			)
		end

		return result
	end

	-- =====================================================
	-- OWNERSHIP
	-- =====================================================

	local function owns(
		track: AnimationTrack
	): boolean

		return ownedTracks[track]
			== true
	end

	-- =====================================================
	-- DESTROY
	-- =====================================================

	local function destroy()
		for _, track in pairs(
			tracksByState
			) do
			track:Destroy()
		end

		table.clear(
			tracksByState
		)

		table.clear(
			ownedTracks
		)

		table.clear(
			animationsByName
		)
	end

	return {
		get = get,

		getAllTracks =
			getAllTracks,

		owns = owns,

		destroy = destroy,
	}
end

return AnimationRegistry