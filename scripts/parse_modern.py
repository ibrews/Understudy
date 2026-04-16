#!/usr/bin/env python3
"""Parser for 19th/early-20th-century English-language plays from Project
Gutenberg that don't fit Shakespeare's format exactly.

Handles:
  - Act headings in any of: "ACT I", "ACT ONE", "FIRST ACT", "ACT I. Location"
  - Scene headings: optional. "SCENE I. Location" OR "SCENE" alone OR none at
    all (whole act becomes one scene).
  - Speaker lines: EITHER "CHARACTER." on its own line with dialogue on the
    following lines (Shakespeare, Wilde), OR "CHARACTER. dialogue text"
    inline on a single line (Chekhov, translated).
  - Stage directions: "[...]" or "_..._" or lines starting with
    "Enter"/"Exit"/"Exeunt"/"Re-enter".

Output matches `Understudy/Shared/Script.swift` PlayScript model — same JSON
shape as parse_hamlet.py's output, so Scripts.all can load plays from either.

Usage:
  curl -s <gutenberg-url> -o /tmp/play.txt
  python3 scripts/parse_modern.py /tmp/play.txt Understudy/Resources/play.json \\
      --title "The Seagull" --author "Anton Chekhov" --source "Project Gutenberg eBook #1754"
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROMAN = {"I":1,"II":2,"III":3,"IV":4,"V":5,"VI":6,"VII":7,"VIII":8,"IX":9,"X":10}
WORDS = {
    "ONE":"I","TWO":"II","THREE":"III","FOUR":"IV","FIVE":"V",
    "FIRST":"I","SECOND":"II","THIRD":"III","FOURTH":"IV","FIFTH":"V",
}

# "ACT I", "ACT ONE", "FIRST ACT", with optional ". Location".
# We accept either ordering since Wilde's Earnest uses "FIRST ACT"
# while Chekhov translations use "ACT I".
ACT_RE_A = re.compile(r"^\s*ACT\s+([IVX]+|ONE|TWO|THREE|FOUR|FIVE)\b\.?\s*(.*?)\s*$",
                      re.IGNORECASE)
ACT_RE_B = re.compile(r"^\s*(FIRST|SECOND|THIRD|FOURTH|FIFTH)\s+ACT\b\.?\s*(.*?)\s*$",
                      re.IGNORECASE)

# Scene: "SCENE I. Location" OR "SCENE" alone OR "SCENE: Location".
SCENE_RE = re.compile(r"^\s*SCENE\b\.?\s*([IVX]+)?\s*\.?\s*(.*?)\s*$",
                      re.IGNORECASE)

# Speaker on its own line: "ALGERNON.", "LADY BRACKNELL.", "FIRST WITCH."
SPEAKER_ONLY = re.compile(r"^([A-Z][A-Z0-9 ’'\-\.]{0,30}?)\.\s*$")

# Speaker + inline dialogue: "MEDVIEDENKO. Why do you always wear mourning?"
SPEAKER_INLINE = re.compile(r"^([A-Z][A-Z0-9 ’'\-]{0,30}?)\.\s+(.+)$")

STAGE_OPENERS = ("Enter ", "Exit ", "Exeunt", "Re-enter", "Re-Enter")


def roman_num(v: str) -> tuple[int, str]:
    """Normalize to (int, roman-string)."""
    u = v.upper()
    if u in WORDS:
        u = WORDS[u]
    if u in ROMAN:
        return (ROMAN[u], u)
    # Fallback — compute from chars.
    vals = {"I":1,"V":5,"X":10,"L":50}
    total = prev = 0
    for c in reversed(u):
        x = vals.get(c, 0)
        total = total - x if x < prev else total + x
        prev = x
    return (total or 1, u)


def is_probable_speaker(name: str) -> bool:
    """Avoid false positives like `A.` or `THE.` by requiring length + alpha."""
    stripped = name.strip()
    if len(stripped) < 2 or len(stripped) > 30:
        return False
    alphas = [c for c in stripped if c.isalpha()]
    return len(alphas) >= 2 and any(c.isupper() for c in alphas)


def parse(text: str, title: str, author: str, source: str) -> dict:
    body = text.replace("\r\n", "\n").replace("\r", "\n").lstrip("\ufeff")
    # Strip Gutenberg pre/post if present.
    m = re.search(r"\*\*\* ?START OF.*?\*\*\*", body)
    if m: body = body[m.end():]
    m = re.search(r"\*\*\* ?END OF", body)
    if m: body = body[:m.start()]

    lines = body.split("\n")
    # Trim everything before the first detected ACT (dramatis personae,
    # translator's preface, table-of-contents, etc.).
    # Real act headings are followed by many lines of content before the
    # next act heading; ToC entries are clustered tightly. Require:
    #   - NO other ACT heading within the next 50 lines, AND
    #   - at least one speaker-shaped line in the next 80 lines.
    for i, ln in enumerate(lines):
        if ACT_RE_A.match(ln) or ACT_RE_B.match(ln):
            lookahead = lines[i + 1:i + 51]
            other_act_hits = sum(1 for l in lookahead
                                 if ACT_RE_A.match(l) or ACT_RE_B.match(l))
            if other_act_hits > 0:
                continue
            content_window = lines[i + 1:i + 81]
            has_speaker = any(
                (SPEAKER_ONLY.match(l.strip()) and is_probable_speaker(SPEAKER_ONLY.match(l.strip()).group(1))) or
                (SPEAKER_INLINE.match(l.strip()) and is_probable_speaker(SPEAKER_INLINE.match(l.strip()).group(1)))
                for l in content_window if l.strip()
            )
            if has_speaker:
                lines = lines[i:]
                break

    acts = []
    current_act = None
    current_scene = None
    current_speaker = None
    dialogue_buffer: list[str] = []
    line_counter = 0

    def flush_speaker():
        nonlocal current_speaker, dialogue_buffer, line_counter
        if current_speaker and dialogue_buffer and current_scene is not None:
            text_block = " ".join(dialogue_buffer).strip()
            text_block = re.sub(r"\s+", " ", text_block)
            if text_block:
                line_counter += 1
                current_scene["entries"].append({
                    "kind": "line",
                    "character": current_speaker,
                    "text": text_block,
                    "lineID": f"{current_act['number']}.{current_scene['number']}.{line_counter}",
                })
        current_speaker = None
        dialogue_buffer = []

    def start_act(number: int, roman: str, location: str):
        nonlocal current_act, current_scene, line_counter
        flush_speaker()
        if current_act is not None:
            if current_scene is not None:
                current_act["scenes"].append(current_scene)
                current_scene = None
            acts.append(current_act)
        current_act = {"number": number, "roman": roman, "scenes": []}
        # Start with an implicit scene — may be replaced by an explicit SCENE
        # heading later (the implicit one just gets dropped if no entries
        # were added to it).
        current_scene = {
            "number": 1, "roman": "I", "location": location or "", "entries": []
        }
        line_counter = 0

    def start_explicit_scene(number: int, roman: str, location: str):
        nonlocal current_scene, line_counter
        flush_speaker()
        if current_act is None:
            return
        # If the current scene has NO entries, drop it (implicit placeholder).
        if current_scene is not None and not current_scene["entries"]:
            pass  # overwrite below
        elif current_scene is not None:
            current_act["scenes"].append(current_scene)
        current_scene = {
            "number": number, "roman": roman, "location": location or "", "entries": []
        }
        line_counter = 0

    for raw in lines:
        line = raw.rstrip()
        stripped = line.strip()
        if not stripped:
            flush_speaker()
            continue

        ma = ACT_RE_A.match(stripped) or ACT_RE_B.match(stripped)
        if ma:
            roman_raw = ma.group(1)
            location = (ma.group(2) or "").strip(" .")
            num, roman = roman_num(roman_raw)
            start_act(num, roman, location)
            continue

        # SCENE only inside an act.
        if current_act is not None:
            ms = SCENE_RE.match(stripped)
            # Avoid treating "SCENE" inside normal text (mid-paragraph)
            # as a heading — require it to be at column 0 after whitespace
            # AND not have dialogue before it on the same scene.
            if ms and len(stripped) < 80 and not any(c.islower() for c in stripped[:30]):
                roman_raw = ms.group(1) or str(len(current_act["scenes"]) + 1)
                location = (ms.group(2) or "").strip(" .")
                # If the "roman" is actually scene location text because the
                # scene is unnumbered, pass a fallback number.
                try:
                    num, roman = roman_num(roman_raw)
                except Exception:
                    num = len(current_act["scenes"]) + 1
                    roman = ["I","II","III","IV","V","VI","VII","VIII","IX","X"][min(num-1, 9)]
                    location = (ms.group(1) or location).strip(" .")
                start_explicit_scene(num, roman, location)
                continue

        if current_scene is None:
            continue

        # Stage directions.
        if stripped.startswith("[") and stripped.endswith("]"):
            flush_speaker()
            current_scene["entries"].append({
                "kind": "stage", "text": stripped.strip("[]")
            })
            continue
        if stripped.startswith("_") and stripped.endswith("_"):
            flush_speaker()
            current_scene["entries"].append({
                "kind": "stage", "text": stripped.strip("_")
            })
            continue
        if any(stripped.startswith(op) for op in STAGE_OPENERS):
            flush_speaker()
            current_scene["entries"].append({"kind": "stage", "text": stripped})
            continue

        # Speaker + inline dialogue — Chekhov style.
        mi = SPEAKER_INLINE.match(stripped)
        if mi and is_probable_speaker(mi.group(1)) and current_speaker is None:
            flush_speaker()
            current_speaker = mi.group(1).strip()
            dialogue_buffer.append(mi.group(2).strip())
            continue

        # Speaker only (own line) — Shakespeare / Wilde style.
        mo = SPEAKER_ONLY.match(stripped)
        if mo and is_probable_speaker(mo.group(1)):
            flush_speaker()
            current_speaker = mo.group(1).strip()
            continue

        # Otherwise: dialogue continuation for the active speaker.
        if current_speaker is not None:
            dialogue_buffer.append(stripped)

    # Flush the tail.
    flush_speaker()
    if current_scene is not None and current_act is not None:
        # Drop empty trailing scene.
        if current_scene["entries"]:
            current_act["scenes"].append(current_scene)
    if current_act is not None:
        acts.append(current_act)

    # Drop acts with no content at all.
    acts = [a for a in acts if a["scenes"]]

    script = {
        "title": title,
        "author": author,
        "source": source,
        "acts": acts,
    }

    # Stats for the console.
    n_lines = sum(1 for a in script["acts"] for s in a["scenes"]
                  for e in s["entries"] if e["kind"] == "line")
    n_stage = sum(1 for a in script["acts"] for s in a["scenes"]
                  for e in s["entries"] if e["kind"] == "stage")
    n_scenes = sum(len(a["scenes"]) for a in script["acts"])
    print(f"{title}: {len(script['acts'])} acts, {n_scenes} scenes, "
          f"{n_lines} lines, {n_stage} stage directions")
    return script


def main():
    p = argparse.ArgumentParser()
    p.add_argument("input")
    p.add_argument("output")
    p.add_argument("--title", required=True)
    p.add_argument("--author", required=True)
    p.add_argument("--source", default="Project Gutenberg (public domain)")
    args = p.parse_args()

    text = Path(args.input).read_text()
    script = parse(text, args.title, args.author, args.source)
    Path(args.output).write_text(json.dumps(script, ensure_ascii=False, indent=2))
    size_kb = Path(args.output).stat().st_size / 1024
    print(f"Wrote {args.output} ({size_kb:.1f} KB)")

    # Sample output for sanity.
    if script["acts"] and script["acts"][0]["scenes"]:
        first_scene = script["acts"][0]["scenes"][0]
        print("First 3 entries of Act I Scene I:")
        for e in first_scene["entries"][:3]:
            preview = e.get("text", "")[:80]
            if e["kind"] == "line":
                print(f"  {e['character']}: {preview}")
            else:
                print(f"  ({preview})")


if __name__ == "__main__":
    main()
