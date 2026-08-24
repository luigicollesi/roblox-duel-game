--!strict

local CombatTypes = require(
	script.Parent.Parent.Combat.CombatTypes
)

type DashDirection = CombatTypes.DashDirection
type DashAction = CombatTypes.DashAction

local DashConfig = {}

-- =========================================================
-- BEHAVIOR
-- =========================================================

local DEFAULT_DIRECTION: DashDirection = "Back"

DashConfig.DEFAULT_DIRECTION = DEFAULT_DIRECTION

-- 10 ticks @ 60 Hz ~= 0,167 s.
DashConfig.DURATION_TICKS = 10

-- 180 ticks @ 60 Hz = 3 s.
DashConfig.COOLDOWN_TICKS = 180

-- Velocidade horizontal alvo produzida pelo impulso.
--
-- 96 studs/s aumenta a distância sem alongar a animação:
-- o dash continua curto e explosivo, mas cobre mais espaço.
DashConfig.HORIZONTAL_SPEED = 96

-- Abaixo deste valor consideramos que o personagem
-- não está tentando andar em nenhuma direção.
DashConfig.MOVE_DIRECTION_THRESHOLD = 0.05

-- =========================================================
-- ACTION
-- =========================================================

function DashConfig.getAction(
	direction: DashDirection
): DashAction

	if direction == "Forward" then
		return "DashF"
	end

	if direction == "Back" then
		return "DashB"
	end

	if direction == "Left" then
		return "DashL"
	end

	if direction == "Right" then
		return "DashR"
	end

	error(`Invalid dash direction: {direction}`)
end

return DashConfig
