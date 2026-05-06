import Foundation
import Observation

@MainActor
@Observable
final class TabRouter {
    var selection: AppTab = .track
}
