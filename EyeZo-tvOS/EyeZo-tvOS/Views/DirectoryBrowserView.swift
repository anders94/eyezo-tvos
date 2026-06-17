import SwiftUI

struct DirectoryBrowserView: View {
    @StateObject private var viewModel = DirectoryViewModel()
    @StateObject private var serverURLManager = ServerURLManager.shared
    @State private var selectedVideo: VideoItem?
    @State private var showingServerSetup = false
    @State private var hasSetInitialFocus = false
    @FocusState private var focusedItem: String?

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
                if viewModel.isLoading && viewModel.directories.isEmpty && viewModel.videos.isEmpty {
                    VStack(spacing: 30) {
                        ProgressView()
                            .scaleEffect(2)
                        Text("Loading...")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                } else if let errorMessage = viewModel.errorMessage, viewModel.directories.isEmpty && viewModel.videos.isEmpty {
                    VStack(spacing: 40) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 100))
                            .foregroundColor(.orange)

                        Text("Error")
                            .font(.largeTitle)
                            .fontWeight(.semibold)

                        Text(errorMessage)
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
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 50)
                            ],
                            spacing: 50
                        ) {
                            // Directories
                            ForEach(Array(viewModel.directories.enumerated()), id: \.element.id) { index, directory in
                                NavigationLink(destination: DirectoryBrowserView(initialPath: directory.urlPath)) {
                                    DirectoryCard(directory: directory)
                                }
                                .buttonStyle(.card)
                                .focused($focusedItem, equals: directory.id)
                            }

                            // Videos
                            ForEach(Array(viewModel.videos.enumerated()), id: \.element.id) { index, video in
                                Button(action: {
                                    selectedVideo = video
                                }) {
                                    VideoCard(video: video, serverURL: serverURLManager.serverURL)
                                }
                                .buttonStyle(.card)
                                .focused($focusedItem, equals: video.id)
                            }
                        }
                        .focusSection()
                        .defaultFocus($focusedItem, defaultFocusID)
                        .padding(80)

                        // Empty state
                        if viewModel.directories.isEmpty && viewModel.videos.isEmpty && !viewModel.isLoading {
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
                    }
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

    init(initialPath: String? = nil) {
        self.initialPath = initialPath
    }
}

struct DirectoryCard: View {
    let directory: DirectoryItem

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.fill")
                .font(.system(size: 70))
                .foregroundColor(.blue)
                .frame(height: 120)

            Text(directory.name)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 250)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(20)
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
        VStack(alignment: .leading, spacing: 15) {
            // Thumbnail with progress bar
            ZStack(alignment: .bottom) {
                if let thumbnailURL = thumbnailURL {
                    AsyncImage(url: thumbnailURL) { phase in
                        switch phase {
                        case .empty:
                            ZStack {
                                Color.secondary.opacity(0.2)
                                ProgressView()
                                    .scaleEffect(1.5)
                            }
                            .frame(height: 200)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
                        case .failure:
                            ZStack {
                                Color.secondary.opacity(0.2)
                                Image(systemName: "film.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                            }
                            .frame(height: 200)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    ZStack {
                        Color.secondary.opacity(0.2)
                        Image(systemName: "film.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                    }
                    .frame(height: 200)
                }

                // Progress bar
                if video.watchProgress > 0 {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.black.opacity(0.3))
                                .frame(height: 6)

                            Rectangle()
                                .fill(Color.red)
                                .frame(width: geometry.size.width * video.watchProgress, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }
            .frame(height: 200)

            // Video info
            VStack(alignment: .leading, spacing: 8) {
                Text(video.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(3)

                Text(video.formattedSize)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 15)
            .padding(.bottom, 15)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(20)
    }
}
