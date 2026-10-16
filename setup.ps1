$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-VerifiedRuntime([string]$Url, [string]$Destination, [string]$Sha256) {
    if ((Test-Path -LiteralPath $Destination) -and ((Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash -eq $Sha256)) {
        return
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
    $temporary = $Destination + '.download'
    Write-Host "Downloading $Url"
    Invoke-WebRequest -Uri $Url -OutFile $temporary -UseBasicParsing -TimeoutSec 600
    if ((Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash -ne $Sha256) {
        throw "SHA-256 mismatch: $Destination"
    }
    Move-Item -LiteralPath $temporary -Destination $Destination -Force
}

$engineZip = Join-Path $projectRoot 'godot\tools\cache\godot-4.7.2.zip'
$engineFolder = Join-Path $projectRoot 'godot\tools\godot-4.7.2'
$nodeBinary = Join-Path $projectRoot 'godot\wanxiang\runtime\node.exe'
Get-VerifiedRuntime 'https://downloads.godotengine.org/?flavor=stable&platform=windows.64&slug=win64.exe.zip&version=4.7.2' $engineZip '731980F9608D61333E5BAF54A2EF17210ACC7A538446C0CB9969F002ACA1E953'
Expand-Archive -LiteralPath $engineZip -DestinationPath $engineFolder -Force
Get-VerifiedRuntime 'https://nodejs.org/dist/v24.14.0/win-x64/node.exe' $nodeBinary '63C259C81E5D472B5F11C8D506070130CB04A1ECF84B80377A34ED6EC9048088'
$engineConsole = Join-Path $engineFolder 'Godot_v4.7.2-stable_win64_console.exe'
& $engineConsole --headless --path (Join-Path $projectRoot 'godot\wanxiang') --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
Write-Host 'Ready. Open project.godot in Godot or use the desktop launcher.'

