--!strict

local RunService =
	game:GetService("RunService")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Shared =
	ReplicatedStorage.Shared

local CombatConfig =
	require(
		Shared.Combat.CombatConfig
	)

local CombatTypes =
	require(
		Shared.Combat.CombatTypes
	)

local LightCombo =
	require(
		Shared.Combat.LightCombo
	)

local CharacterStateStore =
	require(
		script.Parent.Parent.Character.CharacterStateStore
	)

local CharacterService =
	require(
		script.Parent.Parent.Character.CharacterService
	)

local StanceService =
	require(
		script.Parent.Parent.Character.StanceService
	)

local EventBus =
	require(
		script.Parent.Parent.Events.EventBus
	)

local EventQueue =
	require(
		script.Parent.Parent.Events.EventQueue
	)

local EventTypes =
	require(
		script.Parent.Parent.Events.EventTypes
	)

local ActionResolver =
	require(
		script.Parent.Parent.Combat.ActionResolver
	)

local ComboSystem =
	require(
		script.Parent.Parent.Combat.ComboSystem
	)

local AttackSystem =
	require(
		script.Parent.Parent.Combat.AttackSystem
	)

local HitboxSystem =
	require(
		script.Parent.Parent.Combat.HitboxSystem
	)

local CombatResolver =
	require(
		script.Parent.Parent.Combat.CombatResolver
	)

local DamageSystem =
	require(
		script.Parent.Parent.Combat.DamageSystem
	)

local HitReactionSystem =
	require(
		script.Parent.Parent.Combat.HitReactionSystem
	)

local AirSystem =
	require(
		script.Parent.Parent.Movement.AirSystem
	)

local DashSystem =
	require(
		script.Parent.Parent.Movement.DashSystem
	)

local DuelClock =
	require(
		script.Parent.DuelClock
	)

-- =========================================================
-- TYPES
-- =========================================================

type Store =
	CharacterStateStore.Store

type CharacterApi =
	CharacterService.Service

type StanceApi =
	StanceService.Service

type Bus =
	EventBus.Bus

type Disconnect =
	EventBus.Disconnect

type Queue =
	EventQueue.Queue

type ServerEvent =
	EventTypes.ServerEvent

type Clock =
	DuelClock.Clock

type ComboApi =
	ComboSystem.System

type AttackApi =
	AttackSystem.System

type AttackStepResult =
	AttackSystem.StepResult

type ActiveAttack =
	AttackSystem.ActiveAttack

type FinishedAttack =
	AttackSystem.FinishedAttack

type HitboxApi =
	HitboxSystem.System

type HitCandidate =
	HitboxSystem.HitCandidate

type DamageApi =
	DamageSystem.System

type HitReactionApi =
	HitReactionSystem.System

type AirApi =
	AirSystem.System

type DashApi =
	DashSystem.System

type BufferedAttackKind =
	CombatTypes.BufferedAttackKind

type HitResult =
	CombatTypes.HitResult

type AttackAction =
	CombatTypes.AttackAction

local DuelEngine = {}

-- =========================================================
-- SESSION
-- =========================================================

type DuelSession = {
	duelId: string,

	fighterAUserId: number,
	fighterBUserId: number,

	clock: Clock,
	queue: Queue,

	combo: ComboApi,
	attack: AttackApi,

	hitbox: HitboxApi,
	damage: DamageApi,
	hitReaction: HitReactionApi,

	air: AirApi,
	dash: DashApi,

	stanceActivated: boolean,
}

export type Service = {
	start: () -> (),
	stop: () -> (),

	getTick: (
		duelId: string
	) -> number?,
}

-- =========================================================
-- FACTORY
-- =========================================================

function DuelEngine.new(
	store: Store,
	bus: Bus,
	stance: StanceApi,
	characters: CharacterApi
): Service

	local sessions:
		{[string]: DuelSession} = {}

	local started = false

	local heartbeatConnection:
		RBXScriptConnection? = nil

	local duelCreatedDisconnect:
		Disconnect? = nil

	local duelEndedDisconnect:
		Disconnect? = nil

	local intentDisconnect:
		Disconnect? = nil

	local accumulator = 0

	-- =====================================================
	-- SESSION HELPERS
	-- =====================================================

	local function containsUser(
		session: DuelSession,
		userId: number
	): boolean

		return session.fighterAUserId == userId
			or session.fighterBUserId == userId
	end

	local function getOpponentUserId(
		session: DuelSession,
		userId: number
	): number?

		if session.fighterAUserId == userId then
			return session.fighterBUserId
		end

		if session.fighterBUserId == userId then
			return session.fighterAUserId
		end

		return nil
	end

	-- =====================================================
	-- REJECTION
	-- =====================================================

	local function publishReject(
		session: DuelSession,
		userId: number,
		sequence: number,
		reason: string
	)
		bus.publish(
			EventTypes.create(
				"CombatActionRejected",
				{
					tick =
						session.clock.getTick(),

					duelId =
						session.duelId,

					actorUserId =
						userId,

					data = {
						sequence = sequence,
						reason = reason,
					},
				}
			)
		)
	end

	-- =====================================================
	-- COMBAT RESULT
	-- =====================================================

	local function publishCombatResult(
		session: DuelSession,
		attackerUserId: number,
		targetUserId: number,
		action: AttackAction,
		sequence: number,
		result: HitResult,
		damage: number
	)
		bus.publish(
			EventTypes.create(
				"CombatResolved",
				{
					tick =
						session.clock.getTick(),

					duelId =
						session.duelId,

					actorUserId =
						attackerUserId,

					targetUserId =
						targetUserId,

					data = {
						action = action,
						sequence = sequence,

						result = result,
						damage = damage,
					},
				}
			)
		)
	end

	-- =====================================================
	-- BUFFER
	-- =====================================================

	local function bufferAttack(
		session: DuelSession,
		userId: number,
		kind: BufferedAttackKind,
		sequence: number
	)
		session.combo.buffer(
			userId,
			kind,
			sequence
		)

		bus.publish(
			EventTypes.create(
				"CombatActionBuffered",
				{
					tick =
						session.clock.getTick(),

					duelId =
						session.duelId,

					actorUserId =
						userId,

					data = {
						kind = kind,
						sequence = sequence,
					},
				}
			)
		)
	end

	-- =====================================================
	-- NORMAL ATTACK
	-- =====================================================

	local function beginAttack(
		session: DuelSession,
		userId: number,
		kind: BufferedAttackKind,
		sequence: number
	)
		local state =
			store.getRequired(userId)

		local resolved =
			session.combo.resolve(
				kind,
				state.comboStep
			)

		session.attack.start(
			userId,

			resolved.action,
			sequence,
			resolved.nextComboStep,

			session.clock.getTick()
		)
	end

	-- =====================================================
	-- LAND ATTACK
	-- =====================================================

	local function beginLandAttack(
		session: DuelSession,
		userId: number,
		sequence: number
	)
		session.combo.clear(
			userId
		)

		session.attack.start(
			userId,

			"LandAttack",
			sequence,

			LightCombo.getResetStep(),

			session.clock.getTick()
		)
	end

	-- =====================================================
	-- ATTACK INTENT
	-- =====================================================

	local function processAttackIntent(
		session: DuelSession,
		userId: number,
		sequence: number,
		intentKind: BufferedAttackKind
	)
		local state =
			store.get(userId)

		if state == nil then
			return
		end

		-- Ataque solicitado durante Jump/Fall
		-- arma LandAttack em vez de Q1/Strong.
		if state.air == "Jumping"
			or state.air == "Falling"
		then
			local accepted, reason =
				session.air.armLandingAttack(
					userId,
					sequence,
					session.clock.getTick()
				)

			if not accepted then
				publishReject(
					session,
					userId,
					sequence,
					reason
						or "LandAttackRejected"
				)
			end

			return
		end

		local resolution =
			ActionResolver.resolve(
				state,
				intentKind
			)

		if resolution.kind == "Reject" then
			publishReject(
				session,
				userId,
				sequence,
				resolution.reason
			)

			return
		end

		if resolution.kind == "Buffer" then
			bufferAttack(
				session,
				userId,
				intentKind,
				sequence
			)

			return
		end

		beginAttack(
			session,
			userId,
			intentKind,
			sequence
		)
	end

	-- =====================================================
	-- PROCESS INTENT
	-- =====================================================

	local function processIntent(
		session: DuelSession,
		event: ServerEvent
	)
		local userId =
			event.actorUserId

		if userId == nil then
			return
		end

		if not containsUser(
			session,
			userId
			) then
			return
		end

		if type(event.data) ~= "table" then
			return
		end

		local sequence =
			event.data.sequence

		local intentKind =
			event.data.kind

		if type(sequence) ~= "number" then
			return
		end

		if type(intentKind) ~= "string" then
			return
		end

		-- -----------------------------------------------
		-- LIGHT
		-- -----------------------------------------------

		if intentKind == "Light" then
			processAttackIntent(
				session,
				userId,
				sequence,
				"Light"
			)

			return
		end

		-- -----------------------------------------------
		-- STRONG
		-- -----------------------------------------------

		if intentKind == "Strong" then
			processAttackIntent(
				session,
				userId,
				sequence,
				"Strong"
			)

			return
		end

		-- -----------------------------------------------
		-- JUMP
		-- -----------------------------------------------

		if intentKind == "Jump" then
			local accepted, reason =
				session.air.requestJump(
					userId,
					sequence,
					session.clock.getTick()
				)

			if not accepted then
				publishReject(
					session,
					userId,
					sequence,
					reason
						or "JumpRejected"
				)
			end

			return
		end

		-- -----------------------------------------------
		-- DASH
		-- -----------------------------------------------

		if intentKind == "Dash" then
			local accepted, reason =
				session.dash.start(
					userId,
					sequence,
					session.clock.getTick()
				)

			if not accepted then
				publishReject(
					session,
					userId,
					sequence,
					reason
						or "DashRejected"
				)
			end

			return
		end

		publishReject(
			session,
			userId,
			sequence,
			"UnknownIntent"
		)
	end

	-- =====================================================
	-- INTERRUPT
	-- =====================================================

	local function interruptUser(
		session: DuelSession,
		userId: number,
		currentTick: number,
		reason: string
	)
		local state =
			store.get(userId)

		if state == nil then
			return
		end

		local previousAction =
			state.action

		local previousSequence =
			state.actionSequence

		local hadAttack =
			session.attack.hasActive(
				userId
			)

		local hadDash =
			session.dash.hasActive(
				userId
			)

		local hadAirAttack =
			state.airAttackArmed

		-- Removemos primeiro os runtimes.
		if hadAttack then
			session.attack.cancel(
				userId
			)
		end

		if hadDash then
			session.dash.cancel(
				userId
			)
		end

		session.combo.clear(
			userId
		)

		session.air.disarmLandingAttack(
			userId
		)

		if not hadAttack
			and not hadDash
			and not hadAirAttack
			and previousAction == nil
		then
			return
		end

		bus.publish(
			EventTypes.create(
				"CombatInterrupted",
				{
					tick = currentTick,
					duelId = session.duelId,

					actorUserId = userId,

					data = {
						reason = reason,

						previousAction =
							previousAction,

						previousSequence =
							previousSequence,
					},
				}
			)
		)
	end

	-- =====================================================
	-- ACTIVE COMBAT
	-- =====================================================

	local function resolveActiveCombat(
		session: DuelSession,
		activeAttacks: {ActiveAttack}
	)
		local candidates:
			{HitCandidate} = {}

		-- Primeiro coletamos TODOS os ataques
		-- que conectaram neste tick.
		for _, activeAttack in ipairs(
			activeAttacks
			) do
			local candidate =
				session.hitbox.tryHit(
					activeAttack.userId,
					activeAttack.action,
					activeAttack.sequence
				)

			if candidate ~= nil then
				table.insert(
					candidates,
					candidate
				)
			end
		end

		if #candidates == 0 then
			return
		end

		-- Resolve simultaneidade antes de alterar
		-- qualquer estado dos lutadores.
		local outcomes =
			CombatResolver.resolve(
				candidates
			)

		local currentTick =
			session.clock.getTick()

		-- -----------------------------------------------
		-- PUBLICA RESULTADOS
		-- -----------------------------------------------

		for _, outcome in ipairs(
			outcomes
			) do
			publishCombatResult(
				session,

				outcome.attackerUserId,
				outcome.targetUserId,

				outcome.action,
				outcome.sequence,

				outcome.result,
				outcome.damage
			)
		end

		-- -----------------------------------------------
		-- APLICA DANOS E REAÇÕES
		-- -----------------------------------------------

		for _, outcome in ipairs(
			outcomes
			) do
			if outcome.result ~= "Hit" then
				continue
			end

			local damageResult =
				session.damage.apply(
					outcome,
					currentTick
				)

			if damageResult == nil then
				continue
			end

			-- ForceField ou outra condição pode
			-- produzir zero de dano aplicado.
			if damageResult.applied <= 0 then
				continue
			end

			-- Cancela ataque, dash e buffer do alvo.
			interruptUser(
				session,
				outcome.targetUserId,
				currentTick,
				"Hit"
			)

			-- DamageSystem já colocou status Dead.
			if damageResult.killed then
				continue
			end

			session.hitReaction.apply(
				outcome.attackerUserId,
				outcome.targetUserId,
				outcome.action,
				currentTick
			)
		end
	end

	-- =====================================================
	-- FINISHED ATTACKS
	-- =====================================================

	local function resolveFinishedAttacks(
		session: DuelSession,
		finished: {FinishedAttack}
	)
		local tick =
			session.clock.getTick()

		for _, finishedAttack in ipairs(
			finished
			) do
			local userId =
				finishedAttack.userId

			-- O ataque pode ter sido cancelado por
			-- um Hit neste mesmo tick.
			if not session.attack.hasActive(
				userId
				) then
				session.combo.clear(
					userId
				)

				continue
			end

			-- -------------------------------------------
			-- MISS
			-- -------------------------------------------

			if not session.hitbox.wasConsumed(
				userId,
				finishedAttack.sequence
				) then
				local opponentUserId =
					getOpponentUserId(
						session,
						userId
					)

				if opponentUserId ~= nil then
					publishCombatResult(
						session,

						userId,
						opponentUserId,

						finishedAttack.action,
						finishedAttack.sequence,

						"Miss",
						0
					)
				end
			end

			-- -------------------------------------------
			-- BUFFER
			-- -------------------------------------------

			local pending =
				session.combo.take(
					userId
				)

			if pending == nil then
				session.attack.finish(
					userId,
					tick
				)

				continue
			end

			local state =
				store.getRequired(
					userId
				)

			local resolved =
				session.combo.resolve(
					pending.kind,
					state.comboStep
				)

			session.attack.chain(
				userId,

				resolved.action,
				pending.sequence,
				resolved.nextComboStep,

				tick
			)
		end
	end

	-- =====================================================
	-- AIR
	-- =====================================================

	local function resolveAir(
		session: DuelSession
	)
		local requests =
			session.air.step(
				session.clock.getTick()
			)

		for _, request in ipairs(
			requests
			) do
			local userId =
				request.userId

			-- Nunca sobrepor um runtime já ativo.
			if session.attack.hasActive(
				userId
				) then
				continue
			end

			if session.dash.hasActive(
				userId
				) then
				continue
			end

			local state =
				store.get(userId)

			if state == nil then
				continue
			end

			if state.status ~= "Normal" then
				continue
			end

			beginLandAttack(
				session,
				userId,
				request.sequence
			)
		end
	end

	-- =====================================================
	-- STANCE
	-- =====================================================

	local function updateStance(
		session: DuelSession
	)
		if session.stanceActivated then
			return
		end

		if session.clock.getTick()
			< CombatConfig.STANCE_START_TICKS
		then
			return
		end

		local activatedA =
			stance.activate(
				session.fighterAUserId
			)

		local activatedB =
			stance.activate(
				session.fighterBUserId
			)

		if activatedA
			and activatedB
		then
			session.stanceActivated = true
			return
		end

		warn(
			`[DuelEngine] Failed to activate stance for {session.duelId}`
		)
	end

	-- =====================================================
	-- SESSION STEP
	-- =====================================================

	local function stepSession(
		session: DuelSession
	)
		local currentTick =
			session.clock.advance()

		-- 1. Entrada na stance.
		updateStance(
			session
		)

		-- 2. Inputs daquele tick.
		local ready =
			session.queue.drainReady(
				currentTick
			)

		for _, entry in ipairs(
			ready
			) do
			processIntent(
				session,
				entry.event
			)
		end

		-- 3. Estado aéreo / aterrissagem.
		resolveAir(
			session
		)

		-- 4. Dashes temporizados.
		session.dash.step(
			currentTick
		)

		-- 5. Avança Startup/Active/Recovery.
		local attackStep:
			AttackStepResult =
			session.attack.step(
				currentTick
			)

		-- 6. Resolve hitboxes de todos os golpes
		-- Active simultaneamente.
		resolveActiveCombat(
			session,
			attackStep.active
		)

		-- 7. Finaliza ataques ou inicia buffer.
		resolveFinishedAttacks(
			session,
			attackStep.finished
		)

		-- 8. Avança timers de hitstun.
		session.hitReaction.step(
			currentTick
		)
	end

	-- =====================================================
	-- FIXED STEP
	-- =====================================================

	local function fixedStep()
		for _, session in pairs(
			sessions
			) do
			stepSession(
				session
			)
		end
	end

	-- =====================================================
	-- DUEL CREATED
	-- =====================================================

	local function onDuelCreated(
		event: ServerEvent
	)
		local duelId =
			event.duelId

		local fighterA =
			event.actorUserId

		local fighterB =
			event.targetUserId

		if duelId == nil then
			return
		end

		if fighterA == nil then
			return
		end

		if fighterB == nil then
			return
		end

		if sessions[duelId] ~= nil then
			return
		end

		local combo =
			ComboSystem.new()

		local attack =
			AttackSystem.new(
				store,
				bus,
				duelId
			)

		local hitbox =
			HitboxSystem.new(
				characters,
				fighterA,
				fighterB
			)

		local damage =
			DamageSystem.new(
				store,
				bus,
				characters,

				duelId,

				fighterA,
				fighterB
			)

		local hitReaction =
			HitReactionSystem.new(
				store,
				bus,
				characters,

				duelId,

				fighterA,
				fighterB
			)

		local air =
			AirSystem.new(
				store,
				bus,
				characters,

				duelId,

				fighterA,
				fighterB
			)

		local dash =
			DashSystem.new(
				store,
				bus,
				characters,

				duelId
			)

		local session: DuelSession = {
			duelId = duelId,

			fighterAUserId = fighterA,
			fighterBUserId = fighterB,

			clock = DuelClock.new(),
			queue = EventQueue.new(),

			combo = combo,
			attack = attack,

			hitbox = hitbox,
			damage = damage,
			hitReaction = hitReaction,

			air = air,
			dash = dash,

			-- O DuelService agora cria a sessao apenas
			-- quando os dois jogadores ja estao em Active.
			stanceActivated = true,
		}

		sessions[duelId] =
			session
	end

	-- =====================================================
	-- DUEL ENDED
	-- =====================================================

	local function onDuelEnded(
		event: ServerEvent
	)
		local duelId =
			event.duelId

		if duelId == nil then
			return
		end

		local session =
			sessions[duelId]

		if session == nil then
			return
		end

		local fighterA =
			session.fighterAUserId

		local fighterB =
			session.fighterBUserId

		session.combo.clear(
			fighterA
		)

		session.combo.clear(
			fighterB
		)

		session.attack.cancel(
			fighterA
		)

		session.attack.cancel(
			fighterB
		)

		session.hitbox.clear(
			fighterA
		)

		session.hitbox.clear(
			fighterB
		)

		session.hitReaction.clear(
			fighterA
		)

		session.hitReaction.clear(
			fighterB
		)

		session.dash.cancel(
			fighterA
		)

		session.dash.cancel(
			fighterB
		)

		session.air.clear(
			fighterA
		)

		session.air.clear(
			fighterB
		)

		session.queue.clear()

		sessions[duelId] = nil
	end

	-- =====================================================
	-- INTENT RECEIVED
	-- =====================================================

	local function onIntentReceived(
		event: ServerEvent
	)
		local duelId =
			event.duelId

		if duelId == nil then
			return
		end

		local session =
			sessions[duelId]

		if session == nil then
			return
		end

		-- Todo intent entra no próximo tick lógico.
		session.queue.enqueue(
			event,
			session.clock.getTick() + 1
		)
	end

	-- =====================================================
	-- START
	-- =====================================================

	local function start()
		if started then
			return
		end

		started = true

		duelCreatedDisconnect =
			bus.subscribe(
				"DuelCreated",
				onDuelCreated
			)

		duelEndedDisconnect =
			bus.subscribe(
				"DuelEnded",
				onDuelEnded
			)

		intentDisconnect =
			bus.subscribe(
				"PlayerIntentReceived",
				onIntentReceived
			)

		heartbeatConnection =
			RunService.Heartbeat:Connect(
				function(deltaTime: number)
					accumulator +=
						deltaTime

					local steps = 0

					while accumulator
						>= CombatConfig.FIXED_DT
					do
						if steps
							>= CombatConfig.MAX_CATCH_UP_STEPS
						then
							accumulator = 0
							break
						end

						accumulator -=
							CombatConfig.FIXED_DT

						steps += 1

						fixedStep()
					end
				end
			)
	end

	-- =====================================================
	-- STOP
	-- =====================================================

	local function stop()
		if not started then
			return
		end

		started = false

		if heartbeatConnection ~= nil then
			heartbeatConnection:Disconnect()
			heartbeatConnection = nil
		end

		if duelCreatedDisconnect ~= nil then
			duelCreatedDisconnect()
			duelCreatedDisconnect = nil
		end

		if duelEndedDisconnect ~= nil then
			duelEndedDisconnect()
			duelEndedDisconnect = nil
		end

		if intentDisconnect ~= nil then
			intentDisconnect()
			intentDisconnect = nil
		end

		for _, session in pairs(
			sessions
			) do
			local fighterA =
				session.fighterAUserId

			local fighterB =
				session.fighterBUserId

			session.combo.clear(
				fighterA
			)

			session.combo.clear(
				fighterB
			)

			session.attack.cancel(
				fighterA
			)

			session.attack.cancel(
				fighterB
			)

			session.hitbox.clear(
				fighterA
			)

			session.hitbox.clear(
				fighterB
			)

			session.hitReaction.clear(
				fighterA
			)

			session.hitReaction.clear(
				fighterB
			)

			session.dash.cancel(
				fighterA
			)

			session.dash.cancel(
				fighterB
			)

			session.air.clear(
				fighterA
			)

			session.air.clear(
				fighterB
			)

			session.queue.clear()
		end

		table.clear(
			sessions
		)

		accumulator = 0
	end

	-- =====================================================
	-- GET TICK
	-- =====================================================

	local function getTick(
		duelId: string
	): number?

		local session =
			sessions[duelId]

		if session == nil then
			return nil
		end

		return session.clock.getTick()
	end

	return {
		start = start,
		stop = stop,

		getTick = getTick,
	}
end

return DuelEngine