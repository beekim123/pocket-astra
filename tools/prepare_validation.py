#!/usr/bin/env python3
"""Copy source into a disposable project with a separate Godot user-data namespace.

All tests and screenshot captures should use this project. Even an accidental
call to the normal save method cannot overwrite the player's real adventure.
"""
from pathlib import Path
import re
import shutil
import tempfile

SOURCE = Path(__file__).resolve().parents[1]
target = Path(tempfile.mkdtemp(prefix="lanternwake-validation-"))
for directory in ("scripts", "scenes", "shaders", "tests", "tools", "docs"):
    shutil.copytree(SOURCE / directory, target / directory,
                    ignore=shutil.ignore_patterns("__pycache__", "*.pyc", ".DS_Store"))
for filename in ("README.md", "AGENTS.md", ".gitignore"):
    shutil.copy2(SOURCE / filename, target / filename)
config = (SOURCE / "project.godot").read_text()
namespace = "LanternwakeValidation/" + target.name
config, matches = re.subn(r'^config/custom_user_dir_name=.*$',
                         'config/custom_user_dir_name="' + namespace + '"',
                         config, flags=re.MULTILINE)
if matches != 1 or 'config/use_custom_user_dir=true' not in config:
    raise RuntimeError("Expected one explicit custom user-data setting; refusing unsafe validation")
(target / "project.godot").write_text(config)
print(target)
