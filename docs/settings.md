# Settings

[← Back to the README](../README.md)

## Which AI answers

Phoenix can use your **Claude subscription** or a **model running on your own machine**.

### Claude Code CLI — the default

Uses the `claude` command-line tool, so it runs on your existing Claude subscription. **No API
key, no separate billing.** Install it once and Phoenix finds it automatically.

If it is not installed, or you hit your usage limit, Phoenix **falls back to the local model on
its own** — mid-call, without asking. You get a slower answer rather than no answer.

Spoken questions default to **Sonnet**. That is a measured choice, not a guess: time-to-first-token
matters more than anything else when someone has just finished asking you a question, and Sonnet
starts roughly twice as fast as Haiku on this kind of prompt. Screenshots use a stronger model,
because that path is already slower and a coding question on screen is what benefits most.

### Local model

Runs entirely on your machine — no account, no network, nothing leaves the device. Downloads
once (3–5 GB) and works offline afterwards.

Slower to answer than the cloud, and wants 16 GB of memory. On Apple Silicon there is a faster
local backend available if you have Python.

**Phoenix always keeps a local path available.** No feature is cloud-only.

## Speech recognition

Runs on your machine either way.

On Apple Silicon it uses **Parakeet**, which comes in two versions:

| Model | Use it for |
|---|---|
| **v2** (default) | English calls. More accurate on technical vocabulary |
| **v3** | Calls in any other language |

The difference is real and worth knowing: asked about a database, v2 heard *"Postgres"* where v3
heard *"posters"*. Keep v2 for English interviews, switch to v3 for a call in another language.

**v2 discards audio it is not confident about.** It can only output English, so non-English
speech would otherwise come out as convincing-looking nonsense — Armenian singing produced
*"it's bars for men who should"*. Anything the model was guessing at is now dropped instead of
reaching your transcript. This never applies to v3, since choosing v3 means you *want*
non-English speech.

On Windows, Linux and Intel Macs, a local Whisper model is used instead.

## Staying hidden

| Setting | Default | What it does |
|---|---|---|
| **Private mode** | **On** | Excludes the overlay from screen capture and sharing |
| **Auto-hide on share** | On | Hides the overlay when a screen share starts |
| **Auto-detect meetings** | On | Offers to start a session when a call begins — always offers, never starts by itself |

Private mode is the important one. Turn it off only to capture the overlay itself; a banner
appears while it is off.

## Answers

**Auto Answer** answers as soon as the interviewer stops speaking, instead of waiting for ⌘↵.
Useful in a fast conversation, distracting in a slow one.

**Persona** shapes the register of answers. In System Design mode the session's own method takes
precedence, so the two cannot contradict each other.
