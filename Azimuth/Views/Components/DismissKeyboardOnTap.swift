import UIKit

@MainActor
final class GlobalKeyboardDismisser: NSObject, UIGestureRecognizerDelegate {
    static let shared = GlobalKeyboardDismisser()

    private var isInstalled = false

    func install() {
        guard !isInstalled else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  !self.isInstalled,
                  let window = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .flatMap({ $0.windows })
                    .first
            else { return }

            let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleTap))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            window.addGestureRecognizer(tap)
            self.isInstalled = true
        }
    }

    @objc private func handleTap() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    nonisolated func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        true
    }

    nonisolated func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        MainActor.assumeIsolated {
            guard let window = touch.window else { return true }
            let location = touch.location(in: window)
            return !Self.touchHitsTextInput(at: location, in: window)
        }
    }

    // Returns true if the touch lands on (or within ~16pt of) any UITextField/UITextView
    // in the window. Tapping the focused field — or its visual padding — should not
    // dismiss the keyboard, so the user can reposition the cursor, paste, or select.
    private static func touchHitsTextInput(at location: CGPoint, in root: UIView) -> Bool {
        if root is UITextField || root is UITextView {
            let frame = root.convert(root.bounds, to: nil).insetBy(dx: -16, dy: -16)
            if frame.contains(location) { return true }
        }
        for sub in root.subviews where !sub.isHidden && sub.alpha > 0 {
            if touchHitsTextInput(at: location, in: sub) { return true }
        }
        return false
    }
}
