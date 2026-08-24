$ErrorActionPreference = "Stop"

$path =
    ".\src\StarterPlayer\StarterPlayerScripts\Client\Animation\LocalBoxController.luau"

if (-not (Test-Path ".git")) {
    throw "Execute este script na raiz do repositorio RobloxMap."
}

if (-not (Test-Path $path)) {
    throw "Arquivo nao encontrado: $path"
}

$encoding =
    New-Object System.Text.UTF8Encoding($false)

$text =
    [System.IO.File]::ReadAllText($path)

$text =
    $text.Replace("`r`n", "`n")

# O erro gerado no pacote anterior inseriu os dois caracteres
# '\' e 't' no bloco COMBO/STRONG, em vez de tabs reais.
$startMarker =
    '\t-- =====================================================' +
    "`n" +
    '\t-- COMBO'

$endMarker =
    "`n`t-- =====================================================`n`t-- DASH"

$startIndex =
    $text.IndexOf(
        $startMarker,
        [System.StringComparison]::Ordinal
    )

if ($startIndex -lt 0) {
    # Se o arquivo já foi corrigido, não devemos alterar nada.
    if ($text.Contains("`t-- COMBO")) {
        Write-Host "[OK] Bloco COMBO ja usa tabs reais."
        Write-Host ""
        git diff --check
        exit $LASTEXITCODE
    end

    throw "Nao encontrei o inicio contaminado do bloco COMBO."
}

$endIndex =
    $text.IndexOf(
        $endMarker,
        $startIndex,
        [System.StringComparison]::Ordinal
    )

if ($endIndex -lt 0) {
    throw "Nao encontrei o fim do trecho contaminado antes de DASH."
}

$segmentLength =
    $endIndex - $startIndex

$segment =
    $text.Substring(
        $startIndex,
        $segmentLength
    )

$literalTabCount =
    [regex]::Matches(
        $segment,
        [regex]::Escape('\t')
    ).Count

if ($literalTabCount -eq 0) {
    throw "O trecho COMBO/STRONG foi localizado, mas nao contem \t literal."
}

Write-Host "[INFO] Encontrados $literalTabCount marcadores \t literais."

$fixedSegment =
    $segment.Replace(
        '\t',
        "`t"
    )

$fixedText =
    $text.Substring(
        0,
        $startIndex
    ) +
    $fixedSegment +
    $text.Substring(
        $endIndex
    )

# Garantias específicas.
if ($fixedText.Contains('\t-- COMBO')) {
    throw "Ainda existe marcador \t literal no inicio de COMBO."
}

if ($fixedText.Contains('\tlocal function requestStrong')) {
    throw "Ainda existe marcador \t literal no bloco Strong."
}

if (-not $fixedText.Contains("`t-- COMBO")) {
    throw "Bloco COMBO corrigido nao foi encontrado."
}

if (-not $fixedText.Contains("`tlocal function requestStrong()")) {
    throw "requestStrong corrigido nao foi encontrado."
}

[System.IO.File]::WriteAllText(
    $path,
    $fixedText,
    $encoding
)

Write-Host "[OK] Tabs literais corrigidas em LocalBoxController.luau."

Write-Host ""
Write-Host "===== git diff --check ====="
git diff --check

if ($LASTEXITCODE -ne 0) {
    throw "git diff --check encontrou problemas."
}

Write-Host ""
Write-Host "===== trecho corrigido ====="
Get-Content $path |
    Select-Object -Skip 370 -First 35

Write-Host ""
Write-Host "[OK] Correcao concluida."
Write-Host "Agora rode: rojo serve"
