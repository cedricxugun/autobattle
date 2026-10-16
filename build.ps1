$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw 'The .NET Framework C# compiler is required on Windows.' }
$launcher = Join-Path $projectRoot 'godot\WanxiangLauncher.exe'
& $compiler /nologo /target:winexe /codepage:65001 /reference:System.Windows.Forms.dll "/out:$launcher" (Join-Path $projectRoot 'godot\Launcher.cs')
if ($LASTEXITCODE -ne 0) { throw 'Launcher compilation failed.' }
python (Join-Path $projectRoot 'godot\package-carnival.py')
if ($LASTEXITCODE -ne 0) { throw 'Portable build failed.' }

