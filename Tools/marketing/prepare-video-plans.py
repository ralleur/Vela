#!/usr/bin/env python3
"""Validate the current editable Shorts plans without replacing manual edits."""
from pathlib import Path
import json
root = Path(__file__).resolve().parents[2]
plans = root / 'marketing/video/shorts/kurtz-curated-v2'
series = json.loads((plans / 'series.json').read_text())
for item in series:
    assert json.loads((plans / (item['id'] + '.json')).read_text()) == item
print(f'{len(series)} current kurtz plans agree with their per-edit source files.')
