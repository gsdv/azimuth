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
}
