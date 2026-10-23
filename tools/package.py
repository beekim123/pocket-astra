#!/usr/bin/env python3
"""Package only authored text sources; never include engines, caches or media."""
from pathlib import Path
import hashlib
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ALLOWED = {".gd", ".gdshader", ".tscn", ".godot", ".md", ".sh", ".py", ".uid"}
DIRECTORIES = ("scenes", "scripts", "shaders", "tests", "tools", "docs")
files = [ROOT / "project.godot", ROOT / "README.md", ROOT / ".gitignore", ROOT / "AGENTS.md"]
for directory in DIRECTORIES:
    files.extend(p for p in (ROOT / directory).rglob("*") if p.is_file() and p.suffix in ALLOWED)
destination = ROOT / "dist" / "Lanternwake-Godot-4.7.2.zip"
destination.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for source in sorted(files):
        data = source.read_bytes()
        data.decode("utf-8")  # Reject any accidentally introduced binary asset.
        archive.writestr("Lanternwake/" + source.relative_to(ROOT).as_posix(), data)
with zipfile.ZipFile(destination) as archive:
    assert archive.testzip() is None
digest = hashlib.sha256(destination.read_bytes()).hexdigest()
(destination.parent / "SHA256SUMS.txt").write_text(f"{digest}  {destination.name}\n")
print(f"Packaged {len(files)} text files, {destination.stat().st_size:,} bytes: {destination}")
print("SHA256 " + digest)
