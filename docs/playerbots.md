# PlayerBots and AHBot

PlayerBots companions and random world bots make a small family world feel populated when only one or two people are playing. AHBot keeps the auction houses active without requiring a large player population. Both are enabled by default. HermesProxy is a separate optional advanced client route, not a requirement for bots.

## Fresh Installation

Follow the normal source import, image build, database initialization, and client-data extraction/import flow in the [README](../README.md) or [Linux guide](linux-podman.md). Supply all three local source trees as described in [source inputs](source-inputs.md); the public repository does not bundle or download them.

The default `.env` values are:

```text
BUILD_PLAYERBOTS=ON
BUILD_AHBOT=ON
PLAYERBOTS_ENABLED=1
AHBOT_ENABLED=1
```

The image also normally builds with `BUILD_SCRIPTDEV=ON` and extractors enabled. Fresh Classic-DB initialization runs with `PLAYERBOTS_DB=YES` and `AHBOT=YES` when the corresponding build and runtime flags are enabled.

First world startup initializes bot accounts and characters and takes longer than later starts. Allow extra time and follow the `mangosd` logs rather than resetting the database.

## Existing Installations

Bootstrap retains existing `.env` values; updating the repository does not turn on bots in an older configuration. Set the four values shown above in your existing `.env`, preserving passwords and other local settings. Rebuild the image after changing build flags:

Windows:

```powershell
.\scripts\build.ps1
```

Linux:

```bash
./scripts/linux/build.sh
```

**Back up existing databases before migrating.** The initializer deliberately skips existing databases; an image rebuild does not install missing bot tables. Review the supplied PlayerBots module's `sql/world/`, `sql/world/classic/`, and `sql/characters/` scripts against a restored copy of your databases before applying them to a live realm. They can recreate bot tables and are not a universal, non-destructive upgrade command. Preserve existing accounts and characters rather than using a fresh-install reset.

`init-db.ps1 -Force` / `init-db.sh --force` drop and recreate the CMaNGOS databases, including all accounts and characters. They are destructive resets, not bot-enablement commands.

After database compatibility is confirmed, stop and start the world using the commands below.

## Conservative Defaults

The generated `aiplayerbot.conf` starts smaller than upstream defaults. Startup logins are limited to one bot per update interval to keep the small-world population target from being overshot by login batches.

| Setting | Default |
| --- | --- |
| `PLAYERBOTS_ENABLED` | `1` |
| `PLAYERBOTS_MIN_RANDOM_BOTS` | `20` |
| `PLAYERBOTS_MAX_RANDOM_BOTS` | `30` |
| `PLAYERBOTS_MIN_LEVEL` | `1` |
| `PLAYERBOTS_MAX_LEVEL` | `60` |
| `PLAYERBOTS_ACCOUNT_COUNT` | `20` |

AHBot defaults:

| Setting | Default |
| --- | --- |
| `AHBOT_ENABLED` | `1` |
| `AHBOT_SELL_CHANCE` | `10` |
| `AHBOT_BUY_CHANCE` | `5` |
| `AHBOT_MAX_REQUIRED_LEVEL` | `60` |

Edit the ignored `.env` to tune the world, then stop and start it.

Windows:

```powershell
.\scripts\down.ps1
.\scripts\up.ps1
```

Linux:

```bash
./scripts/linux/down.sh
./scripts/linux/up.sh
```

## Explicitly Disable Runtime Bots

Set these values in `.env`, then stop and start the world with the commands above:

```text
PLAYERBOTS_ENABLED=0
AHBOT_ENABLED=0
```

Normally leave `BUILD_PLAYERBOTS=ON` and `BUILD_AHBOT=ON`. Turning runtime bots off does not require rebuilding the image or resetting the database.
