#!/usr/bin/env bash
#
# Dribbble desktop app — installer for Linux and macOS.
#   curl -fsSL https://get.rec.tools/dribbble | bash
#
# Downloads from the latest GitHub release through a permanent /latest/download
# URL, so this script never calls api.github.com and never meets its 60 requests
# per hour limit for unauthenticated callers.
#
# Windows is not covered here: fetch the .msi from the releases page instead.

set -euo pipefail

REPO="rdcstarr/pake-dribbble"
BASE="https://github.com/${REPO}/releases/latest/download"
RELEASES="https://github.com/${REPO}/releases/latest"

say()  { printf '\033[36m==\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31mxx\033[0m %s\n' "$*" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl is required."

# The script is delivered on stdin, so nothing here may prompt.
if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fetch() {
  curl -fL --proto '=https' --tlsv1.2 --progress-bar -o "$2" "$1" \
    || die "Download failed: $1 — is there a published release yet? See ${RELEASES}"
}

install_deb() {
  say "Downloading the .deb package"
  fetch "${BASE}/dribbble-linux-amd64.deb" "${TMP}/dribbble.deb"
  say "Installing (dpkg may ask for your password)"
  $SUDO dpkg -i "${TMP}/dribbble.deb" || $SUDO apt-get -f install -y
  say "Installed. Launch it from your applications menu, or run: dribbble"
}

install_appimage() {
  local bin="${HOME}/.local/bin/dribbble"
  local desktop="${HOME}/.local/share/applications/dribbble.desktop"
  local icon="${HOME}/.local/share/icons/hicolor/192x192/apps/dribbble.png"

  say "No dpkg here — installing the AppImage into ~/.local"
  fetch "${BASE}/dribbble-linux-amd64.AppImage" "${TMP}/dribbble.AppImage"
  install -Dm755 "${TMP}/dribbble.AppImage" "$bin"

  mkdir -p "$(dirname "$icon")"
  curl -fsSL --proto '=https' -o "$icon" \
    "https://raw.githubusercontent.com/${REPO}/main/icons/dribbble.png" || warn "Could not fetch the icon."

  mkdir -p "$(dirname "$desktop")"
  cat > "$desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Dribbble
Comment=Dribbble in a standalone window
Exec=${bin}
Icon=dribbble
Categories=Graphics;Network;
Terminal=false
DESKTOP

  command -v update-desktop-database >/dev/null 2>&1 \
    && update-desktop-database "$(dirname "$desktop")" >/dev/null 2>&1 || true

  case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) ;;
    *) warn "~/.local/bin is not on your PATH — the menu entry works, the 'dribbble' command will not." ;;
  esac
  say "Installed to ${bin}"
}

install_macos() {
  say "Downloading the .dmg"
  fetch "${BASE}/dribbble-macos-arm64.dmg" "${TMP}/dribbble.dmg"

  local mount app name
  mount="$(hdiutil attach -nobrowse -readonly "${TMP}/dribbble.dmg" | awk -F'\t' 'END {print $NF}' | sed 's/[[:space:]]*$//')"
  [ -d "$mount" ] || die "Could not mount the disk image."

  app="$(find "$mount" -maxdepth 1 -name '*.app' -print -quit)"
  if [ -z "$app" ]; then hdiutil detach "$mount" -quiet || true; die "No .app inside the disk image."; fi
  name="$(basename "$app")"

  say "Copying ${name} to /Applications"
  rm -rf "/Applications/${name}" 2>/dev/null || $SUDO rm -rf "/Applications/${name}"
  cp -R "$app" /Applications/ 2>/dev/null || $SUDO cp -R "$app" /Applications/
  hdiutil detach "$mount" -quiet || true

  # The binary is not signed or notarised, so Gatekeeper would refuse it outright.
  xattr -dr com.apple.quarantine "/Applications/${name}" 2>/dev/null \
    || $SUDO xattr -dr com.apple.quarantine "/Applications/${name}" 2>/dev/null \
    || warn "Could not clear the quarantine flag — open the app with right-click → Open the first time."

  say "Installed. Open it from /Applications."
}

os="$(uname -s)"
arch="$(uname -m)"

case "$os" in
  Linux)
    [ "$arch" = "x86_64" ] || die "Only x86_64 Linux builds are published; this machine is ${arch}. See ${RELEASES}"
    if command -v dpkg >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
      install_deb
    else
      install_appimage
    fi
    ;;
  Darwin)
    case "$arch" in
      arm64) install_macos ;;
      *) die "Only Apple Silicon builds are published; this Mac is ${arch}. See ${RELEASES}" ;;
    esac
    ;;
  *)
    die "Unsupported system: ${os}. On Windows, download the .msi from ${RELEASES}"
    ;;
esac

echo
say "Sign in with email and password — Google sign-in is unreliable inside an embedded webview."
