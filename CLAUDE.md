# CLAUDE.md - standing rules for every agent run on WRAITHSTEEL

## Before you write anything
1. Read `WRAITHSTEEL_AGENT_GUIDE.md` fully, especially §0 (originality + compliance), §8
   (architecture, Studio tree, hard rules, frozen contracts), §9 (agent roles), §11 (phases).
   If the guide is missing from the repo, say so and work from `HANDOFF.md`, which records the
   contracts as implemented.
2. Read `PROGRESS.md` and continue with the **next unchecked item** in the current phase.
   Read `HANDOFF.md` for open questions and known risks.

## Workflow
- One branch per run (cloud runs: the branch the run was assigned; otherwise `cloud/night-N`).
  Never push to `main` directly. Small logical commits. Open a PR at the end of the run.
- Cloud runs have **no Roblox Studio**: write Rojo-synced Luau only. Anything that needs Studio
  (maps, models, rigs, animations, UI layout, sounds, playtesting) gets a clear
  `TODO(Studio/Agent X): ...` and a placeholder id (`0` / `"rbxassetid://0"`) - never fake ids.
  Log every placeholder in `AssetLog.md`.
- Before committing run `./tools/check.sh` (luau-lsp type check + unit tests). Keep it clean.
- Update `PROGRESS.md` (check items off, add next steps/risks) and `HANDOFF.md` at the end.

## Hard rules
- **Original content only.** No names, characters, mechanics text, art or audio from any
  existing game. Genre inspiration only.
- **Server-authoritative everything.** Clients send requests; the server validates (types via
  `Shared/NetSchema` + `NetValidate`, rate limits, game rules in `Logic/*`) and decides.
- **All tunable numbers live in Config modules** (`src/config`, server-only ones in
  `src/server/ServerConfig`). No magic numbers in services.
- **Compliance:** no paid randomness without odds shown first. Odds UI and server rolls use the
  same function (`Shared/Odds` via `Shared/LanternOdds`). Paid random items and trading check
  `PolicyService`. No off-platform links anywhere.
- **Purchases:** `ProcessReceipt` stays idempotent (`Logic/ReceiptLedger` + save confirmation).
- `--!strict` where practical. Pure logic goes in `Logic/` or `Shared/` with tests in `tests/`.
- New remotes: add to `Shared/NetSchema` with arg types and a rate limit.
- New services/controllers: a ModuleScript in `Services/` or `Controllers/` with
  `Name`, `Priority`, `Init()`, `Start()`. Bootstrap picks it up automatically.
- Never change an existing field in `Shared/Types` (frozen); add new fields + a migration.
