--!strict

local CombatConfig = {}

-- =========================================================
-- SIMULATION
-- =========================================================

CombatConfig.SIMULATION_HZ = 60
CombatConfig.FIXED_DT = 1 / CombatConfig.SIMULATION_HZ

-- Evita spiral of death caso o servidor tenha um frame
-- excepcionalmente longo.
CombatConfig.MAX_CATCH_UP_STEPS = 5

-- =========================================================
-- STANCE
-- =========================================================

-- Temporário até sincronizarmos exatamente com a
-- duração da animação Start.
CombatConfig.STANCE_START_TICKS = 30

-- =========================================================
-- INPUT BUFFER
-- =========================================================

-- Existe apenas UMA ação futura armazenada.
CombatConfig.ACTION_BUFFER_SIZE = 1

-- O input mais recente substitui o anterior.
CombatConfig.LATEST_BUFFERED_INPUT_WINS = true

-- =========================================================
-- COMBAT
-- =========================================================

CombatConfig.STRONG_RESETS_LIGHT_COMBO = true
CombatConfig.LAND_ATTACK_RESETS_LIGHT_COMBO = true

CombatConfig.LOCK_MOVEMENT_DURING_ATTACK = true

return CombatConfig