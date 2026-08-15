# During a call

[← Back to the README](../README.md)

## The overlay

Three separate floating bars, not one panel — so the answer can grow and scroll while the
controls stay exactly where you last saw them. Buttons that move as text streams in are buttons
you cannot hit without looking.

```
┌──────────────────────────────────────────────────┐
│  the answer — scrolls, resizes, expands          │
└──────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────┐
│  live transcript — what was just heard           │
└──────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────┐
│  ▣ ●  Answer  Screenshot  Chat   ✥ ⤡ ⋮  ⏻ 10:36  │
└──────────────────────────────────────────────────┘
```

**The two icons on the left are per-channel mutes.** The monitor is the other person's audio,
the microphone is yours. Mute either without stopping the session — useful when someone walks
into the room, or during a break you do not want transcribed.

**The red clock is the stop button.** It arms before it fires: the first click shows "End?", the
second ends the session, and it disarms after four seconds. Ending mid-interview stops capture
and closes the session, so the most prominent control on the bar is not one stray click away
from doing that.

## Getting an answer

| | |
|---|---|
| **⌘↵** | Answer the last thing the interviewer said |
| **⌘⇧↵** | Screenshot the screen **and** answer what is on it |
| **⌘⌥↵** | Queue a screenshot without answering yet |
| **⌘⇧Space** | Open chat and type a question |

Answers are formatted to be spoken: the question is echoed first so you can confirm it heard the
right thing, then a short direct answer, then supporting points.

**Auto Answer**, if you turn it on, answers as soon as the interviewer stops speaking. It will
not fire while an answer is already streaming, and it stands down for five seconds after any
manual trigger, so you do not get duplicates.

**⌁ answers again with more thinking.** The fast answer always arrives first; one tap re-answers
the same question at higher effort when the first pass was too shallow.

You can **stop an answer mid-stream** — a long wrong answer is exactly what you want out of.

## Screenshots

**⌘H** captures the screen. **⌘⇧↵** captures and answers in one step — the usual way to handle
a coding question on a shared editor.

Screenshots go to a model chosen for vision rather than the one used for speech, because the
tradeoffs are different: a spoken answer needs to start fast, while a screenshot is already
slower and benefits from a stronger model.

## Staying out of the screen share

**Private mode is on by default.** The overlay is excluded from screen capture and screen
sharing at the OS level — it is on your screen but not in the share.

Turn it off only to capture the overlay itself, e.g. for a bug report. While it is off, a banner
says so plainly, because forgetting and then sharing your screen is the one failure this app
must not have.

Also on by default: the app is hidden from the Dock and from Mission Control, and it carries a
blank icon so it does not stand out in the screen-share picker.

**⌘T** makes the overlay click-through — the mouse passes straight through to whatever is behind
it, so you can keep it over your editor and still type.

## Reference documents

Documents you attach are searched per question and the relevant passages are supplied with it.
The search combines meaning-based and exact-term matching, so names, acronyms and API names are
not lost.

Your **resume is treated differently** — it is supplied in full rather than searched, because a
CV is short enough to fit whole and searching it drops the parts a vague question does not
match. Ask "tell me about yourself" and the answer walks your history forward in time, naming
every employer rather than the three that happened to match.
