# Security

This launcher is intended exclusively for a local Windows PC. It is not an
internet-facing server deployment and has not received an independent security
audit. Do not forward its ports, bind it to public interfaces, or use real Tibia
or other reused account credentials.

Each fresh installation generates new local credentials. Keep `settings.json`,
`db-client.cnf`, SQL backups and the save directory private. A process running as
your Windows user can access these files; loopback does not protect against a
compromised local account. Follow your normal OS security practices.

There is no automatic dependency/security update system during offline play.
Maintain Windows and review upstream software updates separately. Updating the
pinned game version may require different assets, binaries and migration tests.

For a security issue, do not post credentials or exploit details in a public
issue. Contact the maintainer through the GitHub profile's available contact
methods or, if enabled, GitHub's private vulnerability reporting.
