import Foundation

struct WatchProgress: Codable {
    let path: String
    let position: Double
    let lastWatched: TimeInterval?

    var positionFormatted: String {
        let minutes = Int(position) / 60
        let seconds = Int(position) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct WatchProgressUpdate: Codable {
    let path: String
    let position: Double
}

struct WatchProgressResponse: Codable {
    let success: Bool
    let path: String
    let position: Double?
    let message: String?
}
