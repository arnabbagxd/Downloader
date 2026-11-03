import Foundation

/// One foreground operation and its last result, retained until dismissed or replaced.
struct AppActivity: Equatable, Codable {
    enum State: String, Equatable, Codable { case running, succeeded, failed, cancelled }
    let title: String
    var detail: String
    var state: State = .running
    let startedAt: Date

    init(title: String, detail: String, state: State = .running, startedAt: Date = Date()) {
        self.title = title
        self.detail = detail
        self.state = state
        self.startedAt = startedAt
    }

    var isRunning: Bool { state == .running }
}
