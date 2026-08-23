--!strict

local RateLimiter = {}

local DEFAULT_RATE_PER_SECOND = 30
local DEFAULT_BURST_CAPACITY = 15

type Bucket = {
	tokens: number,
	lastRefill: number,
}

export type Limiter = {
	allow: (
		userId: number,
		cost: number?
	) -> boolean,

	reset: (
		userId: number
	) -> (),

	clear: () -> (),
}

-- =========================================================
-- FACTORY
-- =========================================================

function RateLimiter.new(
	ratePerSecond: number?,
	burstCapacity: number?
): Limiter

	local rate =
		ratePerSecond
		or DEFAULT_RATE_PER_SECOND

	local capacity =
		burstCapacity
		or DEFAULT_BURST_CAPACITY

	assert(
		rate > 0,
		"RateLimiter rate must be greater than zero"
	)

	assert(
		capacity > 0,
		"RateLimiter capacity must be greater than zero"
	)

	local buckets: {[number]: Bucket} = {}

	-- =====================================================
	-- ALLOW
	-- =====================================================

	local function allow(
		userId: number,
		cost: number?
	): boolean

		local requestedCost =
			cost or 1

		if requestedCost <= 0 then
			return false
		end

		local now =
			os.clock()

		local bucket =
			buckets[userId]

		if bucket == nil then
			bucket = {
				tokens = capacity,
				lastRefill = now,
			}

			buckets[userId] = bucket
		end

		local elapsed =
			math.max(
				0,
				now - bucket.lastRefill
			)

		bucket.lastRefill = now

		bucket.tokens =
			math.min(
				capacity,
				bucket.tokens
				+ elapsed * rate
			)

		if bucket.tokens < requestedCost then
			return false
		end

		bucket.tokens -= requestedCost

		return true
	end

	-- =====================================================
	-- RESET
	-- =====================================================

	local function reset(
		userId: number
	)
		buckets[userId] = nil
	end

	-- =====================================================
	-- CLEAR
	-- =====================================================

	local function clear()
		table.clear(buckets)
	end

	return {
		allow = allow,

		reset = reset,

		clear = clear,
	}
end

return RateLimiter