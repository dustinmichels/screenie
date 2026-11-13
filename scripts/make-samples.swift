// Renders fake screenshots for docs and demos, so captures of Screenie don't show real files.
// Usage: swift scripts/make-samples.swift <folder>         eight samples, from 2 min to 12 days old
//        swift scripts/make-samples.swift <folder> --new   one more, dated now (makes the dot appear)
//
// Each file gets the `kMDItemIsScreenCapture` xattr and a backdated creation date, as macOS's own
// screenshots do, so Screenie lists them. Run the app against the folder with `mise run demo`.

import AppKit

let args = CommandLine.arguments.dropFirst()
guard let folderArg = args.first else {
    FileHandle.standardError.write(
        "usage: swift scripts/make-samples.swift <folder> [--new]\n".data(using: .utf8)!)
    exit(1)
}
let folder = URL(fileURLWithPath: folderArg, isDirectory: true)
let onlyNew = args.contains("--new")

let width: CGFloat = 1600
let height: CGFloat = 1000

// MARK: Drawing helpers (top-left origin)

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func fill(_ rect: CGRect, _ color: NSColor, radius: CGFloat = 0) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func text(
    _ string: String, _ x: CGFloat, _ y: CGFloat, size: CGFloat, _ color: NSColor,
    weight: NSFont.Weight = .regular, mono: Bool = false
) {
    let font =
        mono
        ? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        : NSFont.systemFont(ofSize: size, weight: weight)
    NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
        .draw(at: CGPoint(x: x, y: y))
}

/// Draws syntax-colored segments left to right; returns nothing, each line is one call.
func segments(_ parts: [(String, NSColor)], _ x: CGFloat, _ y: CGFloat, size: CGFloat) {
    var x = x
    let font = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    for (string, color) in parts {
        let attributed = NSAttributedString(
            string: string, attributes: [.font: font, .foregroundColor: color])
        attributed.draw(at: CGPoint(x: x, y: y))
        x += attributed.size().width
    }
}

/// A gradient backdrop with a macOS-style window on it; returns the window's content rect.
func window(title: String, dark: Bool, backdrop: (UInt32, UInt32)) -> CGRect {
    let gradient = NSGradient(starting: rgb(backdrop.0), ending: rgb(backdrop.1))!
    gradient.draw(in: CGRect(x: 0, y: 0, width: width, height: height), angle: -60)

    let frame = CGRect(x: 90, y: 80, width: width - 180, height: height - 160)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowBlurRadius = 40
    shadow.shadowOffset = CGSize(width: 0, height: -12)
    shadow.shadowColor = NSColor(white: 0, alpha: 0.35)
    shadow.set()
    fill(frame, dark ? rgb(0x1E1E22) : rgb(0xFFFFFF), radius: 14)
    NSGraphicsContext.restoreGraphicsState()

    let bar = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: 52)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: frame, xRadius: 14, yRadius: 14).addClip()
    fill(bar, dark ? rgb(0x2A2A30) : rgb(0xECECEF))
    NSGraphicsContext.restoreGraphicsState()
    for (i, color) in [rgb(0xFF5F57), rgb(0xFEBC2E), rgb(0x28C840)].enumerated() {
        fill(
            CGRect(x: frame.minX + 22 + CGFloat(i) * 26, y: frame.minY + 19, width: 14, height: 14),
            color, radius: 7)
    }
    text(
        title, frame.midX - CGFloat(title.count) * 4.3, frame.minY + 15, size: 16,
        dark ? rgb(0xC8C8D0) : rgb(0x4A4A55), weight: .semibold)
    return CGRect(x: frame.minX, y: bar.maxY, width: frame.width, height: frame.height - bar.height)
}

// MARK: Scenes

func codeEditor() {
    let content = window(
        title: "Tide — ContentView.swift", dark: true, backdrop: (0x3A1C71, 0xD76D77))
    fill(
        CGRect(x: content.minX, y: content.minY, width: 260, height: content.height), rgb(0x232328))
    for (i, name) in [
        "Tide", "  App.swift", "  ContentView.swift", "  Forecast.swift", "  Station.swift",
        "  TideChart.swift", "Resources", "  Assets", "Tests",
    ].enumerated() {
        let y = content.minY + 24 + CGFloat(i) * 34
        if i == 2 {
            fill(
                CGRect(x: content.minX + 10, y: y - 6, width: 240, height: 32), rgb(0x3B4B7A),
                radius: 6)
        }
        text(
            name, content.minX + 24, y, size: 17,
            rgb(i == 0 || i == 6 || i == 8 ? 0x9A9AA5 : 0xDCDCE2))
    }
    let kw = rgb(0xFF7AB2)
    let type = rgb(0x5DD8FF)
    let str = rgb(0xFC6A5D)
    let plain = rgb(0xE6E6EA)
    let comment = rgb(0x7F8C98)
    let num = rgb(0xD9C97C)
    let fn = rgb(0x67B7A4)
    let lines: [[(String, NSColor)]] = [
        [("import", kw), (" SwiftUI", plain)],
        [],
        [("/// Today's tides for the selected station.", comment)],
        [("struct", kw), (" ContentView", type), (": ", plain), ("View", type), (" {", plain)],
        [
            ("    @State ", kw), ("private var", kw), (" station = ", plain), ("Station", type),
            (".portland", plain),
        ],
        [
            ("    @State ", kw), ("private var", kw), (" forecast: ", plain), ("Forecast", type),
            ("?", plain),
        ],
        [],
        [("    var", kw), (" body: ", plain), ("some", kw), (" View", type), (" {", plain)],
        [("        NavigationStack", type), (" {", plain)],
        [("            if let", kw), (" forecast {", plain)],
        [
            ("                TideChart", type), ("(points: forecast.", plain), ("points", fn),
            (")", plain),
        ],
        [
            ("                    .", plain), ("frame", fn), ("(height: ", plain), ("240", num),
            (")", plain),
        ],
        [("            } else", kw), (" {", plain)],
        [
            ("                ProgressView", type), ("(", plain), ("\"Loading tides…\"", str),
            (")", plain),
        ],
        [("            }", plain)],
        [("        }", plain)],
        [("        .", plain), ("task", fn), ("(id: station) {", plain)],
        [
            ("            forecast = ", plain), ("try? await", kw), (" Forecast", type),
            (".", plain), ("load", fn), ("(for: station)", plain),
        ],
        [("        }", plain)],
        [("    }", plain)],
        [("}", plain)],
    ]
    for (i, line) in lines.enumerated() {
        let y = content.minY + 24 + CGFloat(i) * 33
        text(
            String(format: "%2d", i + 1), content.minX + 284, y, size: 18, rgb(0x5A5A66), mono: true
        )
        segments(line, content.minX + 340, y, size: 18)
    }
}

func dashboard() {
    let content = window(
        title: "Analytics — Weekly Overview", dark: false, backdrop: (0x0F9B8E, 0x2A5298))
    let stats = [
        ("Visitors", "48,210", "+12%"), ("Signups", "1,384", "+8%"),
        ("Conversion", "2.9%", "+0.4"), ("Avg. session", "4m 12s", "−3%"),
    ]
    let cardWidth = (content.width - 48 * 2 - 24 * 3) / 4
    for (i, stat) in stats.enumerated() {
        let x = content.minX + 48 + CGFloat(i) * (cardWidth + 24)
        fill(
            CGRect(x: x, y: content.minY + 36, width: cardWidth, height: 130), rgb(0xF4F5F8),
            radius: 12)
        text(stat.0, x + 22, content.minY + 54, size: 17, rgb(0x6B6F7B))
        text(stat.1, x + 22, content.minY + 82, size: 38, rgb(0x1C1E26), weight: .bold)
        text(
            stat.2, x + 22, content.minY + 132, size: 16,
            stat.2.hasPrefix("−") ? rgb(0xD64545) : rgb(0x1E9E5A), weight: .medium)
    }
    let chart = CGRect(
        x: content.minX + 48, y: content.minY + 200, width: content.width - 96,
        height: content.height - 250)
    fill(chart, rgb(0xF4F5F8), radius: 12)
    text(
        "Daily visitors", chart.minX + 24, chart.minY + 20, size: 20, rgb(0x1C1E26),
        weight: .semibold)
    let values: [CGFloat] = [
        0.42, 0.55, 0.48, 0.70, 0.66, 0.82, 0.61, 0.58, 0.74, 0.90, 0.86, 0.68, 0.79, 0.95,
    ]
    let plotTop = chart.minY + 70
    let plotBottom = chart.maxY - 50
    let slot = (chart.width - 48) / CGFloat(values.count)
    for (i, value) in values.enumerated() {
        let barHeight = (plotBottom - plotTop) * value
        let x = chart.minX + 24 + CGFloat(i) * slot + slot * 0.2
        fill(
            CGRect(x: x, y: plotBottom - barHeight, width: slot * 0.6, height: barHeight),
            i == values.count - 1 ? rgb(0x2F6FED) : rgb(0x9DB8F5), radius: 5)
        text("\(i + 1)", x + slot * 0.3 - 6, plotBottom + 14, size: 14, rgb(0x8A8E99))
    }
}

func chat() {
    let content = window(title: "Messages", dark: false, backdrop: (0xF7971E, 0xFFD200))
    let sidebar = CGRect(x: content.minX, y: content.minY, width: 380, height: content.height)
    fill(sidebar, rgb(0xF2F2F5))
    let people = [
        ("Maya Chen", "See you at 6!", 0x7B61FF),
        ("Climbing crew", "Who's in for Saturday?", 0x1EA672),
        ("Sam Ortiz", "Sent the slides", 0xE8553E), ("Priya", "lol yes", 0x2F8FED),
        ("Dad", "Call me later", 0xB07A2A),
    ]
    for (i, person) in people.enumerated() {
        let y = sidebar.minY + 16 + CGFloat(i) * 92
        if i == 0 {
            fill(
                CGRect(x: sidebar.minX + 10, y: y, width: sidebar.width - 20, height: 80),
                rgb(0x2F7CF6), radius: 10)
        }
        fill(
            CGRect(x: sidebar.minX + 26, y: y + 14, width: 52, height: 52), rgb(UInt32(person.2)),
            radius: 26)
        text(
            String(person.0.prefix(1)), sidebar.minX + 44, y + 25, size: 24, .white,
            weight: .semibold)
        text(
            person.0, sidebar.minX + 96, y + 16, size: 19, i == 0 ? .white : rgb(0x1C1C22),
            weight: .semibold)
        text(person.1, sidebar.minX + 96, y + 44, size: 16, i == 0 ? rgb(0xDCE8FF) : rgb(0x7A7A85))
    }
    let messages: [(String, Bool)] = [
        ("Are we still on for dinner tonight?", false), ("Yes! The new ramen place on 5th?", true),
        ("Perfect. I'll book a table for 6", false), ("Can you bring the board game?", false),
        ("Already in my bag 🎲", true), ("See you at 6!", false),
    ]
    var y = content.minY + 40
    for (message, mine) in messages {
        let w = CGFloat(message.count) * 10.5 + 44
        let x = mine ? content.maxX - 48 - w : sidebar.maxX + 48
        fill(
            CGRect(x: x, y: y, width: w, height: 56), mine ? rgb(0x2F7CF6) : rgb(0xE9E9EE),
            radius: 22)
        text(message, x + 22, y + 15, size: 19, mine ? .white : rgb(0x1C1C22))
        y += 80
    }
    fill(
        CGRect(
            x: sidebar.maxX + 40, y: content.maxY - 76, width: content.maxX - sidebar.maxX - 80,
            height: 48),
        rgb(0xF2F2F5), radius: 24)
    text("Message", sidebar.maxX + 66, content.maxY - 63, size: 18, rgb(0x9A9AA5))
}

func terminal() {
    let content = window(title: "zsh — 120×36", dark: true, backdrop: (0x134E5E, 0x71B280))
    let prompt = rgb(0x5FD787)
    let plain = rgb(0xE4E4E4)
    let dim = rgb(0x8A8A96)
    let ok = rgb(0x87D7FF)
    let lines: [[(String, NSColor)]] = [
        [("~/projects/tide ", prompt), ("❯ ", ok), ("git status", plain)],
        [("On branch main", plain)],
        [("Your branch is up to date with 'origin/main'.", plain)],
        [],
        [("~/projects/tide ", prompt), ("❯ ", ok), ("swift test", plain)],
        [("Building for debugging...", dim)],
        [("[42/42] Linking TideTests", dim)],
        [("Test Suite 'All tests' started", plain)],
        [("  ✔ ", prompt), ("ForecastTests.testParsesHighAndLowTides ", plain), ("(0.004s)", dim)],
        [("  ✔ ", prompt), ("ForecastTests.testHandlesMissingStation ", plain), ("(0.002s)", dim)],
        [("  ✔ ", prompt), ("StationTests.testNearestStation ", plain), ("(0.011s)", dim)],
        [("  ✔ ", prompt), ("TideChartTests.testScalesToFit ", plain), ("(0.003s)", dim)],
        [("Executed 4 tests, with 0 failures in 0.020 seconds", prompt)],
        [],
        [("~/projects/tide ", prompt), ("❯ ", ok), ("█", plain)],
    ]
    for (i, line) in lines.enumerated() {
        segments(line, content.minX + 32, content.minY + 28 + CGFloat(i) * 34, size: 20)
    }
}

func landscape() {
    let sky = NSGradient(colors: [rgb(0x2B1055), rgb(0xD1436A), rgb(0xFFB26B)])!
    sky.draw(in: CGRect(x: 0, y: 0, width: width, height: height), angle: -90)
    fill(CGRect(x: 1040, y: 330, width: 220, height: 220), rgb(0xFFE3A3), radius: 110)
    func ridge(_ color: NSColor, _ points: [(CGFloat, CGFloat)]) {
        let path = NSBezierPath()
        path.move(to: CGPoint(x: 0, y: height))
        for (x, y) in points { path.line(to: CGPoint(x: x, y: y)) }
        path.line(to: CGPoint(x: width, y: height))
        path.close()
        color.setFill()
        path.fill()
    }
    ridge(
        rgb(0x6B2D5C),
        [
            (0, 560), (220, 420), (420, 520), (640, 380), (860, 500), (1100, 410), (1350, 520),
            (1600, 450),
        ])
    ridge(
        rgb(0x45204A),
        [(0, 680), (260, 560), (520, 650), (780, 540), (1020, 640), (1280, 570), (1600, 660)])
    ridge(rgb(0x241332), [(0, 820), (300, 730), (600, 800), (900, 720), (1200, 790), (1600, 740)])
}

func calendar() {
    let content = window(
        title: "Calendar — November 2026", dark: false, backdrop: (0x8E2DE2, 0x4A00E0))
    let days = ["Mon 9", "Tue 10", "Wed 11", "Thu 12", "Fri 13"]
    let gutter: CGFloat = 90
    let column = (content.width - gutter - 24) / CGFloat(days.count)
    for (i, day) in days.enumerated() {
        text(
            day, content.minX + gutter + CGFloat(i) * column + 16, content.minY + 20, size: 19,
            i == 4 ? rgb(0xE5484D) : rgb(0x2A2A33), weight: .semibold)
    }
    let top = content.minY + 64
    let hour: CGFloat = 76
    for h in 0..<10 {
        let y = top + CGFloat(h) * hour
        fill(
            CGRect(x: content.minX + gutter, y: y, width: content.width - gutter - 24, height: 1),
            rgb(0xE4E4EA))
        text(
            "\(h + 8 > 12 ? h - 4 : h + 8) \(h + 8 >= 12 ? "PM" : "AM")", content.minX + 22, y - 9,
            size: 14, rgb(0x8A8A96))
    }
    let events: [(Int, CGFloat, CGFloat, String, UInt32)] = [
        (0, 1, 1, "Standup", 0x2F7CF6), (0, 3, 2, "Design review", 0x8E44EF),
        (1, 1, 1, "Standup", 0x2F7CF6),
        (1, 4.5, 1, "Lunch with Maya", 0x1EA672), (2, 0.5, 1.5, "Focus time", 0xF5A623),
        (2, 6, 1, "1:1 Sam", 0xE8553E),
        (3, 1, 1, "Standup", 0x2F7CF6), (3, 2.5, 3, "Workshop", 0x8E44EF),
        (4, 1, 1, "Standup", 0x2F7CF6),
        (4, 5, 1.5, "Climbing 🧗", 0x1EA672),
    ]
    for (day, start, length, title, color) in events {
        let rect = CGRect(
            x: content.minX + gutter + CGFloat(day) * column + 6, y: top + start * hour + 3,
            width: column - 12, height: length * hour - 6)
        fill(rect, rgb(color, 0.18), radius: 8)
        fill(
            CGRect(x: rect.minX, y: rect.minY, width: 5, height: rect.height), rgb(color), radius: 2
        )
        text(title, rect.minX + 16, rect.minY + 10, size: 17, rgb(color), weight: .semibold)
    }
}

func article() {
    let content = window(
        title: "Field Notes — The Quiet Tide", dark: false, backdrop: (0x1D976C, 0x93F9B9))
    fill(
        CGRect(x: content.minX + 220, y: content.minY + 14, width: content.width - 440, height: 38),
        rgb(0xEFEFF2), radius: 10)
    text(
        "fieldnotes.example/the-quiet-tide", content.midX - 150, content.minY + 22, size: 17,
        rgb(0x6B6B78))
    let column = CGRect(
        x: content.minX + 260, y: content.minY + 90, width: content.width - 520, height: 0)
    text("The Quiet Tide", column.minX, column.minY, size: 46, rgb(0x16161C), weight: .bold)
    text(
        "Notes from a week of early mornings on the coast", column.minX, column.minY + 64, size: 22,
        rgb(0x6B6B78))
    let photo = CGRect(x: column.minX, y: column.minY + 120, width: column.width, height: 260)
    NSGradient(starting: rgb(0x89C2D9), ending: rgb(0x2C7DA0))!.draw(in: photo, angle: -90)
    for i in 0..<8 {
        let y = photo.maxY + 40 + CGFloat(i) * 34
        let w = i == 7 ? column.width * 0.55 : column.width * (i % 3 == 0 ? 0.97 : 0.92)
        fill(CGRect(x: column.minX, y: y, width: w, height: 14), rgb(0xDADAE0), radius: 7)
    }
}

func palette() {
    let content = window(title: "Brand colors", dark: false, backdrop: (0xEECDA3, 0xEF629F))
    let swatches: [(UInt32, String)] = [
        (0x0B3C5D, "Deep Sea"), (0x328CC1, "Harbor"), (0x8FC1E3, "Mist"),
        (0xD9B310, "Buoy"), (0xF2E3BC, "Sand"), (0xE4572E, "Flare"),
    ]
    let w = (content.width - 96 - 24 * 2) / 3
    let h = (content.height - 96 - 24) / 2
    for (i, swatch) in swatches.enumerated() {
        let rect = CGRect(
            x: content.minX + 48 + CGFloat(i % 3) * (w + 24),
            y: content.minY + 48 + CGFloat(i / 3) * (h + 24), width: w, height: h)
        fill(rect, rgb(swatch.0), radius: 14)
        fill(
            CGRect(x: rect.minX, y: rect.maxY - 90, width: rect.width, height: 90), .white,
            radius: 14)
        fill(CGRect(x: rect.minX, y: rect.maxY - 90, width: rect.width, height: 20), .white)
        text(swatch.1, rect.minX + 22, rect.maxY - 78, size: 22, rgb(0x1C1C22), weight: .semibold)
        text(
            String(format: "#%06X", swatch.0), rect.minX + 22, rect.maxY - 44, size: 17,
            rgb(0x7A7A85), mono: true)
    }
}

// MARK: Output

func png(_ draw: () -> Void) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(width), pixelsHigh: Int(height),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    // Flip so scenes use a top-left origin, like the screen.
    let flip = NSAffineTransform()
    flip.translateX(by: 0, yBy: height)
    flip.scaleX(by: 1, yBy: -1)
    flip.concat()
    NSGraphicsContext.current = NSGraphicsContext(
        cgContext: NSGraphicsContext.current!.cgContext, flipped: true)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let nameFormat: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "'Screenshot' yyyy-MM-dd 'at' h.mm.ss a'.png'"
    return formatter
}()

let isScreenCapture = try PropertyListSerialization.data(
    fromPropertyList: true, format: .binary, options: 0)

func write(_ draw: () -> Void, age: TimeInterval) throws {
    let date = Date(timeIntervalSinceNow: -age)
    let url = folder.appendingPathComponent(nameFormat.string(from: date))
    try png(draw).write(to: url)
    let status = isScreenCapture.withUnsafeBytes { bytes in
        setxattr(
            url.path, "com.apple.metadata:kMDItemIsScreenCapture", bytes.baseAddress, bytes.count,
            0, 0)
    }
    guard status == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    var values = URLResourceValues()
    values.creationDate = date
    values.contentModificationDate = date
    var mutable = url
    try mutable.setResourceValues(values)
    print(url.path)
}

try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
let scenes: [(() -> Void, TimeInterval)] = [
    (codeEditor, 2 * 60), (dashboard, 25 * 60), (chat, 70 * 60), (terminal, 3 * 3600),
    (landscape, 26 * 3600), (calendar, 2 * 86400), (article, 5 * 86400), (palette, 12 * 86400),
]
if onlyNew {
    // Cycle through every scene but the code editor (the newest sample), so the new one stands out.
    let count = (try? FileManager.default.contentsOfDirectory(atPath: folder.path).count) ?? 0
    try write(scenes[1 + count % (scenes.count - 1)].0, age: 0)
} else {
    for (draw, age) in scenes { try write(draw, age: age) }
}
