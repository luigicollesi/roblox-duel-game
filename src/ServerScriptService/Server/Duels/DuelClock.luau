--!strict

local DuelClock = {}

export type Clock = {
	advance: () -> number,

	getTick: () -> number,

	reset: () -> (),
}

function DuelClock.new(): Clock
	local tick = 0

	local function advance(): number
		tick += 1

		return tick
	end

	local function getTick(): number
		return tick
	end

	local function reset()
		tick = 0
	end

	return {
		advance = advance,

		getTick = getTick,

		reset = reset,
	}
end

return DuelClock