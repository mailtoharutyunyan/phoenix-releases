#!/bin/bash
#
# Phoenix installer for macOS.
#
#   curl -fsSL https://github.com/mailtoharutyunyan/phoenix-releases/releases/latest/download/install.sh | bash
#
# Downloads the current release and installs it to /Applications.
#
# That URL is a RELEASE ASSET, not raw.githubusercontent.com. raw is GitHub's source-viewing
# endpoint and is throttled per IP: it started answering `curl: (56) ... error: 429` mid-install,
# which looks like a broken installer and is really a borrowed distribution channel. Release assets
# come from the same CDN that serves the 156 MB archive, with no such limit. The workflow in the
# source repo attaches this file to every release, so the URL always exists.
#
# Mirror, if GitHub ever rate-limits anyway:
#   curl -fsSL https://cdn.jsdelivr.net/gh/mailtoharutyunyan/phoenix-releases@main/install.sh | bash
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
LOCK=""
LOCK_HELD=0
cleanup() {
  # Loops first so nothing respawns, then the curls by their RECORDED pids (see fetch_range for
  # why the pid file exists), then a second pass for anything that slipped between the two.
  #
  # The pid files live in $TMP, which is unique per run (mktemp -d), and NOT beside the parts in
  # the shared cache. When they were in the cache this loop killed the downloads of any OTHER
  # installer that happened to be running: every run globbed the same directory, so simply
  # starting a second installer terminated the first one's curls. Observed as three
  # "Terminated: 15" lines at 0% on a run that was the only one left alive.
  for _pass in 1 2; do
    for _pid in $CHILDREN; do kill "$_pid" 2>/dev/null || true; done
    for _f in "$TMP"/*.pid; do
      [ -f "$_f" ] || continue
      kill "$(cat "$_f")" 2>/dev/null || true
      rm -f "$_f"
    done
  done
  # ONLY if this run actually acquired it. A run that exited because someone else held the lock
  # must not release it on the way out -- that would hand the cache to a third installer while
  # the real owner is still downloading into it, which is the exact collision the lock prevents.
  [ "$LOCK_HELD" = "1" ] && [ -n "$LOCK" ] && rm -rf "$LOCK"
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

# EVERY GITHUB CALL HERE HAS A SECOND DOOR.
#
# `curl: (56) ... error: 429` was reported mid-install: GitHub rate limits per IP, and when it
# does, one host says no while another still answers -- measured during that failure, raw.github
# 429 while api.github.com returned 200. A single point of contact turns a temporary limit into a
# dead installer, so the two things this script fetches from GitHub each have a fallback on a
# different host. The bytes are identical either way; only the front door differs.
MIRROR_HINT="curl -fsSL https://cdn.jsdelivr.net/gh/$REPO@main/install.sh | bash"

echo "  Finding the latest release…"
# Preferred: the redirect on /releases/latest -- no token, and it costs no API quota.
# Fallback: the API, which is a different host with a separate limit.
resolve_tag() {
  local t
  t="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest" 2>/dev/null | sed 's|.*/tag/||')"
  case "$t" in v[0-9]*) printf '%s' "$t"; return 0 ;; esac
  t="$(curl -fsSL -H 'Accept: application/vnd.github+json' "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
        | awk -F'"' '/"tag_name"/ { print $4; exit }')"
  case "$t" in v[0-9]*) printf '%s' "$t"; return 0 ;; esac
  return 1
}
TAG="$(resolve_tag)" || die "Could not determine the latest version — GitHub may be rate limiting you (error 429), which clears in a few minutes. You can also try: $MIRROR_HINT"
VERSION="${TAG#v}"
ok "Found $TAG"

ASSET="Phoenix-${VERSION}-arm64-mac.zip"
URL="https://github.com/$REPO/releases/download/$TAG/$ASSET"

# The API's own download URL for the same asset, resolved ONLY if the normal one fails: it costs an
# API request, and the unauthenticated allowance is small enough not to spend on the happy path.
# Asset objects list "url" before "name", so the url is remembered and printed when the name matches.
ALT_URL=""
alt_url() {
  [ -n "$ALT_URL" ] && { printf '%s' "$ALT_URL"; return 0; }
  ALT_URL="$(curl -fsSL -H 'Accept: application/vnd.github+json' "https://api.github.com/repos/$REPO/releases/tags/$TAG" 2>/dev/null \
    | awk -v want="$ASSET" -F'"' '
        /"url": *"https:\/\/api\.github\.com\/repos\/[^"]*\/releases\/assets\// { u=$4 }
        /"name":/ { if ($4 == want && u != "") { print u; exit } }')"
  [ -n "$ALT_URL" ] && printf '%s' "$ALT_URL"
}

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

# ONE INSTALLER AT A TIME.
#
# The cache path is fixed and the parts are built by appending, so two installers running at
# once append into the SAME four files and each duplicated region lands in the archive twice.
# This is not hypothetical and it is easy to trigger: re-running because the first run looks
# stuck is the obvious thing to do. Measured when it happened -- the progress ticker read 147%
# and then 155%, and unzip found 85,533,240 extra bytes. Nothing in the output said "you are
# running two of these"; it said the download was not a readable archive.
#
# mkdir is the lock because it is atomic on every filesystem this runs on; a test-then-create
# with [ -e ] is not.
LOCK="$CACHE/.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  LOCK_OWNER="$(cat "$LOCK/pid" 2>/dev/null || echo)"
  if [ -n "$LOCK_OWNER" ] && kill -0 "$LOCK_OWNER" 2>/dev/null; then
    die "Another Phoenix install is already running (pid $LOCK_OWNER). Let it finish, or stop it and run this again."
  fi
  # Stale: the owner died without releasing it (kill -9, or a reboot mid-download). Reclaim,
  # rather than making the user delete a lock file to install an app.
  rm -rf "$LOCK"
  mkdir "$LOCK" 2>/dev/null || die "Could not take the install lock at $LOCK. Remove it and try again."
fi
LOCK_HELD=1
echo $$ > "$LOCK/pid"

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
  local base stage pidf
  base="$(basename "$out")"
  stage="$TMP/$base.chunk"
  pidf="$TMP/$base.pid"
  while :; do
    have="$(have_bytes "$out")"
    [ "$have" -ge "$want" ] && { rm -f "$pidf" "$stage"; return 0; }
    # curl runs in the BACKGROUND and its pid is written down. Killing the enclosing subshell is
    # not enough and cannot be made enough: kill the subshell first and the curl is reparented to
    # launchd, where `pkill -P` can no longer find it; kill the curl first and the loop here
    # simply starts another one. Both were measured, each leaving a download alive. The pid file
    # is the only version that is deterministic.
    #
    # TWO THINGS HERE ARE LOAD-BEARING, and the obvious version of each corrupted real downloads.
    #
    #   * NO --retry. It looks free, and it is not: curl's own retry re-requests the range FROM
    #     ITS START, and the old code redirected with `>> "$out"`, so those bytes were appended a
    #     SECOND time. `have` is read once, before curl runs, so the resume offset cannot see the
    #     duplication -- and nothing downstream checks, because each part is the right length or
    #     longer. The archive then assembles with extra bytes and unzip says "extra bytes at
    #     beginning or within zipfile", which reads as a bad release rather than a bad download.
    #     Retrying belongs to this loop, where the offset is recomputed on every pass.
    #
    #   * The transfer lands in a STAGING file and is appended only once its length is known, so
    #     a killed or failed curl can never leave the part file in a state the resume offset
    #     would misread. The staging file lives in $TMP and NOT at "$out.chunk", because
    #     "$out.chunk" matches the `part[0-9]*` glob that assembles the archive -- it would have
    #     been concatenated into the zip, replacing one corruption with another.
    rm -f "$stage"
    curl -fsL -r "$(( start + have ))-${end}" -o "$stage" "$URL" &
    cpid=$!
    echo "$cpid" > "$pidf"
    if wait "$cpid"; then
      cat "$stage" >> "$out"
      rm -f "$stage"
      continue
    fi
    # A failed transfer still wrote a valid PREFIX of what was asked for -- curl writes in order
    # -- so keep those bytes and let the loop resume past them, rather than discarding good
    # megabytes on the flaky connection that motivated resuming in the first place.
    [ -s "$stage" ] && cat "$stage" >> "$out"
    rm -f "$stage"
    # Counted whether or not progress was made: a link dribbling a few bytes per attempt would
    # otherwise spin here forever, looking like a hung install.
    tries=$(( tries + 1 ))
    [ "$tries" -ge 8 ] && { rm -f "$pidf" "$stage"; return 1; }
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
      # Staging bytes count too, or the bar sits still for a whole chunk and then jumps -- the
      # part file only grows when a transfer completes.
      for i in $(seq 0 $(( PARTS - 1 ))); do
        got=$(( got + $(have_bytes "$ZIP.part$i") + $(have_bytes "$TMP/$ASSET.part$i.chunk") ))
      done
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
  # No pid or staging files to exclude here any more -- both live in $TMP, precisely so they
  # cannot be caught by the glob that assembles the archive.
  cat "$ZIP".part[0-9]* > "$ZIP" && rm -f "$ZIP".part*
  # The assembled length must be exactly what the server advertised. Cheap, and it localises the
  # blame: without it a mis-assembled archive is first noticed by unzip, minutes later, and
  # reported as a bad archive rather than a bad assembly.
  if [ "$(have_bytes "$ZIP")" != "$SIZE" ]; then
    echo "  Assembled size did not match; retrying as a single stream."
    rm -f "$ZIP" "$ZIP".part*
    return 1
  fi
}

download_single() {
  # No array for the resume flag: macOS ships bash 3.2, where expanding an EMPTY array under
  # `set -u` aborts with "unbound variable". Caught in testing, and it would have broken every
  # fallback download.
  local u="${1:-$URL}"
  if [ -f "$ZIP" ]; then
    curl -fL# -C - --retry 5 --retry-delay 2 -H 'Accept: application/octet-stream' -o "$ZIP" "$u"
  else
    curl -fL# --retry 5 --retry-delay 2 -H 'Accept: application/octet-stream' -o "$ZIP" "$u"
  fi
}

# Last resort: the same asset through the API host. Only reached when the normal download failed,
# which on a rate limit is exactly when a different host is worth trying.
#
# One resumable stream rather than four ranges, and NOT because ranges fail here -- measured, this
# endpoint answers a Range request with 206. It is because the unauthenticated API allowance is
# small (60 requests an hour) and this path exists to finish an install that is already in trouble;
# spending four requests plus retries to shave minutes off a last resort is the wrong trade.
download_via_api() {
  local u
  u="$(alt_url)" || return 1
  [ -n "$u" ] || return 1
  echo "  Retrying through GitHub's API host…"
  download_single "$u"
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
    download_parallel || download_single || download_via_api \
      || die "Download failed. Re-run this installer — it continues where it stopped. If it keeps failing with 429, GitHub is rate limiting you; that clears in a few minutes, or try: $MIRROR_HINT"
  else
    download_single || download_via_api \
      || die "Download failed. Re-run this installer — it continues where it stopped. If it keeps failing with 429, GitHub is rate limiting you; that clears in a few minutes, or try: $MIRROR_HINT"
  fi
fi

# CHECK THE BYTES BEFORE SPENDING MINUTES UNPACKING THEM.
#
# unzip does catch a corrupt archive, but it catches it late and describes it badly: it prints a
# screen of "bad zipfile offset" lines and the script says "not a readable archive", which points
# the user at the RELEASE when the release is fine and their copy of it is not. Every release
# ships latest-mac.yml -- it is what the in-app updater verifies against -- so the authoritative
# checksum is one small request away and gives a one-second, unambiguous answer.
#
# Soft-fails when the file or the field is missing: an old release without it should still be
# installable, and codesign --verify below remains the check that actually gates installation.
echo "  Verifying the download…"
EXPECT_SHA="$(curl -fsSL "https://github.com/$REPO/releases/download/$TAG/latest-mac.yml" 2>/dev/null \
  | awk '/^sha512:/ { print $2; exit }')"
if [ -n "$EXPECT_SHA" ]; then
  ACTUAL_SHA="$(openssl dgst -sha512 -binary "$ZIP" | openssl base64 -A)"
  if [ "$ACTUAL_SHA" != "$EXPECT_SHA" ]; then
    rm -f "$ZIP" "$ZIP".part*
    die "The download does not match the checksum published for $TAG, so it has been discarded — the release itself is fine. This is an interrupted or duplicated download; run this installer again."
  fi
  ok "Checksum verified"
else
  echo "  (no checksum published for $TAG — the signature check below still applies)"
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
