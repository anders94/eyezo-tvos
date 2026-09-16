import SwiftUI

/// Fixed sizes for every card in the browser grid.
///
/// The tvOS focus engine picks the next focused view geometrically: on "down"
/// it looks for the focusable frame that sits most directly below the current
/// one. That search is only deterministic when cells share one column grid and
/// every cell in a section has the same, aligned frame. Letting cells size
/// themselves to their content (a wide thumbnail, a long title) produced
/// overlapping frames, which is why cards overflowed their neighbours and why
/// fast presses drifted between columns.
///
/// Directories and videos live in two sections that share the same columns,
/// so directory cards can be shorter without breaking column alignment. This
/// is the same shape as a UICollectionView compositional layout with one
/// item size per section.
enum CardMetrics {
    static let width: CGFloat = 360
    static let thumbnailHeight: CGFloat = width * 9 / 16
    static let videoHeight: CGFloat = 390
    static let directoryIconHeight: CGFloat = 150
    static let directoryHeight: CGFloat = 250
    static let spacing: CGFloat = 48
    static let cornerRadius: CGFloat = 20
    static let columnCount = 4
    static let horizontalPadding: CGFloat = 60

    /// Fixed-width columns so layout never depends on measured content.
    static var columns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(width), spacing: spacing),
            count: columnCount
        )
    }
}

struct DirectoryBrowserView: View {
    @StateObject private var viewModel = DirectoryViewModel()
    @StateObject private var serverURLManager = ServerURLManager.shared
    @FocusState private var focusedItem: String?
    @State private var selectedVideo: VideoItem?
    @State private var showingServerSetup = false
    @State private var hasSetInitialFocus = false

    let initialPath: String?

    /// The grid item that should receive focus by default: the first directory,
    /// or the first video if there are no directories. Nil only when the
    /// directory is empty, in which case focus falls back to the settings icon.
    private var defaultFocusID: String? {
        viewModel.directories.first?.id ?? viewModel.videos.first?.id
    }

    private var displayTitle: String {
        guard let path = viewModel.currentPath else { return "Videos" }
        // Extract just the last component of the path for display
        let components = path.split(separator: "/")
        guard let last = components.last.map(String.init) else { return "Videos" }
        // Decode percent-encoding so paths with spaces (%20) display correctly
        return last.removingPercentEncoding ?? last
    }

    private var isEmpty: Bool {
        viewModel.directories.isEmpty && viewModel.videos.isEmpty
    }

    var body: some View {
        Group {
            // Only the root instance owns the NavigationView. Pushed child
            // instances render their content directly; wrapping each in its own
            // NavigationView breaks tvOS focus routing after a push/pop cycle.
            if initialPath == nil {
                NavigationView {
                    content
                }
                .navigationViewStyle(.stack)
            } else {
                content
            }
        }
        .task {
            await viewModel.loadDirectory(initialPath)
        }
        // The grid appears only after the async load finishes, by which point
        // focus has already settled on the toolbar gear (the only focusable view
        // shown during loading). .defaultFocus can't steal already-established
        // focus, so move it to the first item ourselves once content arrives.
        // Guarded so later refreshes don't yank focus away from the user.
        .onChange(of: viewModel.isLoading) { _, loading in
            guard !loading, !hasSetInitialFocus, let target = defaultFocusID else { return }
            hasSetInitialFocus = true
            focusedItem = target
        }
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if viewModel.isLoading && isEmpty {
                loadingView
            } else if let errorMessage = viewModel.errorMessage, isEmpty {
                errorView(errorMessage)
            } else if isEmpty {
                emptyView
            } else {
                grid
            }
        }
        .navigationTitle(displayTitle)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 30) {
                    if viewModel.serverUnreachable {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                    }

                    Button(action: {
                        showingServerSetup = true
                    }) {
                        Image(systemName: "gearshape")
                            .font(.title3)
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedVideo, onDismiss: {
            // Wait for server to process the final progress update, then refresh
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await viewModel.refresh()
            }
        }) { video in
            VideoPlayerView(video: video, serverURL: serverURLManager.serverURL)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showingServerSetup, onDismiss: {
            Task {
                await viewModel.refresh()
            }
        }) {
            ServerSetupView()
        }
    }

    private var grid: some View {
        ScrollView {
            VStack(spacing: CardMetrics.spacing) {
                if !viewModel.directories.isEmpty {
                    LazyVGrid(columns: CardMetrics.columns, spacing: CardMetrics.spacing) {
                        ForEach(viewModel.directories) { directory in
                            NavigationLink(destination: DirectoryBrowserView(initialPath: directory.urlPath)) {
                                DirectoryCard(directory: directory)
                            }
                            .buttonStyle(.card)
                            .focused($focusedItem, equals: directory.id)
                        }
                    }
                }

                if !viewModel.videos.isEmpty {
                    LazyVGrid(columns: CardMetrics.columns, spacing: CardMetrics.spacing) {
                        ForEach(viewModel.videos) { video in
                            Button(action: {
                                selectedVideo = video
                            }) {
                                VideoCard(video: video, serverURL: serverURLManager.serverURL)
                            }
                            .buttonStyle(.card)
                            .focused($focusedItem, equals: video.id)
                        }
                    }
                }
            }
            .focusSection()
            .defaultFocus($focusedItem, defaultFocusID)
            .padding(.horizontal, CardMetrics.horizontalPadding)
            .padding(.vertical, 60)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 30) {
            ProgressView()
                .scaleEffect(2)
            Text("Loading...")
                .font(.title2)
                .foregroundColor(.secondary)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 40) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 100))
                .foregroundColor(.orange)

            Text("Error")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text(message)
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 100)

            Button("Retry") {
                Task {
                    await viewModel.refresh()
                }
            }
            .buttonStyle(.borderedProminent)
            .font(.title2)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 30) {
            Image(systemName: "folder")
                .font(.system(size: 100))
                .foregroundColor(.secondary)
            Text("No videos or directories found")
                .font(.title2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 100)
    }

    init(initialPath: String? = nil) {
        self.initialPath = initialPath
    }
}

/// Shared chrome for every grid cell: a fixed frame, background and rounded
/// clip. Content that is somehow larger than the cell is clipped rather than
/// allowed to change the cell's size.
private struct CardFrame<Content: View>: View {
    let height: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(width: CardMetrics.width, height: height, alignment: .top)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: CardMetrics.cornerRadius, style: .continuous))
    }
}

struct DirectoryCard: View {
    let directory: DirectoryItem

    var body: some View {
        CardFrame(height: CardMetrics.directoryHeight) {
            VStack(alignment: .leading, spacing: 15) {
                ZStack {
                    Color.secondary.opacity(0.1)
                    Image(systemName: "folder.fill")
                        .font(.system(size: 70))
                        .foregroundColor(.blue)
                }
                .frame(width: CardMetrics.width, height: CardMetrics.directoryIconHeight)

                Text(directory.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 15)
            }
        }
    }
}

struct VideoCard: View {
    let video: VideoItem
    let serverURL: URL?

    private var thumbnailURL: URL? {
        guard let serverURL = serverURL,
              video.hasThumbnail else { return nil }
        let apiService = APIService()
        return apiService.getThumbnailURL(serverURL: serverURL, videoPath: video.urlPath)
    }

    var body: some View {
        CardFrame(height: CardMetrics.videoHeight) {
            VStack(alignment: .leading, spacing: 15) {
                thumbnail
                    .overlay(alignment: .bottom) {
                        if video.watchProgress > 0 {
                            progressBar
                        }
                    }

                VStack(alignment: .leading, spacing: 8) {
                    Text(video.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(video.formattedSize)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 15)
            }
        }
    }

    /// The thumbnail area is always exactly `width` x `thumbnailHeight`.
    /// The image is drawn as an overlay of a fixed-size placeholder, so an
    /// image with a different aspect ratio (2.39:1 posters, 4:3 captures) is
    /// scaled to fill and clipped instead of widening the cell.
    private var thumbnail: some View {
        Color.secondary.opacity(0.2)
            .frame(width: CardMetrics.width, height: CardMetrics.thumbnailHeight)
            .overlay {
                if let thumbnailURL = thumbnailURL {
                    AsyncImage(url: thumbnailURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .scaleEffect(1.5)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            placeholderIcon
                        @unknown default:
                            placeholderIcon
                        }
                    }
                } else {
                    placeholderIcon
                }
            }
            .clipped()
    }

    private var placeholderIcon: some View {
        Image(systemName: "film.fill")
            .font(.system(size: 60))
            .foregroundColor(.gray)
    }

    private var progressBar: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.black.opacity(0.3))

            Rectangle()
                .fill(Color.red)
                .frame(width: CardMetrics.width * video.watchProgress)
        }
        .frame(width: CardMetrics.width, height: 6)
    }
}
