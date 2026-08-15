<div align="center">

# Phoenix

**An AI interview assistant for macOS and Windows. It listens to a call, transcribes both sides,
and streams answers into an overlay that stays out of your screen share.**

Speech recognition, document search, and — if you want it — the language model itself
all run on your own machine.

[![Latest release](https://img.shields.io/github/v/release/mailtoharutyunyan/phoenix-releases?style=for-the-badge&label=download&color=2b7fff)](../../releases/latest)
[![Platform](https://img.shields.io/badge/macOS-Apple%20Silicon-black?style=for-the-badge&logo=apple)](../../releases/latest)
[![Windows](https://img.shields.io/badge/Windows-10%2B-0078D4?style=for-the-badge&logo=windows)](../../releases/latest)

</div>

---

## Install on macOS

One command. Paste it into Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/mailtoharutyunyan/phoenix-releases/main/install.sh | bash
```

That downloads the current release, verifies its signature, installs it to `/Applications`, and
opens it. **macOS will not block it, and you will not have to type anything else.**

<details>
<summary><b>Why this works when double-clicking the download does not</b></summary>

Phoenix is not signed with a paid Apple Developer certificate. macOS tags anything you download
**in a browser** with `com.apple.quarantine` and then refuses to open it, reporting the app as
*"damaged"* or *"could not be verified free of malware"*. It is neither — that is simply the
wording Apple uses for an unsigned app.

That flag is applied by the program doing the downloading, not by macOS itself, and **a download
made with `curl` never receives one**. So the script does not remove a protection or defeat a
check; it never creates the flag in the first place. The app is not modified, and the script
verifies its code signature before installing — if that fails, nothing is installed.

You can [read the script](install.sh) before running it. It is 60 lines.
</details>

**Prefer to do it by hand?**

```bash
echo "Downloading Phoenix (about 165 MB)…" \
  && curl -L# https://github.com/mailtoharutyunyan/phoenix-releases/releases/latest/download/Phoenix-1.6.1-arm64-mac.zip -o /tmp/phoenix.zip \
  && echo "Installing…" \
  && rm -rf /Applications/Phoenix.app \
  && unzip -q /tmp/phoenix.zip -d /Applications \
  && rm /tmp/phoenix.zip \
  && echo "Done." \
  && open /Applications/Phoenix.app
```

`-#` draws a progress bar — a silent 165 MB download looks like a frozen Terminal.

**Already downloaded it in a browser and macOS is refusing to open it?** Nothing is wrong with
the file — see [Troubleshooting](docs/troubleshooting.md#macos-says-the-app-is-damaged-or-unverified).

**Apple Silicon only** (M1 and later). There is no Intel Mac build.

## Install on Windows

Run the `.exe` installer. SmartScreen may warn on first run because the build is unsigned —
choose *More info → Run anyway*.

---

## Documentation

| | |
|---|---|
| **[Getting started](docs/getting-started.md)** | Permissions, your first session, what each mode is for |
| **[During a call](docs/during-a-call.md)** | The overlay, answering, screenshots, system design |
| **[Keyboard shortcuts](docs/shortcuts.md)** | Every shortcut, verified against the build |
| **[Settings](docs/settings.md)** | Models, speech engine, staying hidden |
| **[Privacy](docs/privacy.md)** | What is stored, what leaves your machine |
| **[Troubleshooting](docs/troubleshooting.md)** | Permissions, "damaged", audio, updates |

---

## Requirements

- **macOS:** Apple Silicon (M1 or later), macOS 14 or later
- **Windows:** Windows 10 or later, 64-bit
- **Disk:** ~2 GB for the app, plus 3–5 GB if you use a local language model
- **Memory:** 16 GB recommended when running a model locally

## Updating

Phoenix checks for updates on launch and can install them itself. You can also re-run the
install command above at any time — it replaces the existing copy.

You will be asked to grant Microphone and Screen Recording again after each update. That is
expected, and [explained here](docs/troubleshooting.md#i-have-to-grant-permissions-again-after-every-update).
