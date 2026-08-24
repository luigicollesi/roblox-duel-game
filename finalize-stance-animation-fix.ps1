$ErrorActionPreference = "Stop"

function Assert-Contains {
    param(
        [string]$Path,
        [string]$Needle,
        [string]$Label
    )

    if (-not (Test-Path $Path)) {
        throw "Arquivo ausente: $Path"
    }

    $text = [System.IO.File]::ReadAllText($Path)

    if (-not $text.Contains($Needle)) {
        throw "Validacao falhou: $Label ($Path)"
    }

    Write-Host "[OK] $Label"
}

if (-not (Test-Path ".git")) {
    throw "Execute este script na raiz do repositorio RobloxMap."
}

# ============================================================
# FINALIZE CHARACTER PRESENTATION
# ============================================================

$path =
    ".\src\StarterPlayer\StarterCharacterScripts\CharacterPresentation.client.luau"

if (-not (Test-Path $path)) {
    throw "Arquivo nao encontrado: $path"
}

$encoding =
    New-Object System.Text.UTF8Encoding($false)

$text =
    [System.IO.File]::ReadAllText($path)

$text =
    $text.Replace("`r`n", "`n")

# Remove SOMENTE a declaracao sem tipo:
#
# local player =
#     Players.LocalPlayer
#
# ou:
#
# local player = Players.LocalPlayer
#
# A declaracao tipada 'local player: Player =' e preservada.
$pattern =
    '(?ms)\n[ \t]*local[ \t]+player[ \t]*=[ \t]*(?:\n[ \t]*)?Players\.LocalPlayer[ \t]*\n'

$matches =
    [regex]::Matches(
        $text,
        $pattern
    )

if ($matches.Count -gt 1) {
    throw "Foram encontradas $($matches.Count) declaracoes locais nao tipadas de player. Nao alterei o arquivo."
}

if ($matches.Count -eq 1) {
    $text =
        [regex]::Replace(
            $text,
            $pattern,
            "`n",
            1
        )

    [System.IO.File]::WriteAllText(
        $path,
        $text,
        $encoding
    )

    Write-Host "[OK] Declaracao duplicada de player removida do CharacterPresentation."
}
else {
    Write-Host "[OK] CharacterPresentation ja nao possui declaracao duplicada de player."
}

# ============================================================
# VALIDATE FULL STANCE PIPELINE
# ============================================================

Assert-Contains `
    ".\src\ReplicatedStorage\Shared\Combat\CombatTypes.luau" `
    '"Stance"' `
    "CombatTypes possui intent Stance"

Assert-Contains `
    ".\src\ReplicatedStorage\Shared\Network\Protocol.luau" `
    'value == "Stance"' `
    "Protocol aceita intent Stance"

Assert-Contains `
    ".\src\StarterPlayer\StarterPlayerScripts\Client\Input\InputController.luau" `
    "Enum.KeyCode.One" `
    "InputController captura tecla 1"

Assert-Contains `
    ".\src\StarterPlayer\StarterPlayerScripts\ClientBootstrap.client.luau" `
    'network.sendIntent(' `
    "ClientBootstrap envia intents"

Assert-Contains `
    ".\src\StarterPlayer\StarterPlayerScripts\ClientBootstrap.client.luau" `
    '"Stance"' `
    "ClientBootstrap envia Stance"

Assert-Contains `
    ".\src\ServerScriptService\Server\Events\EventTypes.luau" `
    '"StanceToggleRequested"' `
    "EventTypes possui StanceToggleRequested"

Assert-Contains `
    ".\src\ServerScriptService\Server\Network\InputGateway.luau" `
    '"StanceToggleRequested"' `
    "InputGateway roteia Stance fora de duelo"

Assert-Contains `
    ".\src\ServerScriptService\Server\Character\StanceInputService.luau" `
    "STANCE_START_TICKS" `
    "StanceInputService temporiza Start"

Assert-Contains `
    ".\src\ServerScriptService\ServerBootstrap.server.luau" `
    "StanceInputService" `
    "ServerBootstrap inicializa StanceInputService"

Assert-Contains `
    ".\src\ServerScriptService\Server\Duels\DuelService.luau" `
    '_stance: StanceServiceApi' `
    "DuelService nao controla mais entrada da stance"

Assert-Contains `
    ".\src\ServerScriptService\Server\Duels\DuelService.luau" `
    'if state.stance ~= "Active" then' `
    "DuelService exige stance Active"

Assert-Contains `
    ".\src\ServerScriptService\Server\Duels\DuelEngine.luau" `
    "stanceActivated = true" `
    "DuelEngine recebe stance ja ativa"

# CharacterPresentation: typed player must remain.
Assert-Contains `
    $path `
    "local player: Player =" `
    "CharacterPresentation preserva LocalPlayer tipado"

# Must NOT contain the untyped duplicate anymore.
$finalText =
    [System.IO.File]::ReadAllText($path)

$duplicatePattern =
    '(?ms)local[ \t]+player[ \t]*=[ \t]*(?:\r?\n[ \t]*)?Players\.LocalPlayer'

if ([regex]::IsMatch($finalText, $duplicatePattern)) {
    throw "A declaracao duplicada de player ainda existe no CharacterPresentation."
}

Write-Host "[OK] CharacterPresentation sem LocalPlayer duplicado."

# ============================================================
# GIT CHECKS
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
Write-Host "[OK] Pipeline de stance validado."
Write-Host ""
Write-Host "Proximo passo:"
Write-Host "  rojo serve"
Write-Host ""
Write-Host "No Studio, teste:"
Write-Host "  1 -> Start -> Idle"
Write-Host "  andar -> Walk"
Write-Host "  parar -> Idle"
Write-Host "  1 -> sair da stance"
