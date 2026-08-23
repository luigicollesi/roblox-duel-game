--!strict

local Players =
	game:GetService("Players")

local Debris =
	game:GetService("Debris")

local ClientEventBus =
	require(
		script.Parent.Parent.Events.ClientEventBus
	)

local VFXController = {}

export type Controller = {
	start: () -> (),
	stop: () -> (),
}

function VFXController.new(): Controller

	local disconnect:
		(() -> ())? = nil

	-- =====================================================
	-- FIND PLAYER
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
	-- FLASH
	-- =====================================================

	local function flashCharacter(
		userId: number,
		duration: number
	)
		local player =
			findPlayerByUserId(
				userId
			)

		if player == nil then
			return
		end

		local character =
			player.Character

		if character == nil then
			return
		end

		local highlight =
			Instance.new(
				"Highlight"
			)

		highlight.Name =
			"CombatFlash"

		highlight.FillTransparency =
			0.7

		highlight.OutlineTransparency =
			1

		highlight.Adornee =
			character

		highlight.Parent =
			character

		Debris:AddItem(
			highlight,
			duration
		)
	end

	-- =====================================================
	-- EFFECT
	-- =====================================================

	local function onEffect(
		payload: any
	)
		if type(payload)
			~= "table"
		then
			return
		end

		if payload.eventName
			~= "CombatResolved"
		then
			return
		end

		if type(payload.data)
			~= "table"
		then
			return
		end

		local result =
			payload.data.result

		-- -----------------------------------------------
		-- HIT
		-- -----------------------------------------------

		if result == "Hit" then
			local targetUserId =
				payload.targetUserId

			if type(targetUserId)
				== "number"
			then
				flashCharacter(
					targetUserId,
					0.08
				)
			end

			return
		end

		-- -----------------------------------------------
		-- CLASH
		-- -----------------------------------------------

		if result == "Clash" then
			local actorUserId =
				payload.actorUserId

			local targetUserId =
				payload.targetUserId

			if type(actorUserId)
				== "number"
			then
				flashCharacter(
					actorUserId,
					0.06
				)
			end

			if type(targetUserId)
				== "number"
			then
				flashCharacter(
					targetUserId,
					0.06
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

return VFXController