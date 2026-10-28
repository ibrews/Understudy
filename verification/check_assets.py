import json
from pathlib import Path

assets = Path('android/app/src/main/assets')
files = sorted(assets.glob('*.json'))
samples = sorted(assets.glob('sample-*.json'))
assert len(samples) == 11
for path in files:
    script = json.loads(path.read_text())
    lines = [entry for act in script['acts'] for scene in act['scenes']
             for entry in scene['entries'] if entry['kind'] == 'line']
    assert lines, path
    assert all(line['text'].strip() and line['character'].strip() for line in lines), path
    ids = [line['lineID'] for line in lines]
    assert len(ids) == len(set(ids)), path
print(f'PASS: {len(files)} assets, {len(samples)} original samples; nonempty dialogue/speakers and unique IDs')
demo = json.loads((assets / 'sample-aura-walkthrough.json').read_text())
words = sum(len(entry['text'].split()) for act in demo['acts'] for scene in act['scenes']
            for entry in scene['entries'] if entry['kind'] == 'line')
print(f'Demo walkthrough: {words} words, {words / 130:.2f} minutes at 130 words/minute before pauses')
