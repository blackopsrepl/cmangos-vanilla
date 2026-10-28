param(
    [Parameter(Mandatory = $true)][string]$Username,
    [Parameter(Mandatory = $true)][string]$Password,
    [ValidateRange(0, 3)][int]$GmLevel = 0
)

. "$PSScriptRoot\common.ps1"

Add-Type -AssemblyName System.Numerics

function ConvertTo-Hex {
    param([Parameter(Mandatory = $true)][byte[]]$Bytes)
    return (($Bytes | ForEach-Object { $_.ToString('X2') }) -join '')
}

function ConvertFrom-HexBigEndianToBigInteger {
    param([Parameter(Mandatory = $true)][string]$Hex)

    $clean = $Hex.Trim()
    if (($clean.Length % 2) -eq 1) {
        $clean = "0$clean"
    }

    [byte[]]$bytes = for ($i = 0; $i -lt $clean.Length; $i += 2) {
        [Convert]::ToByte($clean.Substring($i, 2), 16)
    }
    [Array]::Reverse($bytes)

    $positive = New-Object byte[] ($bytes.Length + 1)
    [Array]::Copy($bytes, $positive, $bytes.Length)
    return [System.Numerics.BigInteger]::new($positive)
}

function ConvertFrom-LittleEndianBytesToBigInteger {
    param([Parameter(Mandatory = $true)][byte[]]$Bytes)

    $positive = New-Object byte[] ($Bytes.Length + 1)
    [Array]::Copy($Bytes, $positive, $Bytes.Length)
    return [System.Numerics.BigInteger]::new($positive)
}

function ConvertTo-BigEndianHex {
    param([Parameter(Mandatory = $true)][System.Numerics.BigInteger]$Value)

    if ($Value.Sign -lt 0) {
        throw "Negative BigInteger is not supported."
    }

    [byte[]]$little = $Value.ToByteArray()
    while ($little.Length -gt 1 -and $little[$little.Length - 1] -eq 0) {
        [byte[]]$little = $little[0..($little.Length - 2)]
    }

    [Array]::Reverse($little)
    $hex = ConvertTo-Hex -Bytes $little
    $hex = $hex.TrimStart('0')
    if ([string]::IsNullOrWhiteSpace($hex)) {
        return '0'
    }
    return $hex
}

function New-CmangosSrp6Verifier {
    param(
        [Parameter(Mandatory = $true)][string]$NormalizedUsername,
        [Parameter(Mandatory = $true)][string]$NormalizedPassword
    )

    $sha1 = [System.Security.Cryptography.SHA1]::Create()
    try {
        $identityBytes = [System.Text.Encoding]::UTF8.GetBytes("${NormalizedUsername}:${NormalizedPassword}")
        [byte[]]$identityDigest = $sha1.ComputeHash($identityBytes)

        [byte[]]$saltBigEndian = New-Object byte[] 32
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        try {
            $rng.GetBytes($saltBigEndian)
        } finally {
            $rng.Dispose()
        }

        $saltBigEndian[0] = [byte]($saltBigEndian[0] -bor 0x80)
        $saltBigEndian[31] = [byte]($saltBigEndian[31] -bor 0x01)

        [byte[]]$saltLittleEndian = $saltBigEndian.Clone()
        [Array]::Reverse($saltLittleEndian)

        [byte[]]$xInput = $saltLittleEndian + $identityDigest
        [byte[]]$xDigest = $sha1.ComputeHash($xInput)
        $x = ConvertFrom-LittleEndianBytesToBigInteger -Bytes $xDigest

        $n = ConvertFrom-HexBigEndianToBigInteger -Hex '894B645E89E1535BBDAD5B8B290650530801B18EBFBF5E8FAB3C82872A3E9BB7'
        $g = [System.Numerics.BigInteger]::new(7)
        $v = [System.Numerics.BigInteger]::ModPow($g, $x, $n)

        return @{
            Salt = (ConvertTo-Hex -Bytes $saltBigEndian)
            Verifier = (ConvertTo-BigEndianHex -Value $v).ToUpperInvariant()
        }
    } finally {
        $sha1.Dispose()
    }
}

Ensure-EnvFile | Out-Null
Require-Docker

if ($Username.Length -lt 1 -or $Username.Length -gt 32) {
    throw "Username must be 1 to 32 characters."
}
if ($Password.Length -lt 1 -or $Password.Length -gt 32) {
    throw "Password must be 1 to 32 characters for this legacy account table."
}
if ($Username -notmatch '^[A-Za-z0-9_.@-]+$') {
    throw "Use only ASCII letters, numbers, underscore, dot, at-sign, or hyphen in account names."
}

$values = Get-CmangosEnv
$realmDb = Get-EnvValue -Values $values -Name 'MANGOS_DB_REALM' -Default 'classicrealmd'
$normalizedUsername = $Username.ToUpperInvariant()
$normalizedPassword = $Password.ToUpperInvariant()
$srp = New-CmangosSrp6Verifier -NormalizedUsername $normalizedUsername -NormalizedPassword $normalizedPassword

$u = ConvertTo-SqlString -Value $normalizedUsername
$v = ConvertTo-SqlString -Value $srp.Verifier
$s = ConvertTo-SqlString -Value $srp.Salt

$sql = @"
INSERT INTO account(username, gmlevel, sessionkey, v, s, email, joindate, lockedIp, failed_logins, locked, last_module, module_day, active_realm_id, expansion, mutetime, locale, os, platform, token, flags)
VALUES(${u}, ${GmLevel}, '', ${v}, ${s}, '', NOW(), '127.0.0.1', 0, 0, '', 0, 0, 0, 0, '', '0', '0', NULL, 0)
ON DUPLICATE KEY UPDATE
  gmlevel=VALUES(gmlevel),
  sessionkey='',
  v=VALUES(v),
  s=VALUES(s);

INSERT INTO realmcharacters (realmid, acctid, numchars)
SELECT r.id, a.id, 0
FROM realmlist r
CROSS JOIN account a
LEFT JOIN realmcharacters rc ON rc.acctid = a.id AND rc.realmid = r.id
WHERE a.username=${u} AND rc.acctid IS NULL;
"@

Invoke-DbSql -Database $realmDb -Sql $sql

$result = Invoke-DbQuery -Database $realmDb -Sql "SELECT id, username, gmlevel FROM account WHERE username=${u};"
Write-Host "Account ready:"
Write-Host $result
