# The Bundled Plays

Understudy ships with **ten complete plays** built in. Open the Script Browser in Author mode and any line is one tap away.

All ten are public-domain texts from Project Gutenberg, restructured as JSON for runtime use. You don't need to type a single line of dialogue to author a working blocking — pick a play, pick a scene, drop the whole thing.

---

## The library

| Play | Author | Translation | Acts | Dialogue lines |
| ---- | ---- | ---- | ---- | ---- |
| **Hamlet** | William Shakespeare | (Folger / Project Gutenberg) | 5 | 1,108 |
| **Macbeth** | William Shakespeare | (Folger / PG) | 5 | 647 |
| **A Midsummer Night's Dream** | William Shakespeare | (Folger / PG) | 5 | 484 |
| **The Seagull** | Anton Chekhov | Constance Garnett | 4 | 627 |
| **The Cherry Orchard** | Anton Chekhov | Julius West | 4 | 643 |
| **Three Sisters** | Anton Chekhov | Julius West | 4 | 754 |
| **Uncle Vanya** | Anton Chekhov | Constance Garnett | 4 | 525 |
| **The Importance of Being Earnest** | Oscar Wilde | (PG) | 3 | 873 |
| **Salomé** | Oscar Wilde | Lord Alfred Douglas | 1 | 362 |
| **Ghosts** | Henrik Ibsen | William Archer | 3 | 1,123 |

That's **7,146 lines of dialogue** across three centuries of theatrical canon, ready to attach to your blockings.

---

## Why these ten

The selection isn't random. It's:

- **Foundational** — Shakespeare and Chekhov anchor most theatre training programs.
- **Rangey** — comedy (Wilde, Midsummer), tragedy (Macbeth, Ghosts), naturalism (Three Sisters), poetic-symbolic (Salomé). You can stress-test Understudy across very different rhythms.
- **Public domain** — all ten are out of copyright in every major jurisdiction. We can ship them with the app.
- **Translated where needed** — the Russian and Norwegian plays use translations that are themselves public domain (Garnett, West, Archer). We chose readable translations over scholarly ones.

---

## Picking lines

In Author mode, tap any mark → **Pick from script…** → the Script Browser opens.

Top of the dialog:
- **Play picker** — switch between all ten
- **Scene filter** — drill down to a specific Act / Scene
- **Search** — find any character's line by typing part of their name or a phrase

![Script Browser — play/scene pickers, search, line list with green ✓ on attached lines](https://raw.githubusercontent.com/ibrews/Understudy/main/Screenshots/author-script-browser.png)

Already-attached lines get a green ✓ on the right. Tap any other line to attach it.

---

## Drop Whole Scene — the killer feature

Each scene header in the Script Browser has a **Drop scene** chip. Tap it, and Understudy:

1. Walks every dialogue line in the scene
2. Buckets lines by speaker (one mark per speaker turn, max 4 lines per beat)
3. Auto-lays out a zig-zag path: 1.2 m forward spacing, 0.8 m alternating lateral offsets
4. Yaws each mark towards the next beat
5. Drops them all into your blocking with lines pre-populated

A 20-beat scene becomes a walkable 20-mark blocking in **under a second**.

This is how you go from "I want to rehearse Act I Scene I of Hamlet" to "we're rehearsing Act I Scene I of Hamlet" with no typing. Drop the scene, hit Perform, walk the path.

You can edit, drag, delete after the fact. The auto-layout is a starting point, not a final blocking.

---

## How the scripts are parsed

If you're curious about the engineering layer:

- Shakespeare uses **`scripts/parse_hamlet.py`** — handles SCENE-numbered format with line numbers, identifies speakers as ALL-CAPS lines on their own.
- Wilde and Chekhov use **`scripts/parse_modern.py`** — flexible ACT/SCENE detection, handles two speaker shapes (`CHARACTER.\n dialogue` like Wilde and `CHARACTER. dialogue` inline like Chekhov).
- Salomé uses **`scripts/parse_salome_html.py`** — Wilde's HTML edition has a different structure (`<p>CHARACTER</p><p>text</p>`) and needs HTML parsing.
- Ghosts uses the same modern parser, with stage directions tagged separately so they import as `.note` cues instead of `.line` cues.

All parsed JSON files live in `Understudy/Resources/` and ship as part of the app bundle. You can extend the library by:
1. Finding a public-domain text on Project Gutenberg
2. Running it through one of the parsers (or writing a new one)
3. Dropping the resulting JSON into `Resources/` and adding it to `Scripts.all` in `Script.swift`

---

## Adding your own play

There's no in-app "import script" feature yet (planned for v0.31). For now:

1. Get the text in a clean format (`.txt` from PG works).
2. Use one of the parsers in `scripts/` as a template.
3. Output to `Resources/yourplay.json` matching the existing JSON shape (`{"title": "...", "acts": [{"sceneIndex": 1, "lines": [{"kind": "line", "character": "NAME", "text": "..."}]}]}`).
4. Add `Script.PlayRef(id: "yourplay", title: "Your Play", asset: "yourplay")` to `Scripts.all`.
5. Rebuild — the new play appears in the picker.

We'd love to expand the library. If you parse something, send a PR.

---

## What's NOT bundled and why

- **Beckett** (Waiting for Godot, Endgame, Krapp's Last Tape) — still in copyright until 2059 in Europe.
- **O'Neill** (Long Day's Journey Into Night) — copyright is jurisdiction-specific; check before adding.
- **Tennessee Williams, Arthur Miller, August Wilson, Sarah Kane** — all in copyright.
- **Greek tragedy** — Sophocles, Euripides, Aeschylus would be public-domain, but the *translations* are not always. Most modern translations are still copyrighted.
- **Restoration / Restoration comedy** — Wycherley, Sheridan, Behn would all work; we just haven't parsed them yet.

If you want a play that's not in the public domain, you'll need to type or import the lines manually for now.

---

## Where to next

- **[Author's Guide § Script Browser](Author-Guide#the-script-browser)** — using the bundled plays in the editor.
- **[Quick Start](Quick-Start)** — the 90-second workflow, which uses Hamlet as the demo.
