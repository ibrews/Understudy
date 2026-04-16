# Scripts

Helpers for generating bundled content.

## `parse_hamlet.py`

Turns the Project Gutenberg plaintext of Hamlet (eBook #1524, public domain) into the structured `Resources/hamlet.json` consumed by `PlayScript`. Run from anywhere:

```bash
curl -s "https://www.gutenberg.org/cache/epub/1524/pg1524.txt" -o /tmp/hamlet.txt
python3 scripts/parse_hamlet.py /tmp/hamlet.txt Understudy/Resources/hamlet.json
```

Output shape:
```json
{
  "title": "Hamlet, Prince of Denmark",
  "author": "William Shakespeare",
  "source": "Project Gutenberg eBook #1524 (public domain)",
  "acts": [
    {
      "number": 1, "roman": "I",
      "scenes": [
        {
          "number": 1, "roman": "I",
          "location": "Elsinore. A platform before the Castle.",
          "entries": [
            {"kind": "stage", "text": "Enter Francisco and Barnardo, two sentinels."},
            {"kind": "line", "character": "BARNARDO", "text": "Who's there?", "lineID": "1.1.1"}
          ]
        }
      ]
    }
  ]
}
```

## Adding more plays

Follow the same output shape. Drop the JSON into `Understudy/Resources/` and extend `Scripts.all` in `Shared/Script.swift`. The Script Browser UI will pick it up automatically.
