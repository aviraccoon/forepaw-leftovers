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

/// Fixed color pair for the small-elements section: a moderate-contrast pair
/// that clearly passes 4.5:1 (black on white = 21:1) so any measurement
/// failure is the sampler's fault, not the colors.
private let smallElementFG = RGB(r: 0x33, g: 0x33, b: 0x33)  // #333
private let smallElementBG = RGB(r: 0xEE, g: 0xEE, b: 0xEE)  // #eee
private let smallElementRatio = contrastRatio(smallElementFG, smallElementBG)

/// Font sizes that exercise the small-element boundary. Finder's column-view
/// textfields are 18px tall; sidebar statictext is ~18-21px. The sizes below
/// 24px are the danger zone where pixel sampling struggles.
private let smallElementSizes: [Double] = [10, 12, 14, 16, 18, 20, 24, 30]

/// Container heights for the parent-child section. The text is always 13px
/// (like Finder sidebar); the container varies. When the container is small,
/// the text fills most of the rect and bg detection fails.
private let parentChildContainerHeights: [Double] = [18, 20, 23, 28, 36, 48]

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
        .defaultSize(width: 1100, height: 850)
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

            // Three-column layout: original pairs | small elements | parent-child + vibrancy
            ScrollView {
                HStack(alignment: .top, spacing: 16) {
                    // Column 1: original random samples
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(allSamples) { sample in
                            SampleRow(sample: sample)
                        }
                    }

                    // Column 2: small elements
                    LazyVStack(alignment: .leading, spacing: 6) {
                        SectionDivider(title: "small elements",
                                       note: "fg=\(smallElementFG.hex) bg=\(smallElementBG.hex) ratio=\(String(format: "%.1f", smallElementRatio)):1")

                        ForEach(smallElementSizes, id: \.self) { size in
                            SmallElementRow(fontSize: size,
                                            fg: smallElementFG, bg: smallElementBG,
                                            ratio: smallElementRatio)
                        }
                    }

                    // Column 3: parent-child + vibrancy
                    VStack(alignment: .leading, spacing: 6) {
                        SectionDivider(title: "parent-child bounds",
                                       note: "text 13px, container h varies")

                        ForEach(parentChildContainerHeights, id: \.self) { h in
                            ParentChildRow(containerHeight: h,
                                           fg: smallElementFG, bg: smallElementBG,
                                           ratio: smallElementRatio)
                        }

                        SectionDivider(title: "vibrancy-like bg",
                                       note: "subtle gradient, 13px")

                        VibrancyRow(text: "Sidebar item", fg: smallElementFG)
                        VibrancyRow(text: "Favorites", fg: RGB(r: 0x55, g: 0x55, b: 0x55))
                        VibrancyRow(text: "Locations", fg: RGB(r: 0x88, g: 0x88, b: 0x88))
                    }
                }
                .padding(12)
            }
        }
        .background(Color.black.opacity(0.05))
    }
}

// MARK: - Section divider

struct SectionDivider: View {
    let title: String
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Divider()
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(note)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Original sample row

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

// MARK: - Small element row

/// A text sample at a specific font size, testing whether the sampler can
/// recover colors from tiny rects. The text is always the same fg/bg pair;
/// only the height varies.
struct SmallElementRow: View {
    let fontSize: Double
    let fg: RGB
    let bg: RGB
    let ratio: Double

    private var label: String {
        String(format: "small-%02.0f  fg=%@  bg=%@  ratio=%.2f:1  h≈%02.0fpx",
               fontSize, fg.hex, bg.hex, ratio, fontSize + 10)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Ground-truth label
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white)
                .foregroundColor(.black)
                .accessibilityIdentifier("small-\(Int(fontSize))-label")
                .accessibilityLabel(label)

            // The sample: text on colored bg, with padding that makes the
            // total height ≈ fontSize + 10 (2px top+bottom padding + ascender/
            // descender room). This matches the real-world pattern where
            // textfields have minimal vertical padding.
            Text("Sample text")
                .font(.system(size: fontSize))
                .foregroundColor(fg.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(bg.color)
                .accessibilityIdentifier("small-\(Int(fontSize))")
                .accessibilityLabel("Sample text — fg=\(fg.hex) bg=\(bg.hex)")
        }
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.gray.opacity(0.3)))
    }
}

// MARK: - Parent-child row

/// A text sample inside a container. The container has the background color;
/// the text has no explicit background (inherits from parent). This mimics
/// Finder's column view where the textfield is just the text rendering area
/// and the parent group paints the background.
///
/// The AX tree should show:
///   group (container, h=containerHeight, bg=#eee)
///     statictext (text, h≈18px, fg=#333, no explicit bg)
struct ParentChildRow: View {
    let containerHeight: Double
    let fg: RGB
    let bg: RGB
    let ratio: Double

    private var label: String {
        String(format: "parent-h%02.0f  fg=%@  bg=%@  ratio=%.2f:1",
               containerHeight, fg.hex, bg.hex, ratio)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Ground-truth label
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white)
                .foregroundColor(.black)
                .accessibilityIdentifier("parent-\(Int(containerHeight))-label")
                .accessibilityLabel(label)

            // Container with background; text inside has no explicit bg.
            // DO NOT use .accessibilityElement() here — we want the container
            // and text to be separate AX elements so the sampler sees the
            // parent-child bounds relationship.
            //
            // The fixed frame on the container prevents SwiftUI's LazyVStack
            // from collapsing it when off-screen.
            HStack {
                Text("Sample text")
                    .font(.system(size: 13))
                    .foregroundColor(fg.color)
                    // NO .background() — inherits from parent
                Spacer()
            }
            .frame(height: containerHeight)
            .frame(maxWidth: .infinity)
            .background(bg.color)
            .accessibilityIdentifier("parent-\(Int(containerHeight))")
            .accessibilityLabel("Sample text — fg=\(fg.hex) bg=\(bg.hex)")
        }
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.gray.opacity(0.3)))
    }
}

// MARK: - Vibrancy row

/// A text sample on a subtle gradient background that mimics macOS vibrancy.
/// The gradient creates ~10-15 quantized buckets (similar to a vibrancy blur),
/// which the sampler might misclassify as "diffuse" and skip.
///
/// The gradient is horizontal, going from #f0f0f0 to #e8e8e8 — a very subtle
/// light-gray shift that's barely perceptible but creates enough color spread
/// to exercise the diffuse threshold.
struct VibrancyRow: View {
    let text: String
    let fg: RGB

    private var bgStart: RGB { RGB(r: 0xF0, g: 0xF0, b: 0xF0) }  // #f0f0f0
    private var bgEnd: RGB { RGB(r: 0xE8, g: 0xE8, b: 0xE8) }    // #e8e8e8

    /// Use the midpoint for the ground-truth ratio label.
    private var bgMid: RGB { RGB(r: 0xEC, g: 0xEC, b: 0xEC) }    // #ecec
    private var ratio: Double { contrastRatio(fg, bgMid) }

    private var label: String {
        String(format: "vib-\(text)  fg=%@  bg≈%@  ratio≈%.2f:1  gradient=#f0f0f0→#e8e8e8",
               fg.hex, bgMid.hex, ratio)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Ground-truth label
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white)
                .foregroundColor(.black)
                .accessibilityIdentifier("vib-\(text)-label")
                .accessibilityLabel(label)

            // Text on gradient background
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(fg.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            bgStart.color,
                            bgEnd.color,
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .accessibilityIdentifier("vib-\(text)")
                .accessibilityLabel("\(text) — fg=\(fg.hex) bg=gradient")
        }
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.gray.opacity(0.3)))
    }
}
