# Dribbble, as a desktop app

[Dribbble](https://dribbble.com) packaged with [Pake](https://github.com/tw93/Pake)
into a native window — the system webview, not a bundled browser, so the whole
thing is a few megabytes rather than a few hundred.

## Install

```bash
curl -fsSL https://get.rec.tools/dribbble | bash
```

Linux and macOS. On Linux the script installs the `.deb` where `dpkg` exists and
falls back to the AppImage in `~/.local` where it does not. On Windows, download
the `.msi` from [the latest release](https://github.com/rdcstarr/pake-dribbble/releases/latest).

## Two things worth knowing

**Sign in with email and password.** Google sign-in is unreliable inside an
embedded webview — providers routinely reject them. The app is built with
`newWindow` and `safeDomain` set for Google's domains, which is the mitigation
Pake documents, but it is not a guarantee.

**The binaries are not signed.** macOS needs the quarantine flag cleared, which
the installer does for you; if it cannot, open the app once with right-click →
Open. Windows shows a SmartScreen warning on first run.

## What builds, and where

| Platform | Format | Architecture |
| --- | --- | --- |
| Linux | `.deb`, `.AppImage` | x86_64 |
| macOS | `.dmg` | Apple Silicon |
| Windows | `.msi` | x64 |

Pushing a `v*` tag builds all three in GitHub Actions and publishes them to a
release. Every asset is renamed to a name that never changes, so
`releases/latest/download/dribbble-linux-amd64.deb` is a permanent URL — that is
what lets `install.sh` skip `api.github.com` entirely, and with it the 60
requests per hour that unauthenticated callers get.

`workflow_dispatch` runs the same build without publishing, for when the
workflow itself is what changed.

## The app definition

Everything the app is lives in [`app.json`](app.json) — URL, window size, the
Google-domain allowance. It follows [Pake's schema](https://raw.githubusercontent.com/tw93/Pake/main/schema/pake.schema.json),
so an unknown field fails the build rather than being ignored. The workflow
overrides only what has to differ per platform: the package name (Linux requires
lowercase), the target format, and the version, which comes from the tag.

## Building it yourself

```bash
npm install --no-save pake-cli
npx pake --config app.json --json --name dribbble --targets deb,appimage
```

Needs Rust and, on Linux, `libwebkit2gtk-4.1-dev librsvg2-dev patchelf
build-essential libssl-dev libayatana-appindicator3-dev`. The first build takes
roughly twenty minutes; later ones are minutes.
