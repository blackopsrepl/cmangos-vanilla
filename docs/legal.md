# Project Scope, Copyright, and Licensing

This page records the distribution boundary and the main ownership and licensing notices. It is not legal advice.

## Home-Use Boundary

This project is intended for personal, non-commercial use within one household: one Windows PC, or a Linux host and Windows clients on a trusted home LAN. It provides no public registration, payment system, server listing, or internet-facing deployment guide. Keep game and database ports behind the home router and host firewall; do not port-forward them.

That boundary is not a grant of rights or a promise that every use is legally permitted.

## Distribution Boundary

The public repository distributes orchestration/build recipes, configuration templates, helper scripts, documentation, mascot artwork, pinned version metadata, and project license/contribution files. It contains no server source trees, SQL, binaries, game clients, repacks, or extracted game data.

`server/` is an ignored, local-only dependency directory. Users manually supply the three source trees under the [source-input contract](source-inputs.md); the source-import helpers never download and refuse overwrite. Existing installations keep their local sources and runtime state unchanged. Built images, local databases, extracted data, and separately acquired tools stay local, not in registry uploads or release artifacts.

## Client Software and Data

Use only software and data you are entitled to possess and use. Exclusion from the public tree does not remove restrictions on your local inputs. Supplied core trees may include DBC-derived SQL such as `server/mangos-classic/sql/base/dbc/original_data/Spell.sql` and `server/mangos-classic/sql/updates/mangos/z2691_01_mangos_spell_template.sql`; SQL format does not make game data unrestricted.

Local anticheat materials may include opaque Warden client-module payloads under `server/mangos-classic/src/game/Anticheat/module/warden_modules/`. Redistribution rights for those payloads have not been established. Adjacent implementation files, including `Warden/WardenModule.hpp`, state that sharing requires namreeb's permission. Retain and review the notices in your actual inputs; the repository's GPL license does not override them.

Do not publish client installations, extracted DBC/maps/vmaps/mmaps, proprietary SQL, restricted anticheat materials, or local database dumps in commits, issues, container registries, or releases.

## Terms of Use

Personal and non-commercial use does not override a software license or create authorization from a rights holder. The [Blizzard End User License Agreement](https://www.blizzard.com/en-us/legal/08b946df-660a-40e4-a072-1fbde65173b1/blizzard-end-user-license-agreement) includes restrictions concerning bots, protocol emulation or redirection, unauthorized servers, and connections made with unauthorized third-party tools.

These contractual restrictions are distinct from copyright licenses covering open-source components. Review the terms applicable to your client and the law in your jurisdiction; obtain qualified legal advice if uncertain.

## Independence and Trademarks

CMaNGOS and this repository are independent community projects, not affiliated with, sponsored by, or endorsed by Blizzard Entertainment, Inc.

World of Warcraft, Warcraft, Blizzard Entertainment, and Battle.net are trademarks or registered trademarks of Blizzard Entertainment, Inc. in the United States and/or other countries. This repository does not use Blizzard logos or present itself as an official product.

## Repository License

Unless a file says otherwise, project-authored orchestration, scripts, templates, and documentation are licensed under the [GNU General Public License version 2](../LICENSE), matching CMaNGOS. The existing project license is preserved.

Locally supplied and separately acquired dependencies retain their own notices and license terms. The orchestration license grants no additional rights to those materials.

### World database content is not client-free legal clearance

Classic-DB's [upstream copyright notice](https://github.com/cmangos/classic-db/blob/4d230bb1bd477948cac61c107d2718b3ea04a5b8/COPYRIGHT.md) acknowledges Blizzard-owned material and asserts an intended fair-use basis. A GPL license on the database project does not grant rights to third-party game text or other protected material. Supplied core scripts may also contain game dialogue.

Review local `server/classic-db/COPYRIGHT.md`, `server/classic-db/LICENSE.md`, and all notices in the actual supplied trees. Neither an upstream fair-use assertion nor the absence of client binaries establishes legal clearance to use or redistribute world content. The public distribution excludes these trees and their SQL rather than claiming to clear them.

### Before publishing source or artifacts

- Keep the entire local `server/`, client files, SQL, binaries, credentials, database dumps, and runtime state out of the public tree and release attachments. Keep built images local.
- Inspect the proposed public tree and reachable history, including compressed archives. Ignore rules alone do not remove previously committed files or detect renamed content.
- Preserve source, database, anticheat, and dependency notices on local inputs. Do not treat a lineage marker or successful build as provenance or rights verification.
- Review additions individually for provenance and rights, including artwork. Do not reintroduce excluded content through documentation attachments or generated artifacts.

## External Components

These are dependencies of a local installation, not bundled server sources:

| Component | Local location | License information |
| --- | --- | --- |
| CMaNGOS Classic | `server/mangos-classic/` | GNU GPL v2; review local `LICENSE`, `README.md`, and file-specific notices, including anticheat restrictions |
| Classic-DB | `server/classic-db/` | GPL-3.0 and third-party copyright information; review local `LICENSE.md` and `COPYRIGHT.md` |
| PlayerBots | `server/playerbots/` | GNU GPL v2 notices, including local `CMakeLists.txt` |
| HermesProxy | Separately acquired by its build/publish workflow | GPL-3.0 in the pinned upstream source |

CMaNGOS dependencies under local `server/mangos-classic/dep/` have their own licenses. Review the actual supplied materials, including compatible local fork changes. Upstream repositories and base revisions are recorded in [versions.lock](../versions.lock); they are lineage metadata, not complete local tree hashes or a guarantee of trust.
