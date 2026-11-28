param([string]$SettingsFile = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not $SettingsFile) { $SettingsFile = Join-Path $projectRoot 'garmin\local\VASTTRAFIK.SET' }
if (-not (Test-Path -LiteralPath $SettingsFile -PathType Leaf)) { throw 'Privat SET-fil saknas. Forbered den i Garmin-simulatorn forst.' }
if ((Get-Item -LiteralPath $SettingsFile).Length -lt 100) { throw 'SET-filen verkar sakna API-installningar.' }
$packageRoot = Join-Path $projectRoot 'garmin\local\installation'
New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null
$identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$acl = New-Object Security.AccessControl.DirectorySecurity
$acl.SetAccessRuleProtection($true, $false)
$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($identity, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'))
[IO.Directory]::SetAccessControl($packageRoot, $acl)
foreach ($size in @('41', '45')) {
    $binary = Join-Path $projectRoot "garmin\bin\venu4${size}mm.prg"
    if (-not (Test-Path -LiteralPath $binary)) { throw "Produktionsbygge saknas: $size mm" }
    $apps = Join-Path $packageRoot "$size-mm\GARMIN\APPS"
    New-Item -ItemType Directory -Force -Path (Join-Path $apps 'SETTINGS') | Out-Null
    Copy-Item -LiteralPath $binary -Destination (Join-Path $apps 'VASTTRAFIK.PRG')
    Copy-Item -LiteralPath $SettingsFile -Destination (Join-Path $apps 'SETTINGS\VASTTRAFIK.SET')
    if ((Get-FileHash -LiteralPath $binary).Hash -ne (Get-FileHash -LiteralPath (Join-Path $apps 'VASTTRAFIK.PRG')).Hash) { throw 'Byggfilens kontrollsumma stammer inte.' }
    if ((Get-FileHash -LiteralPath $SettingsFile).Hash -ne (Get-FileHash -LiteralPath (Join-Path $apps 'SETTINGS\VASTTRAFIK.SET')).Hash) { throw 'Installningsfilens kontrollsumma stammer inte.' }
}
Write-Host 'Privata installationsmappar for 41 och 45 mm ar klara under garmin\local\installation. Dela inte dessa mappar.'
