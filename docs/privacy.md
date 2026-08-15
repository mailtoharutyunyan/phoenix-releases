# Privacy

[← Back to the README](../README.md)

## What runs on your machine

- **Speech recognition** — always local, on every platform
- **Document search** — always local
- **The language model** — local if you choose it; the Claude backend sends questions to Anthropic

## What is stored, and where

Everything lives in Phoenix's own folder on your machine. There is no account, no server, and
nothing is uploaded anywhere.

| | |
|---|---|
| **Session details** | Company, role, resume, reference documents — kept so you can reuse them |
| **Answers** | Kept, so you can read them back after the call |
| **Transcript** | **Only if that session had "Save transcript" switched on** |
| **Audio** | **Never written to disk at all** |

Audio is transcribed in memory and discarded. It does not pass through a temporary file on its
way to the speech engine.

## Save transcript is off by default

A transcript contains **the other person's speech**. It is stored only when the session that
produced it had the option switched on, and that choice is made per session rather than once
globally.

With it off, the call still works exactly the same — answers are generated from what was said —
but nothing of the conversation is written to disk when the session ends.

You can tell which past sessions kept one: the transcript button is disabled on the ones that
did not, with a note saying so, rather than showing an empty screen.

## Clearing things

| | |
|---|---|
| `⌘ ⌫` | Clear the answers |
| `⌘ ⇧ ⌫` | Clear the transcript |
| `⌘ ⌥ ⌫` | **Full privacy reset** — clears everything and stops capture |
| Past Sessions | Delete any session with the trash button |

## The screen recording indicator

While a session is running, macOS shows a screen-recording indicator in your menu bar, and
clicking it says Phoenix is sharing.

**This is macOS being honest about what is happening, and no app can turn it off.** Phoenix
captures the other person's audio through the same system framework that screen sharing uses,
because that is the only way macOS exposes system audio to an app.

It appears on **your** menu bar, not the other person's. But if you share your entire screen,
your menu bar is part of what you share.

## What Phoenix uses the network for

- **Once:** downloading the speech model, and a language model if you use a local one. Cached to
  disk; it works offline afterwards
- **Per question, only if you use a cloud backend:** the question and its context
- **On launch:** an update check

There is no telemetry and no analytics.
