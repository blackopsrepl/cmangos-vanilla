# Troubleshooting

## Missing or Incompatible Local Sources

A fresh checkout contains no `server/`. Follow [source inputs](source-inputs.md) to import a manually supplied source parent after bootstrap and before build. Verify existing inputs without overwriting them:

```powershell
.\scripts\import-server-sources.ps1 -Check
```

```bash
./scripts/linux/import-server-sources.sh --check
```

If markers differ from `versions.lock`, investigate actual lineage and compatible local fork changes; do not relabel unknown content just to pass preflight. Import refuses overwrite. Preserve sources and database state before any deliberate replacement.

## Docker Build Fails

Run:

```powershell
.\scripts\build.ps1 -NoCache -Pull
```

If the failure is during CMake or compilation, capture the terminal output and compare it with the SHAs in `versions.lock`.

## Database Import Fails

Check:

```powershell
.\scripts\logs.ps1 db
Get-ChildItem .\artifacts\logs\init-db-*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1
```

Do not use forced initialization to repair an existing bot installation or enable new features. `init-db.ps1 -Force` / `init-db.sh --force` drop and recreate all CMaNGOS databases, including every account and character. Back up databases before any migration; missing bot tables require a verified targeted upstream installation, not a destructive reset. See [existing installations](playerbots.md#existing-installations).

## Bots Missing or First Startup Taking Longer

PlayerBots and AHBot are enabled by default. First startup initializes bot accounts and characters; follow the `mangosd` logs and allow extra time. Defaults target 20–30 random bots, levels 1–60, using 20 bot accounts.

Bootstrap retains existing `.env` values. Check that `BUILD_PLAYERBOTS=ON`, `BUILD_AHBOT=ON`, `PLAYERBOTS_ENABLED=1`, and `AHBOT_ENABLED=1`; rebuild the image after changing build flags. Rebuilding does not add missing bot tables to an existing database. Follow the [existing-installation caveat](playerbots.md#existing-installations) before enabling bots there.

To deliberately disable runtime bots, set `PLAYERBOTS_ENABLED=0` and `AHBOT_ENABLED=0`, then stop and start the world. Normally leave both build flags `ON`; this runtime change needs no rebuild.

## mangosd Exits Immediately

Most first-run failures are missing or invalid extracted data. Verify:

```powershell
$expected = @{
  dbc = '*.dbc'
  maps = '*.map'
  vmaps = '*.vmtree'
  mmaps = '*.mmap'
}
$expected.GetEnumerator() | ForEach-Object {
  Get-ChildItem ".\data\extracted\$($_.Key)" -Recurse -File -Filter $_.Value -ErrorAction SilentlyContinue |
    Where-Object {
      -not @(($_.FullName.Substring((Resolve-Path ".\data\extracted\$($_.Key)").Path.Length).TrimStart('\','/') -split '[\\/]') | Where-Object { $_.StartsWith('.') }).Count
    } |
    Select-Object -First 1
}
.\scripts\logs.ps1 mangosd
```

Then extract from an original 1.12.x MPQ client:

```powershell
.\scripts\extract-data.ps1 -LegacyClientPath "C:\Games\WoW-1.12.1"
```

## Original Vanilla Client Cannot See Realm

Set the DB advertised address and patch the client:

```powershell
.\scripts\set-realm-address.ps1 -Mode legacy-direct
.\scripts\patch-legacy-client-config.ps1 -LegacyClientPath "C:\Games\WoW-1.12.1"
```

Then check ports:

```powershell
Test-NetConnection 127.0.0.1 -Port 3724
Test-NetConnection 127.0.0.1 -Port 8085
```

## Modern Client Rejected Or Cannot Connect Through HermesProxy

Check the executable version first:

```powershell
.\scripts\check-clients.ps1 -ModernClientPath "C:\Games\World of Warcraft\_classic_era_1.14.2.42597"
```

The pinned default expects Classic Era 1.14.2 build 42597. Current Battle.net Classic Era clients are too new for this proxy pin. Use original Vanilla 1.12.x directly unless you have that exact archived modern client.

Patch the portal and restart proxy:

```powershell
.\scripts\patch-modern-client-config.ps1 -ModernClientPath "C:\Games\World of Warcraft\_classic_era_1.14.2.42597"
.\scripts\publish-hermesproxy-container.ps1
docker compose --env-file .env build hermesproxy
docker compose --env-file .env up -d --no-deps --force-recreate hermesproxy
.\scripts\smoke.ps1 -Proxy
```

## Reset Local State

Delete only the selected generated state:

```powershell
.\scripts\reset.ps1 -Database -Force
.\scripts\reset.ps1 -ExtractedData -Force
.\scripts\reset.ps1 -HermesProxy -Force
```
