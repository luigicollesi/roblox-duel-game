--!strict

local EventTypes = require(script.Parent.EventTypes)

type ServerEvent = EventTypes.ServerEvent

local EventQueue = {}

export type QueueEntry = {
	sequence: number,
	tick: number,

	event: ServerEvent,
}

export type Queue = {
	enqueue: (
		event: ServerEvent,
		tick: number
	) -> QueueEntry,

	drainReady: (
		currentTick: number
	) -> {QueueEntry},

	size: () -> number,

	peekNextTick: () -> number?,

	clear: () -> (),
}

-- =========================================================
-- HELPERS
-- =========================================================

local function isValidTick(value: number): boolean
	return value >= 0
		and value % 1 == 0
end

-- =========================================================
-- FACTORY
-- =========================================================

function EventQueue.new(): Queue
	local entries: {QueueEntry} = {}

	local nextSequence = 0

	-- -----------------------------------------------------
	-- Enqueue
	-- -----------------------------------------------------

	local function enqueue(
		event: ServerEvent,
		tick: number
	): QueueEntry

		assert(
			isValidTick(tick),
			`EventQueue received invalid tick: {tick}`
		)

		nextSequence += 1

		local entry: QueueEntry = {
			sequence = nextSequence,
			tick = tick,

			event = event,
		}

		table.insert(entries, entry)

		return entry
	end

	-- -----------------------------------------------------
	-- Drain
	-- -----------------------------------------------------

	local function drainReady(
		currentTick: number
	): {QueueEntry}

		assert(
			isValidTick(currentTick),
			`EventQueue received invalid currentTick: {currentTick}`
		)

		local ready: {QueueEntry} = {}
		local pending: {QueueEntry} = {}

		for _, entry in entries do
			if entry.tick <= currentTick then
				table.insert(ready, entry)
			else
				table.insert(pending, entry)
			end
		end

		-- Primeiro tick, depois ordem de chegada.
		table.sort(
			ready,
			function(
				a: QueueEntry,
				b: QueueEntry
			): boolean

				if a.tick == b.tick then
					return a.sequence < b.sequence
				end

				return a.tick < b.tick
			end
		)

		entries = pending

		return ready
	end

	-- -----------------------------------------------------
	-- Inspection
	-- -----------------------------------------------------

	local function size(): number
		return #entries
	end

	local function peekNextTick(): number?
		local nextTick: number? = nil

		for _, entry in entries do
			if nextTick == nil or entry.tick < nextTick then
				nextTick = entry.tick
			end
		end

		return nextTick
	end

	-- -----------------------------------------------------
	-- Lifecycle
	-- -----------------------------------------------------

	local function clear()
		table.clear(entries)
	end

	return {
		enqueue = enqueue,
		drainReady = drainReady,

		size = size,
		peekNextTick = peekNextTick,

		clear = clear,
	}
end

return EventQueue