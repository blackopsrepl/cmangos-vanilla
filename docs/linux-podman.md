# Linux Podman Home Host

This path keeps the CMaNGOS world on a Linux machine at home while family members play from Windows PCs on the same trusted LAN. The Windows PowerShell/Docker workflow remains available and uses the same compose file.

This is a home-network setup. Keep the documented ports behind your router and host firewall; do not port-forward them to the internet.

## Prerequisites

- Podman 5.x and either `podman compose` or `podman-compose`.
- Git and network access for the first HermesProxy publish (separate from manual server-source import).
- A manually prepared parent containing `mangos-classic`, `classic-db`, and `playerbots`, with markers matching `versions.lock`; see [source inputs](source-inputs.md).
- An original Vanilla 1.12.x MPQ-layout client available to the Linux host, or an archive exported from the Windows repo after extraction.
- Firewall access from the Windows laptop to the Linux host on `3724` and `8085`; add `1119`, `8084`, and `8086` when using HermesProxy.

No game client needs MariaDB port `3306`. Keep it blocked from other machines on the LAN.

After `bootstrap.sh` creates `.env`, replace the example values for `DB_ROOT_PASSWORD` and `MANGOS_DB_PASSWORD` before running `init-db.sh`.

## Home Host Setup

```bash
./scripts/linux/bootstrap.sh --lan-address 192.168.1.50
./scripts/linux/import-server-sources.sh --source /path/to/cmangos-inputs
./scripts/linux/build.sh
./scripts/linux/init-db.sh
./scripts/linux/import-extracted-data.sh --source /path/to/cmangos-extracted-data.zip
./scripts/linux/up.sh
./scripts/linux/create-account.sh --username playerone --password replace-this-1
./scripts/linux/smoke.sh --lan-address 192.168.1.50
```

Source import never downloads and refuses overwrite; build preflights the imported local trees. Existing installations keep their sources and state; use `./scripts/linux/import-server-sources.sh --check` rather than reimporting. Keep built images local.

Create the archive on the Windows machine after running `.\scripts\extract-data.ps1`:

```powershell
.\scripts\export-extracted-data.ps1
```

The Windows extraction script stores data in the Docker volume used by `mangosd` and mirrors it to host `data/extracted/`; the export script packages the host mirror. If the mirror is missing but the Docker volume has data, export attempts to sync it first.

If the original 1.12.x client is mounted directly on Linux, skip the archive and run:

```bash
./scripts/linux/extract-data.sh --legacy-client-path /mnt/wow-1.12.1
```

`bootstrap.sh` creates `.env`, local state directories, and sets `REALM_ADDRESS` plus `HERMES_EXTERNAL_ADDRESS` to the LAN address. If the database was already initialized before changing the address, run:

```bash
./scripts/linux/set-realm-address.sh --mode lan --address 192.168.1.50
```

## Modern Client Through HermesProxy

HermesProxy is published as a Linux self-contained binary into `data/hermesproxy-linux/`. The helper uses a .NET SDK container, so a host .NET SDK is not required.

```bash
./scripts/linux/publish-hermesproxy.sh
./scripts/linux/up.sh --proxy
./scripts/linux/smoke.sh --proxy --lan-address 192.168.1.50
```

If you have the exact archived Classic Era 1.14.2 build 42597 client, set its portal to:

```text
SET portal "192.168.1.50:1119"
```

Or patch it from PowerShell on the Windows laptop:

```powershell
.\scripts\patch-modern-client-config.ps1 -ModernClientPath "C:\Games\World of Warcraft\_classic_era_1.14.2.42597" -Portal "192.168.1.50:1119"
```

To patch and launch through Arctium from the Windows laptop without starting a local Docker proxy:

```powershell
.\scripts\start-modern-client.ps1 -ModernClientPath "C:\Games\World of Warcraft\_classic_era_1.14.2.42597" -Portal "192.168.1.50:1119" -NoProxyRestart
```

For an original 1.12.x client:

```powershell
.\scripts\patch-legacy-client-config.ps1 -LegacyClientPath "C:\Games\WoW-1.12.1" -Address "192.168.1.50"
```

Use the pinned Classic Era 1.14.2 build 42597 client with Arctium. Current Battle.net Classic Era clients are too new for this HermesProxy route and are rejected by the Windows helper scripts.

## Data and Logs

The Linux Bash wrappers load `docker-compose.yml` plus `docker-compose.linux.yml`. The override bind-mounts extracted server data from `data/extracted/` into the containers. Logs are written under `artifacts/logs/`.

Full `mangosd` startup requires extracted `*.dbc`, `*.map`, `*.vmtree`, and `*.mmap` files in `data/extracted/dbc`, `data/extracted/maps`, `data/extracted/vmaps`, and `data/extracted/mmaps`. Empty directories and dot-prefixed placeholder files or directories are treated as missing data.

Use these operational commands:

```bash
./scripts/linux/status.sh --proxy
./scripts/linux/smoke.sh --auth-only --proxy --lan-address 192.168.1.50
./scripts/linux/check-windows-scripts.sh
./scripts/linux/client-handoff.sh
./scripts/linux/logs.sh --follow
./scripts/linux/down.sh
./scripts/linux/down.sh --volumes
```

From the Windows laptop, verify network reachability before launching the client:

```powershell
Test-NetConnection 192.168.1.50 -Port 3724
Test-NetConnection 192.168.1.50 -Port 1119
Test-NetConnection 192.168.1.50 -Port 8084
Test-NetConnection 192.168.1.50 -Port 8086
```

When world data is imported and `mangosd` is running, also check:

```powershell
Test-NetConnection 192.168.1.50 -Port 8085
```

If `./scripts/linux/status.sh --proxy` reports an active firewall with ports not open, allow those TCP ports in the host firewall before testing from Windows.
