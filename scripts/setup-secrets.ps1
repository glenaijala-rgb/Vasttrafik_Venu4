$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$envPath = Join-Path $projectRoot 'backend\.env'
if (Test-Path -LiteralPath $envPath) {
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
$clientIdSecure = Read-Host 'Client ID / nyckel' -AsSecureString
$clientSecretSecure = Read-Host 'Client secret / hemlighet' -AsSecureString
function Get-PlainText([Security.SecureString]$Value) {
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}
$clientId = Get-PlainText $clientIdSecure
$clientSecret = Get-PlainText $clientSecretSecure
if (-not $clientId -or -not $clientSecret -or $clientId -match '[\r\n"'']' -or $clientSecret -match '[\r\n"'']') { throw 'Tomt eller ogiltigt nyckelformat.' }
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
# Restrict access to this Windows user before writing credentials.
$stream = [IO.File]::Create($envPath)
$stream.Dispose()
$acl = Get-Acl -LiteralPath $envPath
$acl.SetAccessRuleProtection($true, $false)
$identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($identity, 'FullControl', 'Allow'))
Set-Acl -LiteralPath $envPath -AclObject $acl
[IO.File]::WriteAllText($envPath, $content, [Text.UTF8Encoding]::new($false))
$clientId = $null; $clientSecret = $null; $content = $null; $watchKey = $null
Write-Host 'Klart. Nycklarna är sparade lokalt. Nästa steg är att verifiera hållplatser och färdriktningar.'
