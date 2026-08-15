# Getting started

[← Back to the README](../README.md)

## 1. Permissions

Phoenix needs two permissions, both under **System Settings → Privacy & Security**:

| Permission | What it is for |
|---|---|
| **Microphone** | Your side of the call |
| **Screen & System Audio Recording** | The other person's audio, and screenshots |

It will ask for these the first time you start a session, and offers a button that takes you
straight to the right pane.

Two things that catch people out:

- **Phoenix has a blank icon on purpose**, so it is inconspicuous in this list and in the
  screen-share picker. Look for the entry named **Phoenix**.
- **Screen Recording only takes effect after a relaunch.** Grant it, then quit Phoenix
  completely (⌘Q — not just closing the window) and open it again.

Without Screen Recording you will still be transcribed, but the interviewer will not be — so
answers will have no question to work from.

## 2. Create a session

Every answer is grounded in a **session**, so there is no "just start answering" mode. Without
the company and the role, the assistant has nothing to specialise on and gives generic answers.

| Field | Why it matters |
|---|---|
| **Company** | Lets answers reference the company's actual domain |
| **Job description** | The strongest single input — paste the whole posting |
| **Resume** | Goes to the model **in full**, so it can answer "tell me about yourself" from your real history |
| **Reference documents** | Notes, past designs, a study guide. Searched per question |
| **Language** | The spoken language of the call |
| **Save transcript** | Off by default. See [Privacy](privacy.md) |

You can reuse a past session's details for a new call — it copies the setup, it does not resume
the old conversation.

## 3. Pick the mode

The mode changes how answers are shaped, and it matters more than it looks.

### Technical

A normal engineering interview. Answers lead with the direct response, then support it — the
format is built to be **spoken**, not read out.

### HR Screen

A recruiter call, usually with someone who is not an engineer. Answers lead with impact in plain
language, and the mode is specifically shaped around what loses offers at this stage: never
volunteering a salary number, never criticising a current employer, and not inventing a notice
period or start date.

### System Design

Answers come with a **diagram drawn beside them**, as a separate request so the words you speak
never wait for the picture.

The diagram is deliberately staged: a **core of 5–7 boxes** for the happy path, with everything
else held back, drawn dimmed and dashed, and labelled *say it, draw if asked*. Reproducing an
18-box architecture in minute three spends the clock and reads as recited.

Every box explains itself on hover, and the main request path is numbered so you can narrate it
in order. There is also a **phase coach** showing where you should be against the clock —
requirements, entities and API, high-level design, then deep dives — because the usual failure
in this round is spending twenty minutes on the high-level design and never reaching a deep dive.

## 4. During the call

See **[During a call](during-a-call.md)** for the overlay itself, and
**[Keyboard shortcuts](shortcuts.md)** for the full list.

The essentials:

- **⌘↵** — answer the last thing the interviewer said
- **⌘⇧↵** — screenshot the screen and answer what is on it
- **⌘⇧Space** — type a question instead of speaking it
- **⌘B** — hide and show the overlay

## 5. After the call

Ending a session releases the local engines, which is worth knowing if you ran a model
locally — those hold several gigabytes of weights while a call is live.

**Past Sessions** keeps what each call produced: the answers, and for System Design every
version of the architecture in order, so you can read back what you actually proposed.
