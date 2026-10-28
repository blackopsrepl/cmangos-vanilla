# Local Server Source Inputs

The public repository is orchestration-only. It does not ship server source, SQL, binaries, or game data. `server/` is ignored local-only dependency storage; builds preflight it before proceeding. Existing installations keep their local sources and runtime state unchanged.

## Contract and Manual Acquisition

Manually prepare a directory containing all three trees, even when PlayerBots is disabled:

```text
cmangos-inputs/
  mangos-classic/
    .source-base
    ...core source and required SQL...
  classic-db/
    .source-base
    ...database source and installer...
  playerbots/
    .source-base
    ...module source...
```

Use only source trees and associated materials you are entitled to possess and use. Obtain them yourself from a source you trust, including any compatible local fork changes required by this stack. Neither helper fetches, downloads, or reconstructs the trees. Upstream locations in `versions.lock` identify lineage, not an automatic acquisition service or permission to redistribute. Review [the legal boundary](legal.md), especially database content and anticheat notices.

Each tree must include a plain-text `.source-base` with `upstream_repo` and `upstream_sha` matching its entry in `versions.lock`. Exact required marker lines for the current pins are:

`mangos-classic/.source-base`:

```ini
upstream_repo=https://github.com/cmangos/mangos-classic.git
upstream_sha=de8f72993b9e1faa1bf92dd5505f3daec5cea3ce
```

`classic-db/.source-base`:

```ini
upstream_repo=https://github.com/cmangos/classic-db.git
upstream_sha=4d230bb1bd477948cac61c107d2718b3ea04a5b8
```

`playerbots/.source-base`:

```ini
upstream_repo=https://github.com/cmangos/playerbots.git
upstream_sha=31e0f32b543fee46941db51225bb7b432eace236
```

Existing markers may also contain historical metadata such as `vendored_at=2026-07-07`; that does not mean the trees are bundled in this distribution.

Markers declare **base lineage**, not the current Git HEAD or a hash of the full tree. They do not establish trust, verify exact contents, attest licensing rights, or prove compatibility. Do not stamp these values onto unknown trees just to pass checks. Review the actual source and retain its provenance and notices.

## Fresh Installation

Run bootstrap, import the prepared parent directory, then build. The examples use placeholder local paths; replace them with your own.

Linux:

```bash
./scripts/linux/bootstrap.sh --lan-address 192.168.1.50
./scripts/linux/import-server-sources.sh --source /path/to/cmangos-inputs
./scripts/linux/import-server-sources.sh --check
./scripts/linux/build.sh
```

Windows PowerShell:

```powershell
.\scripts\bootstrap.ps1
.\scripts\import-server-sources.ps1 -SourcePath "C:\Sources\cmangos-inputs"
.\scripts\import-server-sources.ps1 -Check
.\scripts\build.ps1
```

The import helpers validate and copy inputs into local `server/`, refuse overwrite, and never download. Check mode validates the installed local trees without importing. Continue with database initialization and client-data extraction/import in the [README](../README.md) or [Linux guide](linux-podman.md). Change example passwords before initializing databases.

## Existing Installations and Local Fork Changes

Do not reimport over an existing `server/`. Use check mode to validate it; leave the existing sources, databases, extracted data, and runtime state in place. If validation fails, investigate missing files or lineage mismatches rather than discarding local changes or rewriting markers blindly.

Keep a separate backup or private source checkout for compatible fork changes. A clean checkout of a pinned upstream base is not necessarily equivalent to your working local fork: markers intentionally do not encode patches or full tree contents. Import the complete compatible trees, preserve their notices, and record local modifications separately. Any deliberate replacement should be backed up and reviewed first; the import helper is not an update or merge tool.

Do not commit the supplied trees or SQL to this orchestration repository. Keep built images local: they can contain excluded source-derived content, database material, or restricted components even though the public build recipes do not.
