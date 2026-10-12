#!/usr/bin/env python3
"""Run after `omarchy-theme sync`: fails if upstream Omarchy changed in a way this port doesn't follow.

Checks that every theme resolves to the same palette as upstream's own
bin/omarchy-theme-color, and that every template we use renders completely.
"""
import importlib.machinery
import importlib.util
import json
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
loader = importlib.machinery.SourceFileLoader("ot", str(REPO / "bin/omarchy-theme"))
spec = importlib.util.spec_from_loader("ot", loader)
ot = importlib.util.module_from_spec(spec)
loader.exec_module(ot)

URL = "https://raw.githubusercontent.com/omacom/omarchy/master/bin/omarchy-theme-color"
failures = 0
with tempfile.TemporaryDirectory() as tmp:
    resolver = Path(tmp) / "omarchy-theme-color"
    resolver.write_bytes(urllib.request.urlopen(URL).read())
    resolver.chmod(0o755)
    for name, (d, _) in ot.all_themes().items():
        out = subprocess.run([str(resolver), "--file", str(d / "colors.toml"), "--all"],
                             capture_output=True, text=True).stdout
        upstream = dict(line.split("\t", 1) for line in out.splitlines())
        mine = ot.resolve(d)
        diff = {k for k in set(upstream) | set(mine) if (upstream.get(k) or "").lower() != (mine.get(k) or "").lower()}
        problems = [f"palette differs: {sorted(diff)}"] if diff else []
        for t in ("btop.theme.tpl", "vscode-theme.json.tpl", "chromium.theme.tpl", "ptyxis.palette.tpl",
                  "claude.json.tpl"):
            rendered = ot.template(t, {**mine, "title": name})
            if "{{" in rendered:
                problems.append(f"{t} left a placeholder")
        for t in ("vscode-theme.json.tpl", "claude.json.tpl"):
            try:
                json.loads(ot.template(t, mine))
            except ValueError as e:
                problems.append(f"{t} is not valid JSON: {e}")
        print(f"{'FAIL' if problems else 'ok  '} {name}" + "".join(f"\n       {p}" for p in problems))
        failures += bool(problems)

sys.exit(1 if failures else 0)
