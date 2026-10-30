# BB branding (`bb` brand)

ADR-0002 §Границы: BB branding lives here plus brand `bb` in `surfer.json`.

## Assets
Every asset in this directory is a copy of Zen's `configs/branding/release/`
(Zen OSS Team, MPL-2.0). They are placeholders until E0 replaces them with BB's own
logos; attribution stays with the Zen OSS Team.

## Brand strings
The texts (brand.ftl / brand.properties) are generated from `surfer.json`
(`buildOptions.generateBranding: true`), fields under `brands.bb`:

| field | value |
|---|---|
| `brandFullName` | BROzen BROwser |
| `brandShortName` | BB |
| `brandShorterName` | BB |
| `backgroundColor` | #282A33 |
| `release.displayVersion` | 1.23.4b |

Top-level `vendor` is `broplz`. `name`, `appId`, `binaryName` and `updateHostname` stay Zen's
(ids and the profile dir are unchanged; a separate profile dir is deferred to an E0 ADR).
No `github`/`archives`: BB has no update server.
