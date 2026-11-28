param(
    [string]$SdkPath = $env:CONNECTIQ_SDK_HOME,
    [string]$JavaHome = $env:JAVA_HOME,
    [switch]$SyntaxOnly
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $projectRoot
if (-not $SdkPath -and (Test-Path 'D:\dev-cache\garmin\sdk\bin\monkeyc.bat')) { $SdkPath = 'D:\dev-cache\garmin\sdk' }
if (-not $JavaHome -and (Test-Path 'D:\program\android studio\jbr\bin\java.exe')) { $JavaHome = 'D:\program\android studio\jbr' }
if (-not (Test-Path (Join-Path $SdkPath 'bin\monkeyc.bat'))) { throw 'Installera Garmin Connect IQ SDK och ange -SdkPath.' }
if ($JavaHome) { $env:PATH = "$JavaHome\bin;$env:PATH" }
node scripts/generate-watch-config.mjs
if ($LASTEXITCODE -ne 0) { throw 'Konfigurationen kunde inte genereras.' }
New-Item -ItemType Directory -Force garmin\bin, garmin\local | Out-Null
@'
import fs from "node:fs"; import {generateKeyPairSync} from "node:crypto"; const path="garmin/local/developer.der"; if(!fs.existsSync(path)) fs.writeFileSync(path,generateKeyPairSync("rsa",{modulusLength:4096,privateKeyEncoding:{type:"pkcs8",format:"der"},publicKeyEncoding:{type:"spki",format:"pem"}}).privateKey);
'@ | node --input-type=module
if ($LASTEXITCODE -ne 0) { throw 'Signeringsnyckeln kunde inte skapas.' }
$targets = if ($SyntaxOnly) { @('syntax-check') } else { @('venu441mm', 'venu445mm') }
foreach ($target in $targets) {
    $outputPath = "garmin/bin/$target.prg"
    $compileArgs = @('-f', 'garmin/monkey.jungle', '-o', $outputPath, '-y', 'garmin/local/developer.der')
    if (-not $SyntaxOnly) { $compileArgs += @('-d', $target) }
    $output = & (Join-Path $SdkPath 'bin\monkeyc.bat') @compileArgs 2>&1
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    # Some compiler failures return 0. Require the explicit success marker too.
    if ($exitCode -ne 0 -or -not ($output -match 'BUILD SUCCESSFUL')) { throw "Bygget misslyckades för $target. Installera Venu 4-enheterna i SDK Manager om enhets-ID saknas." }
}
if ($SyntaxOnly) { Write-Host 'Endast generell kompilering. syntax-check.prg får INTE installeras på klockan.' }
else { Write-Host 'Båda enhetsbyggena klara. Simulator- och klocktest återstår.' }
