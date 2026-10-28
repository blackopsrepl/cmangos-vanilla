# PlayerBots and AHBot

PlayerBots can make a small family world feel populated when only one or two people are playing. AHBot keeps the auction houses active without requiring a large player population.

Both features are optional. First get the plain core world working, then opt in by setting these values in `.env`:

```text
BUILD_PLAYERBOTS=ON
BUILD_AHBOT=ON
BUILD_SCRIPTDEV=ON
PLAYERBOTS_ENABLED=1
AHBOT_ENABLED=1
```

When enabled, the Docker image builds CMaNGOS with:

- `-DBUILD_PLAYERBOTS=ON`
- `-DBUILD_AHBOT=ON`
- `-DBUILD_SCRIPTDEV=ON`
- `-DBUILD_EXTRACTORS=ON`

The Classic-DB import runs with `PLAYERBOTS_DB=YES` and `AHBOT=YES` only when the corresponding build and runtime flags are enabled.

## Conservative Defaults

When bots are enabled, the generated `aiplayerbot.conf` intentionally starts smaller than upstream defaults:

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

Edit `.env`, then restart:

```powershell
.\scripts\down.ps1
.\scripts\up.ps1
```

If changing database import options after the DB already exists, rebuild the DB explicitly:

```powershell
.\scripts\init-db.ps1 -Force
```

That drops and recreates the CMaNGOS databases through the upstream Classic-DB installer.
