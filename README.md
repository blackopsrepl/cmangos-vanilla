# CMaNGOS Vanilla — A Home Realm for Family Play

<p align="center">
  <img src="docs/assets/cmangos-vanilla-mascots.png" alt="CMaNGOS Vanilla human and orc mascots in a friendly face-off" width="760">
</p>

Bring a classic Vanilla world onto your own computers and explore it together at home.

This project turns CMaNGOS Classic into a repeatable household setup: run the world on one Windows PC, or keep it on a Linux machine and connect from Windows PCs across your trusted home network. It provides guided setup scripts, separate player accounts, persistent characters, PlayerBots companions and a populated world, and active auction houses through AHBot—all enabled by default.

| At a glance | This project |
| --- | --- |
| Intended use | Personal, non-commercial play within one household |
| Recommended client | Original Vanilla 1.12.x with an MPQ-style `Data` folder |
| Host choices | Windows with Docker Desktop, or Linux with Podman |
| Multiplayer | Same PC or trusted home LAN |
| Internet-facing hosting | Not supported or documented |

## Before You Begin

- **Bring your own sources and client.** This is an orchestration-only distribution: no server source, SQL, binaries, or game data are bundled. Manually supply compatible source trees and client materials you are entitled to use; source-import helpers never download them. See [source inputs](docs/source-inputs.md) and [distribution warnings](docs/legal.md).
- **Keep it on the home network.** The compose stack publishes its configured services on the host. Use a trusted network protected by your router and host firewall, and do not port-forward the game or database ports.
- **Change the example passwords.** After bootstrap, replace `DB_ROOT_PASSWORD` and `MANGOS_DB_PASSWORD` in the ignored `.env` file before initializing the database—especially on the Linux home-LAN path.

## What You Get

- Recipes to build and run a CMaNGOS Classic world from your locally supplied core, Classic-DB, and PlayerBots trees.
- Friendly scripts for building, preparing the database, extracting your own data, starting the world, and checking that it is healthy.
- One login per family member, with characters and progress kept locally.
- A Windows/Docker path for playing on one computer.
- A Linux/Podman path for a small home machine serving Windows PCs on the same LAN.
- PlayerBots companions and random world bots, plus AHBot for active auctions, enabled by default.
- An advanced HermesProxy route for one exact archived Classic Era client build.

PlayerBots and AHBot are part of the default world. HermesProxy is a separate, optional advanced client route; the original Vanilla client connects directly.

## Choose Your Setup

| Your setup | Recommended path | Start here |
| --- | --- | --- |
| One Windows gaming PC | Docker Desktop and PowerShell | [Windows quick start](#windows-quick-start) |
| Linux home host plus one or more Windows PCs | Podman on Linux, clients on the home LAN | [Linux home-LAN guide](docs/linux-podman.md) |
| Exact Classic Era 1.14.2 build 42597 | HermesProxy compatibility bridge | [HermesProxy guide](docs/hermesproxy.md) |

The original Vanilla client is the primary and simplest play path. You do **not** need the modern client or HermesProxy.

## Get the Project

Clone the public repository:

```bash
git clone https://github.com/blackopsrepl/cmangos-vanilla.git
cd cmangos-vanilla
```

## Supported Client Paths

| Client | Use | Support |
| --- | --- | --- |
| Original Vanilla 1.12.x, MPQ layout | Data extraction and direct play | Recommended |
| Classic Era 1.14.2 build 42597 | Optional play through HermesProxy | Advanced, version-locked |
| Current Battle.net Classic Era | — | Not compatible |

Run the client checker before making any changes to a client installation:

```powershell
.\scripts\find-installed-clients.ps1
.\scripts\check-clients.ps1 -LegacyClientPath "C:\Games\WoW-1.12.1"
```

The patching scripts make timestamped backups of existing client configuration files.

## Windows Quick Start

### 1. Prepare the world

From PowerShell in the repository root:

```powershell
.\scripts\bootstrap.ps1
.\scripts\import-server-sources.ps1 -SourcePath "C:\Sources\cmangos-inputs"
.\scripts\build.ps1
.\scripts\init-db.ps1
.\scripts\extract-data.ps1 -LegacyClientPath "C:\Games\WoW-1.12.1"
.\scripts\up.ps1
.\scripts\smoke.ps1
```

Prepare the source parent directory as described in [source inputs](docs/source-inputs.md) before importing. Build scripts preflight the local source contract. Existing installations keep their local sources and runtime state; do not reimport over an existing `server/`.

The first build and data extraction take the longest. First world startup also initializes bot accounts and characters, so allow extra time and follow the `mangosd` logs. Defaults target 20–30 random bots across levels 1–60 using 20 bot accounts. Extracted data, passwords, databases, and logs stay in ignored local storage.

Existing `.env` values are retained, not replaced by new defaults. For an existing installation, see [enabling bots and the database migration caveat](docs/playerbots.md#existing-installations) before rebuilding or starting with bots enabled.

### 2. Give everyone a login

Create a separate login for each person. Replace the example passwords before use:

```powershell
.\scripts\create-account.ps1 -Username "playerone" -Password "replace-this-1"
.\scripts\create-account.ps1 -Username "playertwo" -Password "replace-this-2"
```

These are local CMaNGOS logins, not Battle.net accounts.

### 3. Connect the original client

```powershell
.\scripts\set-realm-address.ps1 -Mode legacy-direct
.\scripts\patch-legacy-client-config.ps1 -LegacyClientPath "C:\Games\WoW-1.12.1"
```

Start `WoW.exe`, sign in with one of the local logins, choose the **Vanilla at Home** realm, and make your first character.

## Linux Home-LAN Quick Start

Run these commands on the Linux host, replacing `192.168.1.50` with that machine's LAN address:

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

Create the extracted-data archive on Windows after extraction:

```powershell
.\scripts\export-extracted-data.ps1
```

Then point each original Vanilla client on the home LAN at the Linux host:

```powershell
.\scripts\patch-legacy-client-config.ps1 `
  -LegacyClientPath "C:\Games\WoW-1.12.1" `
  -Address "192.168.1.50"
```

Keep the game ports inside your trusted home network. Do not port-forward them or expose them to the internet. The full transfer, firewall, status, and client handoff workflow is in the [Linux home-LAN guide](docs/linux-podman.md).

## Everyday Commands

| What you want to do | Windows | Linux |
| --- | --- | --- |
| Start the world | `.\scripts\up.ps1` | `./scripts/linux/up.sh` |
| Stop the world | `.\scripts\down.ps1` | `./scripts/linux/down.sh` |
| Follow the logs | `.\scripts\logs.ps1 mangosd -Follow` | `./scripts/linux/logs.sh --follow` |
| Check health | `.\scripts\smoke.ps1` | `./scripts/linux/smoke.sh` |
| Add a player | `.\scripts\create-account.ps1` | `./scripts/linux/create-account.sh` |

## Make the World Yours

After the basic path works, edit the ignored `.env` file and restart the world.

| Experience | Settings or guide |
| --- | --- |
| Rename the realm | `REALM_NAME` |
| Change leveling speed | `RATE_XP_KILL`, `RATE_XP_QUEST`, `RATE_XP_EXPLORE` |
| Change drops and money | `RATE_DROP_ITEMS`, `RATE_DROP_MONEY` |
| Tune companions, world population, and auctions | [PlayerBots and AHBot](docs/playerbots.md) |
| Use the archived modern client | [HermesProxy](docs/hermesproxy.md) |

Defaults keep the original rates and enable ScriptDev content, PlayerBots, and AHBot. To explicitly turn off bots, set `PLAYERBOTS_ENABLED=0` and `AHBOT_ENABLED=0` in `.env`, then stop and start the world with the everyday commands above. Normally leave `BUILD_PLAYERBOTS=ON` and `BUILD_AHBOT=ON`; disabling runtime bots does not require rebuilding the image.

## What Is Tracked—and What Stays Home

The public tree contains orchestration/build recipes, configuration templates, helper scripts, documentation, mascot artwork, and [versions.lock](versions.lock), plus project license and contribution files. It contains no server source, SQL, binaries, or game data.

`server/` is an ignored, local-only dependency directory: `mangos-classic/`, `classic-db/`, and `playerbots/` are supplied manually, not tracked or downloaded by the source-import helpers. Pins identify base lineage, not a hash of the complete local trees; retain compatible local fork changes. See [the source contract](docs/source-inputs.md).

Your `.env`, client installations, extracted DBC/maps/vmaps/mmaps, databases, third-party tools, runtime logs, and built images stay local. Supplied sources and databases may contain DBC-derived SQL, copyrighted game text, and restricted anticheat materials; their notices still apply. The orchestration license does not clear those materials for redistribution. See [the redistribution boundary](docs/legal.md).

## Guides

- [Required local source inputs](docs/source-inputs.md)
- [Clients and compatibility](docs/clients.md)
- [Linux home-LAN setup](docs/linux-podman.md)
- [PlayerBots and AHBot](docs/playerbots.md)
- [HermesProxy advanced compatibility](docs/hermesproxy.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Technical architecture](docs/architecture.md)
- [Project scope, copyright, and licensing](docs/legal.md)
- [Contributing](CONTRIBUTING.md)

## Project Scope and Legal Note

This is an independent, non-commercial project built around open-source CMaNGOS components. It is not affiliated with or endorsed by Blizzard Entertainment.

Keeping the setup within a household is a project and network-safety boundary; it does not itself grant legal permission or guarantee compliance with a game's license terms. Blizzard's published EULA includes restrictions concerning unauthorized connections, server emulation, protocol redirection, third-party tools, and bots. Review the [project scope and legal note](docs/legal.md), the terms that apply to your client, and the law in your jurisdiction before use.

## License

Unless a file says otherwise, the project-authored orchestration, scripts, templates, and documentation are licensed under the [GNU General Public License version 2](LICENSE), matching CMaNGOS. Locally supplied dependencies retain their own copyright and license notices; see [the licensing notes](docs/legal.md).

## Thanks

This home-focused packaging stands on the work of the [CMaNGOS](https://github.com/cmangos) community, [Classic-DB](https://github.com/cmangos/classic-db), [PlayerBots](https://github.com/cmangos/playerbots), and [HermesProxy](https://github.com/Novivy/HermesProxy). Their copyright notices and licenses remain with the locally supplied or separately acquired source trees; see [the licensing notes](docs/legal.md) before redistributing the repository or built artifacts.
