$ErrorActionPreference = "Stop"

function Write-Ok([string]$Message) {
    Write-Host "[OK] $Message"
}

function Replace-ExactOnce {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Old,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$New
    )

    if (-not (Test-Path $Path)) {
        throw "Arquivo nao encontrado: $Path"
    }

    $encoding = New-Object System.Text.UTF8Encoding($false)
    $text = [System.IO.File]::ReadAllText($Path)
    $text = $text.Replace("`r`n", "`n")

    $count = [regex]::Matches(
        $text,
        [regex]::Escape($Old)
    ).Count

    if ($count -eq 0) {
        throw "Trecho esperado nao encontrado em '$Path'. Rode 'git diff -- $Path' e envie a saida."
    }

    if ($count -ne 1) {
        throw "Esperava encontrar exatamente 1 ocorrencia em '$Path', mas encontrei $count."
    }

    $text = $text.Replace($Old, $New)
    [System.IO.File]::WriteAllText($Path, $text, $encoding)

    Write-Ok "Atualizado: $Path"
}

if (-not (Test-Path ".git")) {
    throw "Execute este script na raiz do repositorio RobloxMap."
}

# Confirma que as duas primeiras alteracoes do script anterior realmente foram aplicadas.
$duelService = ".\src\ServerScriptService\Server\Duels\DuelService.luau"
$duelText = [System.IO.File]::ReadAllText($duelService).Replace("`r`n", "`n")

if (-not $duelText.Contains("_stance: StanceServiceApi")) {
    throw "A primeira alteracao parcial nao foi encontrada (_stance). Nao continue."
}

if (-not $duelText.Contains('if state.stance ~= "Active" then')) {
    throw "A segunda alteracao parcial nao foi encontrada (stance Active no matchmaking). Nao continue."
}

Write-Ok "Estado parcial anterior confirmado."

# ============================================================
# DUEL SERVICE - REMAINING CHANGES
# ============================================================

Replace-ExactOnce `
    $duelService `
    @'
		local stateA =
			store.get(fighterA)

		if stateA ~= nil
			and stateA.stance ~= "Inactive"
		then
			stance.deactivate(fighterA)
		end

		local stateB =
			store.get(fighterB)

		if stateB ~= nil
			and stateB.stance ~= "Inactive"
		then
			stance.deactivate(fighterB)
		end

'@ `
    ""

Replace-ExactOnce `
    $duelService `
    @'
		local stanceAStarted =
			stance.start(aUserId)

		local stanceBStarted =
			stance.start(bUserId)

		if not stanceAStarted
			or not stanceBStarted
		then
			endDuelById(
				duelId,
				"InvalidState"
			)

			return nil
		end

'@ `
    ""

Replace-ExactOnce `
    $duelService `
    @'
		if stateA.duelId ~= duel.id
			or stateB.duelId ~= duel.id
		then
			return "InvalidState"
		end

		if not characters.isCharacterAlive(aUserId)
'@ `
    @'
		if stateA.duelId ~= duel.id
			or stateB.duelId ~= duel.id
		then
			return "InvalidState"
		end

		if stateA.stance ~= "Active"
			or stateB.stance ~= "Active"
		then
			return "InvalidState"
		end

		if not characters.isCharacterAlive(aUserId)
'@

# ============================================================
# DUEL ENGINE
# ============================================================

$duelEngine = ".\src\ServerScriptService\Server\Duels\DuelEngine.luau"

Replace-ExactOnce `
    $duelEngine `
    @'
			air = air,
			dash = dash,

			stanceActivated = false,
'@ `
    @'
			air = air,
			dash = dash,

			-- O DuelService agora cria a sessao apenas
			-- quando os dois jogadores ja estao em Active.
			stanceActivated = true,
'@

# ============================================================
# CHARACTER PRESENTATION
# ============================================================

$characterPresentation = ".\src\StarterPlayer\StarterCharacterScripts\CharacterPresentation.client.luau"

Replace-ExactOnce `
    $characterPresentation `
    @'
local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local player =
	Players.LocalPlayer

local characterInstance =
'@ `
    @'
local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local characterInstance =
'@

# ============================================================
# VERIFY EXPECTED NEW FILES / REPLACEMENTS
# ============================================================

$expectedNewFile =
    ".\src\ServerScriptService\Server\Character\StanceInputService.luau"

if (-not (Test-Path $expectedNewFile)) {
    throw "StanceInputService.luau nao existe. A copia de replacements nao foi concluida corretamente."
}

$combatTypes =
    [System.IO.File]::ReadAllText(
        ".\src\ReplicatedStorage\Shared\Combat\CombatTypes.luau"
    )

if (-not $combatTypes.Contains('"Stance"')) {
    throw "CombatTypes.luau nao contem a intent Stance."
}

$protocol =
    [System.IO.File]::ReadAllText(
        ".\src\ReplicatedStorage\Shared\Network\Protocol.luau"
    )

if (-not $protocol.Contains('value == "Stance"')) {
    throw "Protocol.luau nao reconhece a intent Stance."
}

Write-Ok "Arquivos de stance encontrados e validados."

# ============================================================
# GIT VALIDATION
# ============================================================

Write-Host ""
Write-Host "===== git diff --check ====="
git diff --check

if ($LASTEXITCODE -ne 0) {
    throw "git diff --check encontrou problemas."
}

Write-Host ""
Write-Host "===== git status --short ====="
git status --short

Write-Host ""
Write-Host "[OK] Correcao concluida."
Write-Host "Agora rode:"
Write-Host "  git diff"
Write-Host "  rojo serve"
