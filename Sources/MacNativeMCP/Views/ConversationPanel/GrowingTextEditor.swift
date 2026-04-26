import SwiftUI
import AppKit

/// A growing NSTextView wrapper. ⌘↩ sends, plain ↩ inserts a newline.
struct GrowingTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    var placeholder: String = "Message… (⌘↩ to send)"
    var onSend: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textColor = NSColor(AppColors.textPrimary)
        textView.textContainerInset = NSSize(width: 8, height: 10)
        textView.textContainer?.lineFragmentPadding = 4

        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
            context.coordinator.recalculateHeight(textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: GrowingTextEditor
        init(_ parent: GrowingTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
            recalculateHeight(tv)
        }

        func recalculateHeight(_ textView: NSTextView) {
            guard let lm = textView.layoutManager,
                  let tc = textView.textContainer else { return }
            lm.ensureLayout(for: tc)
            let used = lm.usedRect(for: tc).height
            let inset = textView.textContainerInset.height * 2
            let newHeight = max(40, min(used + inset, 120))
            if abs(parent.height - newHeight) > 0.5 {
                DispatchQueue.main.async { self.parent.height = newHeight }
            }
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)),
               NSApp.currentEvent?.modifierFlags.contains(.command) == true {
                parent.onSend()
                return true
            }
            return false
        }
    }
}
