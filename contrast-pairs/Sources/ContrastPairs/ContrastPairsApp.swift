import SwiftUI

// MARK: - Seeded PRNG (SplitMix64)

/// Deterministic 64-bit generator so a given seed reproduces the same layout.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Golden-ratio offset so small seeds still avalanche.
        state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_1EB
        return z ^ (z >> 31)
    }
}

// MARK: - WCAG ratio (ground truth, computed in-app)

/// sRGB channel linearization per the WCAG 2.x relative-luminance definition.
func linearize(_ channel: UInt8) -> Double {
    let v = Double(channel) / 255.0
    return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
}

func relativeLuminance(_ rgb: RGB) -> Double {
    0.2126 * linearize(rgb.r) + 0.7152 * linearize(rgb.g) + 0.0722 * linearize(rgb.b)
}

/// WCAG 2.x contrast ratio, symmetric, 1.0...21.0.
func contrastRatio(_ a: RGB, _ b: RGB) -> Double {
    let la = relativeLuminance(a)
    let lb = relativeLuminance(b)
    let hi = max(la, lb)
    let lo = min(la, lb)
    return (hi + 0.05) / (lo + 0.05)
}

// MARK: - Model

struct RGB: Hashable {
    let r: UInt8
    let g: UInt8
    let b: UInt8

    var color: Color {
        Color(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    /// `#rrggbb` hex, matching the format accessibility tools exchange.
    var hex: String {
        String(format: "#%02x%02x%02x", r, g, b)
    }
}

struct ContrastSample: Identifiable {
    let id: Int
    let text: String
    let fg: RGB
    let bg: RGB
    let fontSize: Double
    let bold: Bool

    /// Ground-truth WCAG ratio, computed from the exact fg/bg.
    var ratio: Double { contrastRatio(fg, bg) }
}

/// Generate `count` samples from `seed`, biased toward realistic UI colors so
/// the spread includes failing (<4.5) pairs rather than uniformly high-contrast
/// noise (random RGB pairs are almost always >10:1 and boring).
func samples(seed: UInt64, count: Int) -> [ContrastSample] {
    var rng = SeededGenerator(seed: seed)
    // Backgrounds: a realistic mix of light and dark surfaces.
    let bgs: [RGB] = [
        RGB(r: 255, g: 255, b: 255),   // white
        RGB(r: 238, g: 238, b: 238),   // #eee light gray
        RGB(r: 221, g: 221, b: 221),   // #ddd
        RGB(r: 245, g: 245, b: 248),   // near-white panel
        RGB(r: 34, g: 34, b: 34),      // #222 dark
        RGB(r: 30, g: 30, b: 30),      // near-black
        RGB(r: 43, g: 45, b: 54),      // dark slate
    ]
    let words = ["Sample", "Read me", "Submit", "Cancel", "Hello", "Settings",
                 "Profile", "Search", "Done", "Next", "Back", "Save",
                 "Delete", "Edit", "Share", "Open"]

    return (0..<count).map { i in
        let bg = bgs.randomElement(using: &rng)!
        // Foreground: a random gray spanning the full luminance range, plus a
        // few saturated colors, so some pairs land in the failing zone.
        let useGray = Bool.random(using: &rng)
        let fg: RGB
        if useGray {
            let g = UInt8.random(in: 0...255, using: &rng)
            fg = RGB(r: g, g: g, b: g)
        } else {
            fg = RGB(
                r: UInt8.random(in: 0...255, using: &rng),
                g: UInt8.random(in: 0...255, using: &rng),
                b: UInt8.random(in: 0...255, using: &rng)
            )
        }
        let fontSize = [12.0, 14.0, 16.0, 18.0, 24.0].randomElement(using: &rng)!
        let bold = Bool.random(using: &rng)
        let text = words.randomElement(using: &rng)!
        return ContrastSample(id: i, text: text, fg: fg, bg: bg,
                              fontSize: fontSize, bold: bold)
    }
}

// MARK: - App

@main
struct ContrastPairsApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        ProcessInfo.processInfo.disableAutomaticTermination("test app")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 760, height: 720)
    }
}

// MARK: - Content

struct ContentView: View {
    /// Seed from `CONTRAST_SEED` env var; defaults to 1. Shown in the header so
    /// the active seed is visible in both screenshot and accessibility tree.
    private let seed: UInt64
    private let sampleCount = 12
    private let allSamples: [ContrastSample]

    init() {
        let envSeed = ProcessInfo.processInfo.environment["CONTRAST_SEED"]
        self.seed = UInt64(envSeed ?? "1") ?? 1
        self.allSamples = samples(seed: seed, count: sampleCount)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header: always high-contrast so the seed is readable regardless
            // of the generated samples below.
            HStack {
                Text("contrast-pairs")
                    .font(.headline)
                Spacer()
                Text("seed = \(seed)")
                    .font(.system(.body, design: .monospaced))
            }
            .padding(12)
            .background(Color.white)
            .foregroundColor(.black)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(allSamples) { sample in
                        SampleRow(sample: sample)
                    }
                }
                .padding(12)
            }
        }
        .background(Color.black.opacity(0.05))
    }
}

struct SampleRow: View {
    let sample: ContrastSample

    var body: some View {
        // Ground-truth label: always black on white so it never becomes a
        // contrast victim itself, and so it carries the answer key.
        let label = String(format: "id=%d  fg=%@  bg=%@  ratio=%.2f:1",
                           sample.id, sample.fg.hex, sample.bg.hex, sample.ratio)
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white)
                .foregroundColor(.black)
                .accessibilityIdentifier("sample-\(sample.id)-label")
                .accessibilityLabel(label)

            // The actual contrast target: colored text on the colored bg.
            // This is its own AX element (do NOT combine with the label) so the
            // sampler gets its bounds to sample pixels from.
            Text(sample.text)
                .font(.system(size: sample.fontSize, weight: sample.bold ? .bold : .regular))
                .foregroundColor(sample.fg.color)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(sample.bg.color)
                .accessibilityIdentifier("sample-\(sample.id)")
                .accessibilityLabel("\(sample.text) — fg=\(sample.fg.hex) bg=\(sample.bg.hex)")
        }
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.gray.opacity(0.3)))
    }
}
