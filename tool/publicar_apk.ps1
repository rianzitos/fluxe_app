<#
.SYNOPSIS
  Compila o APK de release do SICAPDA e publica na página de apresentação do SystemFluxe.

.DESCRIPTION
  Copia o APK para <SystemFluxe>\storage\downloads\SICAPDA.apk e escreve o app.json ao lado
  (versão, tamanho, SHA-256, data). Depois é só subir a pasta storage\downloads para o servidor
  (ou dar commit, se você publica o site pelo Git).

.PARAMETER Destino
  Pasta do SystemFluxe. Padrão: ..\SystemFluxe (ao lado deste projeto).

.PARAMETER Servidor
  Endereço do servidor que o app deve usar por padrão (ex.: https://fluxeteam.com.br).

.PARAMETER SemBuild
  Não compila: só publica o APK que já existe em build\app\outputs\flutter-apk.

.EXAMPLE
  .\tool\publicar_apk.ps1
  .\tool\publicar_apk.ps1 -Destino C:\Projetos\SystemFluxe -Servidor https://fluxeteam.com.br
#>
param(
    [string]$Destino = (Join-Path $PSScriptRoot '..\..\SystemFluxe'),
    [string]$Servidor = '',
    [switch]$SemBuild
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

if (-not $SemBuild) {
    $argsBuild = @('build', 'apk', '--release', '--target-platform', 'android-arm,android-arm64')
    if ($Servidor) { $argsBuild += "--dart-define=SICAPDA_SERVER_URL=$Servidor" }
    & flutter @argsBuild
    if ($LASTEXITCODE -ne 0) { throw 'flutter build apk falhou.' }
}

$apk = 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $apk)) { throw "APK não encontrado em $apk" }

$pasta = Join-Path (Resolve-Path $Destino).Path 'storage\downloads'
New-Item -ItemType Directory -Force $pasta | Out-Null
$saida = Join-Path $pasta 'SICAPDA.apk'
Copy-Item $apk $saida -Force

$linha = (Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
$partes = $linha.Split('+')
$manifesto = [ordered]@{
    arquivo       = 'SICAPDA.apk'
    versao        = $partes[0]
    build         = if ($partes.Count -gt 1) { [int]$partes[1] } else { 0 }
    tamanho       = (Get-Item $saida).Length
    sha256        = (Get-FileHash $saida -Algorithm SHA256).Hash.ToLower()
    min_sdk       = $null
    atualizado_em = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
}
# UTF-8 SEM BOM (o PHP não lê JSON com BOM)
[IO.File]::WriteAllText((Join-Path $pasta 'app.json'), ($manifesto | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))

Write-Host "APK publicado em $saida"
Write-Host "Versão $($manifesto.versao) · $([math]::Round($manifesto.tamanho / 1MB, 1)) MB · SHA-256 $($manifesto.sha256)"
