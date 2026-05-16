import SwiftUI
import AVKit
import AVFoundation

struct VideoPlayerView: UIViewControllerRepresentable {
    let video: VideoItem
    let serverURL: URL?

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()

        guard let serverURL = serverURL else { return controller }

        let apiService = APIService()
        let videoURL = apiService.getVideoURL(serverURL: serverURL, videoPath: video.urlPath)

        let player = AVPlayer(url: videoURL)
        controller.player = player

        // Auto-play
        player.play()

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // No updates needed
    }
}
