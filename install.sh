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

# Ctrl-C MUST take the background downloads with it.
#
# Found by watching a real interrupted install: the parallel fetch runs curl as background jobs,
# and a background job does NOT receive SIGINT from the terminal -- only the foreground process
# group does. So Ctrl-C killed this script and left four curls plus the progress ticker running,
# orphaned. Observed consequences: stale "6%" lines printed over the NEXT command's output (the
# ticker still had the terminal), and two abandoned downloads of the previous version competing
# for bandwidth with the install the user was waiting on -- on the slow connection that motivated
# parallel downloads in the first place.
#
# Partial part files are deliberately left on disk: they live in the cache and the next run
# resumes from them. It is the processes that must die, not the progress.
# `fetch_range ... &` backgrounds a FUNCTION, so $! is a subshell and the curl is ITS child --
# killing the recorded pid alone leaves the download running, which is precisely what was observed.
# So each child is reaped as a tree: its children first (pkill -P), then itself.
CHILDREN=""
cleanup() {
  # Loops first so nothing respawns, then the curls by their RECORDED pids (see fetch_range for
  # why the pid file exists), then a second pass for anything that slipped between the two.
  for _pass in 1 2; do
    for _pid in $CHILDREN; do kill "$_pid" 2>/dev/null || true; done
    for _f in "$ZIP".part*.pid; do
      [ -f "$_f" ] || continue
      kill "$(cat "$_f")" 2>/dev/null || true
      rm -f "$_f"
    done
  done
  rm -rf "$TMP"
}
# An interrupt must END the run, not just tidy up: a trap that RETURNS resumes the script, and it
# resumed straight into `cat` of the half-finished parts -- assembling a truncated archive and
# carrying on toward installing it. Measured. So the signal handler exits, and 130 is the
# conventional code for "killed by SIGINT".
on_signal() { cleanup; exit 130; }
trap cleanup EXIT
trap on_signal INT TERM

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

# DOWNLOADING 165 MB OVER A SLOW LINK
# -----------------------------------
# This was one `curl -fL#`: a single stream, no resume, into a temp directory wiped on exit. On a
# slow or flaky connection that has two bad properties. A drop at 90% threw away 148 MB and the
# next run started from zero; and a single stream gets whatever throughput the far end feels like
# giving it, which for GitHub's asset host varies a lot by region.
#
# So: keep the partial download in a CACHE that survives the run, resume from it, and pull four
# ranges at once when the host supports Range (it does — it answers 206). Falls back to one
# resumable stream when it does not, so nothing depends on the fast path working.
#
# Integrity is unchanged and still absolute: whatever is assembled here must satisfy
# `codesign --verify --deep --strict` below, or nothing is installed.
CACHE="${HOME}/Library/Caches/phoenix-install"
mkdir -p "$CACHE"
ZIP="$CACHE/$ASSET"
PARTS=4

# One HEAD request for both facts we need: how big it is, and whether ranges are served.
# Lower-cased with tr, NOT with awk's IGNORECASE -- that is a gawk extension and macOS ships BSD
# awk, where it is silently ignored. Caught in testing: the size parsed as empty, so the fast
# path was never taken on the one platform this script runs on.
HEADERS="$(curl -fsSLI "$URL" 2>/dev/null | tr -d '\r' | tr '[:upper:]' '[:lower:]' || true)"
SIZE="$(printf '%s\n' "$HEADERS" | awk '/^content-length:/ {v=$2} END {print v+0}')"
RANGES="$(printf '%s\n' "$HEADERS" | awk '/^accept-ranges:/ {v=$2} END {print v}')"

have_bytes() { [ -f "$1" ] && wc -c < "$1" | tr -d ' ' || echo 0; }

# Fetch one byte range into its own file, resuming and retrying. Appends, so a part that is
# half-there continues rather than restarting.
fetch_range() {
  local start=$1 end=$2 out=$3 want=$(( $2 - $1 + 1 )) tries=0 have cpid
  while :; do
    have="$(have_bytes "$out")"
    [ "$have" -ge "$want" ] && { rm -f "$out.pid"; return 0; }
    # curl runs in the BACKGROUND and its pid is written down. Killing the enclosing subshell is
    # not enough and cannot be made enough: kill the subshell first and the curl is reparented to
    # launchd, where `pkill -P` can no longer find it; kill the curl first and the loop here
    # simply starts another one. Both were measured, each leaving a download alive. The pid file
    # is the only version that is deterministic.
    curl -fsL --retry 3 --retry-delay 2 -r "$(( start + have ))-${end}" "$URL" >> "$out" &
    cpid=$!
    echo "$cpid" > "$out.pid"
    if wait "$cpid"; then continue; fi
    tries=$(( tries + 1 ))
    [ "$tries" -ge 4 ] && { rm -f "$out.pid"; return 1; }
    sleep 2
  done
}

download_parallel() {
  local chunk=$(( SIZE / PARTS )) i start end pids=() rc=0
  for i in $(seq 0 $(( PARTS - 1 ))); do
    start=$(( i * chunk ))
    end=$(( start + chunk - 1 ))
    [ "$i" -eq $(( PARTS - 1 )) ] && end=$(( SIZE - 1 ))
    fetch_range "$start" "$end" "$ZIP.part$i" &
    pids+=($!)
    CHILDREN="$CHILDREN $!"
  done
  # Progress from the parts themselves: four interleaved `curl -#` bars are unreadable. Runs in a
  # subshell, so no `local` here -- it is only valid inside a function.
  ( while :; do
      alive=0
      for p in "${pids[@]}"; do kill -0 "$p" 2>/dev/null && alive=1; done
      [ "$alive" -eq 1 ] || break
      got=0
      for i in $(seq 0 $(( PARTS - 1 ))); do got=$(( got + $(have_bytes "$ZIP.part$i") )); done
      printf '\r  %s%%   ' "$(( got * 100 / SIZE ))"
      sleep 2
    done ) &
  local ticker=$!
  CHILDREN="$CHILDREN $ticker"
  for i in "${pids[@]}"; do wait "$i" || rc=1; done
  kill "$ticker" 2>/dev/null || true
  wait "$ticker" 2>/dev/null || true
  printf '\r            \r'
  [ "$rc" -eq 0 ] || return 1
  rm -f "$ZIP".part*.pid                  # never let a pid file end up inside the archive
  cat "$ZIP".part[0-9]* > "$ZIP" && rm -f "$ZIP".part*
}

download_single() {
  # No array for the resume flag: macOS ships bash 3.2, where expanding an EMPTY array under
  # `set -u` aborts with "unbound variable". Caught in testing, and it would have broken every
  # fallback download.
  if [ -f "$ZIP" ]; then
    curl -fL# -C - --retry 5 --retry-delay 2 -o "$ZIP" "$URL"
  else
    curl -fL# --retry 5 --retry-delay 2 -o "$ZIP" "$URL"
  fi
}

if [ "$(have_bytes "$ZIP")" = "$SIZE" ] && [ "$SIZE" -gt 0 ]; then
  ok "Already downloaded — using the cached copy"
else
  if [ "$SIZE" -gt 0 ]; then
    echo "  Downloading ($(( SIZE / 1000000 )) MB)…"
  else
    echo "  Downloading…"
  fi
  if [ "$RANGES" = "bytes" ] && [ "$SIZE" -gt 0 ]; then
    download_parallel || download_single || die "Download failed. Re-run this installer — it continues where it stopped."
  else
    download_single || die "Download failed. Re-run this installer — it continues where it stopped."
  fi
fi

echo "  Unpacking…"
# Remove the cached copy on failure: a corrupt archive that stays cached would fail identically
# on every re-run, which is the same trap as reusing a broken Python environment.
unzip -q "$ZIP" -d "$TMP/out" || { rm -f "$ZIP"; die "The download was not a readable archive; it has been discarded. Run this installer again."; }
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

# The cache exists to survive a FAILED download, not to keep 165 MB forever once it worked.
rm -f "$ZIP" "$ZIP".part*

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
