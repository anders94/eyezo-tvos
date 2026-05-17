import SwiftUI
import AVKit
import AVFoundation
import Combine

struct VideoPlayerView: UIViewControllerRepresentable {
    let video: VideoItem
    let serverURL: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator(video: video, serverURL: serverURL)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()

        guard let serverURL = serverURL else { return controller }

        let apiService = APIService()
        let videoURL = apiService.getVideoURL(serverURL: serverURL, videoPath: video.urlPath)

        let player = AVPlayer(url: videoURL)
        controller.player = player
        context.coordinator.player = player

        // Start at saved position if available
        if let watchPosition = video.watchPosition, watchPosition > 0 {
            player.seek(to: CMTime(seconds: watchPosition, preferredTimescale: 600))
        }

        // Auto-play
        player.play()

        // Start progress tracking
        context.coordinator.startTracking()

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // No updates needed
    }

    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.stopTracking()
    }

    class Coordinator: NSObject {
        let video: VideoItem
        let serverURL: URL?
        let apiService = APIService()
        var player: AVPlayer?
        private var progressTimer: Timer?
        private var timeObserver: Any?
        private var cancellables = Set<AnyCancellable>()

        init(video: VideoItem, serverURL: URL?) {
            self.video = video
            self.serverURL = serverURL
            super.init()
        }

        func startTracking() {
            guard let player = player, let serverURL = serverURL else { return }

            // Periodic progress updates (every 10 seconds)
            progressTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
                self?.reportProgress()
            }

            // Observe when player pauses
            NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
                .sink { [weak self] _ in
                    self?.reportProgress()
                }
                .store(in: &cancellables)

            // Observe when playback ends
            NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
                .sink { [weak self] _ in
                    self?.reportProgress()
                }
                .store(in: &cancellables)

            // Observe rate changes (play/pause)
            player.publisher(for: \.rate)
                .removeDuplicates()
                .sink { [weak self] rate in
                    if rate == 0 {
                        // Player paused
                        self?.reportProgress()
                    }
                }
                .store(in: &cancellables)
        }

        func stopTracking() {
            progressTimer?.invalidate()
            progressTimer = nil
            cancellables.removeAll()

            // Report final progress when dismissing
            reportProgress()
        }

        private func reportProgress() {
            guard let player = player,
                  let serverURL = serverURL,
                  let currentItem = player.currentItem else {
                return
            }

            let currentTime = currentItem.currentTime()
            let position = CMTimeGetSeconds(currentTime)

            // Only report if position is valid and greater than 0
            guard position > 0 && position.isFinite else { return }

            Task {
                try? await apiService.updateWatchProgress(
                    serverURL: serverURL,
                    videoPath: video.urlPath,
                    position: position
                )
            }
        }

        deinit {
            stopTracking()
        }
    }
}
