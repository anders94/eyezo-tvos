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

        // Progress update throttling
        private var isUpdating = false
        private var pendingPosition: Double?
        private let updateQueue = DispatchQueue(label: "com.videoclient.progressUpdate")

        init(video: VideoItem, serverURL: URL?) {
            self.video = video
            self.serverURL = serverURL
            super.init()
        }

        func startTracking() {
            guard let player = player, serverURL != nil else { return }

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

            // Report final progress synchronously when dismissing
            reportProgressSync()
        }

        private func reportProgressSync() {
            guard let player = player,
                  let serverURL = serverURL,
                  let currentItem = player.currentItem else {
                return
            }

            let currentTime = currentItem.currentTime()
            let position = CMTimeGetSeconds(currentTime)

            // Only report if position is valid and greater than 0
            guard position > 0 && position.isFinite else { return }

            // Capture values needed for the API call to avoid accessing self during deallocation
            let service = self.apiService
            let videoPath = self.video.urlPath

            // Report synchronously during teardown (don't queue or capture self)
            Task.detached {
                try? await service.updateWatchProgress(
                    serverURL: serverURL,
                    videoPath: videoPath,
                    position: position
                )
            }
        }

        private func reportProgress() {
            guard let player = player,
                  let currentItem = player.currentItem else {
                return
            }

            let currentTime = currentItem.currentTime()
            let position = CMTimeGetSeconds(currentTime)

            // Only report if position is valid and greater than 0
            guard position > 0 && position.isFinite else { return }

            updateQueue.async { [weak self] in
                guard let self = self else { return }

                if self.isUpdating {
                    // Update in progress - replace any pending update with this new one
                    self.pendingPosition = position
                } else {
                    // No update in progress - execute immediately
                    self.executeUpdate(position: position)
                }
            }
        }

        private func executeUpdate(position: Double) {
            guard let serverURL = serverURL else { return }

            isUpdating = true

            Task { [weak self] in
                guard let self = self else { return }

                do {
                    try await self.apiService.updateWatchProgress(
                        serverURL: serverURL,
                        videoPath: self.video.urlPath,
                        position: position
                    )
                } catch {
                    // Silently fail - don't spam user with network errors
                }

                // Update completed - check if there's a pending update
                self.updateQueue.async {
                    self.isUpdating = false

                    if let pendingPosition = self.pendingPosition {
                        // Execute the pending update (newest one)
                        self.pendingPosition = nil
                        self.executeUpdate(position: pendingPosition)
                    }
                }
            }
        }

        deinit {
            stopTracking()
        }
    }
}
