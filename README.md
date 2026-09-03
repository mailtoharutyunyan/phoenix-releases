<div align="center">

# Phoenix

**An AI interview assistant for macOS. It listens to a call, transcribes both sides,
and streams answers into an overlay that stays out of your screen share.**

Speech recognition, document search, and — if you want it — the language model itself
all run on your own machine.

[![Latest release](https://img.shields.io/github/v/release/mailtoharutyunyan/phoenix-releases?style=for-the-badge&label=download&color=ff6a2b)](../../releases/latest)
[![Platform](https://img.shields.io/badge/macOS-Apple%20Silicon-black?style=for-the-badge&logo=apple)](../../releases/latest)
[![Windows](https://img.shields.io/badge/Windows-planned-6b7280?style=for-the-badge&logo=windows)](#install-on-windows)

**[Website and screenshots &raquo;](https://mailtoharutyunyan.github.io/phoenix-releases/)**

<img src="docs/images/03-answer.png" alt="The Phoenix overlay during a call" width="820">

</div>

---

## What it looks like

<table>
<tr>
<td width="50%"><img src="docs/images/01-dashboard.png" alt="Session setup"><br><sub><b>Before the call.</b> Company, job description and round type &mdash; technical, system design or HR screen.</sub></td>
<td width="50%"><img src="docs/images/04-design-board.png" alt="System design board"><br><sub><b>System design rounds.</b> The architecture is drawn beside the answer, as a separate request, so your words never wait for the picture.</sub></td>
</tr>
</table>

| | |
|:--|:--|
| **Hears both sides** | Your mic and the interviewer's audio, captured separately and labelled. |
| **Invisible to screen sharing** | Excluded from screen capture at the window level. On by default. |
| **Answers in about 1.5s** | A warm session is kept ready between questions. |
| **Reads your screen** | Screenshot the exercise and it answers about what is on it. |
| **Speech stays on your Mac** | Transcription runs on-device; no audio is uploaded, ever. |
| **Works offline** | Switch to the bundled local model. No account, no API key. |

---

## Install on macOS

One command. Paste it into Terminal:

```bash
curl -fsSL https://github.com/mailtoharutyunyan/phoenix-releases/releases/latest/download/install.sh | bash
```

That downloads the current release, verifies its signature, installs it to `/Applications`, and
opens it. **macOS will not block it, and you will not have to type anything else.**

If it fails with `error: 429` — a GitHub rate limit, nothing to do with your Mac — use the mirror,
which fetches the same script from a different CDN:

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/mailtoharutyunyan/phoenix-releases@main/install.sh | bash
```

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

You can [read the script](install.sh) before running it.
</details>

<details>
<summary><b>If that command fails with <code>error: 429</code></b></summary>

`429` means "too many requests" — a rate limit, not a problem with your Mac or with Phoenix. It
happens when the script is fetched from `raw.githubusercontent.com`, which is GitHub's endpoint for
*viewing source files* and is throttled per IP address. Several installs from one office network, or
one person retrying a few times, is enough to trip it.

The command above avoids it: a release asset is served from the same CDN that hands out the 156 MB
app archive, which has no such limit. If you have an older copy of the one-liner and hit 429, use
either of these instead — both fetch exactly the same script:

```bash
# via jsDelivr's CDN
curl -fsSL https://cdn.jsdelivr.net/gh/mailtoharutyunyan/phoenix-releases@main/install.sh | bash

# via the GitHub API (never cached, so always the newest script)
curl -fsSL -H 'Accept: application/vnd.github.raw' \
  https://api.github.com/repos/mailtoharutyunyan/phoenix-releases/contents/install.sh | bash
```

A 429 is temporary. Waiting a few minutes also clears it.
</details>

**Prefer to do it by hand?**

```bash
echo "Downloading Phoenix…" \\
  && URL=$(curl -fsSL https://api.github.com/repos/mailtoharutyunyan/phoenix-releases/releases/latest \\
       | grep -o 'https://[^"]*arm64-mac\\.zip') \\
  && curl -L# "$URL" -o /tmp/phoenix.zip \\
  && echo "Installing…" \\
  && rm -rf /Applications/Phoenix.app \\
  && unzip -q /tmp/phoenix.zip -d /Applications \\
  && rm /tmp/phoenix.zip \\
  && echo "Done." \\
  && open /Applications/Phoenix.app
```

`-#` draws a progress bar — a silent 165 MB download looks like a frozen Terminal. The inner
`curl` resolves whichever release is current, so the command does not go stale.

**Already downloaded it in a browser and macOS is refusing to open it?** Nothing is wrong with
the file — see [Troubleshooting](docs/troubleshooting.md#macos-says-the-app-is-damaged-or-unverified).

**Apple Silicon only** (M1 and later). There is no Intel Mac build.

## Install on Windows

**Not released yet.** The Windows code paths exist, but no Windows installer has shipped — every
release so far is macOS only. There is nothing to download; this section will say otherwise when
there is.

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
| **[Website](https://mailtoharutyunyan.github.io/phoenix-releases/)** | Screenshots, how it works, FAQ |

---

## Requirements

- **macOS:** Apple Silicon (M1 or later), macOS 14 or later
- **Windows:** not released yet — see above
- **Disk:** ~2 GB for the app, plus 3–5 GB if you use a local language model
- **Memory:** 16 GB recommended when running a model locally

## Updating

Phoenix checks for updates on launch and can install them itself. You can also re-run the
install command above at any time — it replaces the existing copy.

You will be asked to grant Microphone and Screen Recording again after each update. That is
expected, and [explained here](docs/troubleshooting.md#i-have-to-grant-permissions-again-after-every-update).
