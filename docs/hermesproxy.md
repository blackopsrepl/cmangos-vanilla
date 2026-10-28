# HermesProxy

HermesProxy is an optional, advanced bridge for one compatible modern Classic Era client. The pinned Novivy fork is configured for Classic Era 1.14.2 build 42597 and bridges it to the local CMaNGOS 1.12.1 auth/world services. It is not compatible with current Battle.net Classic Era clients, and the original Vanilla client remains the recommended home-play path.

## Windows Docker Mode

Default Windows mode is Docker Compose:

- CMaNGOS runs in Docker and publishes legacy `realmd` on host port `3724`; the same-PC client connects through `127.0.0.1:3724`.
- CMaNGOS publishes legacy `mangosd` on host port `8085`; the same-PC client connects through `127.0.0.1:8085`.
- HermesProxy runs in Docker and connects to the `realmd` service on `3724`.
- The modern client points its `portal` CVar to `127.0.0.1:1119`.

Use a Classic Era 1.14.2 build 42597 client. Its `WTF\Config.wtf` should contain `SET portal "127.0.0.1:1119"`, and the client should be launched with Arctium using `--staticseed --version ClassicEra`. The helper scripts fail fast for any other modern client version.

## Commands

```powershell
.\scripts\start-modern-client.ps1 -ModernClientPath "C:\Games\World of Warcraft\_classic_era_1.14.2.42597"
.\scripts\smoke.ps1 -Proxy
```

`start-modern-client.ps1` publishes the Linux HermesProxy binary for the Docker service, rebuilds the proxy image, then force-recreates the service. Use `-SkipProxyPublish` only when deliberately reusing the existing `data/hermesproxy-linux/HermesProxy`. For manual Docker proxy startup, run `.\scripts\publish-hermesproxy-container.ps1` and `docker compose --env-file .env build hermesproxy` first.

Inspect the Docker proxy while debugging:

```powershell
docker compose --env-file .env logs -f hermesproxy
```

## Linux Podman LAN Mode

First complete the [Linux host setup](linux-podman.md), including manual source import, build, and database initialization. These commands assume that setup is complete; they do not acquire server sources.

On the Linux server host, set `.env` to advertise the host LAN address, import extracted server data, publish the Linux proxy binary, then start the proxy service:

```bash
./scripts/linux/bootstrap.sh --lan-address 192.168.1.50
./scripts/linux/import-extracted-data.sh --source /path/to/cmangos-extracted-data.zip
./scripts/linux/publish-hermesproxy.sh
./scripts/linux/up.sh --proxy
./scripts/linux/smoke.sh --proxy --lan-address 192.168.1.50
```

`up.sh --proxy` starts the full server stack by default, so `dbc`, `maps`, `vmaps`, and `mmaps` must already be present. Use `./scripts/linux/up.sh --auth-only --proxy` only for pre-data auth/proxy checks.

The Windows client should use `SET portal "192.168.1.50:1119"`. The compose service uses `HERMES_EXTERNAL_ADDRESS` from `.env`, so do not leave it at `127.0.0.1` for LAN clients. To launch from the Windows laptop without starting a local Docker proxy:

```powershell
.\scripts\start-modern-client.ps1 -ModernClientPath "C:\Games\World of Warcraft\_classic_era_1.14.2.42597" -Portal "192.168.1.50:1119" -NoProxyRestart
```

## Ports

| Setting | Default | Purpose |
| --- | --- | --- |
| `HERMES_BNET_PORT` | `1119` | Modern BNet/portal listener. |
| `HERMES_REST_PORT` | `8081` | REST listener. |
| `HERMES_REALM_PORT` | `8084` | Modern realm listener. |
| `HERMES_INSTANCE_PORT` | `8086` | Modern instance listener. |
| `LEGACY_AUTH_PORT` | `3724` | CMaNGOS `realmd`. |
| `LEGACY_WORLD_PORT` | `8085` | CMaNGOS `mangosd`. |

## Version Notes

The generated `HermesProxy.config` defaults to:

```text
ClientBuild=42597
ClientSeed=179D3DC3235629D07113A9B3867F97A7
ServerBuild=5875
```

Do not point a current Battle.net Classic Era client at this proxy. The TLS/BNet handshake may reach Hermes, but the required protocol and data mappings are not implemented by this pinned proxy. Use original Vanilla 1.12.x directly, or provide the exact archived 1.14.2.42597 client for HermesProxy.
