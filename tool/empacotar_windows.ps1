<#
.SYNOPSIS
  Gera o instalador do SICAPDA para Windows (SICAPDA-Setup.exe) e o manifesto app-windows.json.

.DESCRIPTION
  Precisa de:
   • "flutter build windows --release" já executado (este script não compila o app);
   • Inno Setup 6 instalado (winget install JRSoftware.InnoSetup  ou  choco install innosetup).
  Copia as DLLs do Visual C++ para a pasta do app (o Windows do cliente pode não ter o runtime instalado),
  compila windows\installer\sicapda.iss e escreve SICAPDA-Setup.exe + app-windows.json em -Saida.
  É o mesmo script que o GitHub Actions usa.

.PARAMETER Saida
  Pasta de destino dos dois arquivos. Padrão: dist

.PARAMETER Versao
  Versão mostrada no instalador. Padrão: a do pubspec.yaml (parte antes do "+").

.EXAMPLE
  flutter build windows --release
  .\tool\empacotar_windows.ps1
#>
param(
    [string]$Saida = 'dist',
    [string]$Versao = ''
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

$linha = (Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
$partes = $linha.Split('+')
if (-not $Versao) { $Versao = $partes[0] }
$build = if ($partes.Count -gt 1) { [int]$partes[1] } else { 0 }

$release = 'build\windows\x64\runner\Release'
if (-not (Test-Path "$release\SICAPDA.exe")) {
    throw "Não encontrei $release\SICAPDA.exe. Rode antes: flutter build windows --release"
}

# Runtime do Visual C++ junto do app (instalação "app-local", permitida pela Microsoft para essas DLLs)
foreach ($dll in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
    $origem = Join-Path $env:SystemRoot "System32\$dll"
    if (Test-Path $origem) { Copy-Item $origem $release -Force }
    else { Write-Warning "$dll não encontrada em System32; o instalador depende do Visual C++ já instalado no Windows do cliente." }
}

$candidatos = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
    "${env:LOCALAPPDATA}\Programs\Inno Setup 6\ISCC.exe"
)
$iscc = $candidatos | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) {
    throw 'Inno Setup 6 não encontrado. Instale com: winget install JRSoftware.InnoSetup'
}

New-Item -ItemType Directory -Force $Saida | Out-Null
$pastaSaida = (Resolve-Path $Saida).Path
& $iscc "/DAppVersion=$Versao" "/DOrigem=$((Resolve-Path $release).Path)" "/DSaida=$pastaSaida" 'windows\installer\sicapda.iss'
if ($LASTEXITCODE -ne 0) { throw 'O Inno Setup falhou.' }

$exe = Join-Path $pastaSaida 'SICAPDA-Setup.exe'
if (-not (Test-Path $exe)) { throw 'O instalador não foi gerado.' }

$manifesto = [ordered]@{
    arquivo       = 'SICAPDA-Setup.exe'
    versao        = $Versao
    build         = $build
    tamanho       = (Get-Item $exe).Length
    sha256        = (Get-FileHash $exe -Algorithm SHA256).Hash.ToLower()
    atualizado_em = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
}
# UTF-8 SEM BOM (o PHP não lê JSON com BOM)
[IO.File]::WriteAllText((Join-Path $pastaSaida 'app-windows.json'), ($manifesto | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))

Write-Host "Instalador: $exe"
Write-Host "Versão $($manifesto.versao) · $([math]::Round($manifesto.tamanho / 1MB, 1)) MB"
