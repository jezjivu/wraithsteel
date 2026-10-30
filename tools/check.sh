#!/usr/bin/env bash
# Type-check every Luau file with luau-lsp + Roblox definitions, then run pure unit tests.
# Needs: luau-lsp, luau (CLI), a Roblox globalTypes.d.luau (from the luau-lsp repo).
#   TOOLS=/path/to/dir/with/binaries ./tools/check.sh
set -euo pipefail
cd "$(dirname "$0")/.."
TOOLS="${TOOLS:-}"
LSP="${TOOLS:+$TOOLS/}luau-lsp"
LUAU="${TOOLS:+$TOOLS/}luau"
DEFS="${DEFS:-${TOOLS:+$TOOLS/}globalTypes.d.luau}"

python3 tools/sourcemap.py
echo "== luau-lsp analyze"
"$LSP" analyze --definitions="$DEFS" --sourcemap=sourcemap.json \
	--ignore="src/server/Packages/**" --flag:LuauSolverV2=false src
echo "== unit tests"
python3 tools/run_tests.py "$LUAU"
