# forepaw-leftovers

A raccoon's leftovers, picked over for testing. Small native apps that let accessibility and desktop-automation tooling verify itself against controlled, known-answer inputs — the digital equivalent of leaving out exactly the right trash so you can check whether the raccoon took the right thing.

Named after a raccoon's habit of inspecting, re-inspecting, and occasionally washing its finds: every app here is something to poke at, measure, and confirm you got the right answer.

## What is this?

Some behaviors only reveal themselves through the full real path — a real accessibility snapshot, a real screenshot capture, real coordinate transforms, real lossy encoding. A synthetic buffer or a mocked API can't exercise them, which means a test failure can hide in the gap between "the math is right" and "it actually works on a real app."

These apps close that gap. Each one renders controlled inputs with the ground-truth answer baked into the accessibility tree (identifiers, labels), so a verifier can read the answer key back out of the same snapshot it just took, and check its recovered values against the known ones.

forepaw-leftovers is the trash. The raccoon is whatever you're testing.

## Apps

| App | Platform | Exercises |
|-----|----------|-----------|
| [`contrast-pairs`](contrast-pairs/) | macOS (SwiftUI) | Color-contrast recovery through a real accessibility snapshot + screenshot pipeline |

More to come as more behaviors need pinning down.

## Building

[mise](https://mise.jdx.dev) orchestrates builds across the apps (monorepo mode). Each app owns its own tasks; run any app's task from the repo root with the `//app:task` syntax.

```bash
# List every app's tasks
mise tasks --all

# Build the contrast-pairs app
mise run //contrast-pairs:build

# Build, bundle as .app, and launch it (default seed)
mise run //contrast-pairs:run

# Launch with a specific seed
CONTRAST_SEED=42 mise run //contrast-pairs:run
```

If `swift build` fails with an SDK/compiler mismatch, your local Swift toolchain may need `SDKROOT`/`DEVELOPER_DIR` set explicitly. Put that in a gitignored `mise.local.toml` at the repo root:

```toml
[env]
SDKROOT = ""
DEVELOPER_DIR = "/path/to/Xcode.app/Contents/Developer"
```

Each app's own `README.md` has the manual (non-mise) build steps and what the app exercises.

## Conventions

- One self-contained app per subdirectory, each with its own `README.md` and build instructions.
- Apps that encode ground truth expose it through the accessibility tree so it survives snapshot capture — not via a side file, not via pixel-position assumptions.
- Default seeds (where an app is randomized) are shown in the window so they're visible in both screenshot and tree.

## License

[Unlicense](LICENSE) — public domain. Pick through it, wash it, take it home.
