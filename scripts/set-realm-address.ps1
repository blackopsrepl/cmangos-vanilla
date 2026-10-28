param(
    [ValidateSet('legacy-direct', 'host-proxy', 'docker-proxy', 'custom')]
    [string]$Mode = 'legacy-direct',
    [string]$Address = '',
    [int]$Port = 0
)

. "$PSScriptRoot\common.ps1"

Ensure-EnvFile | Out-Null
Require-Docker

$values = Get-CmangosEnv
$realmDb = Get-EnvValue -Values $values -Name 'MANGOS_DB_REALM' -Default 'classicrealmd'
$realmName = Get-EnvValue -Values $values -Name 'REALM_NAME' -Default 'Vanilla at Home'

if ($Port -eq 0) {
    $Port = [int](Get-EnvValue -Values $values -Name 'LEGACY_WORLD_PORT' -Default '8085')
}

if ([string]::IsNullOrWhiteSpace($Address)) {
    switch ($Mode) {
        'legacy-direct' { $Address = '127.0.0.1' }
        'host-proxy' { $Address = '127.0.0.1' }
        'docker-proxy' { $Address = 'mangosd' }
        'custom' { throw "-Mode custom requires -Address." }
    }
}

$sqlRealmName = ConvertTo-SqlString -Value $realmName
$sqlAddress = ConvertTo-SqlString -Value $Address

$sql = @"
INSERT INTO realmlist (id, name, address, port, icon, realmflags, timezone, allowedSecurityLevel, population, realmbuilds)
VALUES (1, ${sqlRealmName}, ${sqlAddress}, ${Port}, 1, 0, 1, 0, 0, '')
ON DUPLICATE KEY UPDATE
  name=VALUES(name),
  address=VALUES(address),
  port=VALUES(port),
  realmflags=0,
  realmbuilds='';
"@

Invoke-DbSql -Database $realmDb -Sql $sql
Set-DotEnvValue -Name 'REALM_ADDRESS' -Value $Address

Write-Host "Realm 1 now advertises ${Address}:${Port} (${Mode})."
