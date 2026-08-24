$ErrorActionPreference = "Stop"

function Write-Ok([string]$Message) {
    Write-Host "[OK] $Message"
}

function Replace-ExactOnce {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Old,
        [Parameter(Mandatory = $true)][string]$New
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

    if ($count -ne 1) {
        throw "Esperava encontrar exatamente 1 ocorrencia em '$Path', mas encontrei $count. Nenhuma alteracao adicional foi aplicada nesse trecho."
    }

    $text = $text.Replace($Old, $New)
    [System.IO.File]::WriteAllText($Path, $text, $encoding)

    Write-Ok "Atualizado: $Path"
}

if (-not (Test-Path ".git")) {
    throw "Execute este script na raiz do repositorio RobloxMap."
}

if (-not (Test-Path ".\replacements\src")) {
    throw "A pasta .\replacements\src nao foi encontrada. Mantenha a pasta replacements extraida na raiz do projeto."
}

git diff --quiet
if ($LASTEXITCODE -ne 0) {
    throw "Existem alteracoes rastreadas antes da correcao. Rode 'git diff' e salve/reverta essas alteracoes antes de continuar."
}

git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    throw "Existem alteracoes em staging antes da correcao. Limpe o staging antes de continuar."
}

Write-Ok "Repositorio rastreado esta limpo."

Copy-Item `
    ".\replacements\src\*" `
    ".\src" `
    -Recurse `
    -Force

Write-Ok "Arquivos completos de replacements copiados para src."

$duelService = ".\src\ServerScriptService\Server\Duels\DuelService.luau"

Replace-ExactOnce `
    $duelService `
    @'
	characters: CharacterServiceApi,
	stance: StanceServiceApi
'@ `
    @'
	characters: CharacterServiceApi,
	_stance: StanceServiceApi
'@

Replace-ExactOnce `
    $duelService `
    @'
		if state.duelId ~= nil then
			return false
		end

		if state.stance ~= "Inactive" then
			return false
		end
'@ `
    @'
		if state.duelId ~= nil then
			return false
		end

		-- O jogador precisa terminar a entrada da stance
		-- antes de poder participar do matchmaking.
		if state.stance ~= "Active" then
			return false
		end
'@

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
Write-Host "Correcao aplicada com sucesso."
Write-Host "Agora revise com: git diff"
Write-Host "Depois rode: rojo serve"
