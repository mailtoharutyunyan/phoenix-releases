# Troubleshooting

[← Back to the README](../README.md)

## macOS says the app is "damaged", or unverified

**Nothing is wrong with your download.** That is the wording Apple uses for an app whose
developer has not paid for an Apple certificate. The exact message depends on the file:

- `.dmg` / app — *"Phoenix is damaged and can't be opened. You should move it to the Trash."*
- `.pkg` — *"Apple could not verify Phoenix is free of malware…"*

macOS tags anything downloaded **in a browser** with `com.apple.quarantine` and refuses to open
it. Pick any one of these:

**Reinstall with the script** — avoids the flag entirely, because `curl` never applies one:

```bash
curl -fsSL https://raw.githubusercontent.com/mailtoharutyunyan/phoenix-releases/main/install.sh | bash
```

**Remove the flag from what you already downloaded:**

```bash
xattr -d com.apple.quarantine ~/Downloads/Phoenix-*.pkg
```

**Install the `.pkg` from Terminal** — performs no check at all, and clears the flag from the
installed app for you:

```bash
sudo installer -pkg ~/Downloads/Phoenix-*.pkg -target /
```

**Without Terminal:** open the file, click *Done*, then **System Settings → Privacy & Security**,
scroll to *Security*, and click **Open Anyway**. On macOS 15 (Sequoia) and later, right-click →
*Open* no longer works as a bypass.

## The permission is switched on, but Phoenix says it is missing

Almost always this is the **wrong entry** being switched on.

Because these builds are unsigned, macOS identifies the app by a hash of that exact build. Every
version is a different app to it — so if you have installed Phoenix more than once, the Privacy
list holds several identical-looking **Phoenix** rows, all with blank icons, and the one you
enabled may belong to a copy you no longer run.

Clear them all and start clean:

```bash
tccutil reset ScreenCapture com.phoenix.app
tccutil reset Microphone com.phoenix.app
```

Then quit Phoenix completely (⌘Q), open it **from `/Applications`**, approve the prompts, and
**quit and reopen once more** — Screen Recording only applies after a relaunch.

Installing the `.pkg` does this for you automatically.

## I have to grant permissions again after every update

Expected, for the same reason: each build is a different app to macOS, so the previous version's
grants do not carry over and the old entry stays behind still switched on.

Enable the entry whose toggle is **off** and remove the leftovers with the **−** button. Only a
paid Apple Developer certificate can make permissions survive updates.

## I cannot hear the other person

Phoenix transcribes you but not the interviewer.

1. **Screen Recording** is what captures the other side's audio, not Microphone. Check it is
   granted — see above if it looks granted but is not.
2. **Quit and reopen** after granting. It does not take effect until then.
3. Check the **monitor icon** at the left of the command bar is not muted.

## The transcript is nonsense

**If the call is not in English:** switch the speech model to **v3** in Settings. The default is
English-only and maps whatever it hears onto English words.

**If music or background audio is playing:** it gets transcribed too. Mute the channel you are
not using with the monitor or microphone icon.

## Nothing is transcribed at all (Apple Silicon)

The speech engine needs a one-time setup that runs on first launch. If it was interrupted,
Settings → Speech engine has an install button, and the setup check will say so plainly.

It creates its own isolated Python environment and changes nothing else on your system.

## The overlay is off screen, or will not move

`⌘ ⌥ C` centres it.

If you unplugged a monitor, Phoenix only restores its old position when that position still
overlaps a connected display — otherwise it centres itself.

## The overlay appears in my screen share

Check **Private mode** is on in the **⋮** menu. It is on by default, and a banner appears
whenever it is off.

## Answers are slow

**On the local model:** expected. It runs entirely on your machine. Install the Claude Code CLI
for much faster answers on your existing subscription.

**On Claude:** the first answer of a session is slower than the rest, since it warms up. If every
answer is slow, check your connection.

## An update failed

Re-run the install script — it replaces the existing copy:

```bash
curl -fsSL https://raw.githubusercontent.com/mailtoharutyunyan/phoenix-releases/main/install.sh | bash
```

## Still stuck

Include your log when reporting a problem:

```bash
open ~/Library/Application\ Support/phoenix/logs/
```

`main.log` records what the app did. It contains no audio and, unless the session saved a
transcript, no conversation text.
