# contrast-pairs

A seedable SwiftUI test app for verifying color-contrast recovery through a
real accessibility snapshot + screenshot pipeline. The raccoon's eye chart:
rows of text in known color pairs, left out to find out whether the sampler
reads them back right.

## What it does

Given a seed (env var `CONTRAST_SEED`, default `1`), deterministically generates
a set of text samples at known foreground/background colors and renders each
with a self-describing label. The label shows the sample id, fg hex, bg hex,
and the **ground-truth WCAG 2.x contrast ratio** computed from those exact
colors — so the screenshot and accessibility tree carry the answer key, taped
to the outside of each trash bag for whoever comes looking.

## Why it's useful

The pixel-sampling pipeline's correctness is only really testable through the
full real path (AX snapshot + screenshot + decode + per-element sampling),
because that path involves coordinate transforms (screen→window origin, Retina
2× downscale) and lossy encoding (PNG/webp) that a synthetic buffer can't
exercise. This app provides controlled, **known-answer** inputs through that
real path: a verifier reads the AX tree, samples each `sample-N` element's
pixels, and checks the recovered ratio against the `ratio=X.XX:1` in the
element's accessibility label. No guessing, no approximating — just pick
through it and confirm you got the right find.

## Running

**With mise** (preferred — from the repo root):

```bash
mise run //contrast-pairs:run                       # build + bundle + launch, default seed
CONTRAST_SEED=42 mise run //contrast-pairs:run     # launch with a specific seed
mise run //contrast-pairs:build                    # build only
```

**Without mise** (from this directory):

```bash
swift build
# Bundle as .app so the platform's app-activation APIs can target it.
mkdir -p .build/ContrastPairs.app/Contents/MacOS
cp .build/debug/ContrastPairs .build/ContrastPairs.app/Contents/MacOS/ContrastPairs
open .build/ContrastPairs.app

# Or with a specific seed:
CONTRAST_SEED=42 open .build/ContrastPairs.app
```

The `.app` bundle wrapper is required — unbundled CLI processes can't be
activated by `NSRunningApplication.activate()`.

## Layout

- Header (always black-on-white): app name + `seed = N`.
- Three-column layout, all visible without scrolling at default window size:

### Column 1: Random samples (seed-driven)

One row per sample: a small black-on-white ground-truth label above a colored
block containing the sample text in its fg color on its bg color.

### Column 2: Small elements

Same fg/bg pair (#333 on #eee, ~10.9:1) at font sizes 10, 12, 14, 16, 18, 20,
24, 30px. Heights are ~fontSize+10px (minimal padding), matching Finder's
column-view textfields. If the sampler gets <4.5:1 on these, it's a measurement
failure — the colors clearly pass.

### Column 3: Parent-child bounds + Vibrancy

**Parent-child**: Text "Sample text" at 13px inside a container. The container
has the background color; the text has no explicit background (inherits from
parent). Container heights: 18, 20, 23, 28, 36, 48px. This mimics Finder's
column view where the textfield is just the text rendering area and the parent
group paints the background.

**Vibrancy**: Text on a subtle gradient background (#f0f0f0 to #e8e8e8) that
creates ~10-15 quantized buckets, similar to macOS sidebar vibrancy. Tests the
diffuse threshold.

All three columns have `accessibilityIdentifier` and `accessibilityLabel`
carrying the ground-truth answer key, matching the original sample pattern.
