--!strict

local Players = game:GetService("Players")

local CharacterStateStore =
	require(script.Parent.CharacterStateStore)

local EventBus =
	require(script.Parent.Parent.Events.EventBus)

local EventTypes =
	require(script.Parent.Parent.Events.EventTypes)

type Store = CharacterStateStore.Store
type Bus = EventBus.Bus

local CharacterService = {}

type PlayerRecord = {
	player: Player,

	character: Model?,
	humanoid: Humanoid?,

	characterAddedConnection: RBXScriptConnection?,
	characterRemovingConnection: RBXScriptConnection?,
}

export type Service = {
	start: () -> (),
	stop: () -> (),

	getPlayer: (
		userId: number
	) -> Player?,

	getCharacter: (
		userId: number
	) -> Model?,

	getHumanoid: (
		userId: number
	) -> Humanoid?,

	isCharacterAlive: (
		userId: number
	) -> boolean,
}

-- =========================================================
-- FACTORY
-- =========================================================

function CharacterService.new(
	store: Store,
	bus: Bus
): Service

	local records: {[number]: PlayerRecord} = {}

	local started = false

	local playerAddedConnection: RBXScriptConnection? = nil
	local playerRemovingConnection: RBXScriptConnection? = nil

	-- =====================================================
	-- CHARACTER
	-- =====================================================

	local function onCharacterAdded(
		player: Player,
		character: Model
	)
		local userId = player.UserId
		local record = records[userId]

		if record == nil then
			return
		end

		record.character = character

		local humanoidInstance =
			character:FindFirstChild("Humanoid")

		local humanoid: Humanoid? = nil

		if humanoidInstance ~= nil
			and humanoidInstance:IsA("Humanoid")
		then
			humanoid = humanoidInstance
		end

		record.humanoid = humanoid

		bus.publish(
			EventTypes.create(
				"CharacterSpawned",
				{
					actorUserId = userId,

					data = {
						character = character,
						humanoid = humanoid,
					},
				}
			)
		)
	end

	local function onCharacterRemoving(
		player: Player,
		character: Model
	)
		local userId = player.UserId
		local record = records[userId]

		if record == nil then
			return
		end

		bus.publish(
			EventTypes.create(
				"CharacterDespawning",
				{
					actorUserId = userId,

					data = {
						character = character,
					},
				}
			)
		)

		if store.has(userId) then
			store.reset(
				userId,
				"CharacterDespawning"
			)
		end

		if record.character == character then
			record.character = nil
			record.humanoid = nil
		end
	end

	-- =====================================================
	-- PLAYER
	-- =====================================================

	local function onPlayerAdded(player: Player)
		local userId = player.UserId

		-- Idempotência é importante porque start()
		-- também processa jogadores já conectados.
		if records[userId] ~= nil then
			return
		end

		if not store.has(userId) then
			store.register(userId)
		end

		local record: PlayerRecord = {
			player = player,

			character = nil,
			humanoid = nil,

			characterAddedConnection = nil,
			characterRemovingConnection = nil,
		}

		records[userId] = record

		record.characterAddedConnection =
			player.CharacterAdded:Connect(
				function(character: Model)
					onCharacterAdded(
						player,
						character
					)
				end
			)

		record.characterRemovingConnection =
			player.CharacterRemoving:Connect(
				function(character: Model)
					onCharacterRemoving(
						player,
						character
					)
				end
			)

		-- O personagem pode ter sido criado antes
		-- da inicialização deste serviço.
		local existingCharacter =
			player.Character

		if existingCharacter ~= nil then
			onCharacterAdded(
				player,
				existingCharacter
			)
		end
	end

	local function onPlayerRemoving(player: Player)
		local userId = player.UserId
		local record = records[userId]

		if record == nil then
			return
		end

		if record.characterAddedConnection ~= nil then
			record.characterAddedConnection:Disconnect()
		end

		if record.characterRemovingConnection ~= nil then
			record.characterRemovingConnection:Disconnect()
		end

		records[userId] = nil

		if store.has(userId) then
			store.remove(userId)
		end
	end

	-- =====================================================
	-- START / STOP
	-- =====================================================

	local function start()
		if started then
			return
		end

		started = true

		-- Conectamos primeiro.
		-- Depois processamos quem já existe.
		playerAddedConnection =
			Players.PlayerAdded:Connect(
				onPlayerAdded
			)

		playerRemovingConnection =
			Players.PlayerRemoving:Connect(
				onPlayerRemoving
			)

		for _, player in Players:GetPlayers() do
			onPlayerAdded(player)
		end
	end

	local function stop()
		if not started then
			return
		end

		started = false

		if playerAddedConnection ~= nil then
			playerAddedConnection:Disconnect()
			playerAddedConnection = nil
		end

		if playerRemovingConnection ~= nil then
			playerRemovingConnection:Disconnect()
			playerRemovingConnection = nil
		end

		for userId, record in records do
			if record.characterAddedConnection ~= nil then
				record.characterAddedConnection:Disconnect()
			end

			if record.characterRemovingConnection ~= nil then
				record.characterRemovingConnection:Disconnect()
			end

			if store.has(userId) then
				store.remove(userId)
			end
		end

		table.clear(records)
	end

	-- =====================================================
	-- QUERIES
	-- =====================================================

	local function getPlayer(
		userId: number
	): Player?

		local record = records[userId]

		if record == nil then
			return nil
		end

		return record.player
	end

	local function getCharacter(
		userId: number
	): Model?

		local record = records[userId]

		if record == nil then
			return nil
		end

		return record.character
	end

	local function getHumanoid(
		userId: number
	): Humanoid?

		local record = records[userId]

		if record == nil then
			return nil
		end

		return record.humanoid
	end

	local function isCharacterAlive(
		userId: number
	): boolean

		local humanoid =
			getHumanoid(userId)

		if humanoid == nil then
			return false
		end

		return humanoid.Health > 0
	end

	return {
		start = start,
		stop = stop,

		getPlayer = getPlayer,
		getCharacter = getCharacter,
		getHumanoid = getHumanoid,

		isCharacterAlive = isCharacterAlive,
	}
end

return CharacterService