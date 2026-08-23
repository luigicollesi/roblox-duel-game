--!strict

local DuelHistory = {}

export type HistoryEntry = {
	index: number,

	createdAt: number,

	name: string,

	actorUserId: number?,

	data: any?,
}

export type History = {
	add: (
		name: string,
		actorUserId: number?,
		data: any?
	) -> HistoryEntry,

	getEntries: () -> {HistoryEntry},

	size: () -> number,

	clear: () -> (),
}

local DEFAULT_CAPACITY = 256

-- =========================================================
-- CLONE
-- =========================================================

local function cloneEntry(
	entry: HistoryEntry
): HistoryEntry

	return {
		index = entry.index,

		createdAt = entry.createdAt,

		name = entry.name,

		actorUserId = entry.actorUserId,

		data = entry.data,
	}
end

-- =========================================================
-- FACTORY
-- =========================================================

function DuelHistory.new(
	capacity: number?
): History

	local maxEntries =
		capacity or DEFAULT_CAPACITY

	assert(
		maxEntries > 0
			and maxEntries % 1 == 0,
		"History capacity must be a positive integer"
	)

	local entries: {HistoryEntry} = {}

	local nextIndex = 0

	local function add(
		name: string,
		actorUserId: number?,
		data: any?
	): HistoryEntry

		assert(
			name ~= "",
			"History entry name cannot be empty"
		)

		nextIndex += 1

		local entry: HistoryEntry = {
			index = nextIndex,

			createdAt = os.clock(),

			name = name,

			actorUserId = actorUserId,

			data = data,
		}

		table.insert(
			entries,
			entry
		)

		if #entries > maxEntries then
			table.remove(entries, 1)
		end

		return cloneEntry(entry)
	end

	local function getEntries(): {HistoryEntry}
		local result: {HistoryEntry} = {}

		for _, entry in ipairs(entries) do
			table.insert(
				result,
				cloneEntry(entry)
			)
		end

		return result
	end

	local function size(): number
		return #entries
	end

	local function clear()
		table.clear(entries)
	end

	return {
		add = add,
		getEntries = getEntries,

		size = size,

		clear = clear,
	}
end

return DuelHistory