#!/usr/bin/env python3
"""Bundle the Rojo source tree + tests/*.spec.luau into one Luau file and run it with the
`luau` CLI. Lets us unit-test pure modules (Odds, FormatNumber, Fusion, ReceiptLedger, ...)
without Roblox Studio.

Usage: python3 tools/run_tests.py [path/to/luau]
"""
import json
import os
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUAU = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("LUAU", "luau")


def lua_str(s: str) -> str:
    # Long bracket string with a level that does not occur in the text.
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    eq = "=" * level
    return "[" + eq + "[\n" + s + "]" + eq + "]"


def collect(tree, inst_path, out):
    """Walk the Rojo project tree and map instance paths to source files."""
    for key, node in tree.items():
        if key.startswith("$"):
            continue
        child_path = inst_path + [key]
        if "$path" in node:
            base = ROOT / node["$path"]
            walk_dir(base, child_path, out)
        collect(node, child_path, out)


def walk_dir(path: pathlib.Path, inst_path, out):
    if path.is_file():
        out.append((inst_path, path))
        return
    out.append((inst_path, None))  # folder
    for p in sorted(path.iterdir()):
        if p.is_dir():
            walk_dir(p, inst_path + [p.name], out)
        elif p.suffix in (".luau", ".lua"):
            name = p.name
            for suf in (".server.luau", ".client.luau", ".luau", ".lua"):
                if name.endswith(suf):
                    name = name[: -len(suf)]
                    break
            if name == "init":
                out.append((inst_path, p))
            else:
                out.append((inst_path + [name], p))


def strip_export(src: str) -> str:
    lines = []
    for line in src.split("\n"):
        if line.startswith("export type "):
            line = line[len("export ") :]
        lines.append(line)
    return "\n".join(lines)


def build_bundle(specs, preludes=()):
    """specs: list of (name, source). preludes: extra Luau files loaded after the harness."""
    project = json.loads((ROOT / "default.project.json").read_text())
    entries = []
    collect(project["tree"], [], entries)

    parts = [(ROOT / "tests" / "harness.luau").read_text()]
    for pre in preludes:
        parts.append((ROOT / pre).read_text())
    for inst_path, src in entries:
        parts.append("__node(%s)" % json.dumps(inst_path).replace("[", "{").replace("]", "}"))
        if src is not None and not src.name.endswith((".server.luau", ".client.luau")):
            body = strip_export(src.read_text())
            parts.append(
                "__source(%s, function(script, require)\n%s\nend)"
                % (json.dumps(inst_path).replace("[", "{").replace("]", "}"), body)
            )
    for name, source in specs:
        parts.append(
            "__spec(%s, function(game, require)\n%s\nend)" % (json.dumps(name), strip_export(source))
        )
    parts.append("__run()")
    return "\n".join(parts)


def main():
    specs = [(p.name, p.read_text()) for p in sorted((ROOT / "tests").glob("*.spec.luau"))]
    build = ROOT / "build"
    build.mkdir(exist_ok=True)
    bundle = build / "tests.bundle.luau"
    bundle.write_text(build_bundle(specs))
    res = subprocess.run([LUAU, str(bundle)])
    sys.exit(res.returncode)


if __name__ == "__main__":
    main()
