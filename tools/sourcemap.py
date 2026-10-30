#!/usr/bin/env python3
"""Generate a Rojo-compatible sourcemap.json without needing the rojo binary.
Used by tools/check.sh so luau-lsp can type-check instance-based requires.
(If rojo is installed, `rojo sourcemap -o sourcemap.json` produces the same thing.)
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent

SERVICE_CLASSES = {
    "ReplicatedStorage", "ServerScriptService", "StarterPlayer", "Workspace",
    "ServerStorage", "StarterGui", "Lighting", "SoundService",
}


def script_class(name: str) -> str:
    if name.endswith(".server.luau"):
        return "Script"
    if name.endswith(".client.luau"):
        return "LocalScript"
    return "ModuleScript"


def strip(name: str) -> str:
    for suf in (".server.luau", ".client.luau", ".luau", ".lua"):
        if name.endswith(suf):
            return name[: -len(suf)]
    return name


def from_path(name: str, path: pathlib.Path) -> dict:
    rel = str(path.relative_to(ROOT))
    if path.is_file():
        return {"name": name, "className": script_class(path.name), "filePaths": [rel]}
    node = {"name": name, "className": "Folder", "children": []}
    init = path / "init.luau"
    if init.exists():
        node["className"] = "ModuleScript"
        node["filePaths"] = [str(init.relative_to(ROOT))]
    for p in sorted(path.iterdir()):
        if p.name == "init.luau":
            continue
        if p.is_dir() or p.suffix in (".luau", ".lua"):
            node["children"].append(from_path(strip(p.name), p))
    return node


def build(name: str, tree: dict) -> dict:
    if "$path" in tree:
        node = from_path(name, ROOT / tree["$path"])
    else:
        node = {"name": name, "className": tree.get("$className", "Folder"), "children": []}
    if name in SERVICE_CLASSES:
        node["className"] = name
    if name == "StarterPlayerScripts":
        node["className"] = "StarterPlayerScripts"
    for key, child in tree.items():
        if not key.startswith("$"):
            node.setdefault("children", []).append(build(key, child))
    return node


def main():
    project = json.loads((ROOT / "default.project.json").read_text())
    sm = build(project["name"], project["tree"])
    sm["className"] = "DataModel"
    (ROOT / "sourcemap.json").write_text(json.dumps(sm, indent=1))


if __name__ == "__main__":
    main()
