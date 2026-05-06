import SwiftUI
import UIKit

enum Theme {
    static let sky = Color(red: 0.408, green: 0.690, blue: 0.949)
    static let skyDeep = Color(red: 0.255, green: 0.490, blue: 0.804)
    static let skySoft = Color(red: 0.745, green: 0.871, blue: 0.969)
    static let skyMist = Color(red: 0.890, green: 0.945, blue: 0.988)

    static let success = Color(red: 0.392, green: 0.776, blue: 0.604)
    static let warning = Color(red: 0.969, green: 0.745, blue: 0.404)
    static let danger  = Color(red: 0.937, green: 0.498, blue: 0.498)

    static let canvasLight = LinearGradient(
        colors: [
            Color(red: 0.945, green: 0.973, blue: 0.996),
            Color(red: 0.871, green: 0.929, blue: 0.984),
            Color(red: 0.804, green: 0.890, blue: 0.969)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let canvasDark = LinearGradient(
        colors: [
            Color(red: 0.043, green: 0.078, blue: 0.137),
            Color(red: 0.067, green: 0.122, blue: 0.204),
            Color(red: 0.098, green: 0.165, blue: 0.255)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let pulseGradient = LinearGradient(
        colors: [Color(red: 0.561, green: 0.808, blue: 0.980), sky, skyDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardFill = Color(uiColor: UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.094, green: 0.157, blue: 0.243, alpha: 1.0)
        }
        return UIColor(red: 0.847, green: 0.918, blue: 0.984, alpha: 1.0)
    })

    static let cardStroke = Color(uiColor: UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.235, green: 0.345, blue: 0.471, alpha: 0.5)
        }
        return UIColor(red: 0.549, green: 0.722, blue: 0.910, alpha: 0.45)
    })

    static let chipFill = Color(uiColor: UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.157, green: 0.227, blue: 0.337, alpha: 1.0)
        }
        return UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.85)
    })
}

struct CanvasBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        (colorScheme == .dark ? Theme.canvasDark : Theme.canvasLight)
            .ignoresSafeArea()
    }
}
