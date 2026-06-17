# AGENTS.md

Small native test apps that expose known-answer inputs through the accessibility tree, for verifying accessibility and desktop-automation tooling through the real snapshot + screenshot path.

## Quick Reference

```bash
mise tasks --all                     # list every app's tasks (monorepo mode)
mise run //contrast-pairs:build      # build an app
mise run //contrast-pairs:run        # build + bundle + launch (default seed)
CONTRAST_SEED=42 mise run //contrast-pairs:run   # launch with a specific seed
```

If `swift build` fails with an SDK/compiler mismatch, set `SDKROOT`/`DEVELOPER_DIR` in a gitignored `mise.local.toml` at the repo root — see README.

## Key Paths

| Task | Location |
|------|----------|
| Add a new test app | new subdir with its own `README.md`, `mise.toml`, sources; register it in root `mise.toml` → `[monorepo].config_roots` |
| App build/run tasks | `<app>/mise.toml` |
| App source + ground-truth design | `<app>/Sources/...` and `<app>/README.md` |
| Shared tool/version config | root `mise.toml` |

## Project Context

Each app renders controlled inputs with the **ground-truth answer baked into the accessibility tree** (identifiers and labels), so a verifier reads the answer key out of the same snapshot it just took. This is the whole point: synthetic buffers prove the math; these apps prove the real path (coordinate transforms, Retina scaling, lossy encoding, real AX shape).

**forepaw** is the upstream tooling ecosystem this repo supports (public, on github). This repo is separate so the test apps stay independent of any specific consumer.

## Guidelines

- **Encode ground truth in the AX tree.** Use `accessibilityIdentifier` and `accessibilityLabel` so the answer survives snapshot capture. Use side files or pixel-position assumptions for nothing.
- **Show the active seed in the window** when an app is seedable, so it's visible in both screenshot and AX tree.
- **One self-contained app per subdirectory**, with its own `README.md` (what it exercises + manual build steps) and `mise.toml` (build/run/clean tasks).
- **Keep the committed task files generic.** Personal toolchain overrides (SDK paths, env) go in gitignored `mise.local.toml`, not in the app's `mise.toml`.
- **Register new apps in root `mise.toml`** under `[monorepo].config_roots` so `mise tasks --all` discovers them.
- **Keep it raccoon-inspired.** This repo's identity is the raccoon metaphor (leftovers, picking through trash, washing finds). App names, README prose, and descriptions should carry that voice. Keep it out of identifiers, code, and task names — those stay parseable — but let the human-facing writing have personality.
- **Prefer mise for orchestration.** The monorepo task syntax (`//app:task`) is the primary entry point. Document both the mise command and the raw underlying command (e.g. `swift build`) in each app's README, so the app is usable with or without mise.
- **Privacy: name only public projects.** Reference `forepaw` freely as ecosystem context. Never reference private companion projects, journals, or personal paths in committed files.
