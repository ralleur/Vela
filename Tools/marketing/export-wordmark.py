#!/usr/bin/env python3
"""Regenerate kurtz vectors and brand assets from the checked-in brand source."""
from pathlib import Path
import subprocess
ROOT = Path(__file__).resolve().parents[2]
subprocess.run(["node", str(ROOT / "Tools/marketing/build-kurtz-brand.cjs")], check=True, cwd=ROOT)
