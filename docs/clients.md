# Clients

This project deliberately separates the open-source world software from client files. The public tree bundles no game client or extracted client data, and the helpers never download them. Extraction helpers store user-supplied data in ignored local storage. Server sources and SQL are supplied separately; see [source inputs](source-inputs.md). Use only client software and data you are entitled to use; see the [project scope and legal note](legal.md).

## Original Vanilla Client

This stack has one primary client path: original Vanilla 1.12.x direct to CMaNGOS. The modern-client path is an optional compatibility bridge for one archived Classic Era build.

Use an original 1.12.x MPQ-layout client for:

- Extracting `dbc`, `maps`, `vmaps`, and `mmaps`.
- Normal play against `realmd` on port `3724` and `mangosd` on port `8085`.

The extractor script expects:

- A root folder containing `WoW.exe`.
- A `Data` folder with `.MPQ` files.
- No CASC-only `.build.info` layout.

Commands:

```powershell
.\scripts\find-installed-clients.ps1
.\scripts\check-clients.ps1 -LegacyClientPath "C:\Games\WoW-1.12.1"
.\scripts\extract-data.ps1 -LegacyClientPath "C:\Games\WoW-1.12.1"
.\scripts\patch-legacy-client-config.ps1 -LegacyClientPath "C:\Games\WoW-1.12.1"
```

The legacy patch script uses `REALM_ADDRESS` from `.env` by default, or an explicit `-Address`. It writes `host:port` when `LEGACY_AUTH_PORT` is not `3724`. It also applies `CLIENT_INSTANT_QUEST_TEXT`, enabled by default, by writing this client CVar:

```text
SET instantQuestText "1"
```

## Modern Classic Era Client

Use a separate modern Classic Era client only for the HermesProxy route. This route is version-locked; it is not a path for the current Battle.net Classic Era install. The pinned proxy default is:

- `HERMES_CLIENT_BUILD=42597`
- `HERMES_CLIENT_SEED=179D3DC3235629D07113A9B3867F97A7`
- `HERMES_LEGACY_BUILD=5875`

Use Classic Era 1.14.2 build 42597. Launch with Arctium `--staticseed`; Hermes keeps the real 42597 Wn64 build seed in `BuildAuthSeeds.csv` and uses the configured static seed as fallback. Current Battle.net Classic Era clients are too new for this pinned HermesProxy route. The patch and start scripts reject unsupported modern versions before editing `WTF\Config.wtf` or touching the proxy.

Commands:

```powershell
.\scripts\check-clients.ps1 -ModernClientPath "C:\Games\World of Warcraft\_classic_era_1.14.2.42597"
.\scripts\patch-modern-client-config.ps1 -ModernClientPath "C:\Games\World of Warcraft\_classic_era_1.14.2.42597"
.\scripts\start-modern-client.ps1 -ModernClientPath "C:\Games\World of Warcraft\_classic_era_1.14.2.42597"
```

The modern patch and start scripts use `HERMES_EXTERNAL_ADDRESS` and `HERMES_BNET_PORT` from `.env`, or an explicit `-Portal`. In default Windows Docker mode they set:

```text
SET portal "127.0.0.1:1119"
```

The patch script backs up an existing `WTF\Config.wtf` before editing. The start script also closes Battle.net by default before launch so the Battle.net agent does not restore `SET portal "EU"`. For a Linux LAN server, pass `-Portal "192.168.1.50:1119" -NoProxyRestart` so the client uses the remote proxy instead of starting local Docker.
