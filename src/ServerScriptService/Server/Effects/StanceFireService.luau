--!strict

local Debris =
	game:GetService("Debris")

local RunService =
	game:GetService("RunService")

local Workspace =
	game:GetService("Workspace")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local DashConfig =
	require(
		ReplicatedStorage.Shared.Movement.DashConfig
	)

local CombatConfig =
	require(
		ReplicatedStorage.Shared.Combat.CombatConfig
	)

local CharacterStateStore =
	require(
		script.Parent.Parent.Character.CharacterStateStore
	)

local CharacterService =
	require(
		script.Parent.Parent.Character.CharacterService
	)

local EventBus =
	require(
		script.Parent.Parent.Events.EventBus
	)

type Store =
	CharacterStateStore.Store

type Characters =
	CharacterService.Service

type Bus =
	EventBus.Bus

type Disconnect =
	EventBus.Disconnect

local StanceFireService = {}

export type Service = {
	start: () -> (),
	stop: () -> (),
}

local STANCE_ATTACHMENT_NAME =
	"BoxStanceFireAttachment"

local STANCE_EMITTER_NAME =
	"BoxStanceFireEmitter"

local STANCE_LIGHT_NAME =
	"BoxStanceFireLight"

local DASH_ATTACHMENT_NAME =
	"BoxDashFireAttachment"

local DASH_EMITTER_NAME =
	"BoxDashFireEmitter"

local TRAIL_FOLDER_NAME =
	"DashFireTrails"

local FIRE_TEXTURE =
	"rbxasset://textures/particles/fire_main.dds"

local TRAIL_LIFETIME = 5
local TRAIL_SAMPLE_INTERVAL = 0.05

local DASH_DURATION =
	DashConfig.DURATION_TICKS
	* CombatConfig.FIXED_DT

local DASH_COOLDOWN =
	DashConfig.COOLDOWN_TICKS
	* CombatConfig.FIXED_DT

local STANCE_PARTS = {
	"LeftHand",
	"RightHand",
	"LeftLowerArm",
	"RightLowerArm",
}

local HAND_PARTS = {
	LeftHand = true,
	RightHand = true,
}

type DashRuntime = {
	endAt: number,
	nextSampleAt: number,
}

function StanceFireService.new(
	store: Store,
	bus: Bus,
	characters: Characters
): Service

	local started = false

	local disconnects:
		{Disconnect} = {}

	local heartbeatConnection:
		RBXScriptConnection? = nil

	local dashRuntimeByUser:
		{[number]: DashRuntime} = {}

	local nextSoloDashAt:
		{[number]: number} = {}

	local trailFolder:
		Folder? = nil

	-- =====================================================
	-- TRAIL FOLDER
	-- =====================================================

	local function getTrailFolder():
		Folder

		if trailFolder ~= nil
			and trailFolder.Parent ~= nil
		then
			return trailFolder
		end

		local existing =
			Workspace:FindFirstChild(
				TRAIL_FOLDER_NAME
			)

		if existing ~= nil
			and existing:IsA("Folder")
		then
			trailFolder =
				existing

			return existing
		end

		local folder =
			Instance.new("Folder")

		folder.Name =
			TRAIL_FOLDER_NAME

		folder.Parent =
			Workspace

		trailFolder =
			folder

		return folder
	end

	-- =====================================================
	-- FIRE HELPERS
	-- =====================================================

	local function buildColorSequence():
		ColorSequence

		return ColorSequence.new({
			ColorSequenceKeypoint.new(
				0,
				Color3.fromRGB(
					255,
					235,
					115
				)
			),

			ColorSequenceKeypoint.new(
				0.45,
				Color3.fromRGB(
					255,
					120,
					25
				)
			),

			ColorSequenceKeypoint.new(
				1,
				Color3.fromRGB(
					180,
					30,
					5
				)
			),
		})
	end

	local function buildTransparency():
		NumberSequence

		return NumberSequence.new({
			NumberSequenceKeypoint.new(
				0,
				0.05
			),

			NumberSequenceKeypoint.new(
				0.7,
				0.18
			),

			NumberSequenceKeypoint.new(
				1,
				1
			),
		})
	end

	local function createEmitter(
		parent: Attachment,
		name: string,
		rate: number,
		minSize: number,
		maxSize: number,
		lockedToPart: boolean
	): ParticleEmitter

		local emitter =
			Instance.new(
				"ParticleEmitter"
			)

		emitter.Name =
			name

		emitter.Texture =
			FIRE_TEXTURE

		emitter.Color =
			buildColorSequence()

		emitter.Transparency =
			buildTransparency()

		emitter.LightEmission =
			0.9

		emitter.LightInfluence =
			0

		emitter.Rate =
			rate

		emitter.Lifetime =
			NumberRange.new(
				0.22,
				0.42
			)

		emitter.Speed =
			NumberRange.new(
				0.8,
				2.2
			)

		emitter.SpreadAngle =
			Vector2.new(
				40,
				40
			)

		emitter.Rotation =
			NumberRange.new(
				-180,
				180
			)

		emitter.RotSpeed =
			NumberRange.new(
				-90,
				90
			)

		emitter.Size =
			NumberSequence.new({
				NumberSequenceKeypoint.new(
					0,
					maxSize
				),

				NumberSequenceKeypoint.new(
					0.55,
					minSize
				),

				NumberSequenceKeypoint.new(
					1,
					0
				),
			})

		emitter.LockedToPart =
			lockedToPart

		emitter.Parent =
			parent

		return emitter
	end

	local function removeNamedChildren(
		part: BasePart,
		names: {string}
	)
		for _, name in names do
			local child =
				part:FindFirstChild(
					name
				)

			if child ~= nil then
				child:Destroy()
			end
		end
	end

	-- =====================================================
	-- STANCE FIRE
	-- =====================================================

	local function removeStanceFire(
		userId: number
	)
		local character =
			characters.getCharacter(
				userId
			)

		if character == nil then
			return
		end

		for _, partName in STANCE_PARTS do
			local instance =
				character:FindFirstChild(
					partName
				)

			if instance ~= nil
				and instance:IsA(
					"BasePart"
				)
			then
				removeNamedChildren(
					instance,
					{
						STANCE_ATTACHMENT_NAME,
						STANCE_LIGHT_NAME,
					}
				)
			end
		end
	end

	local function addStanceFire(
		userId: number
	)
		local character =
			characters.getCharacter(
				userId
			)

		if character == nil then
			return
		end

		removeStanceFire(
			userId
		)

		for _, partName in STANCE_PARTS do
			local instance =
				character:FindFirstChild(
					partName
				)

			if instance == nil
				or not instance:IsA(
					"BasePart"
				)
			then
				continue
			end

			local attachment =
				Instance.new(
					"Attachment"
				)

			attachment.Name =
				STANCE_ATTACHMENT_NAME

			attachment.Parent =
				instance

			local isHand =
				HAND_PARTS[partName]
				== true

			createEmitter(
				attachment,
				STANCE_EMITTER_NAME,
				if isHand then 34 else 26,
				if isHand then 0.3 else 0.25,
				if isHand then 1.15 else 0.9,
				true
			)

			if isHand then
				local light =
					Instance.new(
						"PointLight"
					)

				light.Name =
					STANCE_LIGHT_NAME

				light.Color =
					Color3.fromRGB(
						255,
						105,
						25
					)

				light.Brightness =
					1.35

				light.Range =
					7

				light.Shadows =
					false

				light.Parent =
					instance
			end
		end
	end

	-- =====================================================
	-- DASH FOOT FIRE
	-- =====================================================

	local function removeDashFootFire(
		userId: number
	)
		local character =
			characters.getCharacter(
				userId
			)

		if character == nil then
			return
		end

		for _, partName in {
			"LeftFoot",
			"RightFoot",
		} do
			local instance =
				character:FindFirstChild(
					partName
				)

			if instance ~= nil
				and instance:IsA(
					"BasePart"
				)
			then
				removeNamedChildren(
					instance,
					{
						DASH_ATTACHMENT_NAME,
					}
				)
			end
		end
	end

	local function addDashFootFire(
		userId: number
	)
		local character =
			characters.getCharacter(
				userId
			)

		if character == nil then
			return
		end

		removeDashFootFire(
			userId
		)

		for _, partName in {
			"LeftFoot",
			"RightFoot",
		} do
			local instance =
				character:FindFirstChild(
					partName
				)

			if instance == nil
				or not instance:IsA(
					"BasePart"
				)
			then
				continue
			end

			local attachment =
				Instance.new(
					"Attachment"
				)

			attachment.Name =
				DASH_ATTACHMENT_NAME

			attachment.Parent =
				instance

			createEmitter(
				attachment,
				DASH_EMITTER_NAME,
				55,
				0.35,
				1.35,
				true
			)
		end
	end

	-- =====================================================
	-- STATIC WORKSPACE TRAIL
	-- =====================================================

	local function createTrailNode(
		position: Vector3
	)
		local node =
			Instance.new("Part")

		node.Name =
			"DashFireTrail"

		node.Size =
			Vector3.new(
				0.2,
				0.2,
				0.2
			)

		node.Transparency =
			1

		node.Anchored =
			true

		node.CanCollide =
			false

		node.CanTouch =
			false

		node.CanQuery =
			false

		node.CastShadow =
			false

		node.CFrame =
			CFrame.new(
				position
			)

		node.Parent =
			getTrailFolder()

		local fire =
			Instance.new("Fire")

		fire.Name =
			"DashTrailFire"

		fire.Color =
			Color3.fromRGB(
				255,
				80,
				15
			)

		fire.SecondaryColor =
			Color3.fromRGB(
				255,
				220,
				80
			)

		fire.Parent =
			node

		Debris:AddItem(
			node,
			TRAIL_LIFETIME
		)
	end

	local function sampleDashTrail(
		userId: number
	)
		local character =
			characters.getCharacter(
				userId
			)

		if character == nil then
			return
		end

		for _, partName in {
			"LeftFoot",
			"RightFoot",
		} do
			local instance =
				character:FindFirstChild(
					partName
				)

			if instance ~= nil
				and instance:IsA(
					"BasePart"
				)
			then
				createTrailNode(
					instance.Position
				)
			end
		end
	end

	-- =====================================================
	-- DASH RUNTIME
	-- =====================================================

	local function stopDashVFX(
		userId: number
	)
		dashRuntimeByUser[userId] =
			nil

		removeDashFootFire(
			userId
		)
	end

	local function beginDashVFX(
		userId: number
	)
		local state =
			store.get(
				userId
			)

		if state == nil then
			return
		end

		if state.status ~= "Normal" then
			return
		end

		if state.stance ~= "Active" then
			return
		end

		local now =
			os.clock()

		dashRuntimeByUser[userId] = {
			endAt =
				now
				+ DASH_DURATION,

			nextSampleAt =
				now,
		}

		addDashFootFire(
			userId
		)

		sampleDashTrail(
			userId
		)
	end

	local function onSoloDashRequested(
		userId: number
	)
		local now =
			os.clock()

		local readyAt =
			nextSoloDashAt[userId]

		if readyAt ~= nil
			and now < readyAt
		then
			return
		end

		local state =
			store.get(
				userId
			)

		if state == nil
			or state.status ~= "Normal"
			or state.stance ~= "Active"
			or state.duelId ~= nil
		then
			return
		end

		nextSoloDashAt[userId] =
			now
			+ DASH_COOLDOWN

		beginDashVFX(
			userId
		)
	end

	local function stepDashTrails()
		local now =
			os.clock()

		local finished:
			{number} = {}

		for userId, runtime in
			dashRuntimeByUser
		do
			if now >= runtime.endAt then
				table.insert(
					finished,
					userId
				)

				continue
			end

			if now
				>= runtime.nextSampleAt
			then
				runtime.nextSampleAt =
					now
					+ TRAIL_SAMPLE_INTERVAL

				sampleDashTrail(
					userId
				)
			end
		end

		for _, userId in finished do
			stopDashVFX(
				userId
			)
		end
	end

	-- =====================================================
	-- EVENTS
	-- =====================================================

	local function addSubscription(
		eventName: any,
		handler: (any) -> ()
	)
		local disconnect =
			bus.subscribe(
				eventName,
				handler
			)

		table.insert(
			disconnects,
			disconnect
		)
	end

	-- =====================================================
	-- START / STOP
	-- =====================================================

	local function start()
		if started then
			return
		end

		started = true

		getTrailFolder()

		addSubscription(
			"StanceStarted",
			function(event)
				local userId =
					event.actorUserId

				if userId ~= nil then
					addStanceFire(
						userId
					)
				end
			end
		)

		addSubscription(
			"StanceDeactivated",
			function(event)
				local userId =
					event.actorUserId

				if userId ~= nil then
					removeStanceFire(
						userId
					)

					stopDashVFX(
						userId
					)
				end
			end
		)

		addSubscription(
			"StanceDashRequested",
			function(event)
				local userId =
					event.actorUserId

				if userId ~= nil then
					onSoloDashRequested(
						userId
					)
				end
			end
		)

		addSubscription(
			"DashStarted",
			function(event)
				local userId =
					event.actorUserId

				if userId ~= nil then
					beginDashVFX(
						userId
					)
				end
			end
		)

		addSubscription(
			"DashFinished",
			function(event)
				local userId =
					event.actorUserId

				if userId ~= nil then
					stopDashVFX(
						userId
					)
				end
			end
		)

		addSubscription(
			"CharacterKilled",
			function(event)
				local userId =
					event.actorUserId

				if userId ~= nil then
					removeStanceFire(
						userId
					)

					stopDashVFX(
						userId
					)
				end
			end
		)

		addSubscription(
			"CharacterDespawning",
			function(event)
				local userId =
					event.actorUserId

				if userId ~= nil then
					removeStanceFire(
						userId
					)

					stopDashVFX(
						userId
					)

					nextSoloDashAt[userId] =
						nil
				end
			end
		)

		heartbeatConnection =
			RunService.Heartbeat:Connect(
				stepDashTrails
			)
	end

	local function stop()
		if not started then
			return
		end

		started = false

		if heartbeatConnection ~= nil then
			heartbeatConnection:Disconnect()
			heartbeatConnection = nil
		end

		for _, disconnect in disconnects do
			disconnect()
		end

		table.clear(
			disconnects
		)

		for userId in dashRuntimeByUser do
			removeDashFootFire(
				userId
			)
		end

		table.clear(
			dashRuntimeByUser
		)

		table.clear(
			nextSoloDashAt
		)

		for _, player in
			game:GetService(
				"Players"
			):GetPlayers()
		do
			removeStanceFire(
				player.UserId
			)
		end
	end

	return {
		start = start,
		stop = stop,
	}
end

return StanceFireService
