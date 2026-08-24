$ErrorActionPreference = "Stop"

$path = ".\src\StarterPlayer\StarterPlayerScripts\Client\Animation\LocalBoxController.luau"

if (-not (Test-Path ".git")) {
    throw "Execute este script na raiz do repositorio RobloxMap."
}

if (-not (Test-Path $path)) {
    throw "Arquivo nao encontrado: $path"
}

$encoding = New-Object System.Text.UTF8Encoding($false)

$text = [System.IO.File]::ReadAllText($path)
$text = $text.Replace("`r`n", "`n")

$literalTab = '\t'
$startMarker = $literalTab + '-- COMBO'
$endMarker = "`t-- DASH"

$startIndex = $text.IndexOf(
    $startMarker,
    [System.StringComparison]::Ordinal
)

if ($startIndex -lt 0) {
    if ($text.Contains("`t-- COMBO")) {
        Write-Host "[OK] O bloco COMBO ja esta corrigido."

        git diff --check

        if ($LASTEXITCODE -ne 0) {
            throw "git diff --check encontrou problemas."
        }

        exit 0
    }

    throw "Nao encontrei o marcador literal \t-- COMBO."
}

$endIndex = $text.IndexOf(
    $endMarker,
    $startIndex,
    [System.StringComparison]::Ordinal
)

if ($endIndex -lt 0) {
    throw "Nao encontrei o bloco DASH apos o trecho contaminado."
}

$segment = $text.Substring(
    $startIndex,
    $endIndex - $startIndex
)

$countBefore = [regex]::Matches(
    $segment,
    [regex]::Escape($literalTab)
).Count

if ($countBefore -eq 0) {
    throw "Nenhum marcador \t literal encontrado no trecho."
}

Write-Host "[INFO] Marcadores \t literais encontrados: $countBefore"

$fixedSegment = $segment.Replace(
    $literalTab,
    "`t"
)

$fixedText =
    $text.Substring(0, $startIndex) +
    $fixedSegment +
    $text.Substring($endIndex)

if ($fixedText.Contains('\t-- COMBO')) {
    throw "Falha: ainda existe \t literal no bloco COMBO."
}

if ($fixedText.Contains('\tlocal function requestStrong')) {
    throw "Falha: ainda existe \t literal no bloco STRONG."
}

if (-not $fixedText.Contains("`t-- COMBO")) {
    throw "Falha: COMBO com tab real nao foi encontrado."
}

if (-not $fixedText.Contains("`tlocal function requestStrong()")) {
    throw "Falha: requestStrong com tab real nao foi encontrado."
}

[System.IO.File]::WriteAllText(
    $path,
    $fixedText,
    $encoding
)

Write-Host "[OK] LocalBoxController corrigido."

Write-Host ""
Write-Host "===== git diff --check ====="

git diff --check

if ($LASTEXITCODE -ne 0) {
    throw "git diff --check encontrou problemas."
}

Write-Host ""
Write-Host "===== verificacao de \t literal ====="

$verify = [System.IO.File]::ReadAllText($path)

$remaining = [regex]::Matches(
    $verify,
    [regex]::Escape($literalTab)
).Count

Write-Host "Ocorrencias restantes de \t literal no arquivo: $remaining"

Write-Host ""
Write-Host "[OK] Correcao concluida."
Write-Host "Agora rode: rojo serve"
