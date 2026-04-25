import AppKit
import SwiftUI

final class MainWindowController: NSWindowController {
    override func windowDidLoad() {
        super.windowDidLoad()
        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .hidden
        window?.backgroundColor = NSColor(red: 0.035, green: 0.035, blue: 0.035, alpha: 1)
        window?.minSize = NSSize(width: 900, height: 600)
    }
}

/// A transparent NSViewRepresentable that installs MainWindowController on the window
/// when first added to the view hierarchy.
struct MainWindowSetupView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            let controller = MainWindowController(window: window)
            controller.windowDidLoad()
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
