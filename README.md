# Phoenix — releases

Installers for **Phoenix**, a local-first AI interview assistant for macOS and Windows.

Downloads are on the [**Releases**](../../releases) page. The application source is kept in a
private repository; this one exists so downloads and in-app updates work without access to it.

---

## macOS — install with no warnings

Paste this into Terminal. It downloads and installs the current version, and macOS will not
block it:

```bash
curl -sL https://github.com/mailtoharutyunyan/phoenix-releases/releases/latest/download/Phoenix-1.6.1-arm64-mac.zip -o /tmp/phoenix.zip \
  && rm -rf /Applications/Phoenix.app \
  && unzip -q /tmp/phoenix.zip -d /Applications \
  && rm /tmp/phoenix.zip \
  && open /Applications/Phoenix.app
```

**Why this avoids the warning.** macOS blocks apps carrying a `com.apple.quarantine` flag, and
that flag is added by whatever *downloads* the file — Safari, Chrome, AirDrop, Messages. A
download made with `curl` never gets one, so there is nothing to block. The app is not modified
and its signature still verifies.

### If you already downloaded it in a browser

You will see *"damaged and can't be opened"* or *"Apple could not verify … free of malware"*.
The app is not damaged and there is nothing wrong with the download — that is the wording macOS
uses for an app whose developer has not paid for an Apple certificate. Pick one:

**Remove the flag** (one command, works for both the `.dmg` and the `.pkg`):

```bash
xattr -d com.apple.quarantine ~/Downloads/Phoenix-*.pkg
```

**Or install the `.pkg` from Terminal**, which skips the check entirely and clears the flag from
the installed app for you:

```bash
sudo installer -pkg ~/Downloads/Phoenix-1.6.1-arm64.pkg -target /
```

**Or without Terminal at all:** open the file, click *Done*, then go to
**System Settings → Privacy & Security**, scroll to *Security*, and click **Open Anyway** next to
Phoenix. On macOS 15 (Sequoia) and later, right-click → *Open* no longer works as a bypass.

---

## After installing

Grant two permissions under **System Settings → Privacy & Security**:

- **Microphone** — your side of the call
- **Screen & System Audio Recording** — the other side's audio, and screenshots

**Quit and reopen Phoenix afterwards.** Screen Recording only takes effect on relaunch.

Phoenix has a deliberately blank icon, so look for the entry named **Phoenix**.

### Seeing more than one "Phoenix" in the list?

Expected, and it will happen on every update. Because these builds are not signed with an Apple
certificate, macOS identifies the app by a hash of that exact build — so each new version is a
different app to it, the previous version's permissions do not carry over, and the old entry
stays behind still switched on. Enable the entry whose toggle is off and remove the leftovers
with the **−** button. Installing the `.pkg` clears the old entries for you.

---

## Requirements

**Apple Silicon only** (M1 and later). There is no Intel Mac build.

## Windows

Run the `.exe` installer. SmartScreen may warn on first run for the same reason — the build is
unsigned. Choose *More info → Run anyway*.
