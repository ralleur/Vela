#!/usr/bin/env python3
"""Render the six current kurtz Shorts. Pass C01…C06 to select edits."""
from pathlib import Path
import subprocess, sys
root = Path(__file__).resolve().parents[2]
subprocess.run([sys.executable, str(root / 'marketing/video/shorts/kurtz-curated-v2/source/render.py'), *sys.argv[1:]], check=True)
