import SwiftUI
import AppKit

// MARK: - NSTextView wrapper

private struct GrowingTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
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

    // MARK: Coordinator

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

        // ⌘↩ → send; plain ↩ → newline (default)
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

// MARK: - InputBarView

struct InputBarView: View {
    @Environment(AppState.self) private var appState

    @State private var inputText: String = ""
    @State private var editorHeight: CGFloat = 40
    // AppState has no isThinking property yet; track locally until it's added.
    @State private var isSending: Bool = false

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Text input area
            ZStack(alignment: .topLeading) {
                // Background + border
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppColors.border, lineWidth: 1)
                    )

                // Placeholder
                if inputText.isEmpty {
                    Text("Message… (⌘↩ to send)")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.top, 11)
                        .allowsHitTesting(false)
                }

                GrowingTextEditor(
                    text: $inputText,
                    height: $editorHeight,
                    onSend: sendMessage
                )
                .padding(.horizontal, 2)
            }
            .frame(height: editorHeight)
            .animation(.easeInOut(duration: 0.1), value: editorHeight)

            // Send / spinner button
            Button(action: sendMessage) {
                ZStack {
                    if isSending {
                        ProgressView()
                            .scaleEffect(0.75)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(canSend ? AppColors.accent : AppColors.textSecondary)
                    }
                }
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(canSend ? AppColors.surface : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(canSend ? AppColors.border : Color.clear, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .padding(.bottom, (editorHeight - 32) / 2) // align to bottom of input
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppColors.background)
    }

    // MARK: Send

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        appState.messages.append(
            AppState.ConversationMessage(role: "user", content: trimmed)
        )
        inputText = ""
        editorHeight = 40
        isSending = true
        // Reset isSending once a real response arrives; for now use a short delay.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isSending = false
        }
    }
}
