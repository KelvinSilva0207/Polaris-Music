<#
    Compila el instalador de Polaris Music para Windows con Inno Setup 6.

    Uso rapido:
        powershell -ExecutionPolicy Bypass -File installer\build_installer.ps1

    Opciones:
        -SkipBuild        No ejecuta "flutter build windows --release".
        -Version X.Y.Z    Sobrescribe la version de pubspec.yaml.
        -IsccPath <ruta>  Ruta explicita a ISCC.exe.
        -RegenerateAssets Vuelve a generar las imagenes del asistente.

    Salida:
        installer\Output\Polaris-Music-Setup-<version>.exe
#>

[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [string]$Version,
    [string]$IsccPath,
    [switch]$RegenerateAssets
)

$ErrorActionPreference = 'Stop'

$installerDir = $PSScriptRoot
$repoRoot = Split-Path -Parent $installerDir
$releaseDir = Join-Path $repoRoot 'build\windows\x64\runner\Release'
$appExe = Join-Path $releaseDir 'polaris_music.exe'
$pubspec = Join-Path $repoRoot 'pubspec.yaml'

function Write-Step([string]$Message) {
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

if (-not $Version) {
    if (-not (Test-Path -LiteralPath $pubspec)) {
        throw "No se encontro pubspec.yaml en $repoRoot"
    }
    $versionLine = Select-String -LiteralPath $pubspec -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)' |
        Select-Object -First 1
    if (-not $versionLine) {
        throw 'No se pudo leer la version desde pubspec.yaml'
    }
    $Version = $versionLine.Matches[0].Groups[1].Value
}

Write-Step "Version del instalador: $Version"

if (-not $SkipBuild) {
    Write-Step 'Compilando Polaris Music para Windows (release)'
    Push-Location $repoRoot
    try {
        & flutter build windows --release
        if ($LASTEXITCODE -ne 0) {
            throw "flutter build windows fallo con codigo $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}

if (-not (Test-Path -LiteralPath $appExe)) {
    throw "No se encontro el ejecutable compilado: $appExe. Ejecuta sin -SkipBuild."
}

if ($RegenerateAssets -or -not (Test-Path -LiteralPath (Join-Path $installerDir 'assets\wizard.png'))) {
    Write-Step 'Generando imagenes del asistente'
    & (Join-Path $installerDir 'generate_assets.ps1')
    if ($LASTEXITCODE -ne 0) {
        throw "generate_assets.ps1 fallo con codigo $LASTEXITCODE"
    }
}

if (-not $IsccPath) {
    $command = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($command) {
        $IsccPath = $command.Source
    }
    else {
        $candidates = @(
            (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
            (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'),
            (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe')
        )
        $IsccPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    }
}

if (-not $IsccPath -or -not (Test-Path -LiteralPath $IsccPath)) {
    throw @'
No se encontro ISCC.exe (Inno Setup 6).
Instalalo con:  winget install --id JRSoftware.InnoSetup -e
O indica la ruta con -IsccPath "C:\ruta\a\ISCC.exe".
'@
}

Write-Step "Compilando instalador con $IsccPath"
$env:POLARIS_VERSION = $Version
Push-Location $installerDir
try {
    & $IsccPath 'polaris_music.iss'
    if ($LASTEXITCODE -ne 0) {
        throw "ISCC fallo con codigo $LASTEXITCODE"
    }
}
finally {
    Pop-Location
    Remove-Item Env:\POLARIS_VERSION -ErrorAction SilentlyContinue
}

$output = Join-Path $installerDir "Output\Polaris-Music-Setup-$Version.exe"
if (-not (Test-Path -LiteralPath $output)) {
    throw "El compilador no genero el instalador esperado: $output"
}

$sizeMb = [math]::Round((Get-Item -LiteralPath $output).Length / 1MB, 1)
Write-Step "Listo: $output ($sizeMb MB)"
Write-Output $output
