<#
.SYNOPSIS
  Compila o SICAPDA (Android e/ou Windows) e publica na página de apresentação do SystemFluxe.

.DESCRIPTION
  Copia os instaladores para <SystemFluxe>\storage\downloads e escreve os manifestos ao lado
  (app.json do Android e app-windows.json do Windows: versão, tamanho, data).
  Depois é só subir a pasta storage\downloads para o servidor (ou dar commit, se você publica o site pelo Git).
  O Windows precisa do Inno Setup 6 instalado (winget install JRSoftware.InnoSetup).
  Sem tempo ou sem Inno Setup? O GitHub Actions faz tudo isso: veja o README.

.PARAMETER Plataforma
  Todas (padrão), Android ou Windows.

.PARAMETER Destino
  Pasta do SystemFluxe. Padrão: ..\SystemFluxe (ao lado deste projeto).

.PARAMETER Servidor
  Endereço do servidor que o app deve usar por padrão (ex.: https://fluxeteam.com.br).

.PARAMETER SemBuild
  Não compila: só publica o que já foi compilado.

.EXAMPLE
  .\tool\publicar_app.ps1
  .\tool\publicar_app.ps1 -Plataforma Windows -Destino C:\Projetos\SystemFluxe
#>
param(
    [ValidateSet('Todas', 'Android', 'Windows')][string]$Plataforma = 'Todas',
    [string]$Destino = (Join-Path $PSScriptRoot '..\..\SystemFluxe'),
    [string]$Servidor = '',
    [switch]$SemBuild
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

$pasta = Join-Path (Resolve-Path $Destino).Path 'storage\downloads'
New-Item -ItemType Directory -Force $pasta | Out-Null

$linha = (Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
$partes = $linha.Split('+')
$versao = $partes[0]
$build = if ($partes.Count -gt 1) { [int]$partes[1] } else { 0 }
$defines = @()
if ($Servidor) { $defines += "--dart-define=SICAPDA_SERVER_URL=$Servidor" }
$semBom = New-Object Text.UTF8Encoding($false)   # o PHP não lê JSON com BOM

# ---------------------------------------------------------------- Android
if ($Plataforma -in 'Todas', 'Android') {
    if (-not $SemBuild) {
        # só arquiteturas ARM (todos os celulares); emulador de PC: use "flutter run"
        & flutter build apk --release --target-platform android-arm,android-arm64 @defines
        if ($LASTEXITCODE -ne 0) { throw 'flutter build apk falhou.' }
    }
    $apk = 'build\app\outputs\flutter-apk\app-release.apk'
    if (-not (Test-Path $apk)) { throw "APK não encontrado em $apk" }

    $saidaApk = Join-Path $pasta 'SICAPDA.apk'
    Copy-Item $apk $saidaApk -Force
    $manifesto = [ordered]@{
        arquivo       = 'SICAPDA.apk'
        versao        = $versao
        build         = $build
        tamanho       = (Get-Item $saidaApk).Length
        sha256        = (Get-FileHash $saidaApk -Algorithm SHA256).Hash.ToLower()
        min_sdk       = $null
        atualizado_em = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    }
    [IO.File]::WriteAllText((Join-Path $pasta 'app.json'), ($manifesto | ConvertTo-Json), $semBom)
    Write-Host "Android publicado em $saidaApk ($([math]::Round($manifesto.tamanho / 1MB, 1)) MB)"
}

# ---------------------------------------------------------------- Windows
if ($Plataforma -in 'Todas', 'Windows') {
    try {
        if (-not $SemBuild) {
            & flutter build windows --release @defines
            if ($LASTEXITCODE -ne 0) { throw 'flutter build windows falhou.' }
        }
        & (Join-Path $PSScriptRoot 'empacotar_windows.ps1') -Saida $pasta
    }
    catch {
        if ($Plataforma -eq 'Windows') { throw }
        Write-Warning "Windows não foi publicado: $($_.Exception.Message)"
    }
}

Write-Host "Pronto. Suba a pasta $pasta para o servidor."
