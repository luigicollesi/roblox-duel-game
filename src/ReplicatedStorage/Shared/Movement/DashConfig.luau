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

-- 30 ticks @ 60 Hz = 0,5 s.
DashConfig.COOLDOWN_TICKS = 30

-- Velocidade horizontal alvo produzida pelo impulso.
--
-- Não é a distância em studs.
-- É aproximadamente studs/segundo imediatamente
-- após o impulso.
DashConfig.HORIZONTAL_SPEED = 48

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