$ErrorActionPreference = "Stop"

if (-not (Test-Path ".git")) {
    throw "Execute este script na raiz do repositorio RobloxMap."
}

if (-not (Test-Path ".\replacement-src\src")) {
    throw "Pasta replacement-src\src nao encontrada ao lado deste script."
}

Write-Host "Aplicando stance fire, dash fire trail e combat camera..."

Copy-Item `
    ".\replacement-src\src\*" `
    ".\src" `
    -Recurse `
    -Force

$required = @(
    ".\src\ServerScriptService\Server\Effects\StanceFireService.luau",
    ".\src\StarterPlayer\StarterPlayerScripts\Client\Camera\StanceCameraController.luau",
    ".\src\ServerScriptService\Server\Events\EventTypes.luau",
    ".\src\ServerScriptService\Server\Network\InputGateway.luau",
    ".\src\ServerScriptService\ServerBootstrap.server.luau",
    ".\src\StarterPlayer\StarterPlayerScripts\ClientBootstrap.client.luau",
    ".\src\StarterPlayer\StarterPlayerScripts\Client\Animation\LocalBoxController.luau"
)

foreach ($path in $required) {
    if (-not (Test-Path $path)) {
        throw "Arquivo esperado nao encontrado apos copia: $path"
    }
}

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
Write-Host "[OK] Stance VFX + combat camera aplicados."
Write-Host "Agora rode: rojo serve"
