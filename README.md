# Tibia Solo — Stock Canary

A Windows launcher for a local, persistent OpenTibia world. Start the launcher,
play locally, then close the game normally to save and stop the server and database.

This is an **unofficial integration project**, not Tibia's official server or
client, and is not affiliated with or endorsed by CipSoft, OpenTibiaBR or MariaDB.
The server/client work belongs to their upstream authors; see
[acknowledgements](ACKNOWLEDGEMENTS.md) and [licensing](docs/LICENSING.md).

## What “stock” means

The datapack and gameplay settings are from **Canary v3.6.1**, paired with
**OTClient 4.1 / protocol 15.11**. This does not promise exact official Tibia rules:
Canary has its own upstream defaults, including experience stages.

- No custom house or edited map, NPC shops, loot tables or equipment requirements.
- No wall-walking, free-coin commands, XP/loot/skill commands, idle-kick removal,
  free-premium override or preloaded personal characters.
- A fresh ordinary level-1 **Adventurer** starts at the upstream default town,
  Dawnport. Progress, stamina, vocation selection and restrictions follow upstream.
- Only infrastructure differs: loopback networking, isolated ports, automatic
  backups, periodic saves and a graceful shutdown signal from the launcher.
- Group quests are **not** redesigned for one player. Store offers may need coins;
  this project does not grant them or support buying official Tibia Coins.

## What the download includes

The GitHub repository/release contains **launcher source, a launcher-only Windows
EXE, preparation scripts, tests, licenses and documentation**. It does **not**
contain proprietary game assets, a world map, server/client/database binaries,
accounts, passwords, saves or SQL backups.

Consequently the public download is **not a complete one-click game**. A one-time
local assembly with compatible inputs you are entitled to use is required. Once
assembled, the complete local folder runs without internet or a Windows database
service. Do not publish that locally assembled folder without checking every
component's redistribution rights. Acknowledgement alone is not permission.

## Requirements

- Windows 10/11 x64, .NET Framework 4.8 and Git.
- Compatible Canary v3.6.1 and OTClient 4.1 Windows binaries and their DLLs.
  Follow each upstream project's build instructions or obtain matching upstream
  builds; mismatched newer binaries are not a supported substitute.
- MariaDB 11.4.8 Windows x64 portable distribution.
- Compatible extracted 15.11 client things assets and the tested stock world map,
  obtained separately with appropriate permission. We do not provide asset mirrors.
- Enough RAM for the full Canary world and space for the assets and save backups.
  This is a full server, not a lightweight Android or single-file game.

Version/commit pins: [upstream.json](upstream.json).

## Prepare once

Use **PowerShell 5.1 or newer**. Review scripts before running downloaded code.
No administrator privileges, inbound firewall rule, Docker or database service
installation are required. Do not disable Windows security globally.

```powershell
git clone --branch v3.6.1 https://github.com/opentibiabr/canary C:\inputs\canary
git clone --branch 4.1 https://github.com/opentibiabr/otclient C:\inputs\otclient

.\scripts\Prepare.ps1 `
  -CanarySource C:\inputs\canary `
  -ClientSource C:\inputs\otclient `
  -CanaryBinary C:\inputs\canary-bin\canary.exe `
  -ClientBinary C:\inputs\otclient-bin\otclient.exe `
  -MariaDbDirectory C:\inputs\mariadb-11.4.8-winx64 `
  -ThingsDirectory C:\inputs\things\1511 `
  -MapFile C:\inputs\otservbr.otbm
```

`ThingsDirectory` must contain `catalog-content.json`, appearances and extracted
sprites expected by OTClient. Optional `-SoundsDirectory` supplies sound assets.
The map is pinned by SHA-256 to the tested original stock map; a personalized map
is rejected. The script exports **tracked files from pinned upstream commits**,
not your modified runtime directories.

Preparation creates `dist/TibiaSoloStock/`, a fresh database and a newly generated
local account. It refuses to overwrite an existing output or save database.
Build/preparation may be allowed for that invocation with
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Prepare.ps1 ...`
if your normal script policy requires it; never disable policy machine-wide.

## Play and save

1. Open `dist/TibiaSoloStock/TibiaSoloStock.exe`.
2. Wait for map startup, then enter the generated account shown in the launcher.
3. Select **Adventurer**. Closing the **game window normally** saves and stops the
   local server/database. The launcher also has **Save and exit**.

Keep the whole local folder together. `settings.json` and `db-client.cnf` are
generated private credentials; never commit or publish them. `saves/` is your
world, `backups/` contains SQL dumps, and `logs/` helps diagnose problems.
Backups accumulate; archive older backups only after verifying a current one.
Never move or copy the database directory while the launcher is running.
If shutdown cannot be confirmed, the launcher leaves components running to
protect data. Do not force-kill them as a normal shutdown procedure.

Default ports (bound to **127.0.0.1 only**): database `18306`, login HTTP `19088`,
game `18172`, native login `18171`, status `18173`. This is not a public server;
do not forward these ports. Separate ports and client identity allow it to coexist
with an existing personalized installation.

## Build and checks

```powershell
.\scripts\Build.ps1
.\tests\Check-Source.ps1
.\tests\Check-Package.ps1 -PackageDirectory .\dist\TibiaSoloStock
```

The launcher is an EXE **controller**, not a self-contained replacement for its
components. Compiling Canary/OTClient is outside this launcher's build script.
Validation status and limitations are documented in [verification](docs/VERIFICATION.md).
An optional [GitHub Actions workflow template](docs/launcher-workflow.yml) builds
the same launcher/source-only artifact. It is not enabled automatically: an owner
with the necessary permissions can place it in `.github/workflows/launcher.yml`.

## Credits and license

Thank you to **OpenTibiaBR/Canary**, **OTServBR-Global**, **OTClient Redemption**,
**edubart/OTClient**, **The Forgotten Server/OpenTibia community**, **MariaDB**
and their contributors. **CipSoft** created Tibia; game trademarks and proprietary
assets remain with their respective owners.

This integration's source is GPL-2.0-only. Upstream components retain their own
licenses; this repository does not relicense proprietary assets. No warranty is
provided. Please review [ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md) and all notices.
