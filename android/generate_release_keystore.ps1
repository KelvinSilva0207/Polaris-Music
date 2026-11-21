<#
    Genera UN ÚNICO keystore persistente para las builds de release de
    Polaris Music y escribe android/key.properties (ignorado por Git).

    Uso:
        powershell -ExecutionPolicy Bypass -File android\generate_release_keystore.ps1
        powershell -ExecutionPolicy Bypass -File android\generate_release_keystore.ps1 -PrintSecrets

    El keystore se guarda fuera del repo, en:
        %LOCALAPPDATA%\Polaris Music\signing\polaris-release.jks

    Con -PrintSecrets se muestran los valores listos para configurar los
    secrets del workflow de GitHub Actions. Guárdalos en un gestor seguro.
#>

[CmdletBinding()]
param(
    [string]$KeyStorePath,
    [string]$Alias = 'polaris_release',
    [int]$ValidityDays = 10000,
    [switch]$Force,
    [switch]$PrintSecrets
)

$ErrorActionPreference = 'Stop'

$androidDir = $PSScriptRoot
if (-not $KeyStorePath) {
    $base = Join-Path $env:LOCALAPPDATA 'Polaris Music\signing'
    $KeyStorePath = Join-Path $base 'polaris-release.jks'
}

$KeyStorePath = [IO.Path]::GetFullPath($KeyStorePath)
$parent = Split-Path -Parent $KeyStorePath
if (-not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
}

if ((Test-Path -LiteralPath $KeyStorePath) -and -not $Force) {
    throw "Ya existe $KeyStorePath. Usa -Force SOLO si quieres reemplazar la clave de release (invalidará las actualizaciones instaladas)."
}

$keytool = $null
if ($env:JAVA_HOME) {
    $candidate = Join-Path $env:JAVA_HOME 'bin\keytool.exe'
    if (Test-Path -LiteralPath $candidate) { $keytool = $candidate }
}
if (-not $keytool) {
    $command = Get-Command keytool.exe -ErrorAction SilentlyContinue
    if ($command) { $keytool = $command.Source }
}
if (-not $keytool) {
    throw 'No se encontró keytool.exe. Instala JDK 17 o define JAVA_HOME.'
}

function New-RandomPassword([int]$Length = 32) {
    $bytes = New-Object byte[] $Length
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    return -join ($bytes | ForEach-Object { $_.ToString('x2') })
}

$storePassword = New-RandomPassword
# PKCS12 no admite password de clave distinto al del store en JDK 9+.
$keyPassword = $storePassword

$arguments = @(
    '-genkeypair',
    '-v',
    '-keystore', $KeyStorePath,
    '-alias', $Alias,
    '-keyalg', 'RSA',
    '-keysize', '3072',
    '-validity', "$ValidityDays",
    '-storetype', 'PKCS12',
    '-storepass', $storePassword,
    '-keypass', $keyPassword,
    '-dname', 'CN=Polaris Music, OU= releases, O=Kelvin Silva, L=Unknown, ST=Unknown, C=US'
)

Write-Host "==> Generando keystore de release en $KeyStorePath"
# keytool escribe información por stderr; con ErrorActionPreference=Stop,
# redirigirlo convertiría esa salida en una excepción.
$previousPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    & $keytool @arguments 2>&1 | Out-Null
}
finally {
    $ErrorActionPreference = $previousPreference
}
if ($LASTEXITCODE -ne 0) {
    throw "keytool falló con código $LASTEXITCODE"
}

$propertiesPath = Join-Path $androidDir 'key.properties'
$escapedPath = $KeyStorePath.Replace('\', '/')
$lines = @(
    '# Generado por android/generate_release_keystore.ps1. NO versionar.',
    "storeFile=$escapedPath",
    "storePassword=$storePassword",
    "keyAlias=$Alias",
    "keyPassword=$keyPassword"
)
Set-Content -LiteralPath $propertiesPath -Value $lines -Encoding utf8

Write-Host "==> Escrito $propertiesPath"
Write-Host "==> Alias: $Alias"
Write-Host '==> Para CI configurá estos secrets en GitHub (Settings > Secrets and variables > Actions):'
Write-Host '    POLARIS_KEYSTORE_BASE64, POLARIS_KEYSTORE_PASSWORD, POLARIS_KEY_ALIAS, POLARIS_KEY_PASSWORD'

if ($PrintSecrets) {
    $base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($KeyStorePath))
    Write-Host ''
    Write-Host '--- VALORES PARA CI (NO compartir) ---'
    Write-Host "POLARIS_KEYSTORE_BASE64=$base64"
    Write-Host "POLARIS_KEYSTORE_PASSWORD=$storePassword"
    Write-Host "POLARIS_KEY_ALIAS=$Alias"
    Write-Host "POLARIS_KEY_PASSWORD=$keyPassword"
}
