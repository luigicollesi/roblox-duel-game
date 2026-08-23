--!strict

local MovementConfig = {}

-- =========================================================
-- WALK
-- =========================================================

MovementConfig.STANCE_WALK_SPEED_MULTIPLIER = 0.80

-- Quando uma ação trava movimento voluntário.
MovementConfig.LOCKED_WALK_SPEED = 0

-- Velocidade mínima considerada movimento para o
-- estado lógico Walking.
MovementConfig.WALKING_SPEED_THRESHOLD = 0.05

-- =========================================================
-- AIR
-- =========================================================

-- Duração lógica da aterrissagem normal.
-- 8 ticks @ 60 Hz ~= 0,133 s.
--
-- Durante este período AnimationResolver futuramente
-- poderá escolher LandNormal (Jump invertido).
MovementConfig.NORMAL_LANDING_TICKS = 8

return MovementConfig