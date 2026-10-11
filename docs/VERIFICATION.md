# Verification

The launcher compiles successfully with the Windows .NET Framework compiler.
`tests/Check-Source.ps1` validates PowerShell syntax, generated rather than
hardcoded credentials, loopback binding and the infrastructure-only lifecycle
overlay. The public packer checks an explicit allowlist and inspects the ZIP for
excluded files before publication.

## Checks completed on Windows, 2026-10-10

- Launcher compiled successfully with the Windows .NET Framework compiler.
- PowerShell parsing and infrastructure-only/no-cheat source checks passed.
- A new local package was assembled from the pinned upstream Git commits and
  separately supplied, compatible binaries/assets. No saved account was imported.
- **5,520 stock datapack files** were byte-identical to the exported pinned source.
- Every gameplay configuration value matched upstream. Only the documented
  infrastructure values differed; no personalized overlays were present.
- Canary loaded its world and scripts, connected to the fresh database and became
  ready. Local HTTP login rejected a wrong password and returned the correct
  fresh account/character for a valid one.
- Account type 1, zero premium days/coins, player group 1, level 1, vocation 0 and
  upstream town 1 (Dawnport) were verified by read-only database queries.
- Database, HTTP login, native login, game and status ports were all loopback-only.
- The lifecycle shutdown signal saved the world, produced an SQL backup and
  stopped the launcher/server/database without force-killing a process.
- Reopening the same save database passed the runtime checks again. A second
  graceful shutdown was checked before handing off the local package.
- The existing personalized installation remained running on its separate ports;
  its processes and saves were not stopped or replaced.

The runtime checks used `--server-only`. They verify server/database/login
operation, not a character entering the graphical client. Raw TCP readiness
probes can produce a server connection-write warning when the probe closes;
those diagnostic connections are not an end-to-end game session.

Imported third-party license notices are preserved verbatim, including their
original formatting. The project's own source passes Git whitespace checks.

GitHub Actions was not run for this release. The publishing login lacked workflow
write permission, so the tested build commands are provided as an optional workflow
template under `docs/launcher-workflow.yml`, not an enabled workflow.

## Scope limitations

No claim of exhaustive end-to-end playtesting is made. UI entry, combat, long
sessions, every quest and restore/disaster recovery need further testing. The
full upstream world contains content intended for multiple players. This project
does not make those mechanics solo-friendly or provide official services.

The full locally assembled package is intentionally not a public release asset.
