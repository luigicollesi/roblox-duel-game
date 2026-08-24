$ErrorActionPreference = "Stop"

function Assert-ExactOnce {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Needle,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $count = [regex]::Matches(
        $Text,
        [regex]::Escape($Needle)
    ).Count

    if ($count -ne 1) {
        throw "$Label`: esperava 1 ocorrencia, encontrei $count. Nenhum arquivo foi copiado."
    }
}

function Replace-ExactOnce {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Old,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$New,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $count = [regex]::Matches(
        $Text,
        [regex]::Escape($Old)
    ).Count

    if ($count -ne 1) {
        throw "$Label`: esperava 1 ocorrencia, encontrei $count."
    }

    return $Text.Replace($Old, $New)
}

if (-not (Test-Path ".git")) {
    throw "Execute este script na raiz do repositorio RobloxMap."
}

if (-not (Test-Path ".\phase5-src\src")) {
    throw "Pasta .\phase5-src\src nao encontrada ao lado deste script."
}

git diff --quiet
if ($LASTEXITCODE -ne 0) {
    throw "Existem alteracoes rastreadas antes da instalacao. Commit/reverta antes de continuar."
}

git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    throw "Existem alteracoes em staging antes da instalacao."
}

$duelPath =
    ".\src\ServerScriptService\Server\Duels\DuelEngine.luau"

if (-not (Test-Path $duelPath)) {
    throw "DuelEngine.luau nao encontrado."
}

$encoding =
    New-Object System.Text.UTF8Encoding($false)

$duel =
    [System.IO.File]::ReadAllText(
        $duelPath
    ).Replace("`r`n", "`n")

$typeOld = @'
	air: AirApi,
	dash: DashApi,

	stanceActivated: boolean,
'@

$typeNew = @'
	air: AirApi,
	dash: DashApi,

	-- Cooldown autoritativo do Strong por jogador.
	strongReadyTickByUser:
		{[number]: number},

	stanceActivated: boolean,
'@

$beginOld = @'
	local function beginAttack(
		session: DuelSession,
		userId: number,
		kind: BufferedAttackKind,
		sequence: number
	)
		local state =
			store.getRequired(userId)

		local resolved =
			session.combo.resolve(
				kind,
				state.comboStep
			)

		session.attack.start(
			userId,

			resolved.action,
			sequence,
			resolved.nextComboStep,

			session.clock.getTick()
		)
	end
'@

$beginNew = @'
	local function beginAttack(
		session: DuelSession,
		userId: number,
		kind: BufferedAttackKind,
		sequence: number
	)
		local state =
			store.getRequired(userId)

		local resolved =
			session.combo.resolve(
				kind,
				state.comboStep
			)

		local currentTick =
			session.clock.getTick()

		if kind == "Strong" then
			session.strongReadyTickByUser[userId] =
				currentTick
				+ CombatConfig.STRONG_COOLDOWN_TICKS
		end

		session.attack.start(
			userId,

			resolved.action,
			sequence,
			resolved.nextComboStep,

			currentTick
		)
	end
'@

$intentOld = @'
		local resolution =
			ActionResolver.resolve(
				state,
				intentKind
			)
'@

$intentNew = @'
		-- Strong tem cooldown proprio. Ataques no ar ja
		-- retornaram acima como LandAttack e nao consomem
		-- nem dependem deste cooldown.
		if intentKind == "Strong" then
			local readyTick =
				session.strongReadyTickByUser[userId]

			if readyTick ~= nil
				and session.clock.getTick()
				< readyTick
			then
				publishReject(
					session,
					userId,
					sequence,
					"StrongCooldown"
				)

				return
			end
		end

		local resolution =
			ActionResolver.resolve(
				state,
				intentKind
			)
'@

$chainOld = @'
			session.attack.chain(
				userId,

				resolved.action,
				pending.sequence,
				resolved.nextComboStep,

				tick
			)
'@

$chainNew = @'
			if pending.kind == "Strong" then
				session.strongReadyTickByUser[userId] =
					tick
					+ CombatConfig.STRONG_COOLDOWN_TICKS
			end

			session.attack.chain(
				userId,

				resolved.action,
				pending.sequence,
				resolved.nextComboStep,

				tick
			)
'@

$sessionOld = @'
			air = air,
			dash = dash,

			-- O DuelService agora cria a sessao apenas
'@

$sessionNew = @'
			air = air,
			dash = dash,

			strongReadyTickByUser = {},

			-- O DuelService agora cria a sessao apenas
'@

Assert-ExactOnce $duel $typeOld "DuelSession type"
Assert-ExactOnce $duel $beginOld "beginAttack"
Assert-ExactOnce $duel $intentOld "Strong validation insertion"
Assert-ExactOnce $duel $chainOld "buffered Strong chain"
Assert-ExactOnce $duel $sessionOld "DuelSession initialization"

Write-Host "[OK] Preflight do DuelEngine concluido."

Copy-Item `
    ".\phase5-src\src\*" `
    ".\src" `
    -Recurse `
    -Force

Write-Host "[OK] Arquivos completos copiados."

$duel =
    Replace-ExactOnce $duel $typeOld $typeNew "DuelSession type"

$duel =
    Replace-ExactOnce $duel $beginOld $beginNew "beginAttack"

$duel =
    Replace-ExactOnce $duel $intentOld $intentNew "Strong validation"

$duel =
    Replace-ExactOnce $duel $chainOld $chainNew "buffered Strong chain"

$duel =
    Replace-ExactOnce $duel $sessionOld $sessionNew "DuelSession initialization"

[System.IO.File]::WriteAllText(
    $duelPath,
    $duel,
    $encoding
)

Write-Host "[OK] Cooldown autoritativo do Strong aplicado."

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
Write-Host "[OK] Refinamento de combate aplicado."
Write-Host "Agora rode: rojo serve"
