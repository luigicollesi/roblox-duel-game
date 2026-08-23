--!strict

local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Debris =
	game:GetService("Debris")

local ClientEventBus =
	require(
		script.Parent.Parent.Events.ClientEventBus
	)

local SoundController = {}

export type Controller = {
	start: () -> (),
	stop: () -> (),
}

function SoundController.new(): Controller

	local disconnect:
		(() -> ())? = nil

	-- =====================================================
	-- FIND PLAYER BY NUMERIC USER ID
	-- =====================================================

	local function findPlayerByUserId(
		userId: number
	): Player?

		for _, player in ipairs(
			Players:GetPlayers()
			) do
			if player.UserId
				== userId
			then
				return player
			end
		end

		return nil
	end

	-- =====================================================
	-- COMBAT SOUNDS FOLDER
	-- =====================================================

	local function getCombatFolder():
		Folder?

		local assets =
			ReplicatedStorage:FindFirstChild(
				"Assets"
			)

		if assets == nil then
			return nil
		end

		local sounds =
			assets:FindFirstChild(
				"Sounds"
			)

		if sounds == nil then
			return nil
		end

		local combat =
			sounds:FindFirstChild(
				"Combat"
			)

		if combat == nil
			or not combat:IsA("Folder")
		then
			return nil
		end

		return combat
	end

	-- =====================================================
	-- ROOT
	-- =====================================================

	local function getRoot(
		userId: number
	): BasePart?

		local player =
			findPlayerByUserId(
				userId
			)

		if player == nil then
			return nil
		end

		local character =
			player.Character

		if character == nil then
			return nil
		end

		local root =
			character:FindFirstChild(
				"HumanoidRootPart"
			)

		if root == nil
			or not root:IsA("BasePart")
		then
			return nil
		end

		return root
	end

	-- =====================================================
	-- PLAY
	-- =====================================================

	local function play(
		name: string,
		userId: number?
	)
		local folder =
			getCombatFolder()

		if folder == nil then
			return
		end

		local template =
			folder:FindFirstChild(
				name
			)

		if template == nil
			or not template:IsA("Sound")
		then
			return
		end

		local sound: Sound =
			template:Clone()

		if userId ~= nil then
			local root =
				getRoot(
					userId
				)

			if root ~= nil then
				sound.Parent =
					root
			else
				sound.Parent =
					workspace
			end
		else
			sound.Parent =
				workspace
		end

		sound:Play()

		Debris:AddItem(
			sound,
			math.max(
				3,
				sound.TimeLength + 1
			)
		)
	end

	-- =====================================================
	-- EFFECT
	-- =====================================================

	local function onEffect(
		payload: any
	)
		if type(payload) ~= "table" then
			return
		end

		local eventName =
			payload.eventName

		-- -----------------------------------------------
		-- COMBAT
		-- -----------------------------------------------

		if eventName
			== "CombatResolved"
		then
			if type(payload.data)
				~= "table"
			then
				return
			end

			local result =
				payload.data.result

			if result == "Hit" then
				local targetUserId =
					payload.targetUserId

				if type(targetUserId)
					== "number"
				then
					play(
						"Hit",
						targetUserId
					)
				end

				return
			end

			if result == "Clash" then
				local actorUserId =
					payload.actorUserId

				if type(actorUserId)
					== "number"
				then
					play(
						"Clash",
						actorUserId
					)
				end

				return
			end

			return
		end

		-- -----------------------------------------------
		-- DASH
		-- -----------------------------------------------

		if eventName
			== "DashStarted"
		then
			local actorUserId =
				payload.actorUserId

			if type(actorUserId)
				== "number"
			then
				play(
					"Dash",
					actorUserId
				)
			end

			return
		end

		-- -----------------------------------------------
		-- ATTACK
		-- -----------------------------------------------

		if eventName
			== "AttackStarted"
		then
			if type(payload.data)
				~= "table"
			then
				return
			end

			local actorUserId =
				payload.actorUserId

			if type(actorUserId)
				~= "number"
			then
				return
			end

			if payload.data.action
				== "Strong"
			then
				play(
					"Strong",
					actorUserId
				)
			else
				play(
					"Swing",
					actorUserId
				)
			end

			return
		end

		-- -----------------------------------------------
		-- KO
		-- -----------------------------------------------

		if eventName
			== "CharacterKilled"
		then
			local targetUserId =
				payload.targetUserId

			if type(targetUserId)
				== "number"
			then
				play(
					"KO",
					targetUserId
				)
			end
		end
	end

	-- =====================================================
	-- START
	-- =====================================================

	local function start()
		if disconnect ~= nil then
			return
		end

		disconnect =
			ClientEventBus.subscribe(
				"Effect",
				onEffect
			)
	end

	-- =====================================================
	-- STOP
	-- =====================================================

	local function stop()
		if disconnect == nil then
			return
		end

		disconnect()
		disconnect = nil
	end

	return {
		start = start,
		stop = stop,
	}
end

return SoundController