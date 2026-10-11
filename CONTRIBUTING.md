# Contributing

Keep this project a small, auditable launcher and assembly layer. Gameplay
patches, cheats and proprietary asset uploads are outside its stock scope.

- Build the launcher and run `tests/Check-Source.ps1` on Windows.
- Use pinned, unmodified upstream source for package validation.
- Never commit private settings, saves, backups, map files, client assets or
  third-party executables. The release packer intentionally uses an allowlist.
- Preserve upstream acknowledgements, copyright and full license notices.
- Keep database/login/game traffic on loopback and leave other installed worlds
  untouched. Shutdown must save; do not introduce forced process termination.
- Document compatibility changes, test evidence and remaining limitations.
- Submit a pull request with a concise explanation and tests performed.

Report bugs with Windows version, upstream pins and redacted logs. Never attach
settings.json, db-client.cnf, SQL dumps, account passwords or a complete game folder.
