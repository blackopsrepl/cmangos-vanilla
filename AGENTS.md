# Repository Guidelines

## Project Structure & Module Organization

This repository is a local container stack for CMaNGOS Classic Vanilla. The root contains Docker/Podman orchestration (`docker-compose.yml`, `docker-compose.linux.yml`, `Dockerfile.cmangos`, `Dockerfile.hermesproxy`, `.env.example`). PowerShell automation lives in `scripts/`; Linux Bash wrappers live in `scripts/linux/`. Runtime templates are in `config/`, operational documentation is in `docs/`, and user-supplied, ignored local-only server dependencies are under `server/`: `server/mangos-classic/` for the core, `server/classic-db/` for database content, and `server/playerbots/` for the optional PlayerBots module. Generated state such as `.env`, `data/`, container volumes, and `artifacts/logs/` is intentionally ignored.

## Build, Test, and Development Commands

Use PowerShell from the repository root:

```powershell
.\scripts\bootstrap.ps1
.\scripts\import-server-sources.ps1 -SourcePath "C:\Sources\cmangos-inputs"
.\scripts\build.ps1
.\scripts\init-db.ps1
.\scripts\extract-data.ps1 -LegacyClientPath "C:\Games\WoW-1.12.1"
.\scripts\up.ps1
.\scripts\smoke.ps1
```

Use Bash for the Linux/Podman path:

```bash
./scripts/linux/bootstrap.sh --lan-address 192.168.1.50
./scripts/linux/import-server-sources.sh --source /path/to/cmangos-inputs
./scripts/linux/build.sh
./scripts/linux/init-db.sh
./scripts/linux/import-extracted-data.sh --source /path/to/extracted-data.zip
./scripts/linux/up.sh
./scripts/linux/smoke.sh --lan-address 192.168.1.50
```

The bootstrap scripts create local state from `.env.example`. Source-import helpers require a manually supplied parent containing all three trees and matching `.source-base` markers, never download, and refuse overwrite. Build scripts preflight this contract and build CMaNGOS from ignored local `server/` sources, database initialization imports Classic-DB and related SQL, and the extraction/import helpers prepare required DBC/maps/vmaps/mmaps from user-supplied original client data. Pins establish base lineage, not exact tree hashes or trust; preserve compatible local fork changes. See `docs/source-inputs.md`. Existing installations retain local sources and runtime state unchanged. Run the auth-only smoke path before extracted data exists, and include the proxy option when validating HermesProxy.

## Coding Style & Naming Conventions

Follow the style of the file you edit. C++ in `server/mangos-classic/` uses CMaNGOS conventions, four-space indentation, PascalCase types, and camelCase or lowerCamelCase locals/functions depending on the surrounding subsystem. PowerShell scripts use `Set-StrictMode -Version Latest`, approved verb-noun function names, explicit parameters, and ASCII output. SQL update files in `server/classic-db/Updates/` should keep the existing numbered prefix pattern, for example `4614_description.sql`.

## Testing Guidelines

There is no single repository-wide unit test command. Treat a Docker or Podman build plus smoke validation as the baseline gate for stack changes. For core or database edits, rebuild, reinitialize affected database state when needed, then run the platform-appropriate smoke script. Parse Windows scripts from Linux with `./scripts/linux/check-windows-scripts.sh`. For client-facing changes, also validate the relevant route: legacy direct login or exact Classic Era 1.14.2 build 42597 through HermesProxy.

## Commit & Pull Request Guidelines

Use short, imperative Conventional Commit subjects such as `feat(linux): add stack status checks`. Keep commits focused by area: scripts, container config, or docs. Core and database fork changes belong outside this orchestration repository, not in commits here. Pull requests should describe the changed path, validation commands run, affected client mode, and any required local state reset. Link issues when applicable and include logs or screenshots only when they clarify startup, proxy, or client behavior.

## Security & Configuration Tips

The public distribution contains recipes, config, scripts, docs, mascot artwork, pins, and project metadata only. Do not commit `server/`, SQL, binaries, `.env`, client files, extracted game data, repacks, or generated logs. Keep built images local and respect source/database/anticheat notices on supplied inputs. Keep secrets and local paths in `.env` or command parameters. Preserve pinned upstream SHAs in `versions.lock` unless intentionally rebasing the fork.
