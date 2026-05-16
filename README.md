# Video Client for tvOS

A lightweight tvOS video client app for browsing and playing videos from a video server. Features a grid-based UI optimized for TV viewing with standard SwiftUI components and AVPlayerViewController.

## Features

- **Server Configuration**: User-configurable server URL with validation
- **Grid Layout**: Netflix-style grid browsing optimized for TV
- **Directory Navigation**: Browse hierarchical folder structures
- **Video Playback**: Full-screen native video player with standard controls
- **Thumbnail Previews**: Async thumbnail loading from server
- **Focus Navigation**: Native tvOS focus engine support

## Architecture

- **Platform**: tvOS 15.0+
- **Language**: Swift 5.0
- **Framework**: SwiftUI
- **Pattern**: MVVM
- **Dependencies**: Zero external dependencies (Apple frameworks only)

## Project Setup

### Option 1: Create Xcode Project and Add Files

1. **Open Xcode** and select "Create a new Xcode project"

2. **Choose Template**:
   - Select "tvOS" → "App"
   - Click "Next"

3. **Configure Project**:
   - Product Name: `VideoClientTV`
   - Team: Select your development team
   - Organization Identifier: `com.yourcompany`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - Click "Next"

4. **Choose Location**:
   - Navigate to this directory: `/Users/anders/Documents/src/video-client-tvos`
   - **IMPORTANT**: Uncheck "Create Git repository" (already exists)
   - Click "Create"

5. **Delete Default Files**:
   - In the Project Navigator, delete the default `ContentView.swift` file (Move to Trash)

6. **Add Existing Files**:
   - Right-click on the `VideoClientTV` group in Project Navigator
   - Select "Add Files to VideoClientTV..."
   - Navigate to `/Users/anders/Documents/src/video-client-tvos/VideoClientTV/VideoClientTV/`
   - Select all the folders: `Models/`, `Services/`, `ViewModels/`, `Views/`
   - Also select `VideoClientTVApp.swift` and `Info.plist`
   - **IMPORTANT**: Check "Copy items if needed" is UNCHECKED (files already in place)
   - Click "Add"

7. **Configure Info.plist**:
   - In Project Navigator, select the project (VideoClientTV)
   - Select the VideoClientTV target
   - Go to "Build Settings" tab
   - Search for "Info.plist File"
   - Set the path to: `VideoClientTV/Info.plist`

8. **Configure Assets**:
   - Delete the default `Assets.xcassets` in Project Navigator
   - Add the existing `Assets.xcassets` folder from `VideoClientTV/VideoClientTV/`

9. **Set Deployment Target**:
   - Select the project in Project Navigator
   - Select the VideoClientTV target
   - Go to "General" tab
   - Set "Minimum Deployments" to tvOS 15.0

10. **Build and Run**:
    - Select an Apple TV simulator from the scheme selector
    - Press `Cmd+R` to build and run

### Option 2: Use Package.swift (Alternative - Advanced)

If you prefer using Swift Package Manager, you can create a Package.swift file. However, for tvOS apps, using Xcode project is recommended.

## Project Structure

```
VideoClientTV/
├── VideoClientTV/
│   ├── VideoClientTVApp.swift          # App entry point
│   ├── Info.plist                       # Network security config
│   ├── Assets.xcassets/                 # App icons and assets
│   ├── Models/                          # Data models
│   │   ├── VideoItem.swift
│   │   ├── DirectoryItem.swift
│   │   └── BrowseResponse.swift
│   ├── Services/                        # Network & persistence
│   │   ├── APIService.swift
│   │   └── ServerURLManager.swift
│   ├── ViewModels/                      # Business logic
│   │   └── DirectoryViewModel.swift
│   └── Views/                           # UI components
│       ├── ServerSetupView.swift        # Server configuration
│       ├── DirectoryBrowserView.swift   # Grid browser
│       └── VideoPlayerView.swift        # Video player
└── README.md
```

## Usage

### First Launch

1. App will show server setup screen
2. Enter your video server URL (e.g., `http://192.168.1.100:3000`)
3. Press "Connect" to validate and save

### Browsing Videos

- Use Apple TV remote directional buttons to navigate the grid
- Press "Select" on a directory to navigate into it
- Press "Select" on a video to start playback
- Press "Menu" button to go back

### Video Playback

- Video plays in full-screen with standard Apple TV controls
- Press "Menu" button to exit player and return to browser

### Settings

- Press the gear icon in the top-right to reconfigure server
- Press the refresh icon to reload the current directory

## API Requirements

The app expects a video server with these endpoints:

- `GET /api/health` - Health check (returns 200)
- `GET /api/browse` - Browse root directory
- `GET /api/browse/{path}` - Browse subdirectory
- `GET /api/video/{path}` - Stream video file
- `GET /api/thumbnail/{path}` - Get video thumbnail

See the iOS app's README for more details on the expected API format.

## Development

### Requirements

- macOS with Xcode 14.0+
- tvOS 15.0+ SDK
- Apple TV simulator or physical Apple TV device

### Testing

- **Simulator**: Use Apple TV 4K simulator in Xcode
- **Device**: Connect Apple TV via network or USB-C (Apple TV 4K 2nd gen+)

### Focus Testing

- Use simulator keyboard arrows to test focus navigation
- Verify focus effects are visible (scale, shadow)
- Test all interactive elements are focusable

## Key Differences from iOS Version

### UI Adaptations

- **Grid Layout**: Uses `LazyVGrid` instead of `List` for better TV experience
- **Typography**: Larger fonts (min 28pt body text) for 10ft viewing distance
- **Spacing**: Increased padding (60-80px) for TV safe areas
- **Focus**: Uses `.buttonStyle(.card)` for automatic focus effects

### Removed Features

- **Pull-to-Refresh**: Not available on tvOS (replaced with manual refresh button)
- **Touch Gestures**: All interaction via focus-based navigation

### tvOS-Specific Features

- **Focus Engine**: Automatic focus management with directional navigation
- **Card Style**: Standard tvOS card appearance with focus effects
- **Remote Support**: Optimized for Siri Remote and game controllers

## Troubleshooting

### App Won't Connect to Server

- Verify server is running and accessible on local network
- Check Info.plist has `NSAppTransportSecurity` → `NSAllowsArbitraryLoads` set to `true`
- Ensure Apple TV and server are on same network
- Try pinging server IP from another device

### Thumbnails Not Loading

- Check server returns thumbnails at `/api/thumbnail/{path}` endpoint
- Verify thumbnail URLs are accessible
- Check AsyncImage is receiving valid URLs

### Focus Navigation Issues

- Verify `.buttonStyle(.card)` is applied to focusable elements
- Check no overlapping views blocking focus
- Test with simulator keyboard arrows

### Build Errors

- Ensure all files are added to the Xcode project
- Verify deployment target is tvOS 15.0+
- Clean build folder (Cmd+Shift+K) and rebuild

## License

This project is companion to the iOS Video Client app.
