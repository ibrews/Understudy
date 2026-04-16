#!/usr/bin/env python3
"""Parse the Project Gutenberg Hamlet plaintext into a structured JSON
scripty format Understudy can load at runtime.

Output shape:
{
  "title": "Hamlet, Prince of Denmark",
  "author": "William Shakespeare",
  "acts": [
    {
      "number": 1,
      "roman": "I",
      "scenes": [
        {
          "number": 1,
          "roman": "I",
          "location": "Elsinore. A platform before the Castle.",
          "entries": [
            {"kind": "stage", "text": "Enter Francisco and Barnardo, two sentinels."},
            {"kind": "line", "character": "BARNARDO", "text": "Who’s there?", "lineID": "1.1.1"},
            ...
          ]
        }
      ]
    }
  ]
}
"""
import json
import re
import sys
from pathlib import Path

src = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/hamlet.txt").read_text()

# Strip the Gutenberg preamble + postamble.
start = src.find("*** START OF THE PROJECT GUTENBERG EBOOK")
end = src.find("*** END OF THE PROJECT GUTENBERG EBOOK")
body = src[src.find("\n", start) + 1:end] if start != -1 and end != -1 else src

# Normalize line endings and strip BOM.
body = body.replace("\r\n", "\n").replace("\r", "\n").lstrip("\ufeff")

lines = body.split("\n")

# Find the first ACT I that is actually followed by a SCENE I within 20 lines —
# the dramatis personae block lists "ACT I", "ACT II", etc. as bare headers
# without any SCENE underneath, so we skip those.
start_idx = 0
for i, ln in enumerate(lines):
    if re.match(r"^\s*ACT I\b", ln.strip()):
        # Peek ahead for a SCENE heading.
        look = "\n".join(lines[i + 1:i + 25])
        if re.search(r"^\s*SCENE\s+I\b", look, re.MULTILINE):
            start_idx = i
            break
lines = lines[start_idx:]

ACT_RE = re.compile(r"^\s*ACT\s+([IVX]+)\b\s*\.?\s*$")
SCENE_RE = re.compile(r"^\s*SCENE\s+([IVX]+)\s*\.\s*(.*?)\s*$")
SPEAKER_RE = re.compile(r"^([A-Z][A-Z ’'\-]+?)\.\s*$")


def roman_to_int(roman):
    vals = {"I": 1, "V": 5, "X": 10, "L": 50}
    total = 0
    prev = 0
    for c in reversed(roman):
        v = vals.get(c, 0)
        total = total - v if v < prev else total + v
        prev = v
    return total


script = {
    "title": "Hamlet, Prince of Denmark",
    "author": "William Shakespeare",
    "source": "Project Gutenberg eBook #1524 (public domain)",
    "acts": [],
}

act = None
scene = None
current_speaker = None
dialogue_buffer = []
line_counter = 0  # global line index within the scene


def flush_dialogue():
    global line_counter, current_speaker, dialogue_buffer
    if current_speaker is None or not dialogue_buffer:
        current_speaker = None
        dialogue_buffer = []
        return
    text = " ".join(dialogue_buffer).strip()
    # Normalize internal whitespace.
    text = re.sub(r"\s+", " ", text)
    if not text:
        current_speaker = None
        dialogue_buffer = []
        return
    line_counter += 1
    scene["entries"].append({
        "kind": "line",
        "character": current_speaker,
        "text": text,
        "lineID": f"{act['number']}.{scene['number']}.{line_counter}",
    })
    current_speaker = None
    dialogue_buffer = []


for raw in lines:
    line = raw.rstrip()
    stripped = line.strip()

    if not stripped:
        # Blank line — end of a dialogue block.
        if current_speaker is not None:
            flush_dialogue()
        continue

    m = ACT_RE.match(stripped)
    if m:
        flush_dialogue()
        if act is not None and scene is not None:
            act["scenes"].append(scene)
            scene = None
        if act is not None:
            script["acts"].append(act)
        roman = m.group(1)
        act = {"number": roman_to_int(roman), "roman": roman, "scenes": []}
        continue

    m = SCENE_RE.match(stripped)
    if m and act is not None:
        flush_dialogue()
        if scene is not None:
            act["scenes"].append(scene)
        roman = m.group(1)
        location = m.group(2).strip().rstrip(".")
        scene = {
            "number": roman_to_int(roman),
            "roman": roman,
            "location": location,
            "entries": [],
        }
        line_counter = 0
        continue

    # Stage directions: either wrapped in brackets, or the classic
    # "Enter ..." / "Exit ..." / "Exeunt ..." opener.
    if scene is not None:
        if (stripped.startswith("[") and stripped.endswith("]")) or \
           stripped.startswith("_") or \
           re.match(r"^(Enter|Exit|Exeunt|Re-enter|Scene)\b", stripped):
            flush_dialogue()
            text = stripped.strip("[]_")
            scene["entries"].append({"kind": "stage", "text": text})
            continue

        m = SPEAKER_RE.match(stripped)
        # A speaker name is short (<= ~30 chars), uppercase, and followed
        # by dialogue on a new line.
        if m and len(stripped) <= 32 and "." in stripped:
            flush_dialogue()
            current_speaker = m.group(1).strip()
            continue

        # Otherwise it's dialogue (or more stage direction in-line).
        if current_speaker is not None:
            dialogue_buffer.append(stripped)
        # else: pre-scene noise, skip

# Flush tail
flush_dialogue()
if scene is not None and act is not None:
    act["scenes"].append(scene)
if act is not None:
    script["acts"].append(act)

# Sanity stats
n_lines = sum(
    1
    for a in script["acts"]
    for s in a["scenes"]
    for e in s["entries"]
    if e["kind"] == "line"
)
n_stages = sum(
    1
    for a in script["acts"]
    for s in a["scenes"]
    for e in s["entries"]
    if e["kind"] == "stage"
)
print(f"acts={len(script['acts'])}, "
      f"scenes={sum(len(a['scenes']) for a in script['acts'])}, "
      f"lines={n_lines}, stage_directions={n_stages}")

# Preview a sample
first_act = script["acts"][0]
first_scene = first_act["scenes"][0]
print("Act I Scene I first 4 entries:")
for e in first_scene["entries"][:4]:
    print(" ", e)

out = sys.argv[2] if len(sys.argv) > 2 else "/tmp/hamlet.json"
Path(out).write_text(json.dumps(script, ensure_ascii=False, indent=2))
print("wrote", out, f"({Path(out).stat().st_size / 1024:.1f} KB)")
