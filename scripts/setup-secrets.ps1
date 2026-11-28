param([switch]$UpdateCredentials)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$envPath = Join-Path $projectRoot 'backend\.env'
$existing = Test-Path -LiteralPath $envPath
if ($existing -and -not $UpdateCredentials) {
    Write-Host "Inställningsfilen finns redan: $envPath. Den skrivs inte över."
    exit 0
}
Write-Host 'Kopiera uppgifterna från Västtrafiks utvecklarportal. Hemligheterna visas inte och hamnar inte i Git.'
$baseUrl = 'https://ext-api.vasttrafik.se/pr/v4'
$tokenUrl = 'https://ext-api.vasttrafik.se/token'
foreach ($value in @($baseUrl, $tokenUrl)) {
    $uri = [Uri]$value
    if (-not $uri.IsAbsoluteUri -or $uri.Scheme -ne 'https' -or $uri.UserInfo -or $uri.Query -or $uri.Fragment) { throw 'Adressen måste vara HTTPS utan inloggningsuppgifter eller frågeparametrar.' }
}
Write-Host 'Klistra in genom att HÖGERKLICKA i PowerShell-fönstret. Använd inte Ctrl+V vid dessa två frågor.'
$clientIdSecure = Read-Host 'Klientidentifierare (INTE autentiseringsnyckel)' -AsSecureString
$clientSecretSecure = Read-Host 'Client secret / hemlighet' -AsSecureString
function Get-PlainText([Security.SecureString]$Value) {
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}
$clientId = (Get-PlainText $clientIdSecure).Trim()
$clientSecret = (Get-PlainText $clientSecretSecure).Trim()
if (-not $clientId -or -not $clientSecret -or $clientId -match '[\r\n"'']' -or $clientSecret -match '[\r\n"'']') { throw 'Tomt eller ogiltigt nyckelformat.' }
if ($clientId.Length -lt 2 -or $clientSecret.Length -lt 2 -or $clientId -match '[\x00-\x20\x7f]' -or $clientSecret -match '[\x00-\x20\x7f]') {
    throw 'Koderna klistrades inte in korrekt. Ingen ändring har sparats. Kör igen och högerklicka för att klistra in i stället för Ctrl+V.'
}
$bytes = New-Object byte[] 32
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
$watchKey = [BitConverter]::ToString($bytes).Replace('-', '').ToLowerInvariant()
$content = @"
VASTTRAFIK_API_BASE_URL="$baseUrl"
VASTTRAFIK_TOKEN_URL="$tokenUrl"
VASTTRAFIK_CLIENT_ID="$clientId"
VASTTRAFIK_CLIENT_SECRET="$clientSecret"
WATCH_ACCESS_KEY="$watchKey"
HOST=127.0.0.1
PORT=8787
"@
if ($existing) {
    # Preserve the watch key, addresses and all other settings during repair.
    $lines = [IO.File]::ReadAllLines($envPath)
    foreach ($name in @('VASTTRAFIK_CLIENT_ID', 'VASTTRAFIK_CLIENT_SECRET')) {
        if (@($lines | Where-Object { $_ -match "^$name=" }).Count -ne 1) {
            throw 'Inställningsfilen har oväntat format. Ingen ändring har sparats.'
        }
    }
    $content = ($lines | ForEach-Object {
        if ($_ -match '^VASTTRAFIK_CLIENT_ID=') { 'VASTTRAFIK_CLIENT_ID="' + $clientId + '"' }
        elseif ($_ -match '^VASTTRAFIK_CLIENT_SECRET=') { 'VASTTRAFIK_CLIENT_SECRET="' + $clientSecret + '"' }
        else { $_ }
    }) -join [Environment]::NewLine
} else {
    $stream = [IO.File]::Create($envPath)
    $stream.Dispose()
}
# Restrict access to this Windows user before writing credentials.
$acl = New-Object Security.AccessControl.FileSecurity
$acl.SetAccessRuleProtection($true, $false)
$identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($identity, 'FullControl', 'Allow'))
[IO.File]::SetAccessControl($envPath, $acl)
[IO.File]::WriteAllText($envPath, $content, [Text.UTF8Encoding]::new($false))
$clientId = $null; $clientSecret = $null; $content = $null; $watchKey = $null
Write-Host 'Klart. Nycklarna är sparade lokalt. Nästa steg är att verifiera hållplatser och färdriktningar.'
