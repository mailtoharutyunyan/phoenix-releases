#!/bin/bash
#
# Phoenix installer for macOS.
#
#   curl -fsSL https://raw.githubusercontent.com/mailtoharutyunyan/phoenix-releases/main/install.sh | bash
#
# Downloads the current release and installs it to /Applications.
#
# WHY THIS EXISTS, and why it is not a security bypass
# ----------------------------------------------------
# Phoenix is not signed with a paid Apple Developer certificate, so macOS tags anything you
# download in a browser with `com.apple.quarantine` and then refuses to open it -- reporting the
# app as "damaged", which it is not. That flag is applied by the DOWNLOADING program, not by
# macOS itself, and a download made with curl never receives one. So this script does not remove
# a protection or work around a check: it simply never creates the flag in the first place. The
# app's own code signature is verified below and must pass, or nothing is installed.
#
# Unnecessary once releases are signed with a Developer ID and notarized.
set -euo pipefail

REPO="mailtoharutyunyan/phoenix-releases"
APP="/Applications/Phoenix.app"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
ok()   { printf '\033[0;32m✓\033[0m %s\n' "$1"; }
die()  { printf '\033[0;31m✗\033[0m %s\n' "$1" >&2; exit 1; }

echo
bold "  Installing Phoenix"
echo

[ "$(uname -s)" = "Darwin" ] || die "This installer is for macOS."
# Apple Silicon only -- there is no Intel build, and an arm64 app will not run under Rosetta.
[ "$(uname -m)" = "arm64" ] || die "Phoenix requires an Apple Silicon Mac (M1 or later). There is no Intel build."

echo "  Finding the latest release…"
# Resolve the tag from the redirect on /releases/latest rather than the API: no token, no rate
# limit that a few people behind one office IP could trip.
TAG="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest" | sed 's|.*/tag/||')"
[ -n "$TAG" ] || die "Could not determine the latest version. Check your connection."
VERSION="${TAG#v}"
ok "Found $TAG"

ASSET="Phoenix-${VERSION}-arm64-mac.zip"
URL="https://github.com/$REPO/releases/download/$TAG/$ASSET"

echo "  Downloading (about 165 MB)…"
curl -fL# -o "$TMP/phoenix.zip" "$URL" || die "Download failed. The release may not include $ASSET."

echo "  Unpacking…"
unzip -q "$TMP/phoenix.zip" -d "$TMP/out" || die "The download is not a readable archive; it may be incomplete."
[ -d "$TMP/out/Phoenix.app" ] || die "Phoenix.app was not found inside the archive."

# Verify BEFORE replacing anything already installed. A failed check must not cost the user a
# working copy of the app.
echo "  Verifying the signature…"
codesign --verify --deep --strict "$TMP/out/Phoenix.app" 2>/dev/null \
  || die "Signature verification failed — the download may be corrupt. Nothing was installed."
ok "Signature verified"

# Replacing a running app leaves a half-updated bundle.
if pgrep -qf "$APP/Contents/MacOS" 2>/dev/null; then
  echo "  Quitting the running copy…"
  osascript -e 'tell application "Phoenix" to quit' 2>/dev/null || true
  sleep 2
fi

echo "  Installing to /Applications…"
# A copy installed from the .pkg is owned by ROOT -- the installer writes into the localSystem
# domain -- and an unprivileged `rm -rf` cannot delete the files inside it. Every one of them
# failed with "Permission denied", and because this script runs under `set -e` the update then
# aborted at exactly the point where a bundle can be left half-replaced. (Observed: the old
# 1.6.1 survived intact, because nothing could be removed at all, but that was luck rather
# than design.)
#
# So: try as the user, and escalate ONLY when that genuinely fails. sudo prompts on /dev/tty
# rather than stdin, which matters here — stdin is this script, piped from curl.
if [ -e "$APP" ] && ! rm -rf "$APP" 2>/dev/null; then
  echo "  The installed copy is owned by root — it came from the .pkg installer."
  echo "  macOS needs your password to replace it:"
  sudo -p "  Password for %u: " rm -rf "$APP" \
    || die "Could not remove $APP. Run 'sudo rm -rf $APP' and then this installer again. Nothing was changed."
fi

# ditto rather than mv/cp: it preserves extended attributes and keeps the signature intact.
if ! ditto "$TMP/out/Phoenix.app" "$APP" 2>/dev/null; then
  sudo -p "  Password for %u: " ditto "$TMP/out/Phoenix.app" "$APP" \
    || die "Could not write to $APP. Nothing was installed."
  # Hand it to the user, so every future update is a plain user-level replace with no password.
  sudo chown -R "$(id -un):staff" "$APP" 2>/dev/null || true
fi

# Belt and braces. A curl download carries no quarantine flag, so this normally finds nothing --
# but it costs nothing and covers the case where someone pipes this script from a saved file that
# was itself downloaded in a browser.
xattr -cr "$APP" 2>/dev/null || true

echo
ok "Phoenix $VERSION is installed."
echo
bold "  One more step"
echo "  Grant these under System Settings → Privacy & Security:"
echo
echo "    • Microphone                       your side of the call"
echo "    • Screen & System Audio Recording  the other side's audio, and screenshots"
echo
echo "  Phoenix has a blank icon on purpose — look for the entry named Phoenix."
echo "  Screen Recording only takes effect after you quit and reopen the app."
echo "  These are asked for again after every update: without a paid Apple certificate,"
echo "  macOS identifies the app by the hash of one exact binary, so each build is new to it."
echo
open "$APP" 2>/dev/null || true
