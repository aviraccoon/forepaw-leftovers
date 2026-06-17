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
- One row per sample: a small black-on-white ground-truth label above a colored
  block containing the sample text in its fg color on its bg color.
- Each row has `accessibilityIdentifier("sample-N")` and an `accessibilityLabel`
  encoding `id=N fg=#rrggbb bg=#rrggbb ratio=X.XX:1`.

The color generation is biased toward realistic UI backgrounds (white, light
grays, dark surfaces) and a spread of foregrounds (grays across the full
luminance range plus some saturated colors), so the seed produces a mix of
passing and failing pairs rather than uniformly high-contrast noise. A good
trash pile has variety.
