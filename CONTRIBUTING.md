# Contributing

Thanks for helping make the at-home experience easier and more reliable.

## Project Focus

Contributions are a good fit when they improve:

- Setup and recovery on Windows/Docker or Linux/Podman.
- Play between computers on one trusted home LAN.
- Documentation and first-run clarity for players and families.
- Reproducible builds, diagnostics, and compatibility checks.
- Integration of compatible local CMaNGOS, Classic-DB, PlayerBots, or AHBot inputs within this pinned stack.

Internet-facing deployment, public account registration, monetization, client downloads, and redistribution of game data are outside this project's scope.

## Before Opening an Issue

Please include:

- Host operating system and container runtime.
- Client route: original Vanilla direct, or exact archived Classic Era build through HermesProxy.
- The command that failed and the relevant error text.
- Output from `.\scripts\smoke.ps1` or `./scripts/linux/smoke.sh` when available.

Remove passwords, local paths you consider private, and public IP addresses from logs. Never attach a game client, extracted DBC/maps/vmaps/mmaps, keys, repacks, or other proprietary game data.

## Pull Requests

Keep each change focused. Describe the user-facing problem, the path you changed, and the validation you ran. For stack changes, build and run the appropriate smoke check. For client-facing changes, name the exact supported client route you tested.

Before publishing, stage only intended files and run `python3 scripts/check-distribution.py --history`. This inspects the index and every reachable commit for excluded source directories, data/archive/executable formats, and unexpected binary content. It enforces the packaging boundary; it is not a license or provenance audit.

This repository distributes orchestration only. `server/` is ignored local state, not a contribution target. Supply the three source trees manually using [the source-input contract](docs/source-inputs.md); pins describe base lineage, not exact tree contents. Keep compatible local fork changes outside this repository and send generally useful fixes upstream when permitted. Never add source trees, SQL, binaries, or game data to a pull request; preserve notices in local materials and keep built images local.

## Licensing Contributions

Contributions to this orchestration repository are submitted under the repository's [GNU GPL version 2](LICENSE). Preserve all existing copyright and license notices.
