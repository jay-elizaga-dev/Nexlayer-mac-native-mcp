import SwiftUI
import AppKit

struct CodeBlockView: View {
    let content: String
    let language: String

    @State private var copied = false

    init(content: String, language: String = "") {
        self.content = content
        self.language = language
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HighlightedCodeView(content: content)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button(action: copyToClipboard) {
                Text(copied ? "Copied" : "Copy")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(copied ? AppColors.success : AppColors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#1F1F1F"))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(hex: "#2A2A2A"), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .background(Color(hex: "#0E0E0E"))
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }
}

private struct HighlightedCodeView: NSViewRepresentable {
    let content: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = NSColor(red: 0x0E/255.0, green: 0x0E/255.0, blue: 0x0E/255.0, alpha: 1)
        textView.textContainerInset = NSSize(width: 0, height: 8)
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isRichText = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.drawsBackground = true

        scrollView.backgroundColor = NSColor(red: 0x0E/255.0, green: 0x0E/255.0, blue: 0x0E/255.0, alpha: 1)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true

        if let container = textView.textContainer {
            container.widthTracksTextView = false
            container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }

        context.coordinator.textView = textView
        updateText(textView: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if context.coordinator.lastContent != content {
            context.coordinator.lastContent = content
            updateText(textView: textView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func updateText(textView: NSTextView) {
        let attributed = buildAttributedString(content: content)
        textView.textStorage?.setAttributedString(attributed)
    }

    class Coordinator {
        var textView: NSTextView?
        var lastContent: String = ""
    }
}

private func buildAttributedString(content: String) -> NSAttributedString {
    let lines = content.components(separatedBy: "\n")
    let lineCount = lines.count
    let lineNumWidth = "\(lineCount)".count

    let monoFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    let gutterColor = NSColor(red: 0x88/255.0, green: 0x88/255.0, blue: 0x88/255.0, alpha: 1)
    let defaultColor = NSColor(red: 0xE8/255.0, green: 0xE8/255.0, blue: 0xE8/255.0, alpha: 1)

    let result = NSMutableAttributedString()

    for (i, line) in lines.enumerated() {
        let lineNum = String(format: "%\(lineNumWidth)d", i + 1)
        let gutterStr = NSAttributedString(
            string: "\(lineNum)  ",
            attributes: [
                .font: monoFont,
                .foregroundColor: gutterColor
            ]
        )
        result.append(gutterStr)

        let highlighted = highlightLine(line, font: monoFont, defaultColor: defaultColor)
        result.append(highlighted)

        if i < lines.count - 1 {
            result.append(NSAttributedString(string: "\n", attributes: [.font: monoFont, .foregroundColor: defaultColor]))
        }
    }

    return result
}

private func highlightLine(_ line: String, font: NSFont, defaultColor: NSColor) -> NSAttributedString {
    let result = NSMutableAttributedString(
        string: line,
        attributes: [.font: font, .foregroundColor: defaultColor]
    )

    let fullRange = NSRange(location: 0, length: (line as NSString).length)

    // Color constants
    let keywordColor = NSColor(red: 0x5B/255.0, green: 0x8A/255.0, blue: 0xF7/255.0, alpha: 1)   // #5B8AF7 blue
    let stringColor  = NSColor(red: 0x52/255.0, green: 0xC9/255.0, blue: 0x7A/255.0, alpha: 1)   // #52C97A green
    let commentColor = NSColor(red: 0x88/255.0, green: 0x88/255.0, blue: 0x88/255.0, alpha: 1)   // #888888 gray
    let numberColor  = NSColor(red: 0xE8/255.0, green: 0x92/255.0, blue: 0x4A/255.0, alpha: 1)   // #E8924A orange

    // Track ranges already colored so we don't override comments/strings with keywords
    var coloredRanges: [NSRange] = []

    func applyColor(_ pattern: String, color: NSColor, options: NSRegularExpression.Options = []) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let matches = regex.matches(in: line, range: fullRange)
        for match in matches {
            let range = match.range
            let overlaps = coloredRanges.contains { NSIntersectionRange($0, range).length > 0 }
            if !overlaps {
                result.addAttribute(.foregroundColor, value: color, range: range)
                coloredRanges.append(range)
            }
        }
    }

    // Apply in order: comments first (highest priority), then strings, then numbers, then keywords
    // Single-line comments: // and #
    applyColor(#"(//.*|#.*)"#, color: commentColor)
    // Strings: "..." and '...'  (non-greedy, no newlines)
    applyColor(#""[^"\n]*"|'[^'\n]*'"#, color: stringColor)
    // Numbers: standalone digit sequences (with optional decimal)
    applyColor(#"\b\d+(\.\d+)?\b"#, color: numberColor)
    // Keywords
    let keywords = "\\b(if|else|func|return|let|var|class|struct|import|for|while|switch|case|guard|in|break|continue|default|do|try|catch|throw|throws|rethrows|init|deinit|self|super|static|override|public|private|internal|fileprivate|open|final|lazy|weak|unowned|nil|true|false|as|is|new|where|typealias|enum|protocol|extension|some|any|await|async)\\b"
    applyColor(keywords, color: keywordColor)

    return result
}

/* Block comment support for multi-line: handled line-by-line; full /* */ support
   would require stateful parsing across lines, which is outside scope here. */
