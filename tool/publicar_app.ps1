<#
.SYNOPSIS
  Compila o SICAPDA (Android, Windows e/ou web) e publica na página de apresentação do SystemFluxe.

.DESCRIPTION
  Copia os instaladores para <SystemFluxe>\storage\downloads e escreve os manifestos ao lado
  (app.json do Android e app-windows.json do Windows: versão, tamanho, data). A versão web vai para
  <SystemFluxe>\public\aplicativo (o .htaccess dessa pasta é preservado).
  Depois é só subir essas pastas para o servidor (ou dar commit, se você publica o site pelo Git).
  O Windows precisa do Inno Setup 6 instalado (winget install JRSoftware.InnoSetup).
  Sem tempo ou sem Inno Setup? O GitHub Actions faz tudo isso: veja o README.

.PARAMETER Plataforma
  Todas (padrão), Android, Windows ou Web.

.PARAMETER Destino
  Pasta do SystemFluxe. Padrão: ..\SystemFluxe (ao lado deste projeto).

.PARAMETER Servidor
  Endereço do servidor que o app deve usar por padrão (ex.: https://fluxeteam.com.br).

.PARAMETER SemBuild
  Não compila: só publica o que já foi compilado.

.EXAMPLE
  .\tool\publicar_app.ps1
  .\tool\publicar_app.ps1 -Plataforma Windows -Destino C:\Projetos\SystemFluxe
  .\tool\publicar_app.ps1 -Plataforma Web
#>
param(
    [ValidateSet('Todas', 'Android', 'Windows', 'Web')][string]$Plataforma = 'Todas',
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
        # um APK só: ARM de 32 e 64 bits (todos os celulares e tablets) e x86_64 (emuladores do Android Studio)
        & flutter build apk --release --target-platform 'android-arm,android-arm64,android-x64' @defines   # aspas: sem elas o PowerShell trata a vírgula como lista
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

# ---------------------------------------------------------------- Web
if ($Plataforma -in 'Todas', 'Web') {
    if (-not $SemBuild) {
        # --base-href /aplicativo/   : o SystemFluxe publica o app nessa pasta (public\aplicativo)
        # --no-web-resources-cdn     : leva o motor gráfico junto (sem isso o app não abre em redes que bloqueiam o gstatic.com)
        # --pwa-strategy=none        : sem o service worker obsoleto do Flutter; o web\sw.js do projeto cuida da instalação
        & flutter build web --release --base-href /aplicativo/ --no-web-resources-cdn --pwa-strategy=none @defines
        if ($LASTEXITCODE -ne 0) { throw 'flutter build web falhou.' }
    }
    $origemWeb = 'build\web'
    if (-not (Test-Path (Join-Path $origemWeb 'index.html'))) { throw "Build web não encontrado em $origemWeb" }

    # tira o que o navegador nunca baixa nessa configuração (de ~43 MB para ~19 MB)
    Remove-Item (Join-Path $origemWeb 'flutter_service_worker.js'), (Join-Path $origemWeb '.last_build_id') -Force -ErrorAction SilentlyContinue
    $motor = Join-Path $origemWeb 'canvaskit'
    Get-ChildItem $motor -Directory -Filter 'webparagraph' | Remove-Item -Recurse -Force
    Get-ChildItem $motor -File | Where-Object { $_.Name -like 'skwasm*' -or $_.Name -like 'wimp*' } | Remove-Item -Force
    Get-ChildItem $motor -Recurse -Filter '*.symbols' | Remove-Item -Force

    $destinoWeb = Join-Path (Resolve-Path $Destino).Path 'public\aplicativo'
    New-Item -ItemType Directory -Force $destinoWeb | Out-Null
    # apaga a versão antiga (menos o .htaccess da pasta, que é do site) e copia a nova
    Get-ChildItem $destinoWeb -Force | Where-Object { $_.Name -ne '.htaccess' } | Remove-Item -Recurse -Force
    Copy-Item (Join-Path $origemWeb '*') $destinoWeb -Recurse -Force
    Write-Host "Web publicada em $destinoWeb"
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

Write-Host "Pronto. Suba $pasta (e public\aplicativo, se publicou a web) para o servidor."
